package com.newsblur.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.runBlocking

/** PushMessagingService.kt receives the story pushes described in StoryPush.kt. */
class PushMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushMessaging.sync(applicationContext)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        // Firebase calls this off the main thread. StoryPush.kt bounds the work with its own deadline.
        runBlocking { StoryPush.from(applicationContext).deliver(message.data) }
    }
}
