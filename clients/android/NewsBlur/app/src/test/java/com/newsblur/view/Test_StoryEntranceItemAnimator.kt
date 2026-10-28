package com.newsblur.view

import android.animation.TimeInterpolator
import android.animation.ValueAnimator
import android.view.View
import android.view.ViewPropertyAnimator
import androidx.recyclerview.widget.RecyclerView
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.spyk
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_StoryEntranceItemAnimator {
    @Before
    fun preparePlatformAnimator() {
        mockkConstructor(ValueAnimator::class)
        every { anyConstructed<ValueAnimator>().interpolator } returns mockk<TimeInterpolator>()
    }

    @After
    fun releasePlatformAnimator() = unmockkConstructor(ValueAnimator::class)

    @Test
    fun test_story_is_visible_while_the_loading_footer_move_is_pending() {
        val animator = spyk(StoryEntranceItemAnimator())
        val footer = Row()
        val story = Row()
        assertTrue(animator.animateMove(footer.holder, 0, 0, 0, 600))

        animator.animateAdd(story.holder)

        // Test_StoryEntranceItemAnimator.kt reproduces the tablet's pending footer move hiding every inserted title.
        assertEquals("ReaderMotion must not be masked by a queued add fade", 1f, story.alpha, 0f)
        verify(exactly = 1) { animator.onAddFinished(story.holder) }
        animator.endAnimations()
        assertEquals(1f, story.alpha, 0f)
    }

    @Test
    fun test_reused_row_restores_opacity_and_finishes_add_without_a_pending_animation() {
        val animator = spyk(StoryEntranceItemAnimator())
        val story = Row().apply { alpha = 0.2f }

        assertFalse(animator.animateAdd(story.holder))

        assertEquals(1f, story.alpha, 0f)
        assertFalse(animator.isRunning)
        verify(exactly = 1) { story.propertyAnimator.cancel() }
        verify(exactly = 1) { animator.onAddFinished(story.holder) }
    }

    @Test
    fun test_cluster_move_and_removal_still_use_the_framework_animator() {
        val animator = StoryEntranceItemAnimator()
        val row = Row()
        assertTrue(animator.animateMove(row.holder, 0, 0, 0, 100))
        assertEquals(-100f, row.translationY, 0f)
        animator.endAnimations()
        assertEquals(0f, row.translationY, 0f)
        assertTrue(animator.animateRemove(row.holder))
        assertTrue(animator.isRunning)
        animator.endAnimations()
        assertFalse(animator.isRunning)
        assertEquals(1f, row.alpha, 0f)
    }

    private class Row {
        var alpha = 1f
        var translationX = 0f
        var translationY = 0f
        val view = mockk<View>(relaxed = true)
        val propertyAnimator = mockk<ViewPropertyAnimator>(relaxed = true)
        val holder = object : RecyclerView.ViewHolder(view) {}

        init {
            every { view.animate() } returns propertyAnimator
            every { view.alpha } answers { alpha }
            every { view.alpha = any() } answers { alpha = firstArg() }
            every { view.translationX } answers { translationX }
            every { view.translationX = any() } answers { translationX = firstArg() }
            every { view.translationY } answers { translationY }
            every { view.translationY = any() } answers { translationY = firstArg() }
        }
    }
}
