package org.magicgrants.skylight

import android.app.Activity
import android.content.Context

// F-Droid and GitHub build: no Google Play library is compiled in, so there is
// no store to ask and no code that could reach Play. See build.gradle.kts.
object StoreReview {
    @Suppress("UNUSED_PARAMETER")
    fun isAvailable(context: Context): Boolean = false

    @Suppress("UNUSED_PARAMETER")
    fun request(activity: Activity, reply: (Boolean) -> Unit) = reply(false)
}
