package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.log10

/**
 * Test_ListenAudioMix.kt checks the Music / Voice balance math and focus rules in ListenAudioMix.kt, which match
 * iOS's ListenAudioMix.swift.
 */
class Test_ListenAudioMix {
    @Test
    fun test_podcasts_keep_exclusive_focus_and_normal_volume_without_changing_narration_settings() {
        for (volume in listOf(0.01, 10.0)) {
            val saved = ListenAudioMixSettings(playsOverOtherAudio = true, voiceVolume = volume)
            val podcast = saved.forPlayback(isMedia = true)
            assertEquals(ListenFocusMode.EXCLUSIVE, podcast.focusMode)
            assertEquals(1.0, podcast.effectiveVoiceVolume, 0.0)
            assertEquals(ListenFocusMode.DUCK_OTHERS, saved.forPlayback(isMedia = false).focusMode)
            assertEquals(volume, saved.forPlayback(isMedia = false).effectiveVoiceVolume, 0.0)
        }
    }

    private fun decibels(volume: Double): Double = 20 * log10(volume)

    @Test
    fun test_middle_is_the_voice_at_full_volume_and_the_ends_reach_the_limits() {
        assertEquals(1.0, ListenAudioMixMath.voiceVolumeForBalance(0.0), 1e-9)
        assertEquals(ListenAudioMixMath.MAX_VOICE_VOLUME, ListenAudioMixMath.voiceVolumeForBalance(1.0), 1e-9)
        assertEquals(ListenAudioMixMath.MIN_VOICE_VOLUME, ListenAudioMixMath.voiceVolumeForBalance(-1.0), 1e-9)
        assertEquals(20.0, decibels(ListenAudioMixMath.MAX_VOICE_VOLUME), 1e-9)
        assertEquals(-40.0, decibels(ListenAudioMixMath.MIN_VOICE_VOLUME), 1e-9)
    }

    @Test
    fun test_each_half_of_the_slider_is_even_in_decibels() {
        // Test_ListenAudioMix.kt: halfway toward Voice is +10 dB, halfway toward Music is -20 dB.
        assertEquals(10.0, decibels(ListenAudioMixMath.voiceVolumeForBalance(0.5)), 1e-9)
        assertEquals(-20.0, decibels(ListenAudioMixMath.voiceVolumeForBalance(-0.5)), 1e-9)
    }

    @Test
    fun test_balance_round_trips_so_the_slider_reopens_where_it_was_left() {
        var balance = -1.0
        while (balance <= 1.0) {
            val volume = ListenAudioMixMath.voiceVolumeForBalance(balance)
            assertEquals(balance, ListenAudioMixMath.balanceForVoiceVolume(volume), 1e-9)
            balance += 0.125
        }
    }

    @Test
    fun test_out_of_range_volumes_are_clamped() {
        assertEquals(ListenAudioMixMath.MIN_VOICE_VOLUME, ListenAudioMixMath.clampVoiceVolume(0.0), 0.0)
        assertEquals(ListenAudioMixMath.MAX_VOICE_VOLUME, ListenAudioMixMath.clampVoiceVolume(500.0), 0.0)
        assertEquals(1.0, ListenAudioMixMath.clampVoiceVolume(Double.NaN), 0.0)
        assertEquals(1.0, ListenAudioMixMath.voiceVolumeForBalance(Double.NaN), 0.0)
    }

    @Test
    fun test_the_middle_snaps_so_full_volume_is_easy_to_find() {
        assertEquals(0.0, ListenAudioMixMath.snapped(0.05), 0.0)
        assertEquals(0.0, ListenAudioMixMath.snapped(-0.05), 0.0)
        assertEquals(0.07, ListenAudioMixMath.snapped(0.07), 0.0)
    }

    @Test
    fun test_the_balance_only_changes_the_voice_while_playing_over_other_audio() {
        val hidden = ListenAudioMixSettings(playsOverOtherAudio = false, voiceVolume = 0.05)
        assertEquals("A hidden slider can't leave the voice quiet", 1.0, hidden.effectiveVoiceVolume, 0.0)
        val shown = hidden.copy(playsOverOtherAudio = true)
        assertEquals(0.05, shown.effectiveVoiceVolume, 1e-9)
    }

    @Test
    fun test_player_volume_stops_at_one_and_the_boost_carries_the_rest() {
        assertEquals(0.25f, ListenAudioMixMath.playerVolume(0.25), 1e-6f)
        assertEquals(1f, ListenAudioMixMath.playerVolume(4.0), 0f)
        assertEquals(0, ListenAudioMixMath.boostMillibels(1.0))
        assertEquals(0, ListenAudioMixMath.boostMillibels(0.5))
        assertEquals(2000, ListenAudioMixMath.boostMillibels(10.0))
        assertEquals(1000, ListenAudioMixMath.boostMillibels(ListenAudioMixMath.voiceVolumeForBalance(0.5)))
    }

    @Test
    fun test_listen_only_stops_taking_focus_when_playing_over_other_audio() {
        assertEquals(ListenFocusMode.EXCLUSIVE, ListenAudioMixSettings().focusMode)
        assertEquals(
            ListenFocusMode.EXCLUSIVE,
            ListenAudioMixSettings(playsOverOtherAudio = false, lowersMusicWhileSpeaking = false).focusMode,
        )
        assertEquals(ListenFocusMode.DUCK_OTHERS, ListenAudioMixSettings(playsOverOtherAudio = true).focusMode)
        assertEquals(
            ListenFocusMode.NONE,
            ListenAudioMixSettings(playsOverOtherAudio = true, lowersMusicWhileSpeaking = false).focusMode,
        )
    }

    @Test
    fun test_ringing_and_calls_count_as_calls_on_every_android_version() {
        assertTrue(ListenAudioMixMath.isCallMode(android.media.AudioManager.MODE_RINGTONE))
        assertTrue(ListenAudioMixMath.isCallMode(android.media.AudioManager.MODE_IN_CALL))
        assertTrue(ListenAudioMixMath.isCallMode(android.media.AudioManager.MODE_IN_COMMUNICATION))
        // Test_ListenAudioMix.kt: call screening is mode 4 from Android 11.
        assertTrue(ListenAudioMixMath.isCallMode(4))
        assertFalse(ListenAudioMixMath.isCallMode(android.media.AudioManager.MODE_NORMAL))
    }

    @Test
    fun test_defaults_match_ios() {
        val defaults = ListenAudioMixSettings()
        assertFalse(defaults.playsOverOtherAudio)
        assertTrue(defaults.lowersMusicWhileSpeaking)
        assertFalse(defaults.isMusicSectionCollapsed)
        assertEquals(1.0, defaults.voiceVolume, 0.0)
    }
}
