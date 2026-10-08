package org.magicgrants.skylight

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * MethodChannel glue for FIDO2 security keys (FHSE proof of concept); see
 * SecurityKeyOperations for the CTAP work. One key operation at a time
 * (`busy` otherwise); key I/O runs on a background thread and every reply
 * is sent on the main thread.
 *
 * While an operation runs, its progress goes to Dart as `status` calls on the
 * same channel ({state, transport}), on the main thread, fire-and-forget, and
 * never after the operation's result.
 *
 * The `prompt` argument is accepted but unused: Android has no system NFC
 * sheet, so the Flutter UI shows its own instructions.
 */
class SecurityKeyChannel(activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val NAME = "org.magicgrants.skylight/security_key"

        private const val SALT_LENGTH = 32
        private const val MAX_USER_ID_LENGTH = 64

        private fun wipePin(verification: SecurityKeyOperations.Verification) {
            (verification as? SecurityKeyOperations.Verification.Pin)?.pin?.fill('\u0000')
        }

        private fun hmacSecretReply(r: SecurityKeyOperations.HmacSecretResult): Map<String, Any?> =
            mapOf("credentialId" to r.credentialId, "hmacSecret" to r.hmacSecret, "serial" to r.serial)
    }

    private val channel = MethodChannel(messenger, NAME)
    private val activityRef = WeakReference(activity)
    private val operations = SecurityKeyOperations(activity) { activityRef.get() }
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "security-key").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    // Main thread only.
    private var inFlight = false
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    /** Detaches from the engine and cancels anything in flight. Main thread. */
    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        operations.dispose()
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> {
                val capabilities = operations.capabilities()
                result.success(mapOf("nfc" to capabilities.nfc, "usb" to capabilities.usb))
            }
            "cancel" -> {
                operations.cancel()
                result.success(null)
            }
            "inspect", "setPin", "enroll", "getHmacSecret" -> startKeyOperation(call, result)
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------- operations

    /** Result of a key operation: the value to send, and a secret to wipe once it has been sent. */
    private class Reply(val value: Any?, val secret: ByteArray? = null)

    /** A parsed request. Holds copies of the PIN, salt and user id, which [wipe] overwrites. */
    private abstract class Request {
        abstract fun run(operations: SecurityKeyOperations, op: SecurityKeyOperations.Operation): Reply

        open fun wipe() {}
    }

    private class InspectRequest(val touch: Boolean) : Request() {
        override fun run(operations: SecurityKeyOperations, op: SecurityKeyOperations.Operation): Reply {
            val info = operations.inspect(op, touch)
            return Reply(
                mapOf(
                    "pinSet" to info.pinSet,
                    "pinRetries" to info.pinRetries,
                    "hmacSecret" to info.hmacSecret,
                    "credProtect" to info.credProtect,
                    "aaguid" to info.aaguid,
                    "versions" to info.versions,
                    "transport" to info.transport,
                    "uv" to info.uv,
                    "uvSupported" to info.uvSupported,
                    "uvRetries" to info.uvRetries,
                    "pinUvAuthToken" to info.pinUvAuthToken,
                    "minPinLength" to info.minPinLength,
                    "forcePinChange" to info.forcePinChange,
                    "touched" to info.touched,
                    "serial" to info.serial,
                ),
            )
        }
    }

    private class SetPinRequest(val newPin: CharArray, val expectSerial: Long?) : Request() {
        override fun run(operations: SecurityKeyOperations, op: SecurityKeyOperations.Operation): Reply {
            operations.setPin(op, newPin, expectSerial)
            return Reply(null)
        }

        override fun wipe() = newPin.fill('\u0000')
    }

    private class EnrollRequest(
        val rpId: String,
        val userId: ByteArray,
        val salt: ByteArray,
        val verification: SecurityKeyOperations.Verification,
        val excludeCredentialIds: List<ByteArray>,
        val expectSerial: Long?,
    ) : Request() {
        override fun run(operations: SecurityKeyOperations, op: SecurityKeyOperations.Operation): Reply {
            val r = operations.enroll(op, rpId, userId, salt, verification, excludeCredentialIds, expectSerial)
            return Reply(hmacSecretReply(r), r.hmacSecret)
        }

        override fun wipe() {
            wipePin(verification)
            salt.fill(0)
            userId.fill(0)
        }
    }

    private class GetHmacSecretRequest(
        val rpId: String,
        val salt: ByteArray,
        val verification: SecurityKeyOperations.Verification,
        val credentialIds: List<ByteArray>,
        val expectSerial: Long?,
    ) : Request() {
        override fun run(operations: SecurityKeyOperations, op: SecurityKeyOperations.Operation): Reply {
            val r = operations.getHmacSecret(op, rpId, salt, verification, credentialIds, expectSerial)
            return Reply(hmacSecretReply(r), r.hmacSecret)
        }

        override fun wipe() {
            wipePin(verification)
            salt.fill(0)
        }
    }

    /**
     * Sends one operation's status events to Dart: posted to the main thread,
     * fire-and-forget, and dropped once [open] is false (its result has been
     * sent) or the channel is disposed. SecurityKeyOperations drops repeats.
     */
    private inner class StatusSink {
        var open = true // main thread only

        fun post(state: String, transport: String?) {
            mainHandler.post {
                if (open && !disposed) {
                    channel.invokeMethod("status", mapOf("state" to state, "transport" to transport))
                }
            }
        }
    }

    private fun startKeyOperation(call: MethodCall, result: MethodChannel.Result) {
        if (inFlight) {
            result.error(SecurityKeyOperations.BUSY, "Another security key operation is in progress", null)
            return
        }
        val request = try {
            parseRequest(call)
        } catch (e: SecurityKeyException) {
            result.error(e.code, e.message, e.details)
            return
        }
        val status = StatusSink()
        val op = try {
            operations.beginOperation(status::post)
        } catch (e: SecurityKeyException) {
            request.wipe()
            result.error(e.code, e.message, e.details)
            return
        }

        inFlight = true
        try {
            executor.execute {
                var reply: Reply? = null
                var error: SecurityKeyException? = null
                try {
                    reply = request.run(operations, op)
                } catch (e: SecurityKeyException) {
                    error = e
                } catch (e: Throwable) {
                    error = SecurityKeyException(
                        SecurityKeyOperations.UNKNOWN,
                        "Security key error (${e.javaClass.simpleName})",
                    )
                } finally {
                    request.wipe()
                    operations.endOperation(op) // no status events after this
                }
                mainHandler.post {
                    inFlight = false
                    status.open = false // statuses still queued behind this are dropped
                    val failure = error
                    if (failure != null) {
                        result.error(failure.code, failure.message, failure.details)
                    } else {
                        // StandardMethodCodec encodes synchronously, so the secret can be wiped right after.
                        result.success(reply?.value)
                        reply?.secret?.fill(0)
                    }
                }
            }
        } catch (e: RejectedExecutionException) {
            inFlight = false
            status.open = false
            request.wipe()
            operations.endOperation(op)
            result.error(SecurityKeyOperations.UNKNOWN, "The security key channel is shut down", null)
        }
    }

    // ---------------------------------------------------------------- arguments

    private fun parseRequest(call: MethodCall): Request =
        when (call.method) {
            "inspect" -> InspectRequest(touchArgument(call))
            "setPin" -> {
                val expectSerial = expectSerialArgument(call)
                SetPinRequest(pinArgument(call, "newPin"), expectSerial)
            }
            "enroll" -> {
                val expectSerial = expectSerialArgument(call)
                val rpId = rpIdArgument(call)
                val userId = bytesArgument(call, "userId")
                if (userId.isEmpty() || userId.size > MAX_USER_ID_LENGTH) {
                    throw invalidArgument("userId must be 1 to $MAX_USER_ID_LENGTH bytes")
                }
                val salt = saltArgument(call)
                val excludeIds = bytesListArgument(call, "excludeCredentialIds", allowMissing = true)
                val verification = try {
                    verificationArgument(call)
                } catch (e: SecurityKeyException) {
                    salt.fill(0)
                    userId.fill(0)
                    throw e
                }
                EnrollRequest(rpId, userId, salt, verification, excludeIds, expectSerial)
            }
            "getHmacSecret" -> {
                val expectSerial = expectSerialArgument(call)
                val rpId = rpIdArgument(call)
                val salt = saltArgument(call)
                val credentialIds = bytesListArgument(call, "credentialIds", allowMissing = false)
                if (credentialIds.isEmpty()) {
                    salt.fill(0)
                    throw SecurityKeyException(
                        SecurityKeyOperations.NO_CREDENTIALS,
                        "No credential ids were given",
                    )
                }
                val verification = try {
                    verificationArgument(call)
                } catch (e: SecurityKeyException) {
                    salt.fill(0)
                    throw e
                }
                GetHmacSecretRequest(rpId, salt, verification, credentialIds, expectSerial)
            }
            else -> throw invalidArgument("Unknown method")
        }

    /**
     * `expectSerial`: optional int, the serial number of the key the user
     * chose. The codec sends a Dart int as an Integer or, when large, a Long.
     */
    private fun expectSerialArgument(call: MethodCall): Long? =
        when (val serial = call.argument<Any>("expectSerial")) {
            null -> null
            is Int -> serial.toLong()
            is Long -> serial
            else -> throw invalidArgument("expectSerial must be an int")
        }

    /** `touch`: optional bool, default false. */
    private fun touchArgument(call: MethodCall): Boolean =
        when (val touch = call.argument<Any>("touch")) {
            null -> false
            is Boolean -> touch
            else -> throw invalidArgument("touch must be a bool")
        }

    /**
     * `verification`: "pin" (the default when absent) needs a non-null `pin`,
     * copied for the request to wipe; "uv" uses the key's built-in UV and
     * ignores `pin`.
     */
    private fun verificationArgument(call: MethodCall): SecurityKeyOperations.Verification =
        when (call.argument<Any>("verification")) {
            null, "pin" -> SecurityKeyOperations.Verification.Pin(pinArgument(call, "pin"))
            "uv" -> SecurityKeyOperations.Verification.BuiltInUv
            else -> throw invalidArgument("verification must be \"pin\" or \"uv\"")
        }

    private fun invalidArgument(message: String) =
        SecurityKeyException(SecurityKeyOperations.UNKNOWN, "Invalid arguments: $message")

    private fun rpIdArgument(call: MethodCall): String {
        val rpId = call.argument<Any>("rpId") as? String
        if (rpId.isNullOrEmpty()) throw invalidArgument("rpId is required")
        return rpId
    }

    private fun pinArgument(call: MethodCall, key: String): CharArray {
        val pin = call.argument<Any>(key) as? String ?: throw invalidArgument("$key is required")
        return pin.toCharArray()
    }

    private fun bytesArgument(call: MethodCall, key: String): ByteArray =
        call.argument<Any>(key) as? ByteArray ?: throw invalidArgument("$key must be a Uint8List")

    private fun saltArgument(call: MethodCall): ByteArray {
        val salt = bytesArgument(call, "salt")
        if (salt.size != SALT_LENGTH) {
            salt.fill(0)
            throw invalidArgument("salt must be $SALT_LENGTH bytes")
        }
        return salt
    }

    private fun bytesListArgument(call: MethodCall, key: String, allowMissing: Boolean): List<ByteArray> {
        val raw = call.argument<Any>(key)
        if (raw == null && allowMissing) return emptyList()
        val list = raw as? List<*> ?: throw invalidArgument("$key must be a list of Uint8List")
        return list.map { it as? ByteArray ?: throw invalidArgument("$key must be a list of Uint8List") }
    }
}
