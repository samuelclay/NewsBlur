package com.newsblur.view

import kotlin.math.abs

/**
 * ThemeSwipeTracker.kt decides when two fingers have swiped far enough to switch the theme, with no Android types so
 * Test_ThemeSwipeTracker.kt can drive it. ThemeSwipeGesture.kt feeds it touches; ThemeAppearance.kt picks the theme.
 *
 * It follows ThemeManager.m handleThemeGesture: on iOS: once two fingers' midpoint travels at least 50 (dp here,
 * points there) vertically and no more than 50 sideways, the swipe fires, once, until a finger lifts.
 */
class ThemeSwipeTracker(
    density: Float,
) {
    private val travel = TRAVEL_DP * density
    private var tracking = false
    private var finished = false
    private var startX = 0f
    private var startY = 0f
    private var startSpan = 0f

    /**
     * ThemeSwipeTracker.kt takes how many fingers touch after an event, with their midpoint and the distance between the first two.
     * Returns true when the swipe fires with fingers moving down the screen, false moving up, otherwise null.
     */
    fun update(
        fingers: Int,
        x: Float,
        y: Float,
        span: Float,
    ): Boolean? {
        if (fingers != 2) {
            // ThemeSwipeTracker.kt starts over whenever the count leaves two, as iOS's recognizer ends without two touches.
            tracking = false
            return null
        }
        if (!tracking) {
            tracking = true
            finished = false
            startX = x
            startY = y
            startSpan = span
            return null
        }
        if (finished) return null
        // ThemeSwipeTracker.kt leaves pinches to image and reader zoom: holding one finger still moves the midpoint
        // half as far as the other, so a spread that changes by the travel distance marks a pinch, not a swipe.
        if (abs(span - startSpan) > travel) {
            finished = true
            return null
        }
        val dx = x - startX
        val dy = y - startY
        if (abs(dx) > travel || abs(dy) < travel) return null
        finished = true
        return dy > 0
    }

    companion object {
        const val TRAVEL_DP = 50f
    }
}
