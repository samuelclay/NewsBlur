package com.newsblur.util

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DiscoverStoryTextFormatterTest {
    @Test
    fun decodes_html_entities_in_discover_story_titles() {
        assertEquals(
            "Microsoft’s Xbox mode",
            DiscoverStoryTextFormatter.formatTitle("Microsoft&#8217;s Xbox mode").toString(),
        )
    }
}
