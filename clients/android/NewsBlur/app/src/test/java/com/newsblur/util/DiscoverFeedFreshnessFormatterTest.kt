package com.newsblur.util

import com.newsblur.domain.Feed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class DiscoverFeedFreshnessFormatterTest {
    @Test
    fun uses_last_story_date_instead_of_fetch_age() {
        val nowMillis = 1_773_187_200_000L // 2026-03-11T00:00:00Z
        val feed =
            Feed().apply {
                lastStoryDate = "2026-03-10 15:00:00"
                lastUpdated = 60
            }

        val freshness = DiscoverFeedFreshnessFormatter.build(feed, nowMillis)

        requireNotNull(freshness)
        assertEquals(nowMillis - (9L * 60L * 60L * 1000L), freshness.updatedAtMillis)
        assertFalse(freshness.isStale)
    }
}
