package com.newsblur.push

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.FeedApi
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.UnreadStoryHashesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.DeviceNotifications
import com.newsblur.util.Log
import com.newsblur.util.NotificationUtils
import com.newsblur.util.PrefConstants
import com.newsblur.util.StateFilter
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_StoryPush {
    private val context = mockk<Context>(relaxed = true)
    private val dbHelper = mockk<BlurDatabaseHelper>(relaxed = true)
    private val storyApi = mockk<StoryApi>()
    private val feedApi = mockk<FeedApi>()
    private val prefsRepo = mockk<PrefsRepo>(relaxed = true)
    private val storyPush = StoryPush(context, { dbHelper }, storyApi, feedApi, prefsRepo, mockk(relaxed = true))
    private val push = mapOf("story_hash" to "42:abc", "story_feed_id" to "42", "user_id" to "13")
    private val stories = StoriesResponse().apply { stories = arrayOf() }

    private fun unreadHashes(vararg hashes: String) =
        UnreadStoryHashesResponse().apply {
            authenticated = true
            unreadHashes = mapOf("42" to hashes.map { arrayOf(it, "100") })
        }

    @Before fun setUp() {
        mockkStatic(NotificationUtils::class, Log::class, DeviceNotifications::class)
        every { NotificationUtils.notifyPushedStory(any(), any(), any(), any()) } just runs
        every { NotificationUtils.clear(any()) } just runs
        coEvery { storyApi.getUnreadStoryHashes(listOf("42"), true) } returns unreadHashes("42:abc")
        coEvery { storyApi.getStoriesByHash(listOf("42:abc"), true) } returns stories
        every { Log.e(any<Any>(), any()) } just runs
        every { DeviceNotifications.isOn(any(), any()) } returns true
        every { prefsRepo.getUserId() } returns "13"
        every { prefsRepo.getStateFilter() } returns StateFilter.SOME
        every { prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "") } returns ""
    }

    @After fun tearDown() {
        unmockkStatic(NotificationUtils::class, Log::class, DeviceNotifications::class)
    }

    @Test fun test_pushed_story_is_fetched_and_notified() = runTest {
        assertTrue(storyPush.handle(push))

        verify { dbHelper.insertStories(stories, StateFilter.SOME, false) }
        // NotificationUtils.java posts this one story whatever the feed's own notification setting is, which is how a
        // classifier match on a feed with no setting gets shown.
        verify { NotificationUtils.notifyPushedStory(context, dbHelper, any(), "42:abc") }
    }

    @Test fun test_push_for_another_account_or_a_silenced_device_is_dropped() = runTest {
        // The token outlives a sign-out, so the previous account's push can land on the next account's session.
        assertFalse(storyPush.handle(push + ("user_id" to "99")))
        every { prefsRepo.getUserId() } returns null
        assertFalse(storyPush.handle(push))

        every { prefsRepo.getUserId() } returns "13"
        every { DeviceNotifications.isOn(any(), any()) } returns false
        assertFalse(storyPush.handle(push))

        coVerify(exactly = 0) { storyApi.getUnreadStoryHashes(any(), any()) }
        coVerify(exactly = 0) { storyApi.getStoriesByHash(any(), any()) }
        verify(exactly = 0) { NotificationUtils.notifyPushedStory(any(), any(), any(), any()) }
    }

    @Test fun test_story_read_elsewhere_before_the_push_arrived_is_not_notified() = runTest {
        // A push can sit at Firebase for hours, and StoryApiImpl.kt's lookup by hash cannot say the story was read since.
        coEvery { storyApi.getUnreadStoryHashes(listOf("42"), true) } returns unreadHashes("42:other")
        assertFalse(storyPush.handle(push))
        coEvery { storyApi.getUnreadStoryHashes(listOf("42"), true) } returns UnreadStoryHashesResponse().apply { isProtocolError = true }
        assertFalse(storyPush.handle(push))

        coVerify(exactly = 0) { storyApi.getStoriesByHash(any(), any()) }
        verify(exactly = 0) { dbHelper.insertStories(any(), any(), any()) }
        verify(exactly = 0) { NotificationUtils.notifyPushedStory(any(), any(), any(), any()) }
    }

    @Test fun test_story_fetched_for_an_account_that_signed_out_meanwhile_is_dropped() = runTest {
        coEvery { storyApi.getStoriesByHash(listOf("42:abc"), true) } coAnswers {
            // PrefsRepo.kt clears the account while the request is still in flight.
            every { prefsRepo.getUserId() } returns null
            stories
        }

        assertFalse(storyPush.handle(push))

        verify(exactly = 0) { dbHelper.insertStories(any(), any(), any()) }
        verify(exactly = 0) { NotificationUtils.notifyPushedStory(any(), any(), any(), any()) }
    }

    @Test fun test_failed_story_fetch_posts_nothing() = runTest {
        coEvery { storyApi.getStoriesByHash(any(), true) } returns StoriesResponse().apply { isProtocolError = true }
        assertFalse(storyPush.handle(push))
        coEvery { storyApi.getStoriesByHash(any(), true) } returns null
        assertFalse(storyPush.handle(push))

        verify(exactly = 0) { dbHelper.insertStories(any(), any(), any()) }
        verify(exactly = 0) { NotificationUtils.notifyPushedStory(any(), any(), any(), any()) }
    }

    @Test fun test_stalled_request_is_abandoned_at_the_delivery_deadline() = runTest {
        // Firebase keeps the device awake for about 20 seconds per message.
        coEvery { storyApi.getStoriesByHash(any(), true) } coAnswers { awaitCancellation() }

        assertFalse(storyPush.deliver(push))

        assertTrue(currentTime in 1 until 20_000)
        verify(exactly = 0) { dbHelper.insertStories(any(), any(), any()) }
    }

    @Test fun test_token_is_registered_once_and_retried_after_a_failure() = runTest {
        // apps/notifications/views.py answers a saved token with a message, which NewsBlurResponse.isError reads as an error.
        val saved = NewsBlurResponse().apply { message = "Token saved." }
        coEvery { feedApi.registerPushToken("token-1") } returns NewsBlurResponse().apply { isProtocolError = true } andThen saved
        storyPush.clock = { 5_000L }

        assertFalse(storyPush.registerToken("token-1"))
        verify(exactly = 0) { prefsRepo.putString(PrefConstants.PUSH_TOKEN_REGISTERED, any()) }

        assertTrue(storyPush.registerToken("token-1"))
        verify(exactly = 1) { prefsRepo.putString(PrefConstants.PUSH_TOKEN_REGISTERED, "token-1") }

        every { prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "") } returns "token-1"
        every { prefsRepo.getLong(PrefConstants.PUSH_TOKEN_REGISTERED_AT, 0L) } returns 5_000L
        assertTrue(storyPush.registerToken("token-1"))
        coVerify(exactly = 2) { feedApi.registerPushToken("token-1") }
    }

    @Test fun test_unchanged_token_is_sent_again_after_a_day() = runTest {
        // apps/notifications/models.py drops a token Firebase reports dead. A device that never sent its token again
        // would stop getting pushes for good.
        val hour = 60 * 60 * 1000L
        coEvery { feedApi.registerPushToken("token-1") } returns NewsBlurResponse()
        every { prefsRepo.getString(PrefConstants.PUSH_TOKEN_REGISTERED, "") } returns "token-1"
        every { prefsRepo.getLong(PrefConstants.PUSH_TOKEN_REGISTERED_AT, 0L) } returns 1_000L

        storyPush.clock = { 1_000L + 23 * hour }
        assertTrue(storyPush.registerToken("token-1"))
        coVerify(exactly = 0) { feedApi.registerPushToken(any()) }

        storyPush.clock = { 1_000L + 25 * hour }
        assertTrue(storyPush.registerToken("token-1"))
        coVerify(exactly = 1) { feedApi.registerPushToken("token-1") }
        verify { prefsRepo.putLong(PrefConstants.PUSH_TOKEN_REGISTERED_AT, 1_000L + 25 * hour) }
    }

    @Test fun test_token_stays_on_the_device_while_notifications_are_off() = runTest {
        every { DeviceNotifications.isOn(any(), any()) } returns false

        assertFalse(storyPush.wantsPushes())
        assertFalse(storyPush.registerToken("token-1"))

        coVerify(exactly = 0) { feedApi.registerPushToken(any()) }
    }
}
