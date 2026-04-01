package com.newsblur.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.newsblur.activity.DailyBriefingActivity

object DailyBriefingDeepLink {
    const val EXTRA_STORY_HASH = "daily_briefing_story_hash"

    @JvmStatic
    fun isSupported(uri: Uri?): Boolean = DailyBriefingLinkDecision.isSupported(uri?.toString())

    @JvmStatic
    fun storyHash(uri: Uri?): String? = DailyBriefingLinkDecision.storyHash(uri?.toString())

    @JvmStatic
    fun createLaunchIntent(context: Context, uri: Uri?): Intent? {
        if (!isSupported(uri)) return null

        return Intent(context, DailyBriefingActivity::class.java).apply {
            data = uri
            storyHash(uri)?.let { putExtra(EXTRA_STORY_HASH, it) }
        }
    }
}
