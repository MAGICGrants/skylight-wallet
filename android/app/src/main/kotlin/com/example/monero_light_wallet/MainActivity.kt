package org.magicgrants.skylight

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureClipboardChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copySensitive" -> {
                        copySensitive(
                            call.argument<String>("text") ?: "",
                            call.argument<Int>("clearAfterSeconds") ?: 60,
                        )
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
    }

    private val clipboardHandler = Handler(Looper.getMainLooper())
    private var pendingClipClear: Runnable? = null

    // Copies [text] flagged as sensitive so keyboards/clipboard UIs don't show a
    // preview and it isn't synced. The extras key is honored on Android 13+
    // (ClipDescription.EXTRA_IS_SENSITIVE) and by some earlier OEM keyboards.
    private fun copySensitive(text: String, clearAfterSeconds: Int) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clipboard.setPrimaryClip(clip)

        // Clear natively after the timeout: the Dart timer reads the clipboard
        // first, which Android 10+ blocks for a backgrounded app. Writing isn't.
        pendingClipClear?.let { clipboardHandler.removeCallbacks(it) }
        if (clearAfterSeconds <= 0) return
        val clear = Runnable {
            pendingClipClear = null
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    clipboard.clearPrimaryClip()
                } else {
                    clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                }
            } catch (_: Exception) {}
        }
        pendingClipClear = clear
        clipboardHandler.postDelayed(clear, clearAfterSeconds * 1000L)
    }
}
