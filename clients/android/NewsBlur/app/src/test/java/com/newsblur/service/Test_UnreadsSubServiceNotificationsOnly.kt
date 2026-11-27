package com.newsblur.service

import android.text.TextUtils
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.UnreadStoryHashesResponse
import com.newsblur.util.Log
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.function.Predicate

class Test_UnreadsSubServiceNotificationsOnly {
    @Before
    fun set_up() {
        UnreadsSubService.clear()
        mockkStatic(Log::class, TextUtils::class)
        every { Log.i(any<Any>(), any()) } just runs
        every { Log.w(any<Any>(), any()) } just runs
        every { Log.d(any<String>(), any()) } just runs
        every { TextUtils.split(any<String>(), ":") } answers { firstArg<String>().split(':').toTypedArray() }
    }

    @After
    fun tear_down() {
        UnreadsSubService.clear()
        unmockkStatic(Log::class, TextUtils::class)
    }

    @Test
    fun test_notifications_only_run_asks_for_unread_hashes_of_notification_feeds_only() =
        runTest {
            val delegate = delegate(notificationsOnly = true, notifyFeeds = setOf("2", "5"), activeFeeds = setOf("2", "3", "5"))
            val requestedFeeds = mutableListOf<Collection<String>?>()
            coEvery { delegate.storyApi.getUnreadStoryHashes(captureNullable(requestedFeeds)) } returns unreadResponse()
            val service = UnreadsSubService(delegate)
            service.doMetadata()

            service.launchIn(this).join()

            assertEquals(listOf(setOf("2", "5")), requestedFeeds.map { it?.toSet() })
        }

    @Test
    fun test_notifications_only_run_without_notification_feeds_makes_no_request() =
        runTest {
            val delegate =
                delegate(notificationsOnly = true, notifyFeeds = emptySet(), activeFeeds = setOf("3"), localUnreads = listOf("3:unread"))
            val dbHelper = delegate.dbHelper
            val storyApi = delegate.storyApi
            coEvery { storyApi.getUnreadStoryHashes(any()) } returns unreadResponse()
            val service = UnreadsSubService(delegate)
            service.doMetadata()

            service.launchIn(this).join()

            // apps/reader/views.py unread_story_hashes answers a request without feed ids with every feed.
            coVerify(exactly = 0) { storyApi.getUnreadStoryHashes(any()) }
            verify(exactly = 0) { dbHelper.reconcileServerUnreadHashes(any(), any(), any(), any()) }
            verify(exactly = 0) { dbHelper.markStoryHashesRead(any(), any()) }
        }

    @Test
    fun test_feed_filtered_response_cannot_retire_unread_stories_from_other_feeds() =
        runTest {
            val delegate =
                delegate(
                    notificationsOnly = true,
                    notifyFeeds = setOf("2"),
                    activeFeeds = setOf("2", "3"),
                    localUnreads = listOf("2:read-elsewhere", "2:still-unread", "3:other-feed"),
                )
            val dbHelper = delegate.dbHelper
            coEvery { delegate.storyApi.getUnreadStoryHashes(any()) } returns unreadResponse("2" to listOf("2:still-unread"))
            val service = UnreadsSubService(delegate)
            service.doMetadata()

            service.launchIn(this).join()

            val retired = slot<Collection<String>>()
            verify(exactly = 1) { dbHelper.markStoryHashesRead(capture(retired), any()) }
            assertEquals(setOf("2:read-elsewhere"), retired.captured.toSet())
            // ClusterReadStore.kt retires embedded unread children through this predicate.
            val eligibility = slot<Predicate<String>>()
            verify(exactly = 1) { dbHelper.reconcileServerUnreadHashes(any(), any(), capture(eligibility), any()) }
            assertTrue(eligibility.captured.test("2"))
            assertFalse("A feed left out of the request says nothing about its unread stories", eligibility.captured.test("3"))
        }

