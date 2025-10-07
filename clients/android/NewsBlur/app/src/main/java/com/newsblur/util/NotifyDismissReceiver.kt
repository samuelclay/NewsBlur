package com.newsblur.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.newsblur.activity.Reading
import com.newsblur.database.BlurDatabaseHelper
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class NotifyDismissReceiver : BroadcastReceiver() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    override fun onReceive(c: Context, i: Intent) {
        val storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH)
        NBScope.executeAsyncTask(
                doInBackground = {
                    dbHelper.putStoryDismissed(storyHash)
                }
        )
    }
}