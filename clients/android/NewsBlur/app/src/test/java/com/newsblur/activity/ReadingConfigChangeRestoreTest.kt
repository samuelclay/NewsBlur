package com.newsblur.activity

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReadingConfigChangeRestoreTest {
    @Test
    fun noStoryHashDoesNotCreateRestoreState() {
        assertNull(createReadingConfigChangeRestore(null, 0.42f))
    }

    @Test
    fun restoreStateDefaultsMissingScrollPositionToTop() {
        assertEquals(
            ReadingConfigChangeRestore("story-hash", 0f),
            createReadingConfigChangeRestore("story-hash", null),
        )
    }

    @Test
    fun restoreStateKeepsStoryHashAndRelativeScrollPosition() {
        assertEquals(
            ReadingConfigChangeRestore("story-hash", 0.42f),
            createReadingConfigChangeRestore("story-hash", 0.42f),
        )
    }
}
