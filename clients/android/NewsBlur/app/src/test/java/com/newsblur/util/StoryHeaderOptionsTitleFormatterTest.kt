package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test

class StoryHeaderOptionsTitleFormatterTest {
    @Test
    fun keeps_combined_title_in_title_case() {
        val title = StoryHeaderOptionsTitleFormatter.format("All", "Newest", "Options", showReadFilter = true, showOrder = true)

        assertEquals("All · Newest", title)
    }

    @Test
    fun falls_back_to_single_visible_segment() {
        assertEquals("Unread", StoryHeaderOptionsTitleFormatter.format("Unread", "Newest", "Options", showReadFilter = true, showOrder = false))
        assertEquals("Oldest", StoryHeaderOptionsTitleFormatter.format("All", "Oldest", "Options", showReadFilter = false, showOrder = true))
        assertEquals("Options", StoryHeaderOptionsTitleFormatter.format("All", "Newest", "Options", showReadFilter = false, showOrder = false))
    }
}
