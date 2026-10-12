package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_TabletPaneSizing {
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
