package com.newsblur.util

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object PendingIntentUtils {

    @JvmStatic
    fun getImmutableActivity(
            context: Context, requestCode: Int,
            intent: Intent, flags: Int): PendingIntent? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getActivity(context, requestCode, intent, flags or PendingIntent.FLAG_IMMUTABLE, null)
            } else {
                PendingIntent.getActivity(context, requestCode, intent, flags, null)
            }

    @JvmStatic
    fun getImmutableBroadcast(
            context: Context, requestCode: Int,
            intent: Intent, flags: Int): PendingIntent? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getBroadcast(context, requestCode, intent, flags or PendingIntent.FLAG_IMMUTABLE)
            } else {
                PendingIntent.getBroadcast(context, requestCode, intent, flags)
            }
}