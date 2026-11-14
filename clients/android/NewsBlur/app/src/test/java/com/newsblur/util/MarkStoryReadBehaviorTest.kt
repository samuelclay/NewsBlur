package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkStoryReadBehaviorTest {
    @Test
    fun dwellTimesMatchTheirPreferenceLabels() {
        for (seconds in listOf(1, 2, 3, 5, 10, 20, 30, 45, 60)) {
            assertEquals(seconds * 1000L, MarkStoryReadBehavior.valueOf("SECONDS_$seconds").getDelayMillis())
        }
        assertEquals(0L, MarkStoryReadBehavior.ON_SCROLL.getDelayMillis())
        assertEquals(0L, MarkStoryReadBehavior.IMMEDIATELY.getDelayMillis())
        assertEquals(-1L, MarkStoryReadBehavior.MANUALLY.getDelayMillis())
    }
    @Test
    fun sharedMenuOffersRequestedModesAndPreservesExistingLegacySelections() {
        assertEquals(
            listOf("ON_SCROLL", "IMMEDIATELY", "SECONDS_1", "SECONDS_2", "SECONDS_3", "SECONDS_5", "SECONDS_10", "SECONDS_30", "SECONDS_60", "MANUALLY"),
            MarkStoryReadBehavior.options().map { it.name },
        )
        assertEquals(11, MarkStoryReadBehavior.options(MarkStoryReadBehavior.SECONDS_20).size)
        assertEquals(true, MarkStoryReadBehavior.options(MarkStoryReadBehavior.SECONDS_45).contains(MarkStoryReadBehavior.SECONDS_45))
    }
}
