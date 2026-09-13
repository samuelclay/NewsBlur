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
    ): Boolean {
        val event =
            mockk<MotionEvent> {
                every { actionMasked } returns action
                every { eventTime } returns time
                every { getX() } returns x
                every { getY() } returns 100f
                every { getX(1) } returns second
                every { getY(1) } returns 100f
                every { pointerCount } returns fingers
            }
        return gestures.onTouch(view, event)
    }

    private fun tap(
        time: Long,
        fingers: Int = 1,
    ) {
        event(MotionEvent.ACTION_DOWN, time)
        if (fingers == 2) event(MotionEvent.ACTION_POINTER_DOWN, time + 5, fingers = 2)
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
}
