package com.newsblur.realtime

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.text.TextUtils
import com.newsblur.database.BlurDatabase
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
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
import com.newsblur.service.DefaultSyncServiceState
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.Runs
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
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
        every { prefs.isNewStoriesPillEnabled() } returns true
        every { db.storyHashesWithoutLocalCopy(any()) } returns emptySet()
        coEvery { feedApi.getFeedUnreadCounts(any()) } returns UnreadCountResponse()
    }

    private fun TestScope.realtime(
        dbHelper: BlurDatabaseHelper = db,
        state: SyncServiceState = syncState,
    ): RealtimeUpdates {
        val clock = { EPOCH + currentTime }
        every { prefs.getLastSyncTime() } answers { clock() }
        coEvery { feedApi.getFeedUnreadCounts(any()) } answers {
            countRequests += currentTime to firstArg<MutableSet<String>>().toSet()
            UnreadCountResponse()
        }
        return RealtimeUpdates(
            socketClient = socket,
            prefsRepo = prefs,
            dbHelper = dbHelper,
            feedApi = feedApi,
            storyApi = storyApi,
            syncServiceState = state,
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
        // StoryTypeAdapter.java parses story_timestamp into milliseconds.
        timestamp = (EPOCH / 1000 - secondsAgo) * 1000
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

    // A story the reader's classifiers hide (a disliked tag, author or title) must never arrive through the pill,
    // even when the list is in the All state, which lists hidden stories too: Sam's S22 offered two Hoodline
    // stories his tag filters hide.
    @Test
    fun test_pill_never_offers_hidden_stories_even_in_the_all_state() =
        runTest {
            every { prefs.getStateFilter() } returns StateFilter.ALL
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                StoriesResponse().apply {
                    stories =
                        arrayOf(
                            story("1:hidden-by-tag", score = -1),
                            story("1:neutral", score = 0, secondsAgo = 30),
                        )
                }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            for (hash in listOf("1:hidden-by-tag", "1:neutral")) {
                realtime.send("feed:story:new", "1:story", "$hash,$now")
            }
            settle()

            assertEquals(listOf("1:neutral"), realtime.newStories.value.storyHashes)
        }

    // A list left open overnight once loaded every story announced since. Past the cap the pill keeps 20 loaded and
    // only counts announcements older than those, and a counted story read elsewhere leaves that count too.
    @Test
    fun test_pill_loads_up_to_its_cap_and_counts_older_arrivals() =
        runTest {
            val fetched = mutableListOf<String>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                fetched += firstArg<List<String>>()
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            val announced = (1..30).map { "1:story$it" }
            announced.take(25).forEach { realtime.send("feed:story:new", "1:story", "$it,$now") }
            settle()
            announced.drop(25).forEach { realtime.send("feed:story:new", "1:story", "$it,${now - 3_600}") }
            settle()

            assertEquals(RealtimeUpdates.NEW_STORIES_CAP, fetched.size)
            assertEquals(30, realtime.newStories.value.count)
            assertTrue(realtime.newStories.value.overCap)

            val unfetched = announced.first { it !in fetched }
            realtime.send("user:update", "sam", "story:read:$unfetched")
            settle()
            assertEquals(29, realtime.newStories.value.count)
            assertEquals(RealtimeUpdates.NEW_STORIES_CAP, fetched.size)
        }

    // "Show new stories as they arrive" off means no pill and no fetching of announced stories, and turning it
    // off while the pill shows drops what it held, fetched or only counted.
    @Test
    fun test_turning_off_new_stories_stops_buffering_and_fetching() =
        runTest {
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            (1..25).forEach { realtime.send("feed:story:new", "1:story", "1:shown$it,$now") }
            settle()
            assertEquals(25, realtime.newStories.value.count)

            every { prefs.isNewStoriesPillEnabled() } returns false
            realtime.newStoriesSettingChanged()
            assertEquals(NewStories.NONE, realtime.newStories.value)

            realtime.send("feed:story:new", "1:story", "1:while-off,$now")
            settle()
            assertEquals(NewStories.NONE, realtime.newStories.value)
            coVerify(exactly = 0) { storyApi.getStoriesByHash(match { "1:while-off" in it }) }
        }

    // Logout cancels nothing already in flight: a story or count response that arrives after PrefsRepo.logout() wiped
    // the database must not write the previous account's stories, saved state or counts back into it.
    @Test
    fun test_a_response_held_across_sign_out_never_writes() =
        runTest {
            val storyResponse = CompletableDeferred<StoriesResponse>()
            coEvery { storyApi.getStoriesByHash(any()) } coAnswers { storyResponse.await() }
            val realtime = realtime()
            val countResponse = CompletableDeferred<UnreadCountResponse>()
            coEvery { feedApi.getFeedUnreadCounts(any()) } coAnswers { countResponse.await() }
            realtime.setOpenStoryList(FeedSet.singleFeed("1"))
            realtime.send("feed:story:new", "1:story", "1:late,${EPOCH / 1000}")
            realtime.send("user:update", "sam", "feed:5")
            settle()
            coVerify { storyApi.getStoriesByHash(any()) }
            coVerify { feedApi.getFeedUnreadCounts(any()) }

            realtime.stopForAccountChange()
            storyResponse.complete(StoriesResponse().apply { stories = arrayOf(story("1:late")) })
            countResponse.complete(UnreadCountResponse().apply { feeds = mapOf("5" to UnreadCountResponse.UnreadMD()) })
            runCurrent()

            verify(exactly = 0) { db.insertStories(any(), any(), any()) }
            verify(exactly = 0) { db.updateFeedCounts(any(), any()) }
        }

    // A count refresh after reconnecting can write hundreds of feeds. Opening or reloading a list on the main thread
    // must not wait on that write, or the reader sees the app freeze.
    @Test
    fun test_the_pill_and_the_list_never_wait_on_a_database_write() =
        runTest {
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                StoriesResponse().apply { stories = arrayOf(story("1:late")) }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            var mainThreadFinished = false
            every { db.insertStories(any(), any(), any()) } answers {
                val mainThread =
                    Thread {
                        realtime.resetNewStories(FeedSet.singleFeed("2"))
                        realtime.setOpenStoryList(feed)
                    }
                mainThread.start()
                mainThread.join(2_000)
                mainThreadFinished = !mainThread.isAlive
            }
            realtime.send("feed:story:new", "1:story", "1:late,${EPOCH / 1000}")
            settle()

            verify { db.insertStories(any(), any(), any()) }
            assertTrue(mainThreadFinished)
        }

    // With All Site Stories open, every feed's feed:<id> count update waits for the list to close. A read on another
    // device of a story this device never stored can't adjust that count locally, so the server must recount it.
    @Test
    fun test_remote_read_of_a_story_this_device_lacks_recounts_its_feed_under_the_open_river() =
        runTest {
            every { db.storyHashesWithoutLocalCopy(any()) } answers { firstArg<Collection<String>>().filter { it == "9:uncached" }.toSet() }
            val realtime = realtime()
            realtime.setOpenStoryList(FeedSet.allFeeds())
            realtime.send("user:update", "sam", "story:read:9:uncached")
            realtime.send("user:update", "sam", "feed:9")
            settle()

            assertTrue(countRequests.any { (_, feeds) -> "9" in feeds })
        }

    // Sam: the pill always holds the 20 it would show, fully loaded: the 20 newest by date of everything announced, as
    // if the list loaded right then, whatever order they were announced in. The rest are only counted.
    @Test
    fun test_the_pill_loads_the_twenty_newest_of_a_burst_and_counts_the_rest() =
        runTest {
            val requests = mutableListOf<List<String>>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                requests += firstArg<List<String>>()
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it, secondsAgo = 100L - it.substringAfter(":s").toLong()) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            // Announced oldest first, so the newest arrive last.
            (1..25).forEach { realtime.send("feed:story:new", "1:story", "1:s$it,${now - 100 + it}") }
            settle()

            val newest = (25 downTo 6).map { "1:s$it" }
            assertEquals(newest, realtime.newStories.value.storyHashes)
            assertEquals(5, realtime.newStories.value.unfetchedCount)
            assertEquals(newest.toSet(), requests.flatten().toSet())
        }

    // Past the cap an arrival newer than the oldest of the 20 is loaded right away and that oldest one drops to the
    // count; an older arrival is only counted. Either way the pill says one more.
    @Test
    fun test_a_newer_arrival_past_the_cap_is_loaded_and_the_oldest_drops_to_the_count() =
        runTest {
            val ages = HashMap<String, Long>()
            val requests = mutableListOf<List<String>>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                requests += firstArg<List<String>>()
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it, secondsAgo = ages.getValue(it)) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            (1..20).forEach {
                ages["1:old$it"] = 600L + it
                realtime.send("feed:story:new", "1:story", "1:old$it,${now - 600 - it}")
            }
            settle()
            requests.clear()

            ages["1:newer"] = 1L
            realtime.send("feed:story:new", "1:story", "1:newer,${now - 1}")
            realtime.send("feed:story:new", "1:story", "1:older,${now - 10_000}")
            settle()

            assertEquals(listOf(listOf("1:newer")), requests)
            assertEquals(listOf("1:newer") + (1..19).map { "1:old$it" }, realtime.newStories.value.storyHashes)
            assertEquals(2, realtime.newStories.value.unfetchedCount)
            assertEquals(22, realtime.newStories.value.count)
        }

    // A loaded story read on another device leaves an unread-only list's pill, and the newest counted story is loaded
    // in its place, so a tap still needs no fetch.
    @Test
    fun test_a_loaded_story_read_elsewhere_is_replaced_from_the_count() =
        runTest {
            val requests = mutableListOf<List<String>>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                requests += firstArg<List<String>>()
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it, secondsAgo = 100L - it.substringAfter(":s").toLong()) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            (1..25).forEach { realtime.send("feed:story:new", "1:story", "1:s$it,${now - 100 + it}") }
            settle()
            requests.clear()

            realtime.send("user:update", "sam", "story:read:1:s10")
            settle()

            assertEquals(listOf(listOf("1:s5")), requests)
            assertEquals((25 downTo 5).map { "1:s$it" } - "1:s10", realtime.newStories.value.storyHashes)
            assertEquals(4, realtime.newStories.value.unfetchedCount)
            assertEquals(24, realtime.newStories.value.count)
        }

    // A list left open overnight still loads only 20 stories. A tap past the cap then shows exactly the 20 newest
    // waiting, already loaded, with no story fetch: the list's reading session restarts with just those and paging
    // resets.
    @Test
    fun test_tap_past_the_cap_shows_exactly_the_twenty_newest_and_resets_paging() =
        runTest {
            val ages = HashMap<String, Long>()
            val requests = mutableListOf<List<String>>()
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                requests += firstArg<List<String>>()
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it, secondsAgo = ages.getValue(it)) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            (1..20).forEach {
                ages["1:old$it"] = 600L + it
                realtime.send("feed:story:new", "1:story", "1:old$it,${now - 600 - it}")
            }
            settle()
            (1..5).forEach {
                ages["1:new$it"] = it.toLong()
                realtime.send("feed:story:new", "1:story", "1:new$it,${now - it}")
            }
            realtime.send("feed:story:new", "1:story", "1:new1,${now - 1}")
            settle()
            assertEquals("a story announced twice counts once", 25, realtime.newStories.value.count)
            requests.clear()

            val result = realtime.takeNewStoriesForTap(feed)

            val newest = (1..5).map { "1:new$it" } + (1..15).map { "1:old$it" }
            assertEquals(RealtimeUpdates.TapResult.Replace(newest), result)
            assertEquals(emptyList<List<String>>(), requests)
            assertEquals(NewStories.NONE, realtime.newStories.value)

            assertTrue(realtime.showOnly(feed, newest, realtime.readingSession()))
            verify { db.prepareOrderedReadingSession(feed, newest) }
            verify { syncState.restartPaging(feed) }
        }

    // An oldest-first list isn't reloaded: a tap past the cap adds the 20 oldest-dated waiting stories at its end and
    // keeps the rest waiting for the next tap.
    @Test
    fun test_oldest_first_tap_past_the_cap_adds_the_oldest_twenty_and_keeps_the_rest() =
        runTest {
            every { prefs.getStoryOrder(any()) } returns StoryOrder.OLDEST
            every { syncState.isFeedSetExhausted(any()) } returns true
            coEvery { storyApi.getStoriesByHash(any()) } answers {
                StoriesResponse().apply { stories = firstArg<List<String>>().map { story(it) }.toTypedArray() }
            }
            val realtime = realtime()
            val feed = FeedSet.singleFeed("1")
            realtime.setOpenStoryList(feed)
            val now = EPOCH / 1000
            (1..23).forEach { realtime.send("feed:story:new", "1:story", "1:s$it,${now - 100 + it}") }
            settle()

            val result = realtime.takeNewStoriesForTap(feed)

            assertTrue(result is RealtimeUpdates.TapResult.Insert)
            result as RealtimeUpdates.TapResult.Insert
            assertEquals(NewStories.Placement.BOTTOM, result.placement)
            assertEquals(20, result.storyHashes.size)
            assertEquals(3, realtime.newStories.value.count)
        }

    // PrefsRepo.logout() stops realtime before it clears the credentials and the database. A subscription task that
    // already read the old account's feeds, or one started in that window, must not reconnect it: events would show
    // the signed-out account's activity.
    @Test
    fun test_logout_in_the_foreground_never_reconnects_the_signed_out_account() =
        runTest {
            val connects = mutableListOf<String>()
            every { socket.subscribed } returns MutableStateFlow(false)
            every { socket.connect(any(), any()) } answers { connects += firstArg<String>() }
            every { prefs.getUserName() } returns "old"
            every { prefs.hasCookie() } returns true
            every { db.getAllActiveFeeds() } returns setOf("1")
            every { db.getAllSocialFeeds() } returns emptyList()
            val realtime = realtime()
            realtime.onAppForeground()
            runCurrent()
            assertEquals(listOf("old"), connects)
            connects.clear()

            // Logout lands while a subscription task holds the old account's feeds, before it connects.
            every { db.getAllSocialFeeds() } answers {
                realtime.stopForAccountChange()
                emptyList()
            }
            realtime.refreshSubscription()
            every { db.getAllSocialFeeds() } returns emptyList()
            settle()

            assertEquals(emptyList<String>(), connects)
        }

    // Once PrefsRepo.kt has wiped the previous account, the next one's feed list connects as usual.
    @Test
    fun test_the_next_account_connects_once_the_previous_one_is_wiped() =
        runTest {
            val connects = mutableListOf<String>()
            every { socket.subscribed } returns MutableStateFlow(false)
            every { socket.connect(any(), any()) } answers { connects += firstArg<String>() }
            every { prefs.hasCookie() } returns true
            every { db.getAllActiveFeeds() } returns setOf("1")
            every { db.getAllSocialFeeds() } returns emptyList()
            every { prefs.getUserName() } returns "old"
            val realtime = realtime()
            realtime.onAppForeground()
            runCurrent()
            realtime.stopForAccountChange()

            every { prefs.getUserName() } returns "next"
            realtime.accountChangeComplete()
            settle()

            assertEquals(listOf("old", "next"), connects)
        }

    // On a tablet the story list switches feeds in place, and a reload restarts the same feed's session; a tap whose
    // fetch outlasts either must not replace or add to the new session's stories.
    @Test
    fun test_a_tap_held_across_a_list_switch_or_reload_never_changes_the_new_session() =
        runTest {
            withSessionDatabase { helper, sqlite ->
                val state = DefaultSyncServiceState()
                val realtime = realtime(dbHelper = helper, state = state)
                val first = FeedSet.singleFeed("1")
                val second = FeedSet.singleFeed("2")
                openList(helper, first)
                val beforeSwitch = realtime.readingSession()

                openList(helper, second)
                assertFalse(realtime.showOnly(first, listOf("1:new"), beforeSwitch))
                assertFalse(realtime.addToOpenList(listOf("1:new"), beforeSwitch))

                val beforeReload = realtime.readingSession()
                // ItemsList.java's restartReadingSession
                state.resetFetchState(second)
                state.resetReadingSession(helper)
                assertFalse(realtime.showOnly(second, listOf("2:new"), beforeReload))
                assertFalse(realtime.addToOpenList(listOf("2:new"), beforeReload))

                verify(exactly = 0) { sqlite.insert(DatabaseConstants.READING_SESSION_TABLE, any(), any()) }
                assertEquals(emptySet<String>(), helper.pinnedSessionStoryHashes)
            }
        }

    // A page loop starting or finishing during the tap's fetch moves SyncServiceState.kt's pendingFeed (feed, then
    // null, then feed again). That's still the same session, so the tapped stories land.
    @Test
    fun test_a_tap_held_while_the_open_list_pages_still_lands() =
        runTest {
            withSessionDatabase { helper, sqlite ->
                val state = DefaultSyncServiceState()
                val realtime = realtime(dbHelper = helper, state = state)
                val feed = FeedSet.singleFeed("1")
                openList(helper, feed)
                state.pendingFeed = feed
                val tap = realtime.readingSession()

                state.pendingFeed = null
                state.pendingFeed = feed
                assertTrue(realtime.addToOpenList(listOf("1:new1"), tap))
                assertEquals(setOf("1:new1"), helper.pinnedSessionStoryHashes)

                val tapPastCap = realtime.readingSession()
                state.pendingFeed = null
                assertTrue(realtime.showOnly(feed, listOf("1:new2", "1:new1"), tapPastCap))
                verify(exactly = 3) { sqlite.insert(DatabaseConstants.READING_SESSION_TABLE, any(), any()) }
            }
        }

    // FeedUtils.kt's new reading session for a list it wasn't showing.
    private fun openList(
        helper: BlurDatabaseHelper,
        fs: FeedSet,
    ) {
        helper.clearStorySession()
        helper.sessionFeedSet = fs
    }

    // A real BlurDatabaseHelper.java over a stand-in SQLite, so the reading session changes the way the app changes it.
    private inline fun <T> withSessionDatabase(block: (BlurDatabaseHelper, SQLiteDatabase) -> T): T {
        val sqlite = mockk<SQLiteDatabase>(relaxed = true)
        mockkConstructor(BlurDatabase::class, ContentValues::class)
        mockkStatic(TextUtils::class)
        try {
            every { anyConstructed<BlurDatabase>().ro } returns sqlite
            every { anyConstructed<BlurDatabase>().rw } returns sqlite
            every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } just Runs
            every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
            return block(BlurDatabaseHelper(mockk(relaxed = true)), sqlite)
        } finally {
            unmockkConstructor(BlurDatabase::class, ContentValues::class)
            unmockkStatic(TextUtils::class)
        }
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
