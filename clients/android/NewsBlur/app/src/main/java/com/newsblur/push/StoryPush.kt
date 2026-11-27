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
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject
import javax.inject.Singleton

/**
 * StoryPush.kt: this device's side of the pushes that apps/notifications/models.py send_android sends through
 * Firebase Cloud Messaging. A push carries only a story hash. The server has already decided the story is for
 * this account's Android devices, by a feed's setting or by a classifier match. The device fetches the story and
 * posts the notification NotificationUtils.java builds for the background sync, unless the story was read or
 * dismissed since. PushMessaging.kt holds the Firebase calls and only exists in the Play build; F-Droid keeps
 * relying on the background sync in SyncService.kt.
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
        // Test_StoryPush.kt moves this clock to check when a token is sent again.
        internal var clock: () -> Long = { System.currentTimeMillis() }

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
            if (isRegistrationFresh(token)) return true
            val response = feedApi.registerPushToken(token)
            // The endpoint answers success with a message, which NewsBlurResponse.isError treats as an error.
            if (response == null || response.isProtocolError || response.code == -1) return false
            prefsRepo.putString(PrefConstants.PUSH_TOKEN_REGISTERED, token)
            prefsRepo.putLong(PrefConstants.PUSH_TOKEN_REGISTERED_AT, clock())
            return true
        }

        // StoryPush.kt sends an unchanged token again once a day. The server drops a token Firebase reports dead
        // (apps/notifications/models.py), and a device that never sent it again would stop getting pushes for good.
        private fun isRegistrationFresh(token: String): Boolean =
            prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "") == token &&
                clock() - prefsRepo.getLong(PrefConstants.PUSH_TOKEN_REGISTERED_AT, 0L) < REGISTRATION_FRESH_MILLIS

        /**
         * PushMessagingService.kt calls this for each push. Firebase keeps the device awake for about 20 seconds per
         * message, and the requests in [handle] are the cancellable kind, so this deadline really ends them.
         */
        suspend fun deliver(data: Map<String, String>): Boolean = withTimeoutOrNull(DELIVERY_DEADLINE_MILLIS) { handle(data) } ?: false

        /** Returns whether the pushed story was fetched and handed to NotificationUtils.java. */
        suspend fun handle(data: Map<String, String>): Boolean {
            val storyHash = data[KEY_STORY_HASH]
            val feedId = data[KEY_STORY_FEED_ID]
            if (storyHash.isNullOrEmpty() || feedId.isNullOrEmpty()) return false
            // A token outlives a sign-out until Firebase forgets it, so the previous account's push can land here.
            val userId = prefsRepo.getUserId() ?: return false
            if (data[KEY_USER_ID] != userId) return false
            if (!DeviceNotifications.isOn(context, prefsRepo)) return false

            // A push can wait at Firebase for hours, and a lookup by hash cannot say whether the story was read since
            // (StoryApiImpl.kt). It is only shown while the server still lists it among the feed's unread stories.
            val unread = storyApi.getUnreadStoryHashes(listOf(feedId), cancellable = true)
            if (unread.isError || !unread.authenticated) return false
            if (unread.unreadHashes?.get(feedId)?.any { it.firstOrNull() == storyHash } != true) return false

            val response = storyApi.getStoriesByHash(listOf(storyHash), cancellable = true)
            if (!SyncServiceUtil.isStoryResponseGood(response) || response!!.isProtocolError) return false

            val database = dbHelper.get()
            // PrefsRepo.kt clears the account before it wipes the database, and the wipe takes this same lock. A story
            // fetched for an account that signed out meanwhile is therefore never written, or is wiped right after.
            synchronized(BlurDatabaseHelper.RW_MUTEX) {
                if (prefsRepo.getUserId() != userId) return false
                database.insertStories(response, prefsRepo.getStateFilter(), false)
            }
            NotificationUtils.notifyPushedStory(context, database, iconCache, storyHash)
            // The sign-out clears every notification too, possibly a moment before this one was posted.
            if (prefsRepo.getUserId() != userId) NotificationUtils.clear(context)
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
            const val KEY_STORY_FEED_ID = "story_feed_id"
            const val KEY_USER_ID = "user_id"

            private const val REGISTRATION_FRESH_MILLIS = 24 * 60 * 60 * 1000L
            private const val DELIVERY_DEADLINE_MILLIS = 15_000L

            @JvmStatic
            fun from(context: Context): StoryPush =
                EntryPointAccessors
                    .fromApplication(context.applicationContext, StoryPushEntryPoint::class.java)
                    .storyPush()
        }
    }
