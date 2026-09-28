package com.newsblur.service

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class StoryPageRequestTest {
    private val filters = CursorFilters(StateFilter.SOME, ReadFilter.UNREAD, StoryOrder.NEWEST)

    @Test
    fun editingSearchDoesNotRetagAnInflightResponseWithTheNewQuery() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123").apply { searchQuery = "before" }
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        feed.searchQuery = "after"
        var inserted = false

        assertFalse(request.commitIfCurrent(state, filters, 30) { inserted = true })
        assertFalse(inserted)
        assertEquals("before", request.feedSet.searchQuery)
    }

    @Test
    fun changingReadOrderOrIntelligenceRejectsTheOldResponse() {
        val state = DefaultSyncServiceState()
        state.requestMoreForFeed(FeedSet.singleFeed("123"), 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        listOf(filters.copy(readFilter = ReadFilter.ALL), filters.copy(storyOrder = StoryOrder.OLDEST), filters.copy(stateFilter = StateFilter.ALL)).forEach { changed ->
            assertFalse(request.commitIfCurrent(state, changed, 30) { error("Stale filters must not insert stories") })
        }
        assertFalse(request.commitIfCurrent(state, filters, 60) { error("Stale cutoff must not insert stories") })
    }

    @Test
    fun switchingAwayAndBackDoesNotMakeAnOldResponseCurrentAgain() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        state.requestMoreForFeed(FeedSet.singleFeed("456"), 20, null)
        state.requestMoreForFeed(feed, 20, null)

        assertFalse(request.commitIfCurrent(state, filters, 30) { error("An old session must not insert stories") })
    }

    @Test
    fun resettingTheSameQueryRejectsItsInflightResponse() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        state.resetReadingSession(mockk<BlurDatabaseHelper>(relaxed = true))
        state.requestMoreForFeed(feed, 20, null)

        assertFalse(request.commitIfCurrent(state, filters, 30) { error("A reset session must not insert stories") })
    }

    @Test
    fun resettingFetchPaginationRejectsItsInflightResponse() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        state.resetFetchState(feed)

        assertFalse(request.commitIfCurrent(state, filters, 30) { error("Reset pagination must not insert stories") })
    }

    @Test
    fun sameQueryReadRefreshesKeepTheUsefulResponseAndPagination() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        repeat(20) { state.requestMoreForFeed(feed, 40, null) }
        var inserted = false

        assertTrue(request.commitIfCurrent(state, filters, 30) { inserted = true })
        assertTrue(inserted)
    }

    @Test
    fun resettingCannotRaceBetweenValidationAndInsertion() {
        val state = DefaultSyncServiceState()
        val feed = FeedSet.singleFeed("123")
        state.requestMoreForFeed(feed, 20, null)
        val request = StoryPageRequest.capture(state, filters, 30)!!
        val validating = CountDownLatch(1)
        val release = CountDownLatch(1)
        val resetFinished = CountDownLatch(1)
        val commit = thread {
            request.commitIfCurrent(state, filters, 30) {
                validating.countDown()
                check(release.await(5, TimeUnit.SECONDS))
            }
        }
        assertTrue(validating.await(5, TimeUnit.SECONDS))
        val reset = thread { state.resetFetchState(feed); resetFinished.countDown() }
        val raced = resetFinished.await(100, TimeUnit.MILLISECONDS)
        release.countDown()
        commit.join(5_000)
        reset.join(5_000)

        assertFalse("Reset must serialize with the entire commit", raced)
        assertEquals(0L, resetFinished.count)
    }
}
