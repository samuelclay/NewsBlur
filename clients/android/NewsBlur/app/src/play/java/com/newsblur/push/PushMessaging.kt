package com.newsblur.push

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.newsblur.util.NBScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * PushMessaging.kt keeps NewsBlur's copy of this install's Firebase Cloud Messaging token in step with whether the
 * device wants pushes (StoryPush.kt). The token is only created once notifications are on, and is deleted when
 * they are turned off or the account signs out, so the server stops sending here.
 */
object PushMessaging {
    /** False in a build made without google-services.json (app/src/play/dependencies.gradle): Firebase never starts. */
    private fun isAvailable(context: Context): Boolean = FirebaseApp.getApps(context).isNotEmpty()

    @JvmStatic
    fun sync(context: Context) {
        val appContext = context.applicationContext
        if (!isAvailable(appContext)) return
        val storyPush = StoryPush.from(appContext)
        if (storyPush.wantsPushes()) {
            FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                NBScope.launch(Dispatchers.IO) { storyPush.registerToken(token) }
            }
        } else {
            forgetDevice(appContext)
        }
    }

    /** PrefsRepo.kt calls this on sign-out, before it clears the stored token. */
    @JvmStatic
    fun forgetDevice(context: Context) {
        val appContext = context.applicationContext
        if (!isAvailable(appContext)) return
        val storyPush = StoryPush.from(appContext)
        if (!storyPush.hasRegisteredToken()) return
        // The server drops the token the first time Firebase reports it unregistered (apps/notifications/models.py).
        FirebaseMessaging.getInstance().deleteToken()
        storyPush.clearRegisteredToken()
    }
}
