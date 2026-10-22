package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale
import java.util.TimeZone

/** Test_ListenVoiceMatching.kt covers the voice picker's client-side filters and its one combined list. */
class Test_ListenVoiceMatching {
    private val nimrod =
        ListenVoice(
            voiceId = "n",
            name = "Nimrod",
            description = "Warm & Confident",
            gender = "male",
            age = "middle_aged",
            accent = "standard",
            descriptive = "warm",
            useCase = "narrative_story",
            language = "he",
        )
    private val dana = ListenVoice(voiceId = "d", name = "Dana", gender = "female", age = "young", accent = "israeli", language = "he")

    @Test
    fun test_every_filter_must_match() {
        assertTrue(ListenVoiceMatching.matches(nimrod, mapOf("gender" to "male", "age" to "middle_aged"), ""))
        assertFalse(ListenVoiceMatching.matches(nimrod, mapOf("gender" to "male", "age" to "young"), ""))
        assertTrue(ListenVoiceMatching.matches(nimrod, mapOf("descriptive" to "warm"), ""))
    }

    @Test
    fun test_search_looks_at_name_description_and_traits() {
        assertTrue(ListenVoiceMatching.matches(nimrod, emptyMap(), "nim"))
        assertTrue(ListenVoiceMatching.matches(nimrod, emptyMap(), "CONFIDENT"))
        assertTrue(ListenVoiceMatching.matches(nimrod, emptyMap(), "narrative"))
        assertFalse(ListenVoiceMatching.matches(nimrod, emptyMap(), "dana"))
        assertTrue(ListenVoiceMatching.matches(dana, emptyMap(), "  "))
    }

    @Test
    fun test_a_picked_library_voice_stays_at_the_top() {
        val picked = ListenVoice(voiceId = "lib", name = "Library pick", language = "he")
        assertEquals(listOf("lib", "n", "d"), ListenVoiceMatching.recommended(listOf(nimrod, dana), picked).map { it.voiceId })
        assertEquals(listOf("n", "d"), ListenVoiceMatching.recommended(listOf(nimrod, dana), dana).map { it.voiceId })
        assertEquals(listOf("n", "d"), ListenVoiceMatching.recommended(listOf(nimrod, dana), null).map { it.voiceId })
    }

    @Test
    fun test_more_voices_skip_the_ones_already_recommended() {
        val library = listOf(dana, ListenVoice(voiceId = "x", name = "X"), ListenVoice(voiceId = "x", name = "X again"))
        assertEquals(listOf("x"), ListenVoiceMatching.more(library, listOf(nimrod, dana)).map { it.voiceId })
    }

    @Test
    fun test_picker_state_filters_recommended_but_not_the_server_library() {
        val state =
            ListenVoiceSettingsUiState(
                language = "he",
                curated = listOf(nimrod, dana),
                activeFilters = mapOf("gender" to "female"),
                library = ListenLibraryState(voices = listOf(ListenVoice(voiceId = "l", name = "Server filtered"))),
            )
        assertEquals(listOf("d"), state.recommended.map { it.voiceId })
        assertEquals(listOf("l"), state.moreVoices.map { it.voiceId })
        assertTrue(state.hasFilters)
    }

    // android.text.format.DateFormat picks these per locale on a device; here they're given directly.
    private val usMonthDay = "MMM d"

    @Test
    fun test_reset_dates_read_iso_timestamps() {
        assertEquals("Nov 1", listenResetDate("2026-11-01T00:00:00+00:00", Locale.US, usMonthDay))
        assertEquals("Nov 1", listenResetDate("2026-11-01T00:00:00Z", Locale.US, usMonthDay))
        assertNull(listenResetDate("soon", Locale.US, usMonthDay))
        assertNull(listenResetDate(null, Locale.US, usMonthDay))
    }

    @Test
    fun test_reset_dates_follow_the_locales_date_order() {
        assertEquals("1. Nov.", listenResetDate("2026-11-01T00:00:00Z", Locale.GERMANY, "d. MMM"))
    }

    @Test
    fun test_reset_date_is_the_accounts_date_not_the_devices() {
        // The allowance resets at midnight in the account's timezone (apps/listen/usage.py), so an Eastern
        // account shows Nov 1 whatever timezone the phone is in, like the web does.
        val deviceZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/Los_Angeles"))
            assertEquals("Nov 1", listenResetDate("2026-11-01T00:00:00-04:00", Locale.US, usMonthDay))
        } finally {
            TimeZone.setDefault(deviceZone)
        }
    }
}
