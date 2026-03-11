package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.SyncServiceState

object TryFeedSessionResetter {
    fun reset(
        syncServiceState: SyncServiceState,
        dbHelper: BlurDatabaseHelper,
        feedSet: FeedSet?,
    ) {
        dbHelper.clearStorySession()
        syncServiceState.resetReadingSession(dbHelper)
        feedSet?.let(syncServiceState::resetFetchState)
    }
}
