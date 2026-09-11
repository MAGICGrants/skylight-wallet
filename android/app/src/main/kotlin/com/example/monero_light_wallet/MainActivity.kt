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
    // App-neutral name shared with wallet-core's SecureClipboard (D10).
    private val secureClipboardChannel = "org.magicgrants.wallet/secure_clipboard"

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
