package com.newsblur.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.newsblur.activity.Reading

class NotifyDismissReceiver : BroadcastReceiver() {

    override fun onReceive(c: Context, i: Intent) {
        val storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH)
        NBScope.executeAsyncTask(
                doInBackground = {
                    FeedUtils.offerInitContext(c)
                    FeedUtils.dbHelper!!.putStoryDismissed(storyHash)
                }
        )
    }
}