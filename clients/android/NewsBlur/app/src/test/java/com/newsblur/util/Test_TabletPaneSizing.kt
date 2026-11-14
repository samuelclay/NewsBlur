package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_TabletPaneSizing {
    @Test
    fun test_drag_toward_the_reader_widens_either_list_in_both_directions() {
        // TabletPaneDivider.kt must follow the finger when feeds or titles sit on the right in RTL.
        for (isRtl in listOf(false, true)) {
            val towardReader = if (isRtl) -100f else 100f
            val expanded = TabletPaneSizing.draggedRatio(0.4f, towardReader, 1000f, isRtl)
            assertEquals(500f, TabletPaneSizing.feedRatio(expanded, 1000f) * 1000f, 0.01f)
            assertEquals(500f, TabletPaneSizing.storyRatio(expanded, 1000f) * 1000f, 0.01f)
            val contracted = TabletPaneSizing.draggedRatio(0.4f, -towardReader, 1000f, isRtl)
            assertEquals(300f, TabletPaneSizing.feedRatio(contracted, 1000f) * 1000f, 0.01f)
            assertEquals(300f, TabletPaneSizing.storyRatio(contracted, 1000f) * 1000f, 0.01f)
        }
    }

    @Test
    fun test_story_resize_keeps_both_panes_readable() {
        for (width in listOf(600f, 800f, 1280f)) {
            for (requested in listOf(-1f, 0.1f, 0.4f, 0.6f, 2f)) {
                val ratio = TabletPaneSizing.storyRatio(requested, width)
                assertTrue(ratio * width >= 239.9f)
                assertTrue((1 - ratio) * width >= 239.9f)
            }
        }
    }

    @Test
    fun test_feed_size_preserves_room_to_reach_the_titles() {
        assertEquals(280f, TabletPaneSizing.feedRatio(0.1f, 800f) * 800, 0.01f)
        assertEquals(560f, TabletPaneSizing.feedRatio(1f, 800f) * 800, 0.01f)
    }

    @Test
    fun test_narrow_window_only_temporarily_clamps_a_saved_size() {
        val saved = 0.65f
        assertEquals(0.6f, TabletPaneSizing.storyRatio(saved, 600f), 0.001f)
        assertEquals(saved, TabletPaneSizing.storyRatio(saved, 1280f), 0.001f)
        assertEquals(0.4f, TabletPaneSizing.storyRatio(Float.NaN, 800f), 0.001f)
    }
}
