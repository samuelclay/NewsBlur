package com.newsblur.util

/**
 * Same values as R.string.mark_story_read_values
 */
enum class MarkStoryReadBehavior {
    IMMEDIATELY,
    SECONDS_5,
    SECONDS_10,
    SECONDS_20,
    SECONDS_30,
    SECONDS_45,
    SECONDS_60,
    MANUALLY,
    ;

    fun getDelayMillis(): Long = when (this) {
        IMMEDIATELY -> 0
        SECONDS_5 -> 5_000
        SECONDS_10 -> 10_000
        SECONDS_20 -> 20_000
        SECONDS_30 -> 30_000
        SECONDS_45 -> 40_000
        SECONDS_60 -> 50_000
        MANUALLY -> -1
    }
}