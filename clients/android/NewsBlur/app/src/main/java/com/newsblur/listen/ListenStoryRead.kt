package com.newsblur.listen

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.ReadingAction
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject

/**
 * ListenStoryRead.kt marks a story ListenManager.kt played to the end as read, like the web's media_player_view.js
 * and iOS's ListenPlayer.swift. Up Next is shared with the web and iOS (ListenUpNext.kt), so a story queued there
 * can play here without a copy in this device's database. That one is marked read by its hash through the reading
 * action queue (ReadingAction.kt), the way NotifyMarkreadReceiver.kt does, which SyncService.kt sends to the server
 * and keeps retrying while offline.
 */
class ListenStoryRead
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val feedUtils: FeedUtils,
        private val dbHelper: BlurDatabaseHelper,
        private val syncServiceState: SyncServiceState,
    ) {
        /** Runs on Dispatchers.IO, since it reads and writes the database. */
        fun markFinished(finished: ListenStory) {
            // The story may have reached the database since it was queued, and its copy updates counts right away.
            val local = finished.story ?: dbHelper.getStoryByHash(finished.storyHash)
            if (local != null) {
                feedUtils.markStoryAsRead(local, context)
                return
            }
            dbHelper.enqueueAction(ReadingAction.MarkStoryRead(finished.storyHash))
            val feedId = finished.feedId ?: FeedUtils.inferFeedId(finished.storyHash)
            if (feedId != null) syncServiceState.addRecountCandidates(setOf(FeedSet.singleFeed(feedId)))
            FeedUtils.triggerSync(context)
        }
    }
