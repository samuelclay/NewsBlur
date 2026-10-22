package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Test_StoryButtonLayout.kt: five story buttons split three over two, fewer share one row. */
class Test_StoryButtonLayout {
    @Test
    fun test_five_buttons_split_three_over_two() {
        assertEquals(
            listOf(listOf(1, 2, 3), listOf(4, 5)),
            StoryButtonLayout.rows(listOf(1, 2, 3, 4, 5)),
        )
    }

    @Test
    fun test_four_or_fewer_share_one_row() {
        assertEquals(listOf(listOf(1, 2, 3, 4)), StoryButtonLayout.rows(listOf(1, 2, 3, 4)))
        assertEquals(listOf(listOf(1)), StoryButtonLayout.rows(listOf(1)))
        assertEquals(emptyList<List<Int>>(), StoryButtonLayout.rows(emptyList<Int>()))
    }

    @Test
    fun test_story_buttons_use_server_pref_names() {
        assertEquals(
            listOf(
                "show_sideoption_train",
                "show_sideoption_save",
                "show_sideoption_share",
                "show_sideoption_ask_ai",
                "show_sideoption_listen",
            ),
            StoryButton.entries.map { it.prefKey },
        )
        assertEquals(StoryButton.LISTEN, StoryButton.forPrefKey("show_sideoption_listen"))
        assertNull(StoryButton.forPrefKey("show_sideoption_email"))
    }
}
