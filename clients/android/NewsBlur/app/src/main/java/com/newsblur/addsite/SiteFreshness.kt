package com.newsblur.addsite

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

data class SiteFreshness(
    val text: String,
    val stale: Boolean,
) {
    companion object {
        fun from(
            seconds: Long?,
            now: Instant = Instant.now(),
            locale: Locale = Locale.getDefault(),
        ): SiteFreshness? {
            if (seconds == null || seconds <= 0) return null
            if (seconds > 365L * 86400) {
                val month =
                    DateTimeFormatter
                        .ofPattern(
                            "MMM yyyy",
                            locale,
                        ).withZone(ZoneId.systemDefault())
                        .format(now.minusSeconds(seconds))
                return SiteFreshness("Stale $month", true)
            }
            val days = seconds / 86400
            val text =
                when {
                    days < 1 -> "${maxOf(1, seconds / 3600)}h ago"
                    days < 7 -> "${days}d ago"
                    days < 30 -> "${days / 7}w ago"
                    else -> "${days / 30}mo ago"
                }
            return SiteFreshness(text, false)
        }
    }
}
