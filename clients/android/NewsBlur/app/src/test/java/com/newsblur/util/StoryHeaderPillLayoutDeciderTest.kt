package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryHeaderPillLayoutDeciderTest {
    @Test
    fun narrow_header_shortens_options_before_squeezing_any_icon() {
        // ItemsList.java must budget the options title along with every independently clickable icon.
        val decision = StoryHeaderPillLayoutDecider.decide(280, 148, 76, 95, 90, 36, 70, 36, 6, 6, 8, true, true)
        val requiredWidth = decision.optionsWidth() + 95 + 36 + 36 + 6 + 6 + 8

        assertFalse(decision.showFullOptionsTitle())
        assertFalse(decision.showDiscoverText())
        assertFalse(decision.showSearchText())
        assertTrue("All controls must fit the actual header width", requiredWidth <= 280)
        assertEquals(76, decision.optionsWidth())
    }

    @Test
    fun full_options_title_returns_as_soon_as_it_fits_with_the_icons() {
        val decision = StoryHeaderPillLayoutDecider.decide(350, 148, 76, 95, 90, 36, 70, 36, 6, 6, 8, true, true)
        assertTrue(decision.showFullOptionsTitle())
        assertEquals(148, decision.optionsWidth())
    }

    @Test
    fun enlarged_text_has_a_bounded_options_width_after_abbreviating() {
        val decision = StoryHeaderPillLayoutDecider.decide(280, 260, 180, 63, 130, 36, 105, 36, 6, 6, 8, true, true)
        assertFalse(decision.showFullOptionsTitle())
        assertEquals(125, decision.optionsWidth())
    }

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
