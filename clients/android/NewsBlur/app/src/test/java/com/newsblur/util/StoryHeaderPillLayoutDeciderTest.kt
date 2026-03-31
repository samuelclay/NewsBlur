package com.newsblur.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryHeaderPillLayoutDeciderTest {
    @Test
    fun prefers_collapsing_related_sites_before_search_when_only_one_label_fits() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                332,
                111,
                95,
                70,
                36,
                70,
                36,
                6,
                6,
                8,
                true,
                true,
            )

        assertFalse(decision.showDiscoverText())
        assertTrue(decision.showSearchText())
    }

    @Test
    fun keeps_both_labels_when_they_fit() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                420,
                111,
                95,
                70,
                36,
                70,
                36,
                6,
                6,
                8,
                true,
                true,
            )

        assertTrue(decision.showDiscoverText())
        assertTrue(decision.showSearchText())
    }

    @Test
    fun collapses_both_labels_when_only_icons_fit() {
        val decision =
            StoryHeaderPillLayoutDecider.decide(
                300,
                111,
                95,
                70,
                36,
                70,
                36,
                6,
                6,
                8,
                true,
                true,
            )

        assertFalse(decision.showDiscoverText())
        assertFalse(decision.showSearchText())
    }
}
