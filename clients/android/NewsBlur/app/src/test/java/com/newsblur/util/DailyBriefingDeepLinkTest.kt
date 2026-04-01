package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DailyBriefingDeepLinkTest {
    @Test
    fun `extracts story hash from daily briefing query parameter`() {
        assertEquals(
            "feed:1",
            DailyBriefingLinkDecision.storyHash("https://www.newsblur.com/briefing?story=feed%3A1"),
        )
    }

    @Test
    fun `supports canonical daily briefing page paths without a story hash`() {
        assertTrue(DailyBriefingLinkDecision.isSupported("https://newsblur.com/briefing/123/2026-04-01"))
        assertNull(DailyBriefingLinkDecision.storyHash("https://newsblur.com/briefing/123/2026-04-01"))
    }

    @Test
    fun `ignores non briefing urls`() {
        assertFalse(DailyBriefingLinkDecision.isSupported("https://www.newsblur.com/social"))
        assertNull(DailyBriefingLinkDecision.storyHash("https://www.newsblur.com/social?story=feed%3A1"))
        assertFalse(DailyBriefingLinkDecision.isSupported("https://example.com/briefing?story=feed%3A1"))
    }
}
