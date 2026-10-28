package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/** Test_ListenSpeed.kt checks the speed control math in ListenSpeed.kt that the web and iOS players share. */
class Test_ListenSpeed {
    @Test
    fun test_stops_cover_the_range_with_fine_steps_near_normal() {
        assertEquals(83, ListenSpeed.STOPS.size)
        assertEquals(0.5, ListenSpeed.STOPS.first(), 0.0)
        assertEquals(3.0, ListenSpeed.STOPS.last(), 0.0)
        assertEquals(listOf(0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.81), ListenSpeed.STOPS.take(8))
        assertEquals(listOf(1.19, 1.2, 1.25, 1.3), ListenSpeed.STOPS.subList(45, 49))
        // ListenSpeed.kt gives the 0.80 to 1.25 band about half the slider.
        val fineBand = ListenSpeed.STOPS.count { it in 0.8..1.25 }
        assertTrue(fineBand in 38..46)
    }

    @Test
    fun test_normal_speed_has_its_own_stop_for_the_tick() {
        val index = ListenSpeed.nearestStopIndex(1.0)
        assertEquals(26, index)
        assertEquals(1.0, ListenSpeed.stopAt(index), 0.0)
        assertEquals(26f / 82f, ListenSpeed.normalTickFraction, 0.0001f)
    }

    @Test
    fun test_every_stop_maps_back_to_its_own_index() {
        ListenSpeed.STOPS.forEachIndexed { index, stop ->
            assertEquals(index, ListenSpeed.nearestStopIndex(stop))
        }
    }

    @Test
    fun test_typed_value_between_stops_moves_thumb_to_nearest_stop() {
        assertEquals(1.25, ListenSpeed.stopAt(ListenSpeed.nearestStopIndex(1.23)), 0.0)
        assertEquals(1.2, ListenSpeed.stopAt(ListenSpeed.nearestStopIndex(1.22)), 0.0)
        assertEquals(2.05, ListenSpeed.stopAt(ListenSpeed.nearestStopIndex(2.07)), 0.0)
        assertEquals(0.55, ListenSpeed.stopAt(ListenSpeed.nearestStopIndex(0.53)), 0.0)
        assertEquals(1.07, ListenSpeed.stopAt(ListenSpeed.nearestStopIndex(1.07)), 0.0)
    }

    @Test
    fun test_clamp_rounds_to_hundredths_and_stays_in_range() {
        assertEquals(1.07, ListenSpeed.clamp(1.074), 0.0)
        assertEquals(1.08, ListenSpeed.clamp(1.075), 0.0)
        assertEquals(1.25, ListenSpeed.clamp(1.25f.toDouble()), 0.0)
        assertEquals(0.5, ListenSpeed.clamp(0.2), 0.0)
        assertEquals(3.0, ListenSpeed.clamp(9.0), 0.0)
        assertEquals(3.0, ListenSpeed.clamp(Double.MAX_VALUE), 0.0)
        assertEquals(1.0, ListenSpeed.clamp(Double.NaN), 0.0)
    }

    @Test
    fun test_stop_at_clamps_slider_positions() {
        assertEquals(0.5, ListenSpeed.stopAt(-3), 0.0)
        assertEquals(3.0, ListenSpeed.stopAt(200), 0.0)
        assertEquals(1.0, ListenSpeed.stopAt(25.6f), 0.0)
    }

    @Test
    fun test_presets_highlight_only_on_exact_match() {
        assertEquals(listOf(0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0), ListenSpeed.PRESETS)
        assertTrue(ListenSpeed.isSelected(1.1, 1.1))
        assertTrue(ListenSpeed.isSelected(1.25, 1.25f.toDouble()))
        assertFalse(ListenSpeed.isSelected(1.1, 1.11))
        assertFalse(ListenSpeed.isSelected(1.0, 1.05))
        assertEquals(listOf<Double>(), ListenSpeed.PRESETS.filter { ListenSpeed.isSelected(it, 1.07) })
    }

    @Test
    fun test_parse_accepts_typed_rates() {
        assertEquals(1.05, ListenSpeed.parse("1.05")!!, 0.0)
        assertEquals(1.05, ListenSpeed.parse(" 1,05 ")!!, 0.0)
        assertEquals(1.5, ListenSpeed.parse("1.5×")!!, 0.0)
        assertEquals(2.0, ListenSpeed.parse("2x")!!, 0.0)
        assertEquals(0.75, ListenSpeed.parse(".75")!!, 0.0)
        assertNull(ListenSpeed.parse(""))
        assertNull(ListenSpeed.parse("fast"))
        assertNull(ListenSpeed.parse("×"))
    }

    @Test
    fun test_sanitize_input_keeps_one_short_decimal() {
        assertEquals("1.05", ListenSpeed.sanitizeInput("1.05"))
        assertEquals("1,5", ListenSpeed.sanitizeInput("1,5"))
        assertEquals("1.05", ListenSpeed.sanitizeInput("1.0.5"))
        assertEquals("2", ListenSpeed.sanitizeInput("2×"))
        assertEquals("1.25", ListenSpeed.sanitizeInput("1.2549"))
        assertEquals("", ListenSpeed.sanitizeInput("-x"))
    }

    @Test
    fun test_format_shows_up_to_two_decimals() {
        assertEquals("1", ListenSpeed.format(1.0, Locale.US))
        assertEquals("1.1", ListenSpeed.format(1.1, Locale.US))
        assertEquals("1.05", ListenSpeed.format(1.05, Locale.US))
        assertEquals("1.25", ListenSpeed.format(1.2500000476837158, Locale.US))
        assertEquals("1,05", ListenSpeed.format(1.05, Locale.GERMANY))
    }

    @Test
    fun test_pref_string_is_a_plain_two_place_decimal() {
        assertEquals("1.05", ListenSpeed.prefString(1.05))
        assertEquals("1", ListenSpeed.prefString(1.0))
        assertEquals("1.1", ListenSpeed.prefString(1.1))
        assertEquals("1.25", ListenSpeed.prefString(1.25f.toDouble()))
        assertEquals("3", ListenSpeed.prefString(4.0))
        assertEquals("0.5", ListenSpeed.prefString(0.1))
    }
}
