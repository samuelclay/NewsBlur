package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Test_ListenPlayedTime.kt checks the played-time count ListenManager.kt sends to POST /listen/progress. */
class Test_ListenPlayedTime {
    /** Plays from startMs for durationMs of wall time at speed, sampling every 200ms like ListenManager.kt's tick. */
    private fun ListenPlayedTime.play(
        startMs: Long,
        startRealtimeMs: Long,
        durationMs: Long,
        speed: Double = 1.0,
    ): Long {
        var elapsed = 0L
        while (elapsed <= durationMs) {
            sample(startMs + (elapsed * speed).toLong(), startRealtimeMs + elapsed, speed)
            elapsed += 200L
        }
        return startMs + (durationMs * speed).toLong()
    }

    @Test
    fun test_counts_the_timeline_that_played() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 10_000L, durationMs = 30_000L)
        assertEquals(30_000L, played.take(finished = false))
        assertEquals(0L, played.pendingMs)
    }

    @Test
    fun test_counts_timeline_seconds_not_wall_seconds_at_higher_speeds() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 10_000L, speed = 2.0)
        assertEquals(20_000L, played.take(finished = false))
    }

    @Test
    fun test_paused_and_buffering_time_adds_nothing() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 5_000L)
        // Paused for a minute: the position holds while the samples keep coming.
        for (tick in 0..300) played.sample(5_000L, 5_000L + tick * 200L, 1.0)
        played.play(startMs = 5_000L, startRealtimeMs = 65_200L, durationMs = 5_000L)
        assertEquals(10_000L, played.take(finished = false))
    }

    @Test
    fun test_seeks_and_skips_do_not_count() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 4_000L)
        // An unannounced 30 second skip between two samples is too far to have been played.
        played.sample(34_000L, 4_200L, 1.0)
        played.play(startMs = 34_000L, startRealtimeMs = 4_200L, durationMs = 2_000L)
        // A skip back is never counted either.
        played.sample(21_000L, 6_400L, 1.0)
        assertEquals(6_000L, played.take(finished = false))
    }

    @Test
    fun test_jumped_starts_counting_again_where_playback_lands() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 2_000L)
        played.jumped()
        // Paused, then a paragraph tap far ahead: the long wall gap would allow the jump without jumped().
        played.sample(120_000L, 60_000L, 1.0)
        played.play(startMs = 120_000L, startRealtimeMs = 60_000L, durationMs = 3_000L)
        assertEquals(5_000L, played.take(finished = false))
    }

    @Test
    fun test_under_a_second_waits_unless_finished() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 600L)
        assertNull(played.take(finished = false))
        assertEquals(600L, played.pendingMs)
        played.play(startMs = 600L, startRealtimeMs = 800L, durationMs = 600L)
        assertEquals(1_200L, played.take(finished = false))
        assertEquals(0L, played.take(finished = true))
    }

    @Test
    fun test_reset_forgets_the_last_story() {
        val played = ListenPlayedTime()
        played.play(startMs = 0L, startRealtimeMs = 0L, durationMs = 3_000L)
        played.reset()
        played.sample(500L, 3_200L, 1.0)
        assertEquals(0L, played.pendingMs)
    }

    @Test
    fun test_seconds_are_formatted_for_the_form() {
        assertEquals("30.4", ListenPlayedTime.formatSeconds(30_400L))
        assertEquals("1", ListenPlayedTime.formatSeconds(1_000L))
        assertEquals("0.25", ListenPlayedTime.formatSeconds(250L))
        assertEquals("0", ListenPlayedTime.formatSeconds(0L))
    }
}
