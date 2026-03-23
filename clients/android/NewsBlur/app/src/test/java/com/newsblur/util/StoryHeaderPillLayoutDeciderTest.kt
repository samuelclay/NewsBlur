package com.newsblur.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryHeaderPillLayoutDeciderTest {
    @Test
    fun prefers_collapsing_related_sites_before_search_when_only_one_label_fits() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                availableWidth = 332,
                optionsWidth = 111,
                markReadWidth = 95,
                discoverFullWidth = 70,
                discoverCompactWidth = 36,
                searchFullWidth = 70,
                searchCompactWidth = 36,
                discoverMargin = 6,
                searchMargin = 6,
                markReadMargin = 8,
                discoverVisible = true,
                searchVisible = true,
            )

        assertFalse(decision.showDiscoverText())
        assertTrue(decision.showSearchText())
    }

    @Test
    fun keeps_both_labels_when_they_fit() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                availableWidth = 420,
                optionsWidth = 111,
                markReadWidth = 95,
                discoverFullWidth = 70,
                discoverCompactWidth = 36,
                searchFullWidth = 70,
                searchCompactWidth = 36,
                discoverMargin = 6,
                searchMargin = 6,
                markReadMargin = 8,
                discoverVisible = true,
                searchVisible = true,
            )

        assertTrue(decision.showDiscoverText())
        assertTrue(decision.showSearchText())
    }

    @Test
    fun collapses_both_labels_when_only_icons_fit() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                availableWidth = 300,
                optionsWidth = 111,
                markReadWidth = 95,
                discoverFullWidth = 70,
                discoverCompactWidth = 36,
                searchFullWidth = 70,
                searchCompactWidth = 36,
                discoverMargin = 6,
                searchMargin = 6,
                markReadMargin = 8,
                discoverVisible = true,
                searchVisible = true,
            )

        assertFalse(decision.showDiscoverText())
        assertFalse(decision.showSearchText())
    }
}
