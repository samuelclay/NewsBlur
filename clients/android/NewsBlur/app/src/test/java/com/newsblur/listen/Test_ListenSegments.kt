package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenSegments.kt covers paragraph jumps, resuming after a new manifest, previews and skips. */
class Test_ListenSegments {
    private val segments =
        listOf(
            ListenSegment(index = 0, paragraphs = listOf(0)),
            ListenSegment(index = 1, paragraphs = listOf(1, 2)),
            ListenSegment(index = 2, paragraphs = listOf(3)),
            ListenSegment(index = 3, paragraphs = listOf(5, 6)),
        )

    @Test
    fun test_paragraph_tap_finds_first_segment_reading_it() {
        assertEquals(1, ListenSegments.segmentForParagraph(segments, 2))
        assertEquals(3, ListenSegments.segmentForParagraph(segments, 5))
        assertNull(ListenSegments.segmentForParagraph(segments, 4))
    }

    @Test
    fun test_resume_uses_same_paragraph_or_the_next_one() {
        assertEquals(2, ListenSegments.segmentForResume(segments, 3))
        assertEquals(3, ListenSegments.segmentForResume(segments, 4))
        assertEquals(3, ListenSegments.segmentForResume(segments, 40))
        assertEquals(0, ListenSegments.segmentForResume(emptyList(), 2))
    }

    @Test
    fun test_first_paragraph_of_segment() {
        assertEquals(1, ListenSegments.firstParagraph(segments, 1))
        assertEquals(0, ListenSegments.firstParagraph(segments, 9))
    }

    @Test
    fun test_preview_fades_over_its_last_moment() {
        val limit = 30_000L
        assertEquals(1f, ListenPreviewFade.volume(10_000L, limit))
        assertEquals(1f, ListenPreviewFade.volume(limit - ListenPreviewFade.FADE_MS, limit))
        assertEquals(
            0.5f,
            ListenPreviewFade.volume(limit - ListenPreviewFade.FADE_MS / 2, limit),
            0.001f,
        )
        assertEquals(0f, ListenPreviewFade.volume(limit, limit))
        assertEquals(1f, ListenPreviewFade.volume(50_000L, 0L))
    }

    @Test
    fun test_preview_finishes_at_its_limit() {
        assertFalse(ListenPreviewFade.isFinished(29_999L, 30_000L))
        assertTrue(ListenPreviewFade.isFinished(30_000L, 30_000L))
        assertFalse(ListenPreviewFade.isFinished(99_000L, 0L))
    }

    @Test
    fun test_skips_stay_inside_the_story() {
        assertEquals(0L, ListenSeek.target(5_000L, -ListenSeek.SKIP_BACK_MS, 60_000L))
        assertEquals(35_000L, ListenSeek.target(5_000L, ListenSeek.SKIP_FORWARD_MS, 60_000L))
        assertEquals(60_000L, ListenSeek.target(50_000L, ListenSeek.SKIP_FORWARD_MS, 60_000L))
    }
}
