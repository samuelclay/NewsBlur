package com.newsblur.activity

import android.os.Bundle
import androidx.lifecycle.lifecycleScope
import com.newsblur.util.UIUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SocialFeedReading : Reading() {

    override fun onCreate(savedInstanceBundle: Bundle?) {
        super.onCreate(savedInstanceBundle)

        lifecycleScope.launch(Dispatchers.IO) {
            val socialFeed = dbHelper.getSocialFeed(fs!!.singleSocialFeed.key)
            withContext(Dispatchers.Main) {
                if (socialFeed != null) {
                    UIUtils.setupToolbar(this@SocialFeedReading, socialFeed.photoUrl, socialFeed.feedTitle, iconLoader, false)
                } else {
                    finish()
                }
            }
        }
    }
}
