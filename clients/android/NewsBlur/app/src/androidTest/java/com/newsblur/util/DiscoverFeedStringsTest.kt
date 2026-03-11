package com.newsblur.util

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.newsblur.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DiscoverFeedStringsTest {
    @Test
    fun discover_stories_per_month_uses_compact_copy() {
        val resources = InstrumentationRegistry.getInstrumentation().targetContext.resources

        assertEquals("1 story/mo", resources.getQuantityString(R.plurals.discover_stories_per_month, 1, "1"))
        assertEquals("4 stories/mo", resources.getQuantityString(R.plurals.discover_stories_per_month, 4, "4"))
    }
}
