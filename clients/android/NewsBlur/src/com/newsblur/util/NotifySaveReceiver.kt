package com.newsblur.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.newsblur.activity.Reading

class NotifySaveReceiver : BroadcastReceiver() {

    override fun onReceive(c: Context, i: Intent) {
        val storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH)
        NotificationUtils.cancel(c, storyHash.hashCode())
        NBScope.executeAsyncTask(
                doInBackground = {
                    FeedUtils.offerInitContext(c)
                    FeedUtils.dbHelper!!.putStoryDismissed(storyHash)
                    FeedUtils.setStorySaved(storyHash, true, c)
                }
        )
    }
}