package com.newsblur.addsite

import androidx.annotation.PluralsRes
import com.newsblur.R
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * SiteFreshness.kt describes when a search result last published: a compact age in the units iOS
 * shows (2d ago, 3w ago), or the month of its last story once it has gone stale. AddSiteSheet.kt
 * turns it into text with the plural resources, so each language words and counts it natively.
 */
sealed interface SiteFreshness {
    val stale: Boolean

    data class Recent(
        val count: Int,
        val unit: FreshnessUnit,
    ) : SiteFreshness {
        override val stale: Boolean get() = false
    }

    data class Stale(
        val month: String,
    ) : SiteFreshness {
        override val stale: Boolean get() = true
    }

    enum class FreshnessUnit(
        @PluralsRes val plural: Int,
    ) {
        HOURS(R.plurals.compact_hours_ago),
        DAYS(R.plurals.compact_days_ago),
        WEEKS(R.plurals.compact_weeks_ago),
        MONTHS(R.plurals.compact_months_ago),
    }

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
                return Stale(month)
            }
            val days = seconds / 86400
            return when {
                days < 1 -> Recent(maxOf(1, seconds / 3600).toInt(), FreshnessUnit.HOURS)
                days < 7 -> Recent(days.toInt(), FreshnessUnit.DAYS)
                days < 30 -> Recent((days / 7).toInt(), FreshnessUnit.WEEKS)
                else -> Recent((days / 30).toInt(), FreshnessUnit.MONTHS)
            }
        }
    }
}
