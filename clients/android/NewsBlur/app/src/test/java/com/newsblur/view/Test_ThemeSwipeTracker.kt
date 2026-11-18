package com.newsblur.view

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class Test_ThemeSwipeTracker {
    // Test_ThemeSwipeTracker.kt runs at density 3, so a tracker that measured 50px instead of 50dp fires early.
    private val tracker = ThemeSwipeTracker(density = 3f)
    private val span = 300f

    private fun twoFingers(
        x: Float,
        y: Float,
        spread: Float = span,
    ) = tracker.update(fingers = 2, x = x, y = y, span = spread)

    @Test fun test_two_finger_drag_switches_once_after_fifty_dp_of_vertical_travel() {
        assertNull(twoFingers(500f, 1000f))
        assertNull(twoFingers(500f, 1149f))
        assertEquals(true, twoFingers(500f, 1150f))
        assertNull("One drag must switch the theme only once", twoFingers(500f, 1400f))
        assertNull(twoFingers(500f, 900f))
    }

    @Test fun test_fingers_moving_up_report_up() {
        twoFingers(500f, 1000f)
        assertEquals(false, twoFingers(520f, 820f))
    }

    // Test_ThemeSwipeTracker.kt: lifting either finger ends the gesture, as UIPanGestureRecognizer's minimum of two touches does on iOS.
    @Test fun test_lifting_a_finger_ends_the_gesture_so_the_next_drag_switches_again() {
        twoFingers(500f, 1000f)
        assertEquals(true, twoFingers(500f, 1200f))
        assertNull(tracker.update(fingers = 1, x = 500f, y = 1200f, span = 0f))
        assertNull(twoFingers(500f, 1200f))
        assertEquals(false, twoFingers(500f, 1000f))
        assertNull(tracker.update(fingers = 0, x = 0f, y = 0f, span = 0f))
        assertNull(twoFingers(500f, 1000f))
        assertEquals(true, twoFingers(500f, 1160f))
    }

    @Test fun test_more_than_fifty_dp_sideways_blocks_the_switch() {
        twoFingers(500f, 1000f)
        assertNull(twoFingers(651f, 1300f))
        assertNull(twoFingers(349f, 700f))
    }

    // Test_ThemeSwipeTracker.kt: a pinch with one finger held still moves the midpoint half as far as the other finger, which would
    // otherwise pass for a swipe while zooming an image or the reader.
    @Test fun test_a_pinch_never_switches_the_theme() {
        twoFingers(500f, 1000f, spread = 300f)
        assertNull(twoFingers(500f, 1160f, spread = 620f))
        assertNull("Once pinching, the gesture stays a pinch", twoFingers(500f, 1300f, spread = 300f))
    }

    @Test fun test_one_finger_never_switches_the_theme() {
        for (y in listOf(1000f, 1200f, 1600f, 400f)) {
            assertNull(tracker.update(fingers = 1, x = 500f, y = y, span = 0f))
        }
        assertNull(tracker.update(fingers = 3, x = 500f, y = 1000f, span = 300f))
        assertNull(tracker.update(fingers = 3, x = 500f, y = 1300f, span = 300f))
    }
}
