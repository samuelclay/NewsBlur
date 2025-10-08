package com.newsblur.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.newsblur.activity.Reading
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.repository.StoryRepository
import com.newsblur.service.NbSyncManager.UPDATE_SOCIAL
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.util.FeedUtils.Companion.triggerSync
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class NotifyShareReceiver : BroadcastReceiver() {

    @Inject
    lateinit var storyRepository: StoryRepository

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    override fun onReceive(context: Context, intent: Intent) {
        val story = intent.getSerializableExtra(Reading.EXTRA_STORY) as? Story?
        NotificationUtils.cancel(context, story?.storyHash.hashCode())
        story?.let {
            NBScope.executeAsyncTask(
                    doInBackground = {
                        dbHelper.putStoryDismissed(it.storyHash)
                        storyRepository.shareStory(it, "", it.sourceUserId)
                        feedUtils.syncUpdateStatus(UPDATE_SOCIAL or UPDATE_STORY)
                        triggerSync(context)
                    }
            )
        }
    }
}