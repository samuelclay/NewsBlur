package com.newsblur.view

import android.app.Activity
import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import com.newsblur.preference.PrefsRepo
import kotlin.math.hypot

/**
 * ThemeSwipeGesture.kt watches an activity's touches for the two-finger theme swipe that ThemeSwipeTracker.kt recognizes.
 * It claims nothing while watching, so scrolling, pinch zoom, the reader's two-finger double tap and row swipes
 * see every event. Once the swipe fires it cancels the touch for the views underneath and swallows the rest of
 * that drag, so the list stops where ThemeTransition.kt captured the screen for its crossfade.
 */
class ThemeSwipeGesture(
    private val activity: Activity,
    private val prefsRepo: PrefsRepo,
) {
    private val tracker = ThemeSwipeTracker(activity.resources.displayMetrics.density)
    private var swallowing = false

    fun dispatch(
        event: MotionEvent,
        deliver: (MotionEvent) -> Boolean,
    ): Boolean {
        val masked = event.actionMasked
        if (masked == MotionEvent.ACTION_DOWN) swallowing = false
        if (swallowing) {
            if (masked == MotionEvent.ACTION_UP || masked == MotionEvent.ACTION_CANCEL) {
                swallowing = false
                tracker.update(fingers = 0, x = 0f, y = 0f, span = 0f)
            }
            return true
        }
        val fingersMovedDown = track(event) ?: return deliver(event)
        val theme = prefsRepo.themeAfterSwipe(prefsRepo.getResolvedTheme(activity), fingersMovedDown) ?: return deliver(event)
        swallowing = true
        // ThemeSwipeGesture.kt ticks like iOS's light-switch click; CONFIRM needs API 30, CONTEXT_CLICK is lighter.
        val feedback =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.CONTEXT_CLICK
        activity.window.decorView.performHapticFeedback(feedback)
        val cancel = MotionEvent.obtain(event).apply { action = MotionEvent.ACTION_CANCEL }
        deliver(cancel)
        cancel.recycle()
        // ThemeSwipeGesture.kt only saves the theme; NbActivity.kt and Settings.kt observe it and recreate through ThemeTransition.kt.
        prefsRepo.setSelectedTheme(theme)
        return true
    }

    private fun track(event: MotionEvent): Boolean? {
        val lifting = if (event.actionMasked == MotionEvent.ACTION_POINTER_UP) event.actionIndex else -1
        val fingers =
            when (event.actionMasked) {
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> 0
                MotionEvent.ACTION_POINTER_UP -> event.pointerCount - 1
                else -> event.pointerCount
            }
        if (fingers != 2) return tracker.update(fingers, x = 0f, y = 0f, span = 0f)
        val (first, second) = (0 until event.pointerCount).filter { it != lifting }
        val x = (event.getX(first) + event.getX(second)) / 2f
        val y = (event.getY(first) + event.getY(second)) / 2f
        val span = hypot(event.getX(first) - event.getX(second), event.getY(first) - event.getY(second))
        return tracker.update(fingers, x, y, span)
    }
}
