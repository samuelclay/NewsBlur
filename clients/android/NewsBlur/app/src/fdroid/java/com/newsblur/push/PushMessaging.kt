package com.newsblur.push

import android.content.Context

/** PushMessaging.kt: F-Droid ships no push service, so notifications come from the background sync in SyncService.kt. */
object PushMessaging {
    @JvmStatic
    @Suppress("UNUSED_PARAMETER")
    fun sync(context: Context) = Unit

    @JvmStatic
    @Suppress("UNUSED_PARAMETER")
    fun forgetDevice(context: Context) = Unit
}
