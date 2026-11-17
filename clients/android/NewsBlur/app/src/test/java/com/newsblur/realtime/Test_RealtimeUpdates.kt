package com.newsblur.realtime

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.FeedApi
import com.newsblur.network.NewsBlurSocketClient
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.realtime.RealtimeUpdates.NewStories
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.verify
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

@OptIn(ExperimentalCoroutinesApi::class)
class Test_RealtimeUpdates {
    private val socket = mockk<NewsBlurSocketClient>(relaxed = true)
    private val prefs = mockk<PrefsRepo>(relaxed = true)
    private val db = mockk<BlurDatabaseHelper>(relaxed = true)
    private val feedApi = mockk<FeedApi>()
    private val storyApi = mockk<StoryApi>()
    private val syncState = mockk<SyncServiceState>(relaxed = true)

    // The longest jitter the subscriber count allows, so delays are deterministic.
    private val random =
        mockk<Random> {
            every { nextLong(any<Long>()) } answers { firstArg<Long>() - 1 }
        }
    private val updates = mutableListOf<Int>()
    private val countRequests = mutableListOf<Pair<Long, Set<String>>>()

    init {
        // RealtimeUpdates.kt logs connection changes through util/Log.java to android.util.Log.
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { db.getUntriedActionCount() } returns 0
        every { db.isStoryInReadingSession(any()) } returns false
        every { db.isStoryRead(any()) } returns false
        every { db.getFeed(any()) } returns null
        every { prefs.getStateFilter() } returns StateFilter.SOME
        every { prefs.getReadFilter(any()) } returns ReadFilter.UNREAD
        every { prefs.getStoryOrder(any()) } returns StoryOrder.NEWEST
        coEvery { feedApi.getFeedUnreadCounts(any()) } returns UnreadCountResponse()
    }

    private fun TestScope.realtime(): RealtimeUpdates {
        val clock = { EPOCH + currentTime }
        every { prefs.getLastSyncTime() } answers { clock() }
        coEvery { feedApi.getFeedUnreadCounts(any()) } answers {
            countRequests += currentTime to firstArg<MutableSet<String>>().toSet()
            UnreadCountResponse()
        }
        return RealtimeUpdates(
            socketClient = socket,
            prefsRepo = prefs,
            dbHelper = db,
            feedApi = feedApi,
            storyApi = storyApi,
            syncServiceState = syncState,
            scope = backgroundScope,
            clock = clock,
            random = random,
            requestSync = {},
            submitUpdate = { updates += it },
        ).also { it.onLiveChanged(true) }
    }

    // RealtimeUpdates.kt runs in backgroundScope, which TestScope.advanceUntilIdle() doesn't wait for.
    private fun TestScope.settle() {
        advanceTimeBy(2 * 60 * 1000L)
        runCurrent()
    }

    private fun RealtimeUpdates.send(
        event: String,
        channel: String,
        message: String,
    ) = handle(RealtimeMessage.parse(event, listOf(channel, message))!!)

    private fun story(
        hash: String,
        score: Int = 0,
        read: Boolean = false,
        secondsAgo: Long = 60,
    ) = Story().apply {
        storyHash = hash
        feedId = hash.substringBefore(':')
        timestamp = EPOCH / 1000 - secondsAgo
        intelligence.intelligenceFeed = score
        this.read = read
    }

    @Test
    fun test_count_messages_in_a_burst_share_one_request() =
        runTest {
            val realtime = realtime()
            realtime.send("user:update", "sam", "feed:1")
            advanceTimeBy(500)
            realtime.send("user:update", "sam", "feed:2,3")
            settle()

            assertEquals(listOf(setOf("1", "2", "3")), countRequests.map { it.second })
        }

    @Test
    fun test_popular_feed_fetch_waits_its_jitter_without_holding_back_earlier_counts() =
        runTest {
            every { db.getFeed("1") } returns Feed().apply { subscribers = "6000" }
            val realtime = realtime()
            realtime.send("feed:update", "1", "story:new_count:2")
            realtime.send("user:update", "sam", "feed:2")
            settle()

            // reader.js waits up to num_subscribers * 10ms, so 6,000 subscribers spread over a minute.
            assertEquals(listOf(1_000L to setOf("2"), 60_000L to setOf("1")), countRequests)
        }

    @Test
    fun test_open_list_counts_wait_until_the_list_closes() =
        runTest {
            val realtime = realtime()
            val folder = FeedSet.folder("Tech", setOf("1", "2"))
            realtime.setOpenStoryList(folder)
            realtime.send("user:update", "sam", "feed:1,3")
            settle()
            assertEquals(listOf(setOf("3")), countRequests.map { it.second })

            realtime.clearOpenStoryList(folder)
            settle()
            assertEquals(listOf(setOf("3"), setOf("1")), countRequests.map { it.second })
        }

