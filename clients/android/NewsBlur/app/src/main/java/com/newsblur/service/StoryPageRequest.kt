package com.newsblur.service

import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet

internal class StoryPageRequest private constructor(
    val feedSet: FeedSet,
    val cursorFilters: CursorFilters,
    val infrequentCutoff: Int,
    private val generation: Long,
) {
    fun commitIfCurrent(
        state: SyncServiceState,
        currentFilters: CursorFilters,
        currentInfrequentCutoff: Int,
        sessionReady: () -> Boolean = { true },
        commit: () -> Unit,
    ): Boolean = synchronized(state.pendingFeedMutex) {
        // StoryPageRequest.kt shares the reset lock so a validated response cannot enter a replacement session.
        if (generation != state.readingSessionGeneration || feedSet != state.pendingFeed ||
            state.resetFeed != null || cursorFilters != currentFilters ||
            infrequentCutoff != currentInfrequentCutoff || !sessionReady()) return@synchronized false
        commit()
        true
    }

    companion object {
        fun capture(
            state: SyncServiceState,
            filters: CursorFilters,
            infrequentCutoff: Int,
        ): StoryPageRequest? = synchronized(state.pendingFeedMutex) {
            state.pendingFeed?.let {
                StoryPageRequest(FeedSet.fromCompactSerial(it.toCompactSerial()), filters, infrequentCutoff, state.readingSessionGeneration)
            }
        }
    }
}
