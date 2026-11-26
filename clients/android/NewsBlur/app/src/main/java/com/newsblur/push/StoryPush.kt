package com.newsblur.push

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconFileCache
import com.newsblur.network.FeedApi
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceUtil
import com.newsblur.util.DeviceNotifications
import com.newsblur.util.FileCache
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import dagger.Lazy
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject
import javax.inject.Singleton

/**
 * StoryPush.kt: this device's side of the pushes that apps/notifications/models.py send_android sends through
 * Firebase Cloud Messaging. A push carries only a story hash. The device fetches that story and posts the
 * notification NotificationUtils.java already builds for the background sync, so read state, dismissals and the
 * feed's Android setting still decide what shows. PushMessaging.kt holds the Firebase calls and only exists in
 * the Play build; F-Droid keeps relying on the background sync in SyncService.kt.
 */
@Singleton
class StoryPush
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        // NbApplication.kt warms the database on IO; StoryPush.kt only touches it from background work.
        private val dbHelper: Lazy<BlurDatabaseHelper>,
        private val storyApi: StoryApi,
        private val feedApi: FeedApi,
        private val prefsRepo: PrefsRepo,
        @param:IconFileCache private val iconCache: FileCache,
    ) {
        /** Pushes are only useful to a signed-in device that can post notifications (DeviceNotifications.kt). */
        fun wantsPushes(): Boolean = prefsRepo.getUserId() != null && DeviceNotifications.isOn(context, prefsRepo)

        fun hasRegisteredToken(): Boolean = prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "").isNotEmpty()

        fun clearRegisteredToken() = prefsRepo.putString(PrefConstants.PUSH_TOKEN_REGISTERED, "")

        /**
         * Tells NewsBlur which token reaches this device. Returns whether the server has it, so a failure is
         * retried the next time PushMessaging.kt syncs.
         */
        suspend fun registerToken(token: String): Boolean {
            if (!wantsPushes()) return false
            if (prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "") == token) return true
            val response = feedApi.registerPushToken(token)
            // The endpoint answers success with a message, which NewsBlurResponse.isError treats as an error.
            if (response == null || response.isProtocolError || response.code == -1) return false
            prefsRepo.putString(PrefConstants.PUSH_TOKEN_REGISTERED, token)
            return true
        }

        /** Returns whether the pushed story was fetched and this device's notifications were refreshed. */
        suspend fun handle(data: Map<String, String>): Boolean {
            val storyHash = data[KEY_STORY_HASH]
            if (storyHash.isNullOrEmpty()) return false
            // A token outlives a sign-out until Firebase forgets it, so the previous account's push can land here.
            val userId = prefsRepo.getUserId() ?: return false
            if (data[KEY_USER_ID] != userId) return false
            if (!DeviceNotifications.isOn(context, prefsRepo)) return false

            val response = storyApi.getStoriesByHash(listOf(storyHash))
            if (!SyncServiceUtil.isStoryResponseGood(response) || response!!.isProtocolError) return false
            val database = dbHelper.get()
            database.insertStories(response, prefsRepo.getStateFilter(), false)
            NotificationUtils.notifyUnreadStories(context, database, iconCache)
            return true
        }

        @EntryPoint
        @InstallIn(SingletonComponent::class)
        interface StoryPushEntryPoint {
            fun storyPush(): StoryPush
        }

        companion object {
            // Keys of the data message built by apps/notifications/models.py send_android.
            const val KEY_STORY_HASH = "story_hash"
            const val KEY_USER_ID = "user_id"

            @JvmStatic
            fun from(context: Context): StoryPush =
                EntryPointAccessors
                    .fromApplication(context.applicationContext, StoryPushEntryPoint::class.java)
                    .storyPush()
        }
    }