    @Test
    fun test_counts_wait_for_queued_actions_to_reach_the_server() =
        runTest {
            every { db.getUntriedActionCount() } returnsMany listOf(1, 0)
            val realtime = realtime()
            realtime.send("user:update", "sam", "feed:3")
            advanceTimeBy(1_500)
            assertTrue(countRequests.isEmpty())

            settle()
            assertEquals(listOf(setOf("3")), countRequests.map { it.second })
        }

    @Test
    fun test_remote_reads_apply_once_and_ignore_echoes_of_our_own() =
        runTest {
            every { db.isStoryRead("1:mine") } returns true
            every { db.isStoryRead("1:restored") } returns true
            val realtime = realtime()
            realtime.send("user:update", "sam", "story:read:1:mine")
            settle()
            verify(exactly = 0) { db.applyRemoteStoryReadHashes(any(), any()) }
            assertTrue(updates.isEmpty())

            realtime.send("user:update", "sam", "story:read:1:mine")
            realtime.send("user:update", "sam", "story:read:1:elsewhere")
            realtime.send("user:update", "sam", "story:unread:1:restored")
            settle()
            verify(exactly = 1) { db.applyRemoteStoryReadHashes(listOf("1:elsewhere"), true) }
            verify(exactly = 1) { db.applyRemoteStoryReadHashes(listOf("1:restored"), false) }
            assertEquals(listOf(UPDATE_STORY or UPDATE_METADATA), updates)
        }

    @Test
    fun test_focus_pill_keeps_only_unread_focus_stories_for_the_open_feed() =
        runTest {
            every { prefs.getStateFilter() } returns StateFilter.BEST
            every { db.isStoryInReadingSession("1:listed") } returns true
            val fetched = mutableListOf<List<String>>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                fetched += firstArg<List<String>>()
                StoriesResponse().apply {
                    stories =
                        arrayOf(
                            story("1:focus", score = 1, secondsAgo = 120),
                            story("1:newer-focus", score = 1, secondsAgo = 30),
                            story("1:neutral", score = 0),
                            story("1:read-elsewhere", score = 1, read = true),
                        )
                }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            for (hash in listOf("1:focus", "1:focus", "1:newer-focus", "1:neutral", "1:read-elsewhere", "1:listed")) {
                realtime.send("feed:story:new", "1:story", "$hash,$now")
            }
            realtime.send("feed:story:new", "1:story", "1:future,${now + 2 * 60 * 60}")
            realtime.send("feed:story:new", "2:story", "2:other-feed,$now")
            settle()

            assertEquals(listOf(listOf("1:focus", "1:newer-focus", "1:neutral", "1:read-elsewhere")), fetched)
            assertEquals(NewStories(feed, listOf("1:newer-focus", "1:focus"), NewStories.Placement.TOP), realtime.newStories.value)

            // Read on another device before the tap: an unread-only list no longer offers it.
            realtime.send("user:update", "sam", "story:read:1:focus")
            settle()
            assertEquals(listOf("1:newer-focus"), realtime.newStories.value.storyHashes)
        }

    @Test
    fun test_oldest_first_pill_waits_for_the_last_page() =
        runTest {
            every { prefs.getStoryOrder(any()) } returns StoryOrder.OLDEST
            every { prefs.getReadFilter(any()) } returns ReadFilter.ALL
            every { syncState.isFeedSetExhausted(any()) } returns false
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it) }.toTypedArray() }
            }
            every { prefs.getUserName() } returns "sam"
            every { prefs.hasCookie() } returns true
            every { db.getAllActiveFeeds() } returns setOf("1")
            val realtime = realtime()
            val allStories = FeedSet.allFeeds()
            realtime.setOpenStoryList(allStories)
            realtime.refreshSubscription()
            val now = EPOCH / 1000
            realtime.send("feed:story:new", "1:story", "1:early,$now")
            settle()
            coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }

            every { syncState.isFeedSetExhausted(allStories) } returns true
            realtime.send("feed:story:new", "1:story", "1:late,$now")
            settle()
            assertEquals(NewStories(allStories, listOf("1:late"), NewStories.Placement.BOTTOM), realtime.newStories.value)
        }

    @Test
    fun test_reconnecting_after_a_gap_refreshes_every_count_once() =
        runTest {
            coEvery { feedApi.refreshFeedCounts() } returns UnreadCountResponse()
            val realtime = realtime()
            coVerify(exactly = 0) { feedApi.refreshFeedCounts() }
            val lastSync = EPOCH + currentTime
            every { prefs.getLastSyncTime() } returns lastSync

            realtime.onLiveChanged(false)
            assertFalse(realtime.keepsCountsCurrent(lastSync))
            advanceTimeBy(5 * 60 * 1000L)
            realtime.onLiveChanged(true)
            runCurrent()
            coVerify(exactly = 1) { feedApi.refreshFeedCounts() }
            assertTrue(realtime.keepsCountsCurrent(lastSync))

            // SyncService.kt still reloads the feed list every hour in case publishing silently stopped.
            advanceTimeBy(60 * 60 * 1000L)
            assertFalse(realtime.keepsCountsCurrent(lastSync))
        }

    private companion object {
        const val EPOCH = 1_700_000_000_000L
    }
}
