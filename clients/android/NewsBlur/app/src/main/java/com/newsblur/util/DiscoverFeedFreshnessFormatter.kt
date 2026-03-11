package com.newsblur.util

import com.newsblur.domain.Feed
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object DiscoverFeedFreshnessFormatter {
    private const val STALE_THRESHOLD_SECONDS = 365L * 24L * 60L * 60L
    private const val MINIMUM_RELATIVE_SECONDS = 60L
    private const val SECOND_IN_MILLIS = 1000L

    private val apiDateFormat by lazy {
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    data class FreshnessInfo(
        val updatedAtMillis: Long,
        val isStale: Boolean,
    )

    fun build(
        feed: Feed,
        nowMillis: Long = System.currentTimeMillis(),
    ): FreshnessInfo? {
        val lastStoryTimestamp = parseApiDateMillis(feed.lastStoryDate) ?: return null
        val updatedSecondsAgo = ((nowMillis - lastStoryTimestamp) / SECOND_IN_MILLIS).coerceAtLeast(0L)
        val resolvedSecondsAgo = updatedSecondsAgo.coerceAtLeast(MINIMUM_RELATIVE_SECONDS)
        return FreshnessInfo(
            updatedAtMillis = nowMillis - (resolvedSecondsAgo * SECOND_IN_MILLIS),
            isStale = resolvedSecondsAgo >= STALE_THRESHOLD_SECONDS,
        )
    }

    fun parseApiDateMillis(rawDate: String?): Long? {
        if (rawDate.isNullOrBlank()) return null
        return runCatching { apiDateFormat.parse(rawDate)?.time }.getOrNull()
    }
}
