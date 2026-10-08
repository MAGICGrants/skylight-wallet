package org.magicgrants.skylight

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // App-neutral name shared with wallet-core's SecureClipboard.
    private val secureClipboardChannel = "org.magicgrants.wallet/secure_clipboard"

    // App-neutral name shared with wallet-core's StoreReview. Which StoreReview
    // this resolves to -- Play's review flow or a no-op -- is chosen at build
    // time; see build.gradle.kts.
    private val storeReviewChannel = "org.magicgrants.wallet/store_review"

    // FIDO2 security keys over USB and NFC (FHSE wallet-file protection).
    private var securityKeyChannel: SecurityKeyChannel? = null

    // MainActivity is exported, so any app (or adb) can start it with an intent
    // that names a route, via the "route" extra or a data URI, and reach screens
    // past App Lock. The app takes no links, so ignore both: it always starts at
    // its own initial route, and a new intent never pushes one.
    override fun getInitialRoute(): String? = null

    override fun shouldHandleDeeplinking(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureClipboardChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copySensitive" -> {
                        copySensitive(call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    // Android 13 shows its own clipboard confirmation, so the
                    // app must not add a second one. Older releases show
                    // nothing and still need the in-app toast.
                    "systemConfirmsCopy" -> {
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storeReviewChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(StoreReview.isAvailable(this))
                    "requestReview" -> StoreReview.request(this) { result.success(it) }
                    else -> result.notImplemented()
                }
            }
        securityKeyChannel?.dispose()
        securityKeyChannel = SecurityKeyChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        securityKeyChannel?.dispose()
        securityKeyChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Copies [text] flagged as sensitive so keyboards/clipboard UIs don't show a
    // preview and it isn't synced. The extras key is honored on Android 13+
    // (ClipDescription.EXTRA_IS_SENSITIVE) and by some earlier OEM keyboards.
    private fun copySensitive(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clipboard.setPrimaryClip(clip)
    }
}
