package com.newsblur.database

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_ReadingPageOrder {
    private val leftToRight = ReadingPageOrder(mirrored = false)
    private val rightToLeft = ReadingPageOrder(mirrored = true)

    @Test
    fun test_left_to_right_pages_are_story_positions() {
        for (position in 0 until 5) {
            assertEquals(position, leftToRight.pageFor(position, 5))
            assertEquals(position, leftToRight.storyPositionFor(position, 5))
        }
    }

    @Test
    fun test_right_to_left_puts_the_first_story_on_the_last_page_and_the_next_story_to_its_left() {
        assertEquals(4, rightToLeft.pageFor(0, 5))
        assertEquals(0, rightToLeft.pageFor(4, 5))
        for (position in 0 until 4) {
            assertEquals(rightToLeft.pageFor(position, 5) - 1, rightToLeft.pageFor(position + 1, 5))
        }
    }

    @Test
    fun test_right_to_left_mapping_round_trips() {
        for (position in 0 until 7) {
            assertEquals(position, rightToLeft.storyPositionFor(rightToLeft.pageFor(position, 7), 7))
        }
    }

    @Test
    fun test_loading_more_stories_shifts_the_current_page_but_keeps_its_story() {
        val story = 3
        val pageBefore = rightToLeft.pageFor(story, 10)
        val pageAfter = rightToLeft.pageFor(story, 25)
        // ViewPager follows the current page by the number of stories added, so the reader stays put.
        assertEquals(pageBefore + 15, pageAfter)
        assertEquals(story, rightToLeft.storyPositionFor(pageAfter, 25))
    }

    @Test
    fun test_an_empty_pager_keeps_page_zero() {
        assertEquals(0, rightToLeft.pageFor(0, 0))
        assertEquals(0, rightToLeft.storyPositionFor(0, 0))
    }

    @Test
    fun test_mirrored_pager_drops_the_repeat_of_the_current_story_after_more_stories_load() {
        val selections = ReadingPageSelections(rightToLeft)
        assertTrue(selections.select(3, "feed:3"))
        // More stories loaded: ViewPager re-reports story 3 under its shifted page.
        assertFalse(selections.select(3, "feed:3"))
        assertTrue(selections.select(4, "feed:4"))
        assertTrue(selections.select(3, "feed:3"))
        // A different story at the same position is a real selection.
        assertTrue(selections.select(3, "feed:inserted"))
    }

    @Test
    fun test_left_to_right_selections_always_pass_through() {
        val selections = ReadingPageSelections(leftToRight)
        assertTrue(selections.select(3, "feed:3"))
        assertTrue(selections.select(3, "feed:3"))
    }
}
