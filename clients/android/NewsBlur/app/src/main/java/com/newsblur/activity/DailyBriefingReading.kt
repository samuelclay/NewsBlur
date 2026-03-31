package com.newsblur.activity

import android.os.Bundle
import com.newsblur.R
import com.newsblur.util.UIUtils

class DailyBriefingReading : Reading() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        UIUtils.setupToolbar(this, R.drawable.ic_briefing, getString(R.string.daily_briefing_title), false)
    }
}
