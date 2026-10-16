package com.newsblur.activity

import android.app.Activity
import android.content.Context
import android.text.TextPaint
import android.view.ViewGroup
import android.view.ViewPropertyAnimator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.appcompat.content.res.AppCompatResources
import androidx.appcompat.widget.AppCompatButton
import androidx.viewpager.widget.ViewPager
import com.newsblur.R
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_ReadingFixedTraversal {
    @Test
    fun test_story_transition_moves_pages_but_keeps_navigation_stationary() {
        mockkStatic(UIUtils::class)
        mockkConstructor(DecelerateInterpolator::class)
        try {
            val activity = mockk<Activity>(relaxed = true)
            val binding = mockk<ActivityReadingBinding>(relaxed = true)
            val content = mockk<FrameLayout>(relaxed = true)
            val overlay = mockk<FrameLayout>(relaxed = true)
            val pager = mockk<ViewPager>(relaxed = true)
            val animator = mockk<ViewPropertyAnimator>(relaxed = true)
            bindingField(binding, "content", content)
            bindingField(binding, "contentBottomOverlay", overlay)
            every { content.width } returns 1080
            every { UIUtils.towardEndSign(activity) } returns 1f
            every { pager.animate() } returns animator
            every { animator.translationX(any()) } returns animator
            every { animator.setDuration(any()) } returns animator
            every { animator.setInterpolator(any()) } returns animator
            every { animator.withEndAction(any()) } returns animator

            val snapshot = ReaderPageSnapshot(activity, binding, pager)
            snapshot.animate(1) {}
            snapshot.animate(-1) {}
            snapshot.release()

            verify { pager.translationX = 1080f }
            verify { pager.translationX = -1080f }
            verify(exactly = 0) { overlay.translationX = any() }
            verify(exactly = 0) { overlay.animate() }
        } finally {
            unmockkConstructor(DecelerateInterpolator::class)
            unmockkStatic(UIUtils::class)
        }
    }

    @Test
    fun test_next_and_done_share_a_tap_target_that_fits_either_localized_label() {
        mockkStatic(UIUtils::class, AppCompatResources::class)
        try {
            val context = mockk<Context>(relaxed = true)
            every { UIUtils.dp2px(context, any<Int>()) } answers { secondArg<Int>() }
            every { AppCompatResources.getDrawable(context, any()) } returns null
            every { context.getString(R.string.overlay_next) } returns "Next localized"
            every { context.getString(R.string.overlay_done) } returns "Done localized"

            // Test_ReadingFixedTraversal.kt covers languages where either label is the wider one.
            for ((nextTextWidth, doneTextWidth) in listOf(30f to 60f, 80f to 20f)) {
                val binding = mockk<ActivityReadingBinding>(relaxed = true)
                val next = mockk<AppCompatButton>(relaxed = true)
                val paint = mockk<TextPaint>()
                val params = mockk<ViewGroup.LayoutParams>()
                params.width = ViewGroup.LayoutParams.WRAP_CONTENT
                bindingField(binding, "readingOverlayRight", next)
                every { next.layoutParams } returns params
                every { next.paint } returns paint
                every { next.paddingStart } returns 6
                every { next.paddingEnd } returns 10
                every { next.compoundDrawablePadding } returns 4
                every { paint.measureText("Next localized") } returns nextTextWidth
                every { paint.measureText("Done localized") } returns doneTextWidth
                val bar = ReadingTraverseBar(context, binding, ThemeValue.LIGHT)
                ReadingTraverseBar::class.java.getDeclaredMethod("configureNextButton").apply {
                    isAccessible = true
                    invoke(bar)
                }

                val fixedWidth = params.width
                assertTrue("Next and its chevron must fit", fixedWidth >= nextTextWidth + 24 + 20)
                assertTrue("Done and its checkmark must fit", fixedWidth >= doneTextWidth + 12 + 20)
                bar.updateNextShowDone(true)
                assertEquals(fixedWidth, params.width)
                verify { next.text = "Done localized" }
                bar.updateNextShowDone(false)
                assertEquals(fixedWidth, params.width)
                verify { next.text = "Next localized" }
            }
        } finally {
            unmockkStatic(UIUtils::class, AppCompatResources::class)
        }
    }

    private fun bindingField(binding: ActivityReadingBinding, name: String, value: Any) {
        ActivityReadingBinding::class.java.getDeclaredField(name).apply {
            isAccessible = true
            set(binding, value)
        }
    }
}
