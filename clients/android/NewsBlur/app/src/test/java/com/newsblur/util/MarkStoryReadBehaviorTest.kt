package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkStoryReadBehaviorTest {
    @Test
    fun dwellTimesMatchTheirPreferenceLabels() {
        for (seconds in listOf(5, 10, 20, 30, 45, 60)) {
            assertEquals(seconds * 1000L, MarkStoryReadBehavior.valueOf("SECONDS_$seconds").getDelayMillis())
        }
        assertEquals(0L, MarkStoryReadBehavior.IMMEDIATELY.getDelayMillis())
        assertEquals(-1L, MarkStoryReadBehavior.MANUALLY.getDelayMillis())
    }
}
