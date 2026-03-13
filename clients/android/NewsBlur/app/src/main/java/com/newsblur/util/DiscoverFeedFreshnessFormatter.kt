package com.newsblur.util

import com.newsblur.domain.Feed
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
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
        return parseIsoDateMillis(rawDate) ?: runCatching { apiDateFormat.parse(rawDate)?.time }.getOrNull()
    }

    private fun parseIsoDateMillis(rawDate: String): Long? {
        return runCatching { Instant.parse(rawDate).toEpochMilli() }.getOrNull()
            ?: runCatching { OffsetDateTime.parse(rawDate).toInstant().toEpochMilli() }.getOrNull()
            ?: runCatching {
                LocalDateTime
                    .parse(rawDate, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    .atOffset(ZoneOffset.UTC)
                    .toInstant()
                    .toEpochMilli()
            }.getOrNull()
    }
}
