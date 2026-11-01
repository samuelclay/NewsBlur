package com.newsblur.view

import android.graphics.Rect
import android.animation.ValueAnimator
import android.view.View
import android.view.ViewTreeObserver
import com.newsblur.util.ViewUtils
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class Test_ReaderControlMotion {
    @Before fun setup() {
        mockkStatic(ReaderMotion::class)
        mockkStatic(ValueAnimator::class, ViewUtils::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
        mockkConstructor(Rect::class)
    }
    @After fun cleanup() = unmockkAll()

    @Test fun test_controls_wait_for_visible_layout_instead_of_spending_their_entrance_off_window() {
        val view = control(10)
        val listeners = mutableListOf<ViewTreeObserver.OnPreDrawListener>()
        every { view.viewTreeObserver.addOnPreDrawListener(capture(listeners)) } just Runs
        var ready = false
        var started = 0
        every { view.isAttachedToWindow } answers { ready }
        every { ReaderMotion.enter(view, any(), any()) } answers { if (ready) started++; ready }
        ReaderMotion.cascade(listOf(view))
        ready = true
        listeners.toList().forEach { it.onPreDraw() }
        verify(exactly = 1) { view.viewTreeObserver.addOnPreDrawListener(any()) }
        verify(atLeast = 1) { ReaderMotion.enter(view, any(), any()) }
        assertEquals(1, started)
    }

    @Test fun test_control_cascade_follows_screen_order_with_distinct_bounded_delays() {
        val views = (0 until 9).map { control((8 - it) * 40) }
        val calls = mutableListOf<Pair<View, Long>>()
        every { ReaderMotion.enter(any(), any(), any()) } answers { calls.add(firstArg<View>() to secondArg()); true }
        ReaderMotion.cascade(views)
        assertEquals(views.reversed(), calls.map { it.first })
        assertTrue(calls.zipWithNext().all { (a, b) -> a.second < b.second })
        assertTrue(calls.all { it.second <= 150 })
    }

    @Test fun test_persistent_controls_animate_only_appearance_or_the_control_that_changed() {
        val views = List(4) { control(it * 40) }
        val listeners = mutableListOf<ViewTreeObserver.OnPreDrawListener>()
        every { views[0].viewTreeObserver.addOnPreDrawListener(capture(listeners)) } just Runs
        every { ReaderMotion.enter(any(), any(), any()) } returns true
        var nextIsDone = false
        val motion = ReaderControlMotion(views[0], {
            views.mapIndexed { index, view -> ReaderControlMotion.Control(view, state = if (index == 3) nextIsDone else false) }
        })
        repeat(10) { listeners.toList().forEach { it.onPreDraw() } }
        verify(exactly = 4) { ReaderMotion.enter(any(), any(), any()) }
        nextIsDone = true
        listeners.toList().forEach { it.onPreDraw() }
        verify(exactly = 2) { ReaderMotion.enter(views[3], any(), any()) }
        views.take(3).forEach { verify(exactly = 1) { ReaderMotion.enter(it, any(), any()) } }
        every { views[1].isShown } returns false
        listeners.toList().forEach { it.onPreDraw() }
        every { views[1].isShown } returns true
        listeners.toList().forEach { it.onPreDraw() }
        verify(exactly = 2) { ReaderMotion.enter(views[1], any(), any()) }
        views.forEach { verify(exactly = 0) { it.alpha = any() } }
        motion.close()
        nextIsDone = false
        listeners.toList().forEach { it.onPreDraw() }
        verify(exactly = 6) { ReaderMotion.enter(any(), any(), any()) }
        verify { views[0].viewTreeObserver.removeOnPreDrawListener(any()) }
    }

    @Test fun test_reduced_motion_and_power_save_present_controls_without_delayed_replay() {
        for (powerSave in listOf(false, true)) {
            val view = control(0)
            val listeners = mutableListOf<ViewTreeObserver.OnPreDrawListener>()
            every { view.viewTreeObserver.addOnPreDrawListener(capture(listeners)) } just Runs
            every { ValueAnimator.areAnimatorsEnabled() } returns powerSave
            every { ViewUtils.isPowerSaveMode(any()) } returns powerSave
            val motion = ReaderControlMotion(view, { listOf(ReaderControlMotion.Control(view)) })
            every { ValueAnimator.areAnimatorsEnabled() } returns true
            every { ViewUtils.isPowerSaveMode(any()) } returns false
            listeners.forEach { it.onPreDraw() }
            verify(exactly = 0) { ReaderMotion.enter(view, any(), any()) }
            verify(exactly = 0) { view.alpha = any() }
            motion.close()
        }
    }

    @Test fun test_offscreen_social_rows_wait_then_enter_once_when_visible() {
        val view = control(0)
        val listeners = mutableListOf<ViewTreeObserver.OnPreDrawListener>()
        every { view.viewTreeObserver.addOnPreDrawListener(capture(listeners)) } just Runs
        every { ReaderMotion.enter(any(), any(), any()) } returns true
        every { view.getGlobalVisibleRect(any()) } returns false
        val motion = ReaderControlMotion(view, { listOf(ReaderControlMotion.Control(view, "comment-user")) })
        verify(exactly = 0) { ReaderMotion.enter(any(), any(), any()) }
        every { view.getGlobalVisibleRect(any()) } returns true
        listeners.forEach { it.onPreDraw() }
        every { view.getGlobalVisibleRect(any()) } returns false
        listeners.forEach { it.onPreDraw() }
        every { view.getGlobalVisibleRect(any()) } returns true
        listeners.forEach { it.onPreDraw() }
        verify(exactly = 1) { ReaderMotion.enter(view, any(), any()) }
        motion.close()
    }

    private fun control(top: Int): View = mockk<View>(relaxed = true).also { view ->
        every { view.isAttachedToWindow } returns true
        every { view.isShown } returns true
        every { view.windowVisibility } returns View.VISIBLE
        every { view.visibility } returns View.VISIBLE
        every { view.alpha } returns .4f
        every { view.parent } returns null
        every { view.viewTreeObserver.isAlive } returns true
        every { view.getGlobalVisibleRect(any()) } answers {
            firstArg<Rect>().apply { this.top = top; left = 10; right = 100; bottom = top + 30 }
            true
        }
    }
}