    @Test
    fun test_notifications_only_run_fetches_only_notification_feed_stories_with_offline_reading_on() =
        runTest {
            val delegate =
                delegate(notificationsOnly = true, notifyFeeds = setOf("2"), activeFeeds = setOf("2", "3"), offlineEnabled = true)
            val batches = mutableListOf<List<String>>()
            coEvery { delegate.storyApi.getStoriesByHash(capture(batches)) } returns storiesResponse()
            // UnreadsSubService.kt keeps the offline reading hashes of an interrupted full sync in this queue.
            UnreadsSubService.storyHashQueue.addAll(listOf("3:offline-a", "2:notify", "3:offline-b"))
            val service = UnreadsSubService(delegate)

            service.launchIn(this).join()

            assertEquals(listOf(listOf("2:notify")), batches)
            assertTrue("SyncService.kt holds notifications back while hashes are queued", UnreadsSubService.storyHashQueue.isEmpty())
        }

    @Test
    fun test_notifications_only_run_sends_no_story_request_when_only_other_feeds_are_queued() =
        runTest {
            val delegate =
                delegate(notificationsOnly = true, notifyFeeds = setOf("2"), activeFeeds = setOf("2", "3"), offlineEnabled = true)
            val storyApi = delegate.storyApi
            coEvery { storyApi.getStoriesByHash(any()) } returns storiesResponse()
            UnreadsSubService.storyHashQueue.add("3:offline")
            val service = UnreadsSubService(delegate)

            service.launchIn(this).join()

            // apps/reader/views.py load_river_stories__redis answers a request without hashes with a page of every feed.
            coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
            assertTrue("SyncService.kt holds notifications back while hashes are queued", UnreadsSubService.storyHashQueue.isEmpty())
        }

    @Test
    fun test_full_run_still_asks_for_every_feed_and_reconciles_all_of_them() =
        runTest {
            val delegate =
                delegate(
                    notificationsOnly = false,
                    notifyFeeds = setOf("2"),
                    activeFeeds = setOf("2", "3"),
                    localUnreads = listOf("2:read-elsewhere", "3:read-elsewhere"),
                    offlineEnabled = true,
                )
            val dbHelper = delegate.dbHelper
            val requestedFeeds = mutableListOf<Collection<String>?>()
            val batches = mutableListOf<List<String>>()
            coEvery { delegate.storyApi.getUnreadStoryHashes(captureNullable(requestedFeeds)) } returns
                unreadResponse("3" to listOf("3:new"))
            coEvery { delegate.storyApi.getStoriesByHash(capture(batches)) } returns storiesResponse()
            val service = UnreadsSubService(delegate)
            service.doMetadata()

            service.launchIn(this).join()

            assertEquals("A full sync must not limit the request to some feeds", listOf(null), requestedFeeds)
            val retired = slot<Collection<String>>()
            verify(exactly = 1) { dbHelper.markStoryHashesRead(capture(retired), any()) }
            assertEquals(setOf("2:read-elsewhere", "3:read-elsewhere"), retired.captured.toSet())
            val eligibility = slot<Predicate<String>>()
            verify(exactly = 1) { dbHelper.reconcileServerUnreadHashes(any(), any(), capture(eligibility), any()) }
            assertTrue(eligibility.captured.test("2"))
            assertTrue(eligibility.captured.test("3"))
            assertEquals("Offline reading downloads every feed on a full sync", listOf(listOf("3:new")), batches)
        }

    private fun delegate(
        notificationsOnly: Boolean,
        notifyFeeds: Set<String>,
        activeFeeds: Set<String>,
        localUnreads: List<String> = emptyList(),
        offlineEnabled: Boolean = false,
    ): SyncServiceDelegate {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val prefsRepo = delegate.prefsRepo
        every { delegate.isNotificationsOnlySync } returns notificationsOnly
        every { dbHelper.getNotifyFeeds() } returns notifyFeeds
        every { dbHelper.getAllActiveFeeds() } returns activeFeeds
        every { dbHelper.getUnreadStoryTimestamps() } returns localUnreads.associateWith { 99_000L }
        every { prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        every { prefsRepo.getStateFilter() } returns StateFilter.SOME
        every { prefsRepo.isOfflineEnabled() } returns offlineEnabled
        every { prefsRepo.isEnableNotifications() } returns true
        return delegate
    }

    private fun unreadResponse(vararg feeds: Pair<String, List<String>>) =
        UnreadStoryHashesResponse().apply {
            authenticated = true
            unreadHashes = feeds.associate { (feedId, hashes) -> feedId to hashes.map { arrayOf(it, "100") } }
        }

    private fun storiesResponse() = StoriesResponse().apply { stories = emptyArray() }
}
