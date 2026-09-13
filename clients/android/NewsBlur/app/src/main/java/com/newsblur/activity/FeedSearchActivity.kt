package com.newsblur.activity

import android.os.Bundle
import com.newsblur.fragment.AddFeedFragment
import dagger.hilt.android.AndroidEntryPoint

/** FeedSearchActivity.kt keeps existing launch intents working with the unified Add site sheet. */
@AndroidEntryPoint
class FeedSearchActivity : NbActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            AddFeedFragment.newInstance().show(supportFragmentManager, "add_site")
        }
    }
}
