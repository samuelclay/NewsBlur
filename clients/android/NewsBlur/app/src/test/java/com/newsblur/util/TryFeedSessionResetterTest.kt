package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.DefaultSyncServiceState
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TryFeedSessionResetterTest {
    @Test
    fun resets_pending_session_before_loading_try_feed() {
        val syncServiceState = DefaultSyncServiceState()
        val previousFeedSet = FeedSet.allFeeds()
        val tryFeedSet = FeedSet.singleFeed("123")

        syncServiceState.pendingFeed = previousFeedSet
        syncServiceState.pendingFeedTarget = 432
        syncServiceState.addFeedPagesSeen(tryFeedSet, 9)
        syncServiceState.addFeedStoriesSeen(tryFeedSet, 108)
        syncServiceState.addFeedSetExhausted(tryFeedSet)

        TryFeedSessionResetter.reset(syncServiceState, mockk<BlurDatabaseHelper>(relaxed = true), tryFeedSet)

        assertNull(syncServiceState.pendingFeed)
        assertEquals(tryFeedSet, syncServiceState.resetFeed)
    }
}
