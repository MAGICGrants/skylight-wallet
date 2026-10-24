package org.magicgrants.skylight

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.view.WindowManager
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

    // App-neutral name shared with wallet-core's SecureScreenMixin: FLAG_SECURE
    // (no screenshots, recordings or casting) while a screen shows a secret.
    private val secureScreenChannel = "org.magicgrants.wallet/secure_screen"

    // Payment links (monero:) reach Dart over this channel and nowhere else; Dart
    // holds them until the user is past every lock (wallet_ui's PaymentLinkGate).
    // Flutter's own deep linking is off (the manifest's flutter_deeplinking_enabled
    // and the two overrides below), so no intent can name a screen: its data URI
    // and its "route" extra are both ignored.
    private val paymentLinksChannel = "org.magicgrants.wallet/payment_links"
    private val paymentLinkSchemes = setOf("monero")
    private var paymentLinks: MethodChannel? = null
    private var pendingPaymentLink: String? = null
    private var dartTakesPaymentLinks = false

    override fun getInitialRoute(): String? = null

    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity (rotation, a restored process) still carries the
        // intent it was opened with; that link was taken already.
        if (savedInstanceState == null) pendingPaymentLink = paymentLink(intent)
        super.onCreate(savedInstanceState)
        // Recents shows no picture of the wallet (Android 13 and later). Not
        // FLAG_SECURE, which would also stop the user's own screenshots; the
        // screens that show a secret add that themselves (SecureScreenMixin).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) setRecentsScreenshotEnabled(false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = paymentLink(intent) ?: return
        val channel = paymentLinks
        if (dartTakesPaymentLinks && channel != null) {
            channel.invokeMethod("link", link)
        } else {
            pendingPaymentLink = link
        }
    }

    // The payment link in a VIEW intent with one of [paymentLinkSchemes], or null.
    // Not one Android replays when the app is reopened from Recents, and not one
    // longer than any real payment link. Dart parses and checks it again.
    private fun paymentLink(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val uri = intent.data ?: return null
        val scheme = uri.scheme?.lowercase() ?: return null
        if (scheme !in paymentLinkSchemes) return null
        val link = uri.toString()
        return if (link.length <= MAX_PAYMENT_LINK_LENGTH) link else null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        paymentLinks = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, paymentLinksChannel)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Dart is listening: hand over the launch link, if any;
                        // later ones go straight over the channel.
                        "takeInitialLink" -> {
                            dartTakesPaymentLinks = true
                            result.success(pendingPaymentLink)
                            pendingPaymentLink = null
                        }
                        else -> result.notImplemented()
                    }
                }
            }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureScreenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.argument<Boolean>("secure") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
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

    companion object {
        private const val MAX_PAYMENT_LINK_LENGTH = 2048
    }
}
