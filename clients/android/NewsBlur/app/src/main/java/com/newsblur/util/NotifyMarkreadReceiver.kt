package com.newsblur.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.newsblur.activity.Reading
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.repository.StoryRepository
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils.Companion.inferFeedId
import com.newsblur.util.FeedUtils.Companion.triggerSync
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class NotifyMarkreadReceiver : BroadcastReceiver() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    lateinit var syncServiceState: SyncServiceState

    @Inject
    lateinit var storyRepository: StoryRepository

    override fun onReceive(c: Context, i: Intent) {
        val storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH)
        NotificationUtils.cancel(c, storyHash.hashCode())
        storyHash ?: return
        NBScope.executeAsyncTask(
                doInBackground = {
                    dbHelper.putStoryDismissed(storyHash)
                    storyRepository.setStoryReadStateExternal(storyHash, true)
                },
                onPostExecute = {
                    val feedId = inferFeedId(storyHash)
                    val impactedFeed = FeedSet.singleFeed(feedId)
                    syncServiceState.addRecountCandidates(setOf(impactedFeed))
                    triggerSync(c)
                }
        )
    }
}