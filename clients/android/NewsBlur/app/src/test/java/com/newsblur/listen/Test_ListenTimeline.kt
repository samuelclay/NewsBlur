package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenTimeline.kt checks the one-story timeline ListenManager.kt shows across segments. */
class Test_ListenTimeline {
    private val segments =
        listOf(
            ListenSegment(index = 0, paragraphs = listOf(0), duration = 3.2, estimated = false),
            ListenSegment(index = 1, paragraphs = listOf(1, 2), duration = 20.0),
            ListenSegment(index = 2, paragraphs = listOf(3), duration = 10.5),
        )

    @Test
    fun test_segments_lay_end_to_end() {
        val timeline = ListenTimeline.fromSegments(segments)
        assertEquals(33_700L, timeline.totalMs)
        assertEquals(0L, timeline.startMs(0))
        assertEquals(3_200L, timeline.startMs(1))
        assertEquals(23_200L, timeline.startMs(2))
        assertEquals(listOf(true, false, false), timeline.known)
    }

    @Test
    fun test_locate_finds_segment_and_offset() {
        val timeline = ListenTimeline.fromSegments(segments)
        assertEquals(ListenTimeline.Location(0, 0L), timeline.locate(0L))
        assertEquals(ListenTimeline.Location(0, 3_199L), timeline.locate(3_199L))
        assertEquals(ListenTimeline.Location(1, 0L), timeline.locate(3_200L))
        assertEquals(ListenTimeline.Location(2, 1_800L), timeline.locate(25_000L))
    }

    @Test
    fun test_locate_clamps_outside_the_story() {
        val timeline = ListenTimeline.fromSegments(segments)
        assertEquals(ListenTimeline.Location(0, 0L), timeline.locate(-500L))
        assertEquals(ListenTimeline.Location(2, 10_500L), timeline.locate(99_000L))
    }

    @Test
    fun test_position_round_trips_with_locate() {
        val timeline = ListenTimeline.fromSegments(segments)
        listOf(0L, 1_000L, 3_200L, 12_345L, 23_200L, 30_000L).forEach { position ->
            val location = timeline.locate(position)
            assertEquals(position, timeline.positionMs(location.segmentIndex, location.offsetMs))
        }
    }

    @Test
    fun test_position_never_runs_past_its_segment() {
        val timeline = ListenTimeline.fromSegments(segments)
        assertEquals(3_200L, timeline.positionMs(0, 9_000L))
    }

    @Test
    fun test_real_durations_replace_estimates() {
        val timeline =
            ListenTimeline
                .fromSegments(
                    segments,
                ).withDuration(1, 18_250L, isKnown = true)
        assertEquals(18_250L, timeline.durationMs(1))
        assertTrue(timeline.known[1])
        assertEquals(31_950L, timeline.totalMs)
        assertEquals(21_450L, timeline.startMs(2))
    }

    @Test
    fun test_estimates_never_replace_measured_durations() {
        val measured =
            ListenTimeline
                .fromSegments(
                    segments,
                ).withDuration(1, 18_250L, isKnown = true)
        assertSame(measured, measured.withDuration(1, 25_000L, isKnown = false))
        assertEquals(18_250L, measured.durationMs(1))
    }

    @Test
    fun test_estimates_can_stretch_while_streaming() {
        val timeline =
            ListenTimeline
                .fromSegments(
                    segments,
                ).withDuration(2, 12_000L, isKnown = false)
        assertEquals(12_000L, timeline.durationMs(2))
        assertFalse(timeline.known[2])
    }

    @Test
    fun test_bad_updates_are_ignored() {
        val timeline = ListenTimeline.fromSegments(segments)
        assertSame(timeline, timeline.withDuration(7, 1_000L, isKnown = true))
        assertSame(timeline, timeline.withDuration(1, 0L, isKnown = true))
    }

    @Test
    fun test_unestimated_segments_still_take_time() {
        val timeline = ListenTimeline.fromSegments(listOf(ListenSegment(index = 0, duration = 0.0)))
        assertTrue(timeline.totalMs > 0L)
    }

    @Test
    fun test_empty_timeline_is_safe() {
        val timeline = ListenTimeline(emptyList())
        assertEquals(0L, timeline.totalMs)
        assertEquals(ListenTimeline.Location(0, 0L), timeline.locate(5_000L))
        assertEquals(0L, timeline.positionMs(3, 100L))
    }
}
