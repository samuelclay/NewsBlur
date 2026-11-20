package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Locale
import java.util.TimeZone

/** Test_ListenUsageText.kt checks how ListenUsageText.kt words the weekly allowance: the time left and the reset day. */
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
    private val usWeekday = "EEEE"

    @Test
    fun test_reset_dates_read_iso_timestamps_as_the_weekday() {
        // The week starts on Sunday (apps/listen/usage.py), and 2026-11-01 is one.
        assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00+00:00", Locale.US, usWeekday))
        assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00Z", Locale.US, usWeekday))
        assertNull(listenResetDate("soon", Locale.US, usWeekday))
        assertNull(listenResetDate(null, Locale.US, usWeekday))
    }

    @Test
    fun test_reset_dates_follow_the_locales_language() {
        assertEquals("Sonntag", listenResetDate("2026-11-01T00:00:00Z", Locale.GERMANY, "EEEE"))
    }

    @Test
    fun test_reset_date_is_the_accounts_day_not_the_devices() {
        // The allowance resets at midnight in the account's timezone (apps/listen/usage.py), so an Eastern
        // account shows Sunday whatever timezone the phone is in, like the web does; in Los Angeles that
        // instant is still Saturday evening.
        val deviceZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/Los_Angeles"))
            assertEquals("Sunday", listenResetDate("2026-11-01T00:00:00-04:00", Locale.US, usWeekday))
        } finally {
            TimeZone.setDefault(deviceZone)
        }
    }
}
