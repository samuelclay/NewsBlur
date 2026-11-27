package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Locale
import java.util.TimeZone

/** Test_ListenUsageText.kt checks how ListenUsageText.kt words the listening allowance: the time left and the reset day. */
class Test_ListenUsageText {
    @Test
    fun test_hours_and_minutes_split_the_seconds_left() {
        assertEquals(9 to 58, listenHoursAndMinutes(35_880.0))
        assertEquals(1 to 0, listenHoursAndMinutes(3_600.0))
        assertEquals(0 to 45, listenHoursAndMinutes(2_700.0))
        assertEquals(10 to 0, listenHoursAndMinutes(36_000.0))
    }

    @Test
    fun test_partial_minutes_round_down_and_overdrawn_time_reads_as_nothing_left() {
        assertEquals(0 to 0, listenHoursAndMinutes(59.9))
        assertEquals(0 to 1, listenHoursAndMinutes(119.0))
        assertEquals(0 to 0, listenHoursAndMinutes(-300.0))
    }

    // android.text.format.DateFormat picks these per locale on a device; here they're given directly.
    private val usPatterns = mapOf("EEEE" to "EEEE", "MMMMd" to "MMMM d")

    @Test
    fun test_reset_dates_read_iso_timestamps_as_the_weekday() {
        // Pro's week starts on Sunday (apps/listen/usage.py), and 2026-11-01 is one.
        assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00+00:00", "week", Locale.US, usPatterns::getValue))
        assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00Z", "week", Locale.US, usPatterns::getValue))
        assertNull(listenResetDate("soon", "week", Locale.US, usPatterns::getValue))
        assertNull(listenResetDate(null, "week", Locale.US, usPatterns::getValue))
    }

    @Test
    fun test_a_monthly_allowance_resets_on_a_date_and_a_weekly_one_on_a_weekday() {
        // Premium Archive's month starts at midnight on the 1st in the account's timezone; 2026-12-01 is a Tuesday.
        assertEquals("December 1", listenResetDate("2026-12-01T00:00:00-05:00", "month", Locale.US, usPatterns::getValue))
        assertEquals("Tuesday", listenResetDate("2026-12-01T00:00:00-05:00", "week", Locale.US, usPatterns::getValue))
        assertEquals("Tuesday", listenResetDate("2026-12-01T00:00:00-05:00", null, Locale.US, usPatterns::getValue))
    }

    @Test
    fun test_reset_dates_follow_the_locales_language() {
        assertEquals("Sonntag", listenResetDate("2026-11-01T00:00:00Z", "week", Locale.GERMANY) { "EEEE" })
    }

    @Test
    fun test_reset_date_is_the_accounts_day_not_the_devices() {
        // The allowance resets at midnight in the account's timezone (apps/listen/usage.py), so an Eastern
        // account shows Sunday whatever timezone the phone is in, like the web does; in Los Angeles that
        // instant is still Saturday evening.
        val deviceZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/Los_Angeles"))
            assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00-04:00", "week", Locale.US, usPatterns::getValue))
            // The first of the month at Eastern midnight is still November 30 in Los Angeles.
            assertEquals("December 1", listenResetDate("2026-12-01T00:00:00-05:00", "month", Locale.US, usPatterns::getValue))
        } finally {
            TimeZone.setDefault(deviceZone)
        }
    }
}
