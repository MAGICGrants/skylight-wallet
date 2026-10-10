package org.magicgrants.skylight

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.yubico.yubikit.android.YubiKitManager
import com.yubico.yubikit.android.transport.nfc.NfcConfiguration
import com.yubico.yubikit.android.transport.nfc.NfcNotAvailable
import com.yubico.yubikit.android.transport.nfc.NfcYubiKeyDevice
import com.yubico.yubikit.android.transport.usb.UsbConfiguration
import com.yubico.yubikit.android.transport.usb.UsbYubiKeyDevice
import com.yubico.yubikit.core.YubiKeyDevice
import com.yubico.yubikit.core.application.ApplicationNotAvailableException
import com.yubico.yubikit.core.application.CommandException
import com.yubico.yubikit.core.application.CommandState
import com.yubico.yubikit.core.fido.CtapException
import com.yubico.yubikit.core.fido.FidoConnection
import com.yubico.yubikit.core.smartcard.ApduException
import com.yubico.yubikit.core.smartcard.SmartCardConnection
import com.yubico.yubikit.fido.ctap.ClientPin
import com.yubico.yubikit.fido.ctap.Ctap2Session
import com.yubico.yubikit.fido.ctap.PinUvAuthProtocol
import com.yubico.yubikit.fido.ctap.PinUvAuthProtocolV1
import com.yubico.yubikit.fido.ctap.PinUvAuthProtocolV2
import com.yubico.yubikit.fido.webauthn.AuthenticatorData
import com.yubico.yubikit.management.ManagementSession
import java.io.IOException
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * A failure that crosses the security key channel. [code] is one of the error
 * codes in the channel contract; [details] is the optional PlatformException
 * details (only `pinInvalid` and `uvInvalid` use it: the PIN or UV retries
 * left, or null).
 *
 * Messages never contain PINs, salts, user ids, credential ids, serial
 * numbers or secrets.
 */
class SecurityKeyException(
    val code: String,
    message: String,
    val details: Any? = null,
    cause: Throwable? = null,
) : Exception(message, cause)

/**
 * FIDO2 (CTAP2) operations for FHSE, driven through Yubico's yubikit-android
 * at the Ctap2Session / ClientPin level. FHSE needs a non-discoverable
 * credential under a non-domain rpId ("fhse:encryption") and a raw,
 * unhashed hmac-secret salt, neither of which the WebAuthn-level clients
 * allow, so this builds the CTAP requests itself.
 *
 * Threading: [beginOperation], [cancel], [dispose] and [capabilities] run on
 * the main thread. The key operations ([inspect], [setPin], [enroll],
 * [getHmacSecret]) block and must run on a worker thread; [endOperation] may
 * be called from any thread. Status events reach the operation's listener on
 * the worker thread; the listener moves them to the main thread itself.
 *
 * Nothing secret is logged or put in a status event, and no PIN/UV token
 * outlives the call that got it. The key's serial number is never logged.
 */
