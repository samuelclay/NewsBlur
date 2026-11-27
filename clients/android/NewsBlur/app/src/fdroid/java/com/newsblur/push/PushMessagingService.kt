package com.newsblur.push

import android.app.Service
import android.content.Intent
import android.os.IBinder

/** AndroidManifest.xml disables this service in F-Droid; PushMessaging.kt explains why. */
class PushMessagingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}
