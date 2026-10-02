package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import dagger.hilt.android.AndroidEntryPoint

/** FeedSearchActivity.kt keeps existing menu and keyboard intents opening discovery. */
@AndroidEntryPoint
class FeedSearchActivity : NbActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(Intent(this, DiscoverSitesActivity::class.java))
        finish()
    }
}
