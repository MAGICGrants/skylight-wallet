package org.magicgrants.skylight

import android.app.Activity
import android.content.Context
import android.os.Build
import com.google.android.play.core.review.ReviewManagerFactory

// Google Play build: the in-app review flow, for installs Google Play made.
// Compiled in only when the build passes -PplayStore=true; see build.gradle.kts.
object StoreReview {
    private const val PLAY_STORE = "com.android.vending"

    // Whether Google Play installed this app. A local package-manager lookup:
    // nothing here talks to Play, and everything that would is gated on it. The
    // same bundle is attached to GitHub releases, so a copy installed by hand
    // lands here too -- and must not reach Play.
    fun isAvailable(context: Context): Boolean = installerOf(context) == PLAY_STORE

    // Replies true once Play has been asked, whatever it then showed: Play
    // reports neither whether the card appeared nor whether the user rated.
    fun request(activity: Activity, reply: (Boolean) -> Unit) {
        if (!isAvailable(activity)) {
            reply(false)
            return
        }
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful) {
                reply(true)
                return@addOnCompleteListener
            }
            manager.launchReviewFlow(activity, request.result).addOnCompleteListener { reply(true) }
        }
    }

    @Suppress("DEPRECATION")
    private fun installerOf(context: Context): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            context.packageManager.getInstallerPackageName(context.packageName)
        }
    } catch (_: Exception) {
        null
    }
}
