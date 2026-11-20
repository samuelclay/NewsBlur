package com.newsblur.util

import androidx.annotation.StringRes
import com.newsblur.R

/** Shared choices for SettingsScreen.kt and the story-title settings popover. */
enum class MarkStoryReadBehavior(@StringRes val labelRes: Int) {
    ON_SCROLL(R.string.mark_story_read_on_scroll),
    IMMEDIATELY(R.string.mark_story_read_immediately),
    SECONDS_1(R.string.mark_story_read_1_second),
    SECONDS_2(R.string.mark_story_read_2_seconds),
    SECONDS_3(R.string.mark_story_read_3_seconds),
    SECONDS_5(R.string.mark_story_read_5_seconds),
    SECONDS_10(R.string.mark_story_read_10_seconds),
    SECONDS_20(R.string.mark_story_read_20_seconds),
    SECONDS_30(R.string.mark_story_read_30_seconds),
    SECONDS_45(R.string.mark_story_read_45_seconds),
    SECONDS_60(R.string.mark_story_read_60_seconds),
    MANUALLY(R.string.mark_story_read_manually),
    ;

    fun getDelayMillis(): Long =
        when (this) {
            ON_SCROLL, IMMEDIATELY -> 0
            SECONDS_1 -> 1_000
            SECONDS_2 -> 2_000
            SECONDS_3 -> 3_000
            SECONDS_5 -> 5_000
            SECONDS_10 -> 10_000
            SECONDS_20 -> 20_000
            SECONDS_30 -> 30_000
            SECONDS_45 -> 45_000
            SECONDS_60 -> 60_000
            MANUALLY -> -1
        }

    companion object {
        fun options(current: MarkStoryReadBehavior? = null): List<MarkStoryReadBehavior> =
            entries.filter { it != SECONDS_20 && it != SECONDS_45 || it == current }
    }
}
