package com.newsblur.addsite

import com.google.gson.Gson
import com.newsblur.domain.FeedResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.util.Locale

class SiteFreshnessTest {
    @Test fun missingDatesStayHiddenAndRecentDatesMatchIosUnits() {
        assertNull(SiteFreshness.from(null))
        assertNull(SiteFreshness.from(0))
        assertEquals("1h ago", SiteFreshness.from(1)?.text)
        assertEquals("2d ago", SiteFreshness.from(172800)?.text)
        assertEquals("2w ago", SiteFreshness.from(14 * 86400)?.text)
        assertEquals("2mo ago", SiteFreshness.from(60 * 86400)?.text)
        assertFalse(SiteFreshness.from(365 * 86400)!!.stale)
    }

    @Test fun olderDatesShowStaleMonthAndYear() {
        val now = Instant.parse("2026-09-13T12:00:00Z")
        val then = Instant.parse("2014-06-15T12:00:00Z")
        val result = SiteFreshness.from(now.epochSecond - then.epochSecond, now, Locale.US)!!
        assertEquals("Stale Jun 2014", result.text)
        assertTrue(result.stale)
    }

    @Test fun apiFreshnessFieldIsOptionalAndParsed() {
        val gson = Gson()
        assertEquals(
            172800L,
            gson
                .fromJson(
                    """{"id":1,"label":"Site","value":"https://example.com","last_story_seconds_ago":172800}""",
                    FeedResult::class.java,
                ).lastStorySecondsAgo,
        )
        assertNull(gson.fromJson("""{"id":1,"label":"Site","value":"https://example.com"}""", FeedResult::class.java).lastStorySecondsAgo)
    }
}