class SecurityKeyOperations(
    context: Context,
    private val activityProvider: () -> Activity?,
) {
    companion object {
        const val CANCELLED = "cancelled"
        const val TIMEOUT = "timeout"
        const val BUSY = "busy"
        const val PIN_NOT_SET = "pinNotSet"
        const val PIN_ALREADY_SET = "pinAlreadySet"
        const val PIN_INVALID = "pinInvalid"
        const val PIN_BLOCKED = "pinBlocked"
        const val PIN_AUTH_BLOCKED = "pinAuthBlocked"
        const val PIN_POLICY = "pinPolicy"
        const val NO_CREDENTIALS = "noCredentials"
        const val CREDENTIAL_EXCLUDED = "credentialExcluded"
        const val UNSUPPORTED = "unsupported"
        const val TRANSPORT = "transport"
        const val UNKNOWN = "unknown"
        const val UV_INVALID = "uvInvalid"
        const val UV_BLOCKED = "uvBlocked"
        const val UV_NOT_CONFIGURED = "uvNotConfigured"
        const val PIN_CHANGE_REQUIRED = "pinChangeRequired"
        const val DIFFERENT_KEY = "differentKey"

        // Status event states (native -> Dart `status`).
        private const val STATE_WAITING_FOR_KEY = "waitingForKey"
        private const val STATE_KEY_CONNECTED = "keyConnected"
        private const val STATE_PROCESSING = "processing"
        private const val STATE_TOUCH_NEEDED = "touchNeeded"
        private const val STATE_FINGERPRINT_NEEDED = "fingerprintNeeded"

        private const val USB = "usb"
        private const val NFC = "nfc"

        private const val TAG = "SecurityKey"

        /** How long to wait for a key to be inserted or tapped. */
        private const val KEY_WAIT_TIMEOUT_MS = 60_000L

        /** IsoDep transceive timeout; FIDO over NFC can be slow on weak fields. */
        private const val NFC_TIMEOUT_MS = 5_000

        /**
         * After an NFC operation, NFC reader mode stays on until the key leaves
         * the field (or this long), so Android doesn't re-dispatch the still
         * present tag (e.g. a YubiKey's NDEF OTP link) to another app.
         */
        private const val NFC_REMOVAL_GRACE_MS = 10_000L

        private const val DEFAULT_MAX_CREDENTIALS_IN_LIST = 8
        private const val HMAC_SECRET_LENGTH = 32
        private const val MIN_PIN_LENGTH = 4
        private const val MAX_PIN_BYTES = 63
        private const val CRED_PROTECT_UV_REQUIRED = 3
        private const val EXT_HMAC_SECRET = "hmac-secret"
        private const val EXT_CRED_PROTECT = "credProtect"
        private const val FHSE_USER_NAME = "FHSE Encryption"

        /** rp of the CTAP 2.0 touch request, which never creates a credential. */
        private const val TOUCH_RP_ID = "fhse:encryption"
        private const val PUBLIC_KEY = "public-key"
        private const val COSE_ES256 = -7

        /** clientDataHash = SHA-256({0x01}), as FHSE's libfido2 code uses clientdata {0x01}. */
        private fun clientDataHash(): ByteArray =
            MessageDigest.getInstance("SHA-256").digest(byteArrayOf(0x01))

        private val CANCEL_SENTINEL = Any()
    }

    data class Capabilities(val nfc: Boolean, val usb: Boolean)

    data class KeyInfo(
        val pinSet: Boolean,
        val pinRetries: Int?,
        val hmacSecret: Boolean,
        val credProtect: Boolean,
        val aaguid: ByteArray?,
        val versions: List<String>,
        val transport: String,
        /** options.uv == true: built-in UV (fingerprint) present and set up. */
        val uv: Boolean,
        /** options has a `uv` entry at all. */
        val uvSupported: Boolean,
        /** When [uv]; null if getUVRetries failed. */
        val uvRetries: Int?,
        val pinUvAuthToken: Boolean,
        val minPinLength: Int,
        val forcePinChange: Boolean,
        /** The authenticatorSelection touch happened. */
        val touched: Boolean,
        /** YubiKey serial number, or null (hidden, not a YubiKey, or unreadable). */
        val serial: Int?,
    )

    /**
     * [hmacSecret] is secret: the caller should overwrite it once it has been
     * sent. [serial] is that of the key that did the work, or null.
     */
    class HmacSecretResult(val credentialId: ByteArray, val hmacSecret: ByteArray, val serial: Int? = null)

    /** How [enroll] and [getHmacSecret] get the user verified for their PIN/UV auth tokens. */
    sealed class Verification {
        /** With the key's PIN. [pin] is not modified here; the caller wipes it. */
        class Pin(val pin: CharArray) : Verification()

        /** With the key's built-in UV (a YubiKey Bio's fingerprint reader). */
        object BuiltInUv : Verification()
    }

    /**
     * One key operation: its device queue, cancel state, status events and the
     * key it used. [onStatus] gets (state, transport) on the worker thread,
     * without consecutive repeats, until [endOperation]; it must not block.
     */
    class Operation internal constructor(private val onStatus: (String, String?) -> Unit) {
        internal val devices = LinkedBlockingQueue<Any>()

        private val statusLock = Any()
        private var lastState: String? = null // guarded by statusLock
        private var lastTransport: String? = null // guarded by statusLock
        private var statusClosed = false // guarded by statusLock

        /** Cancels the CTAP command in flight, and reports the key's keepalives. */
        internal val commandState: CommandState = KeepAliveState()

        @Volatile
        internal var cancelled = false

        /** Set when the operation talked to a key over NFC; read on the main thread. */
        @Volatile
        internal var nfcDevice: NfcYubiKeyDevice? = null

        /** `usb` / `nfc` while a key is attached, for status events. */
        @Volatile
        internal var transport: String? = null

        /** The user is verified by built-in UV, so a wait for the user is a wait for a finger. */
        @Volatile
        internal var builtInUv = false

        internal fun offer(device: YubiKeyDevice) {
            devices.offer(device)
        }

        internal fun cancel() {
            cancelled = true
            commandState.cancel()
            devices.offer(CANCEL_SENTINEL)
        }

        internal fun throwIfCancelled() {
            if (cancelled) throw SecurityKeyException(CANCELLED, "The operation was cancelled")
        }

        /** Sends [state] with the current transport, unless it repeats the last one or the operation is over. */
        internal fun report(state: String) {
            synchronized(statusLock) {
                val transport = transport
                if (statusClosed || (state == lastState && transport == lastTransport)) return
                lastState = state
                lastTransport = transport
                Log.i(TAG, "status: $state (${transport ?: "-"})")
                onStatus(state, transport)
            }
        }

        /** The key waits for the user: a touch, or a finger on the sensor in built-in UV mode. */
        internal fun reportUserNeeded() {
            report(if (builtInUv) STATE_FINGERPRINT_NEEDED else STATE_TOUCH_NEEDED)
        }

        /** No status events after this. */
        internal fun closeStatus() {
            synchronized(statusLock) { statusClosed = true }
        }

        /**
         * yubikit calls this on the thread running the command: over USB for every
         * CTAPHID keepalive (about every 100 ms), over NFC when the status changes.
         */
        private inner class KeepAliveState : CommandState() {
            override fun onKeepAliveStatus(status: Byte) = onKeepAlive(status, "yubikit")
        }

        private var keepAlives = 0 // worker thread only
        private var lastKeepAlive: Byte = -1 // worker thread only

        /**
         * A keepalive status, from yubikit's CommandState or, over USB, read off
         * the CTAPHID packet by [KeepAliveTap]: yubikit 3.1.0 and 3.2.1 pass the
         * high byte of the packet's length (always 0) instead of the status.
         */
        internal fun onKeepAlive(status: Byte, source: String) {
            // Demo-build diagnostics: the first keepalive of each kind, then every 40th.
            // yubikit's (wrong) zeros are logged once, not interleaved with the real ones.
            keepAlives++
            if ((source != "yubikit" || keepAlives == 1) && (status != lastKeepAlive || keepAlives % 40 == 0)) {
                Log.i(TAG, "keepalive status=$status from $source (#$keepAlives)")
                lastKeepAlive = status
            }
            when (status) {
                CommandState.STATUS_PROCESSING -> report(STATE_PROCESSING)
                CommandState.STATUS_UPNEEDED -> reportUserNeeded()
            }
        }
    }

    /**
     * Passes the FIDO HID connection through and reports the status byte of
     * each CTAPHID_KEEPALIVE initialization packet (CID 4 bytes, CMD, BCNTH,
     * BCNTL, status) to [op]. Continuation packets carry a sequence number
     * below 0x80 where the command byte would be, so they never match.
     */
    private class KeepAliveTap(private val inner: FidoConnection, private val op: Operation) : FidoConnection {
        override fun send(packet: ByteArray) = inner.send(packet)

        override fun receive(packet: ByteArray) {
            inner.receive(packet)
            if (packet.size > 7 && packet[4] == CTAPHID_KEEPALIVE) op.onKeepAlive(packet[7], "usb")
        }

        override fun close() = inner.close()

        companion object {
            private const val CTAPHID_KEEPALIVE = 0xBB.toByte()
        }
    }

    /** [serial]: the YubiKey serial number read before [ctap] was opened, or null. */
    private class KeySession(val ctap: Ctap2Session, val transport: String, val serial: Int?)

    private val appContext: Context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())

    private val lock = Any()
    private var current: Operation? = null // guarded by lock

    // Main thread only.
    private var yubiKitInstance: YubiKitManager? = null
    private var discoveryOwner: Operation? = null
    private var nfcActivity: Activity? = null

    private fun yubiKit(): YubiKitManager =
        yubiKitInstance ?: YubiKitManager(appContext).also { yubiKitInstance = it }

    // ---------------------------------------------------------------- lifecycle

    fun capabilities(): Capabilities {
        val usb = appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
        val adapter = NfcAdapter.getDefaultAdapter(appContext)
        return Capabilities(nfc = adapter != null && adapter.isEnabled, usb = usb)
    }

    /**
     * Registers a new operation and starts USB and NFC discovery for it. Main
     * thread only. Throws `busy` if another operation is in flight. [onStatus]
     * receives the operation's status events (state, transport) on the worker
     * thread; see [Operation].
     */
    fun beginOperation(onStatus: (state: String, transport: String?) -> Unit): Operation {
        check(Looper.myLooper() == Looper.getMainLooper()) { "beginOperation must run on the main thread" }
        val op = Operation(onStatus)
        synchronized(lock) {
            if (current != null) {
                throw SecurityKeyException(BUSY, "Another security key operation is in progress")
            }
            current = op
        }
        startDiscovery(op)
        return op
    }

    /** Releases [op], ends its status events and stops discovery. Safe to call more than once, from any thread. */
    fun endOperation(op: Operation) {
        op.closeStatus()
        synchronized(lock) {
            if (current === op) current = null
        }
        mainHandler.post { stopDiscovery(op) }
    }

    /** Cancels the operation in flight, if any: it fails with `cancelled`. */
    fun cancel() {
        val op = synchronized(lock) { current }
        op?.cancel()
    }

    /** Cancels everything and stops discovery now (the activity is going away). Main thread. */
    fun dispose() {
        cancel()
        discoveryOwner = null
        stopUsbDiscovery()
        stopNfcDiscovery()
    }

    // ---------------------------------------------------------------- discovery (main thread)

    private fun startDiscovery(op: Operation) {
        discoveryOwner = op
        val yubiKit = yubiKit()
        try {
            // Default filter: Yubico's vendor id. The listener runs once USB
            // permission is granted (Android asks the user the first time).
            yubiKit.startUsbDiscovery(UsbConfiguration()) { device -> op.offer(device) }
        } catch (e: RuntimeException) {
            Log.w(TAG, "USB discovery unavailable: ${e.javaClass.simpleName}")
        }

        // Still on from the previous NFC operation (waiting for its tag to
        // leave): stop it so its executor is shut down, then start afresh.
        stopNfcDiscovery()
        val activity = activityProvider()
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            Log.w(TAG, "No foreground activity; NFC discovery not started")
            return
        }
        try {
            val config = NfcConfiguration()
                .timeout(NFC_TIMEOUT_MS)
                .skipNdefCheck(true)
                .handleUnavailableNfc(false)
            yubiKit.startNfcDiscovery(config, activity) { device -> op.offer(device) }
            nfcActivity = activity
        } catch (e: NfcNotAvailable) {
            // No NFC hardware, or NFC switched off: USB only.
        } catch (e: RuntimeException) {
            Log.w(TAG, "NFC discovery unavailable: ${e.javaClass.simpleName}")
        }
    }

    private fun stopDiscovery(op: Operation) {
        if (discoveryOwner !== op) return // a newer operation owns discovery now
        val started = SystemClock.elapsedRealtime()
        stopUsbDiscovery()
        Log.i(TAG, "USB discovery stopped in ${SystemClock.elapsedRealtime() - started} ms")
        val nfcDevice = op.nfcDevice
        if (nfcDevice == null) {
            discoveryOwner = null
            stopNfcDiscovery()
            return
        }
        // Keep reader mode on until the tag leaves the field, so Android does not
        // hand the still-present key to another app; give up after a grace period.
        val finish = Runnable {
            if (discoveryOwner === op) {
                discoveryOwner = null
                stopNfcDiscovery()
            }
        }
        try {
            nfcDevice.remove { mainHandler.post(finish) }
        } catch (e: RuntimeException) {
            mainHandler.post(finish)
        }
        mainHandler.postDelayed(finish, NFC_REMOVAL_GRACE_MS)
    }

    private fun stopUsbDiscovery() {
        val yubiKit = yubiKitInstance ?: return
        try {
            yubiKit.stopUsbDiscovery()
        } catch (e: RuntimeException) {
            Log.w(TAG, "Stopping USB discovery failed: ${e.javaClass.simpleName}")
        }
    }

    private fun stopNfcDiscovery() {
        val yubiKit = yubiKitInstance ?: return
        val activity = nfcActivity ?: return
        nfcActivity = null
        try {
            yubiKit.stopNfcDiscovery(activity)
        } catch (e: RuntimeException) {
            Log.w(TAG, "Stopping NFC discovery failed: ${e.javaClass.simpleName}")
        }
    }

    // ---------------------------------------------------------------- operations (worker thread)

    /**
     * authenticatorGetInfo (+ getPinRetries when a PIN is set, getUVRetries when
     * built-in UV is set up). With [touch], over USB only, it then asks for a
     * touch with authenticatorSelection (CTAP 2.0 keys: a zero-length
     * pinUvAuthParam makeCredential); over NFC, holding the key is the presence.
     */
    fun inspect(op: Operation, touch: Boolean): KeyInfo = withKey(op) { session ->
        val info = session.ctap.cachedInfo
        val options = info.options
        val pinSet = options["clientPin"] == true
        val uv = options["uv"] == true
        val clientPin = ClientPin(session.ctap, pinProtocolFor(info))
        val retries = if (pinSet) guardCtap { clientPin.pinRetries.count } else null
        val uvRetries = if (uv) uvRetriesOrNull(clientPin) else null
        @Suppress("USELESS_CAST")
        val aaguid = (info.aaguid as ByteArray?)?.takeIf { it.size == 16 }?.copyOf()
        val touched = touch && session.transport == USB && requestTouch(op, session.ctap)
        KeyInfo(
            pinSet = pinSet,
            pinRetries = retries,
            hmacSecret = info.extensions.contains(EXT_HMAC_SECRET),
            credProtect = info.extensions.contains(EXT_CRED_PROTECT),
            aaguid = aaguid,
            versions = ArrayList(info.versions),
            transport = session.transport,
            uv = uv,
            uvSupported = options.containsKey("uv"),
            uvRetries = uvRetries,
            pinUvAuthToken = ClientPin.isTokenSupported(info),
            minPinLength = info.minPinLength,
            forcePinChange = info.forcePinChange,
            touched = touched,
            serial = session.serial,
        )
    }

    /**
     * Sets a PIN on a key that has none. [newPin] is not modified; the caller
     * wipes it. [expectSerial]: see [withKey].
     */
    fun setPin(op: Operation, newPin: CharArray, expectSerial: Long?) {
        withKey(op, expectSerial) { session ->
            val info = session.ctap.cachedInfo
            when (info.options["clientPin"]) {
                true -> throw SecurityKeyException(PIN_ALREADY_SET, "This security key already has a PIN")
                null -> throw SecurityKeyException(UNSUPPORTED, "This security key does not support a PIN")
            }
            checkNewPin(newPin, maxOf(MIN_PIN_LENGTH, info.minPinLength))
            op.throwIfCancelled()
            guardCtap { ClientPin(session.ctap, pinProtocolFor(info)).setPin(newPin) }
        }
    }

    /**
     * Creates the FHSE credential (hmac-secret, credProtect 3, non-discoverable)
     * and immediately evaluates hmac-secret with [salt] on it. A PIN token and a
     * built-in UV token both set the UV flag, so either gives the same secret.
     * [expectSerial]: see [withKey].
     */
    fun enroll(
        op: Operation,
        rpId: String,
        userId: ByteArray,
        salt: ByteArray,
        verification: Verification,
        excludeCredentialIds: List<ByteArray>,
        expectSerial: Long?,
    ): HmacSecretResult = withKey(op, expectSerial) { session ->
        val ctap = session.ctap
        val info = ctap.cachedInfo
        op.builtInUv = verification is Verification.BuiltInUv

        // a. Capabilities.
        val missing = listOf(EXT_HMAC_SECRET, EXT_CRED_PROTECT).filterNot { info.extensions.contains(it) }
        if (missing.isNotEmpty()) {
            throw SecurityKeyException(
                UNSUPPORTED,
                "This security key does not support the ${missing.joinToString(" and ")} extension" +
                    if (missing.size > 1) "s" else "",
            )
        }
        requireVerification(info, verification)

        // b. PIN/UV auth protocol.
        val protocol = pinProtocolFor(info)
        val clientPin = ClientPin(ctap, protocol)
        val clientDataHash = clientDataHash()

        // c. PIN/UV token for makeCredential + getAssertion, bound to rpId.
        val credentialId: ByteArray
        var token = getToken(op, clientPin, verification, ClientPin.PIN_PERMISSION_MC or ClientPin.PIN_PERMISSION_GA, rpId)
        try {
            // d. makeCredential.
            val excludeList = descriptors(usableCredentialIds(excludeCredentialIds, info))
            val pinUvAuthParam = protocol.authenticate(token, clientDataHash)
            op.throwIfCancelled()
            val credential = try {
                ctap.makeCredential(
                    clientDataHash,
                    mapOf("id" to rpId, "name" to rpId),
                    mapOf("id" to userId, "name" to FHSE_USER_NAME, "displayName" to FHSE_USER_NAME),
                    listOf(mapOf("type" to PUBLIC_KEY, "alg" to COSE_ES256)),
                    excludeList.ifEmpty { null },
                    mapOf(EXT_HMAC_SECRET to true, EXT_CRED_PROTECT to CRED_PROTECT_UV_REQUIRED),
                    null, // options: rk omitted (non-discoverable); uv comes from pinUvAuthParam
                    pinUvAuthParam,
                    protocol.version,
                    null,
                    op.commandState,
                )
            } catch (e: CtapException) {
                throw mapCtapException(e, op.builtInUv)
            }
            op.report(STATE_PROCESSING)

            val authData = parseAuthenticatorData(credential.authenticatorData)
            val extensions = authData.extensions
                ?: throw SecurityKeyException(UNSUPPORTED, "credProtect not applied")
            // As a number: the CBOR decoder may hand back an Integer or a Long.
            if ((extensions[EXT_CRED_PROTECT] as? Number)?.toInt() != CRED_PROTECT_UV_REQUIRED) {
                throw SecurityKeyException(UNSUPPORTED, "credProtect not applied")
            }
            if (extensions[EXT_HMAC_SECRET] != true) {
                throw SecurityKeyException(UNSUPPORTED, "hmac-secret not enabled for the new credential")
            }
            credentialId = authData.attestedCredentialData?.credentialId?.copyOf()
                ?: throw SecurityKeyException(UNKNOWN, "The security key returned no credential")
        } finally {
            token.fill(0)
        }

        // e. Fresh token: CTAP 2.1 clears the permissions after makeCredential.
        op.throwIfCancelled()
        token = getToken(op, clientPin, verification, ClientPin.PIN_PERMISSION_GA, rpId)
        try {
            // f. getAssertion with hmac-secret on the new credential.
            val result = try {
                hmacSecretAssertion(ctap, protocol, clientPin, token, rpId, clientDataHash, listOf(credentialId), salt, op)
            } catch (e: CtapException) {
                throw mapCtapException(e, op.builtInUv)
            }
            HmacSecretResult(credentialId, result.hmacSecret, session.serial)
        } finally {
            token.fill(0)
        }
    }

    /**
     * Evaluates hmac-secret with [salt] on whichever of [credentialIds] lives on
     * the key. [expectSerial]: see [withKey].
     */
    fun getHmacSecret(
        op: Operation,
        rpId: String,
        salt: ByteArray,
        verification: Verification,
        credentialIds: List<ByteArray>,
        expectSerial: Long?,
    ): HmacSecretResult = withKey(op, expectSerial) { session ->
        val ctap = session.ctap
        val info = ctap.cachedInfo
        op.builtInUv = verification is Verification.BuiltInUv
        if (!info.extensions.contains(EXT_HMAC_SECRET)) {
            throw SecurityKeyException(UNSUPPORTED, "This security key does not support the hmac-secret extension")
        }
        requireVerification(info, verification)

        val protocol = pinProtocolFor(info)
        val clientPin = ClientPin(ctap, protocol)
        val clientDataHash = clientDataHash()
        val ids = usableCredentialIds(credentialIds, info)
        val batchSize = (info.maxCredentialCountInList ?: DEFAULT_MAX_CREDENTIALS_IN_LIST)
            .coerceAtLeast(1)

        var found: HmacSecretResult? = null
        for (batch in ids.chunked(batchSize)) {
            op.throwIfCancelled()
            // A fresh token per batch: never rely on a token surviving a getAssertion.
            val token = getToken(op, clientPin, verification, ClientPin.PIN_PERMISSION_GA, rpId)
            try {
                found = hmacSecretAssertion(ctap, protocol, clientPin, token, rpId, clientDataHash, batch, salt, op)
            } catch (e: CtapException) {
                if (e.ctapError != CtapException.ERR_NO_CREDENTIALS) throw mapCtapException(e, op.builtInUv)
            } finally {
                token.fill(0)
            }
            if (found != null) break
        }
        val result = found
            ?: throw SecurityKeyException(NO_CREDENTIALS, "None of the enrolled credentials is on this security key")
        HmacSecretResult(result.credentialId, result.hmacSecret, session.serial)
    }

    // ---------------------------------------------------------------- CTAP helpers

    /**
     * authenticatorGetAssertion with the hmac-secret extension and ONE salt
     * (CTAP 2.1 §12.5): keyAgreement from the authenticator, encapsulate →
     * (platform key, sharedSecret), saltEnc = encrypt(sharedSecret, salt),
     * saltAuth = authenticate(sharedSecret, saltEnc); the output is
     * decrypt(sharedSecret, extension output). CtapExceptions propagate.
     */
    private fun hmacSecretAssertion(
        ctap: Ctap2Session,
        protocol: PinUvAuthProtocol,
        clientPin: ClientPin,
        token: ByteArray,
        rpId: String,
        clientDataHash: ByteArray,
        allowIds: List<ByteArray>,
        salt: ByteArray,
        op: Operation,
    ): HmacSecretResult {
        val keyAgreement = clientPin.sharedSecret // getKeyAgreement + encapsulate
        val platformKey = keyAgreement.first
        val sharedSecret = keyAgreement.second
        var saltEnc: ByteArray? = null
        var output: ByteArray? = null
        try {
            saltEnc = protocol.encrypt(sharedSecret, salt)
            val saltAuth = protocol.authenticate(sharedSecret, saltEnc)
            val hmacInput = HashMap<Int, Any>().apply {
                put(1, platformKey)
                put(2, saltEnc)
                put(3, saltAuth)
                if (protocol.version != PinUvAuthProtocolV1.VERSION) put(4, protocol.version)
            }
            val allowList = descriptors(allowIds)
            val pinUvAuthParam = protocol.authenticate(token, clientDataHash)

            op.throwIfCancelled()
            val assertion = ctap.getAssertions(
                rpId,
                clientDataHash,
                allowList,
                mapOf(EXT_HMAC_SECRET to hmacInput),
                null, // options: up defaults to true; uv comes from pinUvAuthParam
                pinUvAuthParam,
                protocol.version,
                op.commandState,
            ).first()
            op.report(STATE_PROCESSING)

            val authData = parseAuthenticatorData(assertion.authenticatorData)
            if (!authData.isUv) {
                // Without UV the key would answer with its non-UV CredRandom, a different secret.
                throw SecurityKeyException(UNSUPPORTED, "The security key did not verify the user for this assertion")
            }
            val encrypted = authData.extensions?.get(EXT_HMAC_SECRET) as? ByteArray
                ?: throw SecurityKeyException(UNSUPPORTED, "The security key returned no hmac-secret output")
            output = try {
                protocol.decrypt(sharedSecret, encrypted)
            } catch (e: RuntimeException) {
                throw SecurityKeyException(UNSUPPORTED, "The hmac-secret output could not be decrypted")
            }
            if (output.size != HMAC_SECRET_LENGTH) {
                throw SecurityKeyException(
                    UNSUPPORTED,
                    "The hmac-secret output is ${output.size} bytes, expected $HMAC_SECRET_LENGTH",
                )
            }

            val responseId = assertion.credential?.get("id") as? ByteArray
            val credentialId = responseId?.copyOf()
                ?: allowIds.singleOrNull()?.copyOf()
                ?: throw SecurityKeyException(UNKNOWN, "The security key did not say which credential it used")

            val result = HmacSecretResult(credentialId, output)
            output = null // ownership passes to the caller
            return result
        } finally {
            sharedSecret.fill(0)
            saltEnc?.fill(0)
            output?.fill(0)
        }
    }

    /**
     * A PIN/UV auth token with [permissions] bound to [rpId], from the PIN or
     * from the key's built-in UV as [verification] says. The caller wipes it.
     */
    private fun getToken(
        op: Operation,
        clientPin: ClientPin,
        verification: Verification,
        permissions: Int,
        rpId: String,
    ): ByteArray =
        when (verification) {
            is Verification.Pin -> getPinToken(clientPin, verification.pin, permissions, rpId)
            Verification.BuiltInUv -> getUvToken(op, clientPin, permissions, rpId)
        }

    /**
     * getPinUvAuthTokenUsingUvWithPermissions: the key waits for a finger on
     * its sensor (cancellable through the operation's CommandState). The
     * caller wipes the returned token.
     */
    private fun getUvToken(op: Operation, clientPin: ClientPin, permissions: Int, rpId: String): ByteArray {
        op.throwIfCancelled()
        op.report(STATE_FINGERPRINT_NEEDED)
        val token = try {
            clientPin.getUvToken(permissions, rpId, op.commandState)
        } catch (e: CtapException) {
            throw when (e.ctapError) {
                CtapException.ERR_UV_INVALID ->
                    SecurityKeyException(UV_INVALID, "Fingerprint not recognised", uvRetriesOrNull(clientPin), e)
                // CTAP 2.1: built-in UV not enabled (e.g. no fingerprint enrolled any more).
                CtapException.ERR_NOT_ALLOWED -> uvNotConfigured(e)
                else -> mapCtapException(e, builtInUv = true)
            }
        } catch (e: IllegalStateException) {
            // ClientPin's own check: options.pinUvAuthToken is not true.
            throw uvNotConfigured(e)
        }
        op.report(STATE_PROCESSING)
        return token
    }

    /**
     * Checks the key can verify the user as [verification] asks: a PIN that is
     * set and need not be changed first, or built-in UV that is set up and
     * hands out PIN/UV auth tokens.
     */
    private fun requireVerification(info: Ctap2Session.InfoData, verification: Verification) {
        when (verification) {
            is Verification.Pin -> {
                requirePinSet(info)
                if (info.forcePinChange) {
                    throw SecurityKeyException(
                        PIN_CHANGE_REQUIRED,
                        "This security key needs a new PIN before it can be used",
                    )
                }
            }
            Verification.BuiltInUv ->
                if (info.options["uv"] != true || !ClientPin.isTokenSupported(info)) throw uvNotConfigured()
        }
    }

    private fun uvNotConfigured(cause: Throwable? = null) =
        SecurityKeyException(
            UV_NOT_CONFIGURED,
            "This security key has no fingerprint set up for use without its PIN",
            cause = cause,
        )

    /**
     * authenticatorSelection (CTAP 2.1): the key blinks until it is touched.
     * True once touched. Keys older than CTAP 2.1 (YubiKey 5 firmware 5.2-5.4
     * lists only FIDO_2_0 / FIDO_2_1_PRE) use [requestTouchCtap20] instead;
     * keys that answer CTAP1_ERR_INVALID_COMMAND give false.
     */
    private fun requestTouch(op: Operation, ctap: Ctap2Session): Boolean {
        Log.i(TAG, "touch: versions=${ctap.cachedInfo.versions} selection=${supportsSelection(ctap.cachedInfo)}")
        if (!supportsSelection(ctap.cachedInfo)) return requestTouchCtap20(op, ctap)
        op.throwIfCancelled()
        op.report(STATE_TOUCH_NEEDED)
        try {
            ctap.selection(op.commandState)
            Log.i(TAG, "touch: selection returned")
        } catch (e: CtapException) {
            Log.i(TAG, "touch: selection failed ${e.errorName}")
            if (e.ctapError != CtapException.ERR_INVALID_COMMAND) throw mapCtapException(e)
            Log.d(TAG, "authenticatorSelection not supported; no touch requested")
            op.report(STATE_PROCESSING)
            return false
        }
        op.report(STATE_PROCESSING)
        return true
    }

    /** authenticatorSelection is CTAP 2.1: any FIDO_2_x version past 2.0 and the 2.1 preview. */
    private fun supportsSelection(info: Ctap2Session.InfoData): Boolean =
        info.versions.any { it.startsWith("FIDO_2_") && it != "FIDO_2_0" && it != "FIDO_2_1_PRE" }

    /**
     * The CTAP 2.0 way to wait for a touch, as browsers and libfido2 do it:
     * makeCredential with a zero-length pinUvAuthParam (CTAP 2.0 §5.1 step 2,
     * CTAP 2.1 §6.1.2 step 1). The key waits for a touch, then answers
     * PIN_INVALID (PIN set) or PIN_NOT_SET, creating nothing and using no PIN
     * retry. yubikit 3.1.0 sends the empty array as a zero-length CBOR byte
     * string (its args() drops only nulls). Keys without clientPin are not
     * asked; any other refusal is no touch. Cancel / timeout fail as usual.
     */
    private fun requestTouchCtap20(op: Operation, ctap: Ctap2Session): Boolean {
        if (!ctap.cachedInfo.options.containsKey("clientPin")) return false
        val userId = ByteArray(1).also { SecureRandom().nextBytes(it) }
        op.throwIfCancelled()
        op.report(STATE_TOUCH_NEEDED)
        try {
            ctap.makeCredential(
                ByteArray(32), // dummy clientDataHash
                mapOf("id" to TOUCH_RP_ID, "name" to TOUCH_RP_ID),
                mapOf("id" to userId, "name" to FHSE_USER_NAME, "displayName" to FHSE_USER_NAME),
                listOf(mapOf("type" to PUBLIC_KEY, "alg" to COSE_ES256)),
                null, // excludeList
                null, // extensions
                null, // options: rk omitted, so even a key that went ahead would store nothing
                ByteArray(0), // zero-length pinUvAuthParam: "wait for a touch"
                PinUvAuthProtocolV1.VERSION,
                null,
                op.commandState,
            )
            // Success: a key that made a (non-discoverable) credential anyway, after a touch.
            Log.i(TAG, "touch: ctap2.0 makeCredential returned")
        } catch (e: CtapException) {
            Log.i(TAG, "touch: ctap2.0 makeCredential answered ${e.errorName}")
            when (e.ctapError) {
                // Touched. Some CTAP 2.0 keys answer PIN_AUTH_INVALID; libfido2 counts it too.
                CtapException.ERR_PIN_INVALID,
                CtapException.ERR_PIN_NOT_SET,
                CtapException.ERR_PIN_AUTH_INVALID -> Unit
                CtapException.ERR_KEEPALIVE_CANCEL,
                CtapException.ERR_OPERATION_DENIED,
                CtapException.ERR_USER_ACTION_TIMEOUT,
                CtapException.ERR_ACTION_TIMEOUT -> throw mapCtapException(e)
                else -> {
                    Log.d(TAG, "Zero-length pinUvAuthParam refused (${e.errorName}); no touch requested")
                    op.report(STATE_PROCESSING)
                    return false
                }
            }
        }
        op.report(STATE_PROCESSING)
        return true
    }

    /**
     * getPinToken: getPinUvAuthTokenUsingPinWithPermissions when the key sets
     * options.pinUvAuthToken, else the legacy getPinToken (ClientPin decides
     * from the cached getInfo). The caller wipes the returned token.
     */
    private fun getPinToken(clientPin: ClientPin, pin: CharArray, permissions: Int, rpId: String): ByteArray {
        if (pin.size < MIN_PIN_LENGTH || utf8Length(pin) > MAX_PIN_BYTES) {
            // Cannot be the key's PIN; not sent, so no retry is used.
            throw SecurityKeyException(PIN_INVALID, "Incorrect PIN", pinRetriesOrNull(clientPin))
        }
        try {
            return clientPin.getPinToken(pin, permissions, rpId)
        } catch (e: CtapException) {
            if (e.ctapError == CtapException.ERR_PIN_INVALID) {
                throw SecurityKeyException(PIN_INVALID, "Incorrect PIN", pinRetriesOrNull(clientPin))
            }
            throw mapCtapException(e)
        } catch (e: IllegalArgumentException) {
            throw SecurityKeyException(PIN_INVALID, "Incorrect PIN", pinRetriesOrNull(clientPin))
        }
    }

    private fun pinRetriesOrNull(clientPin: ClientPin): Int? =
        try {
            clientPin.pinRetries.count
        } catch (e: Exception) {
            null
        }

    private fun uvRetriesOrNull(clientPin: ClientPin): Int? =
        try {
            clientPin.uvRetries
        } catch (e: Exception) {
            null
        }

    private fun requirePinSet(info: Ctap2Session.InfoData) {
        if (info.options["clientPin"] != true) {
            throw SecurityKeyException(PIN_NOT_SET, "This security key has no PIN set")
        }
    }

    private fun pinProtocolFor(info: Ctap2Session.InfoData): PinUvAuthProtocol =
        if (info.pinUvAuthProtocols.contains(PinUvAuthProtocolV2.VERSION)) {
            PinUvAuthProtocolV2()
        } else {
            PinUvAuthProtocolV1()
        }

    /** Drops ids this key could never have issued (empty, or longer than maxCredentialIdLength). */
    private fun usableCredentialIds(ids: List<ByteArray>, info: Ctap2Session.InfoData): List<ByteArray> {
        val maxLength = info.maxCredentialIdLength
        return ids.filter { it.isNotEmpty() && (maxLength == null || it.size <= maxLength) }
    }

    private fun descriptors(ids: List<ByteArray>): List<Map<String, Any>> =
        ids.map { mapOf("type" to PUBLIC_KEY, "id" to it) }

    private fun parseAuthenticatorData(bytes: ByteArray): AuthenticatorData =
        try {
            AuthenticatorData.parseFrom(ByteBuffer.wrap(bytes))
        } catch (e: RuntimeException) {
            throw SecurityKeyException(UNKNOWN, "The security key returned malformed authenticator data", cause = e)
        }

    /** PIN length rules for setPin: [minLength] code points, at most 63 UTF-8 bytes. */
    private fun checkNewPin(pin: CharArray, minLength: Int) {
        val codePoints = Character.codePointCount(pin, 0, pin.size)
        if (codePoints < minLength) {
            throw SecurityKeyException(PIN_POLICY, "The PIN must be at least $minLength characters")
        }
        if (utf8Length(pin) > MAX_PIN_BYTES) {
            throw SecurityKeyException(PIN_POLICY, "The PIN must be at most $MAX_PIN_BYTES bytes")
        }
        if (pin.size < MIN_PIN_LENGTH) {
            // yubikit counts UTF-16 units; unreachable unless minLength < 4.
            throw SecurityKeyException(PIN_POLICY, "The PIN must be at least $MIN_PIN_LENGTH characters")
        }
    }

    /** UTF-8 length without building a String copy of the PIN. */
    private fun utf8Length(chars: CharArray): Int {
        var length = 0
        var i = 0
        while (i < chars.size) {
            val cp = Character.codePointAt(chars, i)
            length += when {
                cp < 0x80 -> 1
                cp < 0x800 -> 2
                cp < 0x10000 -> 3
                else -> 4
            }
            i += Character.charCount(cp)
        }
        return length
    }

    /** Runs a short ClientPin command (getPinRetries / setPin), mapping CTAP errors. */
    private fun <T> guardCtap(block: () -> T): T =
        try {
            block()
        } catch (e: CtapException) {
            throw mapCtapException(e)
        } catch (e: IllegalArgumentException) {
            // yubikit's own PIN length checks; checkNewPin normally catches these first.
            throw SecurityKeyException(PIN_POLICY, "The PIN does not meet the security key's requirements")
        }

    /**
     * [builtInUv]: the operation verifies the user with built-in UV, so
     * PUAT_REQUIRED (the key wants a PIN token, its UV being blocked) is `uvBlocked`.
     * `uvInvalid` gets no retries here; [getUvToken] adds them.
     */
    private fun mapCtapException(e: CtapException, builtInUv: Boolean = false): SecurityKeyException {
        val code = when (e.ctapError) {
            CtapException.ERR_KEEPALIVE_CANCEL, CtapException.ERR_OPERATION_DENIED -> CANCELLED
            CtapException.ERR_USER_ACTION_TIMEOUT, CtapException.ERR_ACTION_TIMEOUT -> TIMEOUT
            CtapException.ERR_PIN_INVALID -> PIN_INVALID
            CtapException.ERR_PIN_BLOCKED -> PIN_BLOCKED
            CtapException.ERR_PIN_AUTH_BLOCKED -> PIN_AUTH_BLOCKED
            CtapException.ERR_PIN_NOT_SET -> PIN_NOT_SET
            CtapException.ERR_PIN_POLICY_VIOLATION -> PIN_POLICY
            CtapException.ERR_UV_INVALID -> UV_INVALID
            CtapException.ERR_UV_BLOCKED -> UV_BLOCKED
            CtapException.ERR_PUAT_REQUIRED -> if (builtInUv) UV_BLOCKED else UNKNOWN
            CtapException.ERR_NO_CREDENTIALS -> NO_CREDENTIALS
            CtapException.ERR_CREDENTIAL_EXCLUDED -> CREDENTIAL_EXCLUDED
            CtapException.ERR_UNSUPPORTED_EXTENSION,
            CtapException.ERR_UNSUPPORTED_ALGORITHM,
            CtapException.ERR_UNSUPPORTED_OPTION,
            CtapException.ERR_INVALID_COMMAND,
            CtapException.ERR_LIMIT_EXCEEDED,
            CtapException.ERR_REQUEST_TOO_LARGE -> UNSUPPORTED
            else -> UNKNOWN
        }
        val message = when (code) {
            CANCELLED -> "The operation was cancelled"
            TIMEOUT ->
                if (builtInUv) "No fingerprint was given in time" else "The security key was not touched in time"
            PIN_INVALID -> "Incorrect PIN"
            PIN_BLOCKED -> "The PIN is blocked; the security key must be reset"
            PIN_AUTH_BLOCKED -> "Too many incorrect PINs; remove and reinsert (or re-tap) the security key"
            PIN_NOT_SET -> "This security key has no PIN set"
            PIN_POLICY -> "The PIN does not meet the security key's requirements"
            UV_INVALID -> "Fingerprint not recognised"
            UV_BLOCKED -> "Fingerprint verification is blocked; use the PIN"
            NO_CREDENTIALS -> "None of the enrolled credentials is on this security key"
            CREDENTIAL_EXCLUDED -> "This security key is already enrolled"
            else -> when (e.ctapError) {
                CtapException.ERR_LIMIT_EXCEEDED, CtapException.ERR_REQUEST_TOO_LARGE ->
                    "Too many credential ids for this security key (${e.errorName})"
                else -> e.message ?: "CTAP error"
            }
        }
        return SecurityKeyException(code, message, cause = e)
    }

    // ---------------------------------------------------------------- connection

    /**
     * Waits for a key (USB or NFC, whichever comes first), opens a CTAP2
     * session on it (USB: FIDO HID; NFC: ISO-DEP), runs [block] and closes the
     * session. Maps every failure to a [SecurityKeyException]. Reports
     * waitingForKey, then keyConnected when a key turns up, then processing
     * once its CTAP2 session is open.
     *
     * [expectSerial]: when set and the key reports a different serial number,
     * fails with `differentKey` before [block] runs, so no PIN, UV token
     * request or setPin reaches the wrong key. A key without a readable serial
     * passes.
     */
    private fun <T> withKey(op: Operation, expectSerial: Long? = null, block: (KeySession) -> T): T {
        try {
            val deadline = SystemClock.elapsedRealtime() + KEY_WAIT_TIMEOUT_MS
            op.transport = null
            op.report(STATE_WAITING_FOR_KEY)
            while (true) {
                val device = awaitDevice(op, deadline)
                Log.i(TAG, "device offered: ${device.javaClass.simpleName}")
                op.transport = transportOf(device)
                op.report(STATE_KEY_CONNECTED)
                val session = try {
                    openSession(device, op)
                } catch (e: Exception) {
                    op.throwIfCancelled()
                    if (device is NfcYubiKeyDevice &&
                        (e is IOException || e is ApplicationNotAvailableException)
                    ) {
                        // The tap was too short, or the tag is not a FIDO key: wait for another tap.
                        Log.d(TAG, "Ignoring NFC tag: ${e.javaClass.simpleName}")
                        op.transport = null
                        op.report(STATE_WAITING_FOR_KEY)
                        continue
                    }
                    throw e
                }
                if (device is NfcYubiKeyDevice) op.nfcDevice = device
                Log.i(
                    TAG,
                    "session open: fw=${session.ctap.version} versions=${session.ctap.cachedInfo.versions} " +
                        "serial=${if (session.serial != null) "read" else "none"}",
                )
                op.report(STATE_PROCESSING)
                try {
                    op.throwIfCancelled()
                    val serial = session.serial
                    if (expectSerial != null && serial != null && serial.toLong() != expectSerial) {
                        throw SecurityKeyException(DIFFERENT_KEY, "This is not the expected security key")
                    }
                    val value = block(session)
                    Log.i(TAG, "operation finished on the key")
                    return value
                } finally {
                    closeQuietly(session.ctap) // also closes the connection
                }
            }
        } catch (e: Exception) {
            val mapped = toSecurityKeyException(e, op.builtInUv)
            if (op.cancelled && mapped.code in setOf(TRANSPORT, UNKNOWN, TIMEOUT)) {
                throw SecurityKeyException(CANCELLED, "The operation was cancelled", cause = e)
            }
            // Demo-build diagnostics: the failure and its cause chain, never secrets.
            val ctap = generateSequence<Throwable>(e) { it.cause }.filterIsInstance<CtapException>().firstOrNull()
            val chain = generateSequence<Throwable>(e) { it.cause }.take(4)
                .joinToString(" <- ") { "${it.javaClass.simpleName}(${it.message?.take(80) ?: ""})" }
            Log.w(TAG, "Security key operation failed: ${mapped.code}; ${ctap?.errorName ?: "-"}; $chain")
            throw mapped
        }
    }

    private fun awaitDevice(op: Operation, deadline: Long): YubiKeyDevice {
        while (true) {
            op.throwIfCancelled()
            val remaining = deadline - SystemClock.elapsedRealtime()
            if (remaining <= 0) {
                throw SecurityKeyException(TIMEOUT, "No security key was found within 60 seconds")
            }
            val item = op.devices.poll(remaining, TimeUnit.MILLISECONDS)
            if (item is YubiKeyDevice) return item
            // null (time left elapsed) or the cancel sentinel: loop to re-check.
        }
    }

    private fun transportOf(device: YubiKeyDevice): String? =
        when (device) {
            is UsbYubiKeyDevice -> USB
            is NfcYubiKeyDevice -> NFC
            else -> null
        }

    /**
     * Opens the key's connection, reads its serial number ([readSerial]) and
     * then opens the CTAP2 session on the same connection.
     */
    private fun openSession(device: YubiKeyDevice, op: Operation): KeySession =
        when (device) {
            // USB: CTAPHID over the key's FIDO HID interface.
            is UsbYubiKeyDevice -> {
                if (!device.supportsConnection(FidoConnection::class.java)) {
                    throw SecurityKeyException(UNSUPPORTED, "This security key has FIDO disabled over USB")
                }
                var connection = openFidoConnection(device, op)
                var serial: Int? = null
                try {
                    serial = readSerial { ManagementSession(connection) }
                } catch (e: IOException) {
                    // The CTAPHID exchange broke off and may have left packets
                    // behind: CTAP2 starts on a fresh connection.
                    closeQuietly(connection)
                    connection = openFidoConnection(device, op)
                }
                try {
                    KeySession(startCtap2 { Ctap2Session(connection) }, USB, serial)
                } catch (e: Throwable) {
                    closeQuietly(connection)
                    throw e
                }
            }
            // NFC: ISO 7816 (IsoDep). The Management applet is selected first,
            // then the FIDO applet by Ctap2Session. If the serial read lost the
            // tag, opening CTAP2 fails too and withKey waits for another tap.
            is NfcYubiKeyDevice -> {
                val connection = device.openConnection(SmartCardConnection::class.java)
                try {
                    val serial = try {
                        readSerial { ManagementSession(connection) }
                    } catch (e: IOException) {
                        null
                    }
                    KeySession(startCtap2 { Ctap2Session(connection) }, NFC, serial)
                } catch (e: Throwable) {
                    closeQuietly(connection)
                    throw e
                }
            }
            else -> throw SecurityKeyException(UNSUPPORTED, "Unsupported security key transport")
        }

    private fun openFidoConnection(device: UsbYubiKeyDevice, op: Operation): FidoConnection =
        try {
            KeepAliveTap(device.openConnection(FidoConnection::class.java), op)
        } catch (e: IllegalStateException) {
            // USB permission revoked, or the key was unplugged.
            throw SecurityKeyException(TRANSPORT, "Could not open the security key", cause = e)
        }

    /**
     * The YubiKey serial number, from the Management application
     * (ManagementSession -> getDeviceInfo -> serialNumber), read before the
     * CTAP2 session: on a smart card, selecting Management after FIDO would
     * undo the FIDO applet selection. Over USB it is a Yubico vendor CTAPHID
     * command on the FIDO interface. Null when the key hides it, is not a
     * YubiKey, or the read fails: the serial never fails an operation. Only an
     * IOException (the link may be in an unknown state) is thrown, for the
     * caller to recover from. The ManagementSession is deliberately not closed:
     * closing it closes the connection. The serial is never logged.
     */
    private fun readSerial(open: () -> ManagementSession): Int? =
        try {
            open().deviceInfo.serialNumber
        } catch (e: IOException) {
            Log.d(TAG, "Serial number not read: ${e.javaClass.simpleName}")
            throw e
        } catch (e: Exception) {
            // Not a YubiKey / no Management applet, firmware before 4.1
            // (UnsupportedOperationException), or a malformed response.
            Log.d(TAG, "Serial number not read: ${e.javaClass.simpleName}")
            null
        }

    /**
     * Opens the CTAP2 session (which runs authenticatorGetInfo). A key whose FIDO
     * application answers but rejects CTAP2 (a U2F-only key) is `unsupported`.
     */
    private fun startCtap2(open: () -> Ctap2Session): Ctap2Session =
        try {
            open()
        } catch (e: CtapException) {
            throw SecurityKeyException(UNSUPPORTED, "This security key does not support FIDO2", cause = e)
        } catch (e: ApduException) {
            throw SecurityKeyException(UNSUPPORTED, "This security key does not support FIDO2", cause = e)
        }

    private fun closeQuietly(closeable: java.io.Closeable) {
        try {
            closeable.close()
        } catch (e: IOException) {
            // Already gone.
        }
    }

    private fun toSecurityKeyException(e: Exception, builtInUv: Boolean): SecurityKeyException =
        when (e) {
            is SecurityKeyException -> e
            is InterruptedException -> {
                Thread.currentThread().interrupt()
                SecurityKeyException(CANCELLED, "The operation was cancelled", cause = e)
            }
            is CtapException -> mapCtapException(e, builtInUv)
            is ApplicationNotAvailableException ->
                SecurityKeyException(UNSUPPORTED, "This security key does not support FIDO2", cause = e)
            is IOException ->
                SecurityKeyException(TRANSPORT, "Lost the connection to the security key", cause = e)
            is CommandException ->
                SecurityKeyException(UNKNOWN, e.message ?: e.javaClass.simpleName, cause = e)
            else -> SecurityKeyException(UNKNOWN, "Security key error (${e.javaClass.simpleName})", cause = e)
        }
}
