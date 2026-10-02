package com.newsblur.view

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class ReaderTapGesturesTest {
    private val context = mockk<Context>()
    private val view = mockk<View> { every { context } returns this@ReaderTapGesturesTest.context }
    private val actions = mutableListOf<Boolean>()
    private lateinit var gestures: ReaderTapGestures

    @Before fun setup() {
        mockkStatic(ViewConfiguration::class)
        val config =
            mockk<ViewConfiguration> {
                every { scaledTouchSlop } returns 8
                every { scaledDoubleTapSlop } returns 40
            }
        every { ViewConfiguration.get(context) } returns config
        every { ViewConfiguration.getTapTimeout() } returns 100
        every { ViewConfiguration.getDoubleTapTimeout() } returns 300
        gestures =
            ReaderTapGestures(view) {
                actions.add(it)
                true
            }
    }

    @After fun cleanup() {
        unmockkStatic(ViewConfiguration::class)
    }

    private fun event(
        action: Int,
        time: Long,
        x: Float = 100f,
        fingers: Int = 1,
        second: Float = 150f,
        firstPointerId: Int = 0,
        actionPointerIndex: Int = if (action == MotionEvent.ACTION_POINTER_DOWN) 1 else 0,
    ): Boolean {
        val event =
            mockk<MotionEvent> {
                every { actionMasked } returns action
                every { actionIndex } returns actionPointerIndex
                every { eventTime } returns time
                every { getX() } returns x
                every { getY() } returns 100f
                every { getX(0) } returns x
                every { getY(0) } returns 100f
                every { getX(1) } returns second
                every { getY(1) } returns 100f
                every { pointerCount } returns fingers
                every { getPointerId(0) } returns firstPointerId
                every { getPointerId(1) } returns 1
            }
        return gestures.onTouch(view, event)
    }

    private fun tap(
        time: Long,
        fingers: Int = 1,
    ) {
        event(MotionEvent.ACTION_DOWN, time)
        if (fingers == 2) {
            event(MotionEvent.ACTION_POINTER_DOWN, time + 5, fingers = 2)
            event(MotionEvent.ACTION_POINTER_UP, time + 40, fingers = 2, actionPointerIndex = 1)
        }
        event(MotionEvent.ACTION_UP, time + 50)
    }

    @Test fun distinguishesOneAndTwoFingerDoubleTaps() {
        tap(100)
        tap(250)
        tap(1000, 2)
        tap(1150, 2)
        assertEquals(listOf(false, true), actions)
    }

    @Test fun singleTapAndMixedFingerCountsDoNotAct() {
        tap(100)
        tap(250, 2)
        assertTrue(actions.isEmpty())
    }

    @Test fun dragAndPinchCannotTriggerDoubleTap() {
        tap(100)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_MOVE, 260, x = 125f)
        event(MotionEvent.ACTION_UP, 280, x = 125f)
        tap(1000, 2)
        event(MotionEvent.ACTION_DOWN, 1150)
        event(MotionEvent.ACTION_POINTER_DOWN, 1155, fingers = 2)
        event(MotionEvent.ACTION_MOVE, 1160, fingers = 2, second = 190f)
        event(MotionEvent.ACTION_UP, 1180)
        assertTrue(actions.isEmpty())
    }

    @Test fun canceledTouchAndLongPressDoNotAct() {
        tap(100)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_CANCEL, 260)
        event(MotionEvent.ACTION_UP, 270)
        tap(500)
        event(MotionEvent.ACTION_DOWN, 650)
        event(MotionEvent.ACTION_UP, 1000)
        assertTrue(actions.isEmpty())
    }
    @Test fun twoFingerDoubleTapAllowsFirstFingerToLiftFirst() {
        tap(100, 2)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_POINTER_DOWN, 255, fingers = 2)
        event(MotionEvent.ACTION_POINTER_UP, 270, fingers = 2)
        event(MotionEvent.ACTION_MOVE, 275, x = 150f, firstPointerId = 1)
        event(MotionEvent.ACTION_UP, 280, x = 150f, firstPointerId = 1)
        assertEquals(listOf(true), actions)
    }

    @Test fun remainingSecondFingerDragCannotTriggerDoubleTap() {
        tap(100, 2)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_POINTER_DOWN, 255, fingers = 2)
        event(MotionEvent.ACTION_POINTER_UP, 270, fingers = 2)
        event(MotionEvent.ACTION_MOVE, 275, x = 175f, firstPointerId = 1)
        event(MotionEvent.ACTION_UP, 280, x = 175f, firstPointerId = 1)
        assertTrue(actions.isEmpty())
    }

    @Test fun remainingFirstFingerMoveAllowsDoubleTap() {
        tap(100, 2)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_POINTER_DOWN, 255, fingers = 2)
        event(MotionEvent.ACTION_POINTER_UP, 270, fingers = 2, actionPointerIndex = 1)
        event(MotionEvent.ACTION_MOVE, 275)
        event(MotionEvent.ACTION_UP, 280)
        assertEquals(listOf(true), actions)
    }

    @Test fun movementAtPointerLiftCannotTriggerDoubleTap() {
        tap(100, 2)
        event(MotionEvent.ACTION_DOWN, 250)
        event(MotionEvent.ACTION_POINTER_DOWN, 255, fingers = 2)
        event(MotionEvent.ACTION_POINTER_UP, 270, x = 125f, fingers = 2)
        event(MotionEvent.ACTION_UP, 280, x = 150f, firstPointerId = 1)
        assertTrue(actions.isEmpty())
    }
}
