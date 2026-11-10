package com.newsblur.activity

import android.net.Uri
import android.os.Bundle
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint

/** F-Droid upgrades use NewsBlur's website instead of SubscriptionActivity.kt's Play billing flow. */
@AndroidEntryPoint
class SubscriptionActivity : NbActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!isFinishing) UIUtils.handleUri(this, prefsRepo, Uri.parse("https://newsblur.com/?next=premium"))
        finish()
    }
}
