package com.newsblur.service

import com.newsblur.domain.Story
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryOrder
import com.google.gson.GsonBuilder
import com.newsblur.serialization.StoriesResponseTypeAdapter
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.runTest
import java.io.IOException
import org.junit.Assert.*
import org.junit.Test

class Test_TryFeedStoryFetcher {
    private val api = mockk<StoryApi>()
    private val feed = FeedSet.singleFeed("123")

    private fun response(vararg stories: Story, fetched: Boolean? = true) = StoriesResponse().apply {
        feedId = "123"
        this.stories = arrayOf(*stories)
        fetchedOnce = fetched
    }

    @Test fun test_only_confirmed_empty_first_try_feed_page_starts_refresh() {
        assertTrue(TryFeedStoryFetcher.shouldRefresh(feed, 1, response(), true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 2, response(), true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 1, response(), false))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 1, response(Story()), true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 1, null, true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 1, response().apply { isProtocolError = true }, true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed, 1, response().apply { feedId = "456" }, true))
        assertFalse(TryFeedStoryFetcher.shouldRefresh(feed.apply { searchQuery = "missing" }, 1, response(), true))
    }

    @Test fun test_refresh_polls_until_stories_are_ready_and_forces_only_once() = runTest {
        val story = Story()
        coEvery { api.getTryFeedStories("123", StoryOrder.NEWEST, ReadFilter.ALL, true) } returns response(fetched = false)
        coEvery { api.getTryFeedStories("123", StoryOrder.NEWEST, ReadFilter.ALL, false) } returnsMany
            listOf(response().apply { notYetFetched = true }, response(story))
        val result = TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true }
        assertSame(story, (result as TryFeedStoryFetcher.Result.Complete).response.stories.single())
        coVerify(exactly = 1) { api.getTryFeedStories(any(), any(), any(), true) }
        coVerify(exactly = 2) { api.getTryFeedStories(any(), any(), any(), false) }
    }

    @Test fun test_successful_empty_result_finishes_without_repeated_refresh() = runTest {
        coEvery { api.getTryFeedStories(any(), any(), any(), true) } returns response()
        assertTrue(TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true } is TryFeedStoryFetcher.Result.Complete)
        coVerify(exactly = 1) { api.getTryFeedStories(any(), any(), any(), any()) }
    }

    @Test fun test_failed_malformed_and_wrong_feed_responses_finish_as_failed() = runTest {
        listOf(null, response().apply { hasException = true }, response().apply { stories = null },
            response().apply { feedId = "456" }, response().apply { isProtocolError = true }).forEach { result ->
            coEvery { api.getTryFeedStories(any(), any(), any(), true) } returns result
            assertEquals(TryFeedStoryFetcher.Result.Failed, TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true })
        }
    }

    @Test fun test_never_fetched_site_and_hung_network_timeout() = runTest {
        coEvery { api.getTryFeedStories(any(), any(), any(), any()) } returns response(fetched = false)
        assertEquals(TryFeedStoryFetcher.Result.Failed, TryFeedStoryFetcher(api, timeoutMillis = 5_000).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true })
        coEvery { api.getTryFeedStories(any(), any(), any(), any()) } coAnswers { awaitCancellation() }
        assertEquals(TryFeedStoryFetcher.Result.Failed, TryFeedStoryFetcher(api, timeoutMillis = 5_000).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true })
    }

    @Test fun test_account_or_feed_switch_discards_response_and_stops_polling() = runTest {
        var current = true
        coEvery { api.getTryFeedStories(any(), any(), any(), true) } coAnswers {
            current = false
            response(fetched = false)
        }
        assertEquals(TryFeedStoryFetcher.Result.Stale, TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { current })
        coVerify(exactly = 0) { api.getTryFeedStories(any(), any(), any(), false) }
    }

    @Test fun test_cancellation_is_not_converted_to_an_error() = runTest {
        coEvery { api.getTryFeedStories(any(), any(), any(), any()) } throws CancellationException("Stopped")
        try {
            TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true }
            fail("Cancellation must reach the service")
        } catch (_: CancellationException) {
        }
    }

    @Test fun test_network_failure_finishes_with_retryable_error() = runTest {
        coEvery { api.getTryFeedStories(any(), any(), any(), any()) } throws IOException("Offline")
        assertEquals(TryFeedStoryFetcher.Result.Failed, TryFeedStoryFetcher(api).refresh("123", StoryOrder.NEWEST, ReadFilter.ALL) { true })
    }

    @Test fun test_fetch_metadata_survives_the_production_response_adapter() {
        val gson = GsonBuilder().registerTypeAdapter(StoriesResponse::class.java, StoriesResponseTypeAdapter()).create()
        val response = gson.fromJson("""{"feed_id":123,"stories":[],"not_yet_fetched":1,"fetched_once":false,"has_exception":0}""", StoriesResponse::class.java)
        assertEquals("123", response.feedId)
        assertEquals(true, response.notYetFetched)
        assertEquals(false, response.fetchedOnce)
        assertEquals(false, response.hasException)
    }

    @Test fun test_terminal_state_blocks_automatic_retry_until_explicit_reset() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.d(any(), any()) } returns 0
        try {
        val state = DefaultSyncServiceState()
        state.requestMoreForFeed(feed, 20, null)
        state.lastFeedSet = feed
        state.setTryFeedRefreshStatus(feed, TryFeedRefreshStatus.FAILED)
        state.addFeedSetExhausted(feed)
        state.pendingFeed = null
        assertFalse(state.requestMoreForFeed(feed, 1, 0))
        assertEquals(TryFeedRefreshStatus.FAILED, state.getTryFeedRefreshStatus(feed))
        state.resetFetchState(feed)
        assertEquals(TryFeedRefreshStatus.NONE, state.getTryFeedRefreshStatus(feed))
        assertTrue(state.requestMoreForFeed(feed, 1, 0))
        state.setTryFeedRefreshStatus(feed, TryFeedRefreshStatus.FETCHING)
        state.clearState()
        assertEquals(TryFeedRefreshStatus.NONE, state.getTryFeedRefreshStatus(feed))
        } finally {
            unmockkStatic(android.util.Log::class)
        }
    }
}
