package com.newsblur.toolbar

import com.newsblur.util.FloatingToolbarLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_FloatingToolbarLayout {
    @Test fun test_phone_keeps_groups_separate_and_options_readable() {
        val fit = FloatingToolbarLayout.fit(328, 118, 83, 120, 82)
        assertFalse(fit.merged)
        assertEquals(2, fit.options)
        assertFalse(fit.discoverText)
        assertFalse(fit.searchText)
    }

    @Test fun test_narrow_window_merges_and_reduces_options_to_icon() {
        val fit = FloatingToolbarLayout.fit(240, 150, 95, 120, 82)
        assertTrue(fit.merged)
        assertEquals(0, fit.options)
        assertFalse(fit.discoverText)
        assertFalse(fit.searchText)
    }

    @Test fun test_landscape_restores_all_labels() {
        val fit = FloatingToolbarLayout.fit(680, 118, 83, 120, 82)
        assertFalse(fit.merged)
        assertEquals(2, fit.options)
        assertTrue(fit.discoverText)
        assertTrue(fit.searchText)
    }

    @Test fun test_hidden_actions_do_not_reserve_space() {
        val fit = FloatingToolbarLayout.fit(280, 118, 83, 120, 82, false, true, false)
        assertFalse(fit.merged)
        assertTrue(fit.searchText)
        assertFalse(fit.discoverText)
    }

    @Test fun test_bottom_menu_never_covers_its_button_even_in_landscape() {
        val popup = FloatingToolbarLayout.popover(0, 24, 780, 360, 620, 300, 664, 344, 320, 700, 8)
        assertTrue(popup.y >= 24)
        assertTrue(popup.y + popup.height <= 292)
        assertTrue(popup.x + popup.width <= 780)
        assertTrue(popup.height < 700)
    }

    @Test fun test_menu_lines_up_with_button_end_edge() {
        val ltr = FloatingToolbarLayout.popover(0, 24, 360, 780, 260, 70, 304, 114, 200, 300, 8)
        assertEquals(104, ltr.x)
        val rtl = FloatingToolbarLayout.popover(0, 24, 360, 780, 56, 70, 100, 114, 200, 300, 8, rtl = true)
        assertEquals(56, rtl.x)
        assertEquals(360 - ltr.x - ltr.width, rtl.x)
    }

    @Test fun test_rtl_menu_stays_on_screen_beside_the_right_edge() {
        val popup = FloatingToolbarLayout.popover(0, 24, 360, 780, 300, 70, 344, 114, 200, 300, 8, rtl = true)
        assertEquals(152, popup.x)
        assertTrue(popup.x + popup.width <= 352)
    }

    @Test fun test_top_menu_opens_below_visible_button() {
        val popup = FloatingToolbarLayout.popover(0, 24, 360, 780, 16, 70, 60, 114, 400, 600, 8)
        assertEquals(122, popup.y)
        assertTrue(popup.width <= 344)
        assertTrue(popup.y + popup.height < 780)
    }
}
