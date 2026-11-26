package com.newsblur.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull

/** PushMessagingService.kt receives the story pushes described in StoryPush.kt. */
class PushMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushMessaging.sync(applicationContext)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        // Firebase calls this off the main thread and keeps the device awake for about 20 seconds.
        runBlocking {
            withTimeoutOrNull(HANDLE_TIMEOUT_MILLIS) { StoryPush.from(applicationContext).handle(message.data) }
        }
    }

    private companion object {
        const val HANDLE_TIMEOUT_MILLIS = 15_000L
    }
}
