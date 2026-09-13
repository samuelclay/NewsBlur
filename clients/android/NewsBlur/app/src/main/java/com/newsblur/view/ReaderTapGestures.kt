package com.newsblur.view

import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import kotlin.math.abs

/** ReaderTapGestures.kt ignores drags, pinches, and canceled touches before recognizing a double tap. */
class ReaderTapGestures(
    private val view: View,
    private val perform: (Boolean) -> Boolean,
) : View.OnTouchListener {
    private val slop = ViewConfiguration.get(view.context).scaledTouchSlop
    private val doubleSlop = ViewConfiguration.get(view.context).scaledDoubleTapSlop
    private var downX = 0f
    private var downY = 0f
    private var downTime = 0L
    private var fingers = 1
    private var moved = false
    private var priorTime = 0L
    private var priorX = 0f
    private var priorY = 0f
    private var priorFingers = 0
    private var secondX = 0f
    private var secondY = 0f

    override fun onTouch(
        v: View,
        event: MotionEvent,
    ): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.x
                downY = event.y
                downTime = event.eventTime
                fingers = 1
                moved = false
            }
            MotionEvent.ACTION_POINTER_DOWN -> {
                fingers = event.pointerCount
                if (fingers == 2) {
                    secondX = event.getX(1)
                    secondY = event.getY(1)
                } else {
                    moved = true
                }
            }
            MotionEvent.ACTION_MOVE -> {
                if (abs(event.x - downX) > slop ||
                    abs(event.y - downY) > slop ||
                    (event.pointerCount == 2 && (abs(event.getX(1) - secondX) > slop || abs(event.getY(1) - secondY) > slop))
                ) {
                    moved = true
                }
            }
            MotionEvent.ACTION_CANCEL -> {
                moved = true
                priorTime = 0
            }
            MotionEvent.ACTION_UP -> {
                if (moved || event.eventTime - downTime > ViewConfiguration.getTapTimeout() * 2) {
                    priorTime = 0
                    return false
                }
                val double =
                    priorTime != 0L &&
                        downTime - priorTime <= ViewConfiguration.getDoubleTapTimeout() &&
                        priorFingers == fingers &&
                        abs(downX - priorX) < doubleSlop &&
                        abs(downY - priorY) < doubleSlop
                priorTime = event.eventTime
                priorX = downX
                priorY = downY
                priorFingers = fingers
                if (double) {
                    priorTime = 0
                    return perform(fingers == 2)
                }
            }
        }
        return false
    }
}
