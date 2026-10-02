package com.newsblur.util

import android.animation.ValueAnimator
import android.view.View
import android.view.ViewPropertyAnimator
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.PopupWindow
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class Test_PopoverEntranceAnimation {
    private val anchor = mockk<View>(relaxed = true)
    private val content = mockk<View>(relaxed = true)
    private val popup = mockk<PopupWindow>(relaxed = true)
    private val animator = mockk<ViewPropertyAnimator>(relaxed = true)
    private val observer = mockk<ViewTreeObserver>(relaxed = true)
    private val attach = slot<View.OnAttachStateChangeListener>()
    private val preDraw = slot<ViewTreeObserver.OnPreDrawListener>()
    private val completed = slot<Runnable>()

    @Before fun setUp() {
        mockkStatic(ValueAnimator::class)
        mockkConstructor(DecelerateInterpolator::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { anchor.rootView } returns anchor
        every { anchor.width } returns 40
        every { anchor.height } returns 40
        every { anchor.getLocationOnScreen(any()) } answers {
            firstArg<IntArray>().apply { this[0] = 270; this[1] = 620 }
        }
        every { popup.contentView } returns content
        every { content.animate() } returns animator
        every { content.viewTreeObserver } returns observer
        every { observer.isAlive } returns true
        every { content.addOnAttachStateChangeListener(capture(attach)) } answers { }
        every { observer.addOnPreDrawListener(capture(preDraw)) } answers { }
        every { animator.alpha(any()) } returns animator
        every { animator.scaleX(any()) } returns animator
        every { animator.scaleY(any()) } returns animator
        every { animator.setStartDelay(any()) } returns animator
        every { animator.setDuration(any()) } returns animator
        every { animator.setInterpolator(any()) } returns animator
        every { animator.withEndAction(capture(completed)) } returns animator
    }

    @After fun tearDown() = unmockkAll()

    private fun show() = PopoverEntranceAnimation.show(anchor, popup, 0, 10, 200, 300, 400, 290f, 640f)

    @Test fun test_menu_starts_hidden_before_show_and_animates_only_after_layout() {
        show()
        verifyOrder {
            content.setAlpha(0f)
            content.setScaleX(0.94f)
            content.setScaleY(0.94f)
            popup.showAtLocation(anchor, 0, 10, 200)
        }
        verify(exactly = 0) { animator.start() }
        attach.captured.onViewAttachedToWindow(content)
        preDraw.captured.onPreDraw()
        verify(exactly = 1) { animator.start() }
        verify { observer.removeOnPreDrawListener(preDraw.captured) }
        completed.captured.run()
        verify {
            content.setAlpha(1f)
            content.setScaleX(1f)
            content.setScaleY(1f)
            content.removeOnAttachStateChangeListener(attach.captured)
        }
        verify(exactly = 0) { popup.setOnDismissListener(any()) }
    }

    @Test fun test_disabled_system_animations_show_immediately() {
        every { ValueAnimator.areAnimatorsEnabled() } returns false
        show()
        verify { popup.showAtLocation(anchor, 0, 10, 200) }
        verify(exactly = 0) {
            content.setAlpha(any())
            content.addOnAttachStateChangeListener(any())
            animator.start()
        }
    }

    @Test fun test_updating_an_open_menu_does_not_restart_entrance() {
        every { popup.isShowing } returns true
        show()
        verify { popup.update(10, 200, 300, 400) }
        verify(exactly = 0) {
            popup.showAtLocation(any(), any(), any(), any())
            content.setAlpha(any())
            content.addOnAttachStateChangeListener(any())
        }
    }

    @Test fun test_dismissal_before_first_draw_cancels_pending_animation() {
        show()
        attach.captured.onViewAttachedToWindow(content)
        attach.captured.onViewDetachedFromWindow(content)
        preDraw.captured.onPreDraw()
        verify(exactly = 0) { animator.start() }
        verify {
            observer.removeOnPreDrawListener(preDraw.captured)
            content.removeOnAttachStateChangeListener(attach.captured)
            content.setAlpha(1f)
            content.setScaleX(1f)
            content.setScaleY(1f)
        }
    }

    @Test fun test_dismissal_during_animation_restores_reusable_content() {
        show()
        attach.captured.onViewAttachedToWindow(content)
        preDraw.captured.onPreDraw()
        attach.captured.onViewDetachedFromWindow(content)
        completed.captured.run()
        verify(exactly = 2) { animator.cancel() }
        verify(exactly = 1) { content.removeOnAttachStateChangeListener(attach.captured) }
        verify {
            content.setAlpha(1f)
            content.setScaleX(1f)
            content.setScaleY(1f)
        }
    }

    @Test fun test_failed_window_attachment_restores_content() {
        every { popup.showAtLocation(any(), any(), any(), any()) } throws IllegalStateException("No window token")
        try {
            show()
            throw AssertionError("Expected the original window attachment error")
        } catch (error: IllegalStateException) {
            assertEquals("No window token", error.message)
        }
        verify {
            content.removeOnAttachStateChangeListener(attach.captured)
            content.setAlpha(1f)
            content.setScaleX(1f)
            content.setScaleY(1f)
        }
    }

    @Test fun test_pivot_follows_anchor_while_staying_inside_menu_bounds() {
        assertEquals(PopoverEntranceAnimation.Pivot(280f, 400f), PopoverEntranceAnimation.pivot(290f, 640f, 10, 200, 300, 400))
        assertEquals(PopoverEntranceAnimation.Pivot(80f, 0f), PopoverEntranceAnimation.pivot(90f, 100f, 10, 200, 300, 400))
        assertEquals(PopoverEntranceAnimation.Pivot(0f, 150f), PopoverEntranceAnimation.pivot(0f, 350f, 10, 200, 300, 400))
        assertEquals(PopoverEntranceAnimation.Pivot(300f, 150f), PopoverEntranceAnimation.pivot(500f, 350f, 10, 200, 300, 400))
    }

    @Test fun test_window_relative_pivot_does_not_include_split_screen_origin() {
        // Test_PopoverEntranceAnimation.kt uses a window below/right of the screen origin, with its anchor above the menu.
        every { anchor.getLocationOnScreen(any()) } answers {
            firstArg<IntArray>().apply { this[0] = 470; this[1] = 620 }
        }
        PopoverEntranceAnimation.show(anchor, popup, 0, 10, 200, 300, 400, 90f, 140f)
        verify {
            content.setPivotX(80f)
            content.setPivotY(0f)
            popup.showAtLocation(anchor, 0, 10, 200)
        }
        verify(exactly = 0) { anchor.getLocationOnScreen(any()) }
    }
}
