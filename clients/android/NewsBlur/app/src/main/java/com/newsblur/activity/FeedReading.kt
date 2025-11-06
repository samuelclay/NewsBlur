package com.newsblur.activity

import android.os.Bundle
import androidx.lifecycle.lifecycleScope
import com.newsblur.util.UIUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class FeedReading : Reading() {
    override fun onCreate(savedInstanceBundle: Bundle?) {
        super.onCreate(savedInstanceBundle)

        if (fs == null) {
            // if the activity got launch with a missing FeedSet, it will be in the process of cancelling
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            val feed = dbHelper.getFeed(fs!!.getSingleFeed())
            withContext(Dispatchers.Main) {
                if (feed != null) {
                    UIUtils.setupToolbar(this@FeedReading, feed.faviconUrl, feed.title, iconLoader, false)
                } else {
                    finish()
                }
            }
        }
    }
}
