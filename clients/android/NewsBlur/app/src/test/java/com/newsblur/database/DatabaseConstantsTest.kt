package com.newsblur.database

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DatabaseConstantsTest {
    @Test
    fun `daily briefing reader query preserves session order without ambiguous rowid`() {
        val query = DatabaseConstants.DAILY_BRIEFING_SESSION_STORY_QUERY

        assertTrue(query.contains("FROM reading_session"))
        assertTrue(query.contains("INNER JOIN stories ON reading_session.session_story_hash = stories.story_hash"))
        assertTrue(query.contains("ORDER BY reading_session.rowid"))
        assertFalse(query.contains("ORDER BY rowid"))
    }
}
