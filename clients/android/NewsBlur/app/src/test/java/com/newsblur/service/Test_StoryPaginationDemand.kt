package com.newsblur.service

import com.newsblur.util.FeedSet
import com.newsblur.util.CursorFilters
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import org.junit.Assert.*
import org.junit.Test

class Test_StoryPaginationDemand {
    @Test
    fun test_loaded_viewport_does_not_restart_loading_without_a_request() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)

        assertFalse(state.requestMoreForFeed(feed, 40, 60))
        assertFalse("A satisfied viewport must not leave the footer loading", state.isFeedSetSyncing(feed))
    }

    @Test
    fun test_smaller_viewport_does_not_shrink_inflight_pagination() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)
        assertTrue(state.requestMoreForFeed(feed, 80, 60))

        assertFalse(state.requestMoreForFeed(feed, 65, 60))
        assertEquals(80, state.pendingFeedTarget)
    }

    @Test
    fun test_larger_viewport_extends_inflight_pagination_without_invalidating_the_page() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)
        assertTrue(state.requestMoreForFeed(feed, 80, 60))
        val generation = state.readingSessionGeneration

        assertTrue(state.requestMoreForFeed(feed, 100, 60))
        assertEquals(100, state.pendingFeedTarget)
        assertEquals(generation, state.readingSessionGeneration)
    }

    @Test
    fun test_filtered_rows_can_request_another_page_without_shrinking_the_target() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)
        assertTrue(state.requestMoreForFeed(feed, 80, 60))

        assertTrue(state.requestMoreForFeed(feed, 40, 20))
        assertEquals(20, state.feedStoriesSeen[feed])
        assertEquals(80, state.pendingFeedTarget)
    }

    @Test
    fun test_switching_back_to_loaded_feed_supersedes_other_pending_feed() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        val filters = CursorFilters(StateFilter.SOME, ReadFilter.UNREAD, StoryOrder.NEWEST)
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)
        assertTrue(state.requestMoreForFeed(FeedSet.singleFeed("456"), 80, null))
        val otherRequest = StoryPageRequest.capture(state, filters, 30)!!

        assertTrue(state.requestMoreForFeed(feed, 40, 60))
        assertEquals(feed, state.pendingFeed)
        assertEquals(40, state.pendingFeedTarget)
        assertFalse(otherRequest.commitIfCurrent(state, filters, 30) { error("The abandoned feed must not insert stories") })
    }

    @Test
    fun test_explicit_reset_schedules_work_even_when_old_rows_satisfy_the_viewport() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = feed
        state.addFeedStoriesSeen(feed, 60)
        state.addFeedSetExhausted(feed)
        state.resetFetchState(feed)

        assertTrue(state.requestMoreForFeed(feed, 40, 60))
        assertEquals(feed, state.pendingFeed)
    }

    @Test
    fun test_new_feed_schedules_session_preparation_even_when_cached_count_is_sufficient() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.lastFeedSet = FeedSet.singleFeed("456")
        state.addFeedStoriesSeen(feed, 60)

        assertTrue(state.requestMoreForFeed(feed, 40, 60))
        assertEquals(feed, state.pendingFeed)
    }
}
