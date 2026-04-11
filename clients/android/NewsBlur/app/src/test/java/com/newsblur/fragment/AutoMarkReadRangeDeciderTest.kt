package com.newsblur.fragment

import org.junit.Assert.assertEquals
import org.junit.Test

class AutoMarkReadRangeDeciderTest {
    @Test
    fun normalScrollMarksOnlyStoriesAboveFirstVisible() {
        // first visible is 4, story 4's title hasn't crossed the fold yet
        assertEquals(3, AutoMarkReadRangeDecider.findMarkEnd(4, false, 10))
    }

    @Test
    fun topRowHalfwayPastFoldAlsoMarksTheTopVisibleStory() {
        // first visible is 4 and story 4 is halfway hidden under the feed bar
        assertEquals(4, AutoMarkReadRangeDecider.findMarkEnd(4, true, 10))
    }

    @Test
    fun partiallyVisibleTopStoryWithMidpointNotYetPastFoldIsNotMarked() {
        // first visible is 2 but less than half of it is hidden, so 2 stays unread
        assertEquals(1, AutoMarkReadRangeDecider.findMarkEnd(2, false, 10))
    }

    @Test
    fun reachingTheBottomWithoutScrollingOffDoesNotMarkVisibleStories() {
        // user scrolled to the bottom; story 7 is still more than half-visible below the feed bar
        assertEquals(6, AutoMarkReadRangeDecider.findMarkEnd(7, false, 10))
    }

    @Test
    fun scrollingTheLastStoryOffTheTopMarksEverything() {
        // footer padding let the user scroll the last story fully off the top
        assertEquals(9, AutoMarkReadRangeDecider.findMarkEnd(10, false, 10))
    }

    @Test
    fun markEndIsClampedToLastStory() {
        // firstVisible can land on the fleuron footer row once it becomes the topmost item
        assertEquals(9, AutoMarkReadRangeDecider.findMarkEnd(15, false, 10))
    }

    @Test
    fun halfwayPastFoldOnFooterRowIsClampedToLastStory() {
        // if firstVisible is the footer row, "halfway past fold" still clamps to storyCount - 1
        assertEquals(9, AutoMarkReadRangeDecider.findMarkEnd(10, true, 10))
    }

    @Test
    fun firstStoryStillAtTopMarksNothing() {
        assertEquals(-1, AutoMarkReadRangeDecider.findMarkEnd(0, false, 10))
    }

    @Test
    fun firstStoryHalfwayPastFoldMarksJustTheFirstStory() {
        assertEquals(0, AutoMarkReadRangeDecider.findMarkEnd(0, true, 10))
    }

    @Test
    fun noPositionMarksNothing() {
        assertEquals(-1, AutoMarkReadRangeDecider.findMarkEnd(-1, false, 10))
    }

    @Test
    fun emptyListsDoNotMarkAnything() {
        assertEquals(-1, AutoMarkReadRangeDecider.findMarkEnd(0, false, 0))
    }
}
