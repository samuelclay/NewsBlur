package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.SyncServiceState

object TryFeedSessionResetter {
    fun reset(
        syncServiceState: SyncServiceState,
        dbHelper: BlurDatabaseHelper,
        feedSet: FeedSet?,
    ) {
        syncServiceState.resetReadingSession(dbHelper)
        feedSet?.let(syncServiceState::resetFetchState)
    }
}
