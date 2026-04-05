package com.newsblur.fragment

import org.junit.Assert.assertEquals
import org.junit.Test

class AutoMarkReadRangeDeciderTest {
    @Test
    fun normalScrollMarksTheTopObscuredStory() {
        assertEquals(3, AutoMarkReadRangeDecider.findMarkEnd(4, 7, 10, 2))
    }

    @Test
    fun bottomOnlyAdvancesOneStoryWhenTheVisibleBoundaryHasNotMoved() {
        assertEquals(5, AutoMarkReadRangeDecider.findMarkEnd(5, 9, 10, 4))
    }

    @Test
    fun bottomStartsFromTheFirstRemainingStoryWhenPreviouslyMarkedRowsDroppedOut() {
        assertEquals(0, AutoMarkReadRangeDecider.findMarkEnd(0, 5, 6, -1))
    }

    @Test
    fun emptyListsDoNotMarkAnything() {
        assertEquals(-1, AutoMarkReadRangeDecider.findMarkEnd(0, -1, 0, -1))
    }
}
