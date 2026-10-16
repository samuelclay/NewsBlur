package com.newsblur.activity

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.view.ViewPropertyAnimator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.OneShotPreDrawListener
import androidx.viewpager.widget.ViewPager
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.UIUtils
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_ReaderPageSnapshot {
    @Test
    fun test_visible_controls_keep_the_full_article_while_destination_readiness_is_delayed() {
        mockkStatic(Bitmap::class, Looper::class, PixelCopy::class, OneShotPreDrawListener::class, UIUtils::class)
        mockkConstructor(Rect::class, Handler::class, ImageView::class, FrameLayout.LayoutParams::class, DecelerateInterpolator::class)
        try {
            val activity = mockk<Activity>(relaxed = true)
            val binding = mockk<ActivityReadingBinding>(relaxed = true)
            val content = mockk<FrameLayout>(relaxed = true)
            val overlay = mockk<FrameLayout>(relaxed = true)
            val controls = mockk<ConstraintLayout>(relaxed = true)
            val pager = mockk<ViewPager>(relaxed = true)
            val bitmap = mockk<Bitmap>(relaxed = true)
            val beforeDraw = slot<Runnable>()
            val pixelCopy = slot<PixelCopy.OnPixelCopyFinishedListener>()
            val capturedBounds = slot<Rect>()
            val snapshotView = slot<View>()
            val animationEnd = slot<Runnable>()
            val animator = mockk<ViewPropertyAnimator>(relaxed = true)
            bindingField(binding, "content", content)
            bindingField(binding, "contentBottomOverlay", overlay)
            bindingField(binding, "readingOverlayLeftGroup", controls)
            bindingField(binding, "readingOverlayRightGroup", controls)
            every { content.width } returns 1080
            every { content.height } returns 2200
            every { content.getLocationInWindow(any()) } answers { firstArg<IntArray>()[1] = 100 }
            every { overlay.getLocationInWindow(any()) } answers { firstArg<IntArray>()[1] = 2100 }
            every { controls.isShown } returns true
            every { controls.alpha } returns 1f
            every { activity.window.decorView.isAttachedToWindow } returns true
            every { activity.window.decorView.width } returns 1080
            every { activity.window.decorView.height } returns 2400
            every { OneShotPreDrawListener.add(content, capture(beforeDraw)) } returns mockk()
            every { content.post(any()) } answers { firstArg<Runnable>().run(); true }
            every { anyConstructed<Rect>().isEmpty } returns false
            every { anyConstructed<Rect>().intersect(any<Int>(), any(), any(), any()) } returns true
            every { anyConstructed<Rect>().width() } returns 1080
            every { anyConstructed<Rect>().height() } returns 2200
            every { Bitmap.createBitmap(any<Int>(), any(), any<Bitmap.Config>()) } returns bitmap
            every { Looper.getMainLooper() } returns mockk()
            every { PixelCopy.request(activity.window, capture(capturedBounds), bitmap, capture(pixelCopy), any()) } just Runs
            every { anyConstructed<ImageView>().scaleType = any() } just Runs
            every { anyConstructed<ImageView>().setImageBitmap(any()) } just Runs
            every { anyConstructed<ImageView>().isClickable = any() } just Runs
            every { anyConstructed<ImageView>().contentDescription = any() } just Runs
            every { anyConstructed<ImageView>().setImageDrawable(any()) } just Runs
            every { anyConstructed<ImageView>().animate() } returns mockk(relaxed = true)
            every { content.addView(capture(snapshotView), any<ViewGroup.LayoutParams>()) } just Runs
            every { UIUtils.towardEndSign(activity) } returns 1f
            every { pager.animate() } returns animator
            every { animator.translationX(any()) } returns animator
            every { animator.setDuration(any()) } returns animator
            every { animator.setInterpolator(any()) } returns animator
            every { animator.withEndAction(capture(animationEnd)) } returns animator

            val snapshot = ReaderPageSnapshot(activity, binding, pager)
            val navigation = PreparedReaderNavigation(snapshot::capture, {}, {}, snapshot::animate, snapshot::release, {})
            navigation.request(ReaderPageTarget("source", 0), ReaderPageTarget("destination", 1))
            beforeDraw.captured.run()

            assertEquals("Visible controls must not crop article pixels beneath or beside them", 2300, capturedBounds.captured.bottom)
            verify { Bitmap.createBitmap(1080, 2200, Bitmap.Config.ARGB_8888) }
            pixelCopy.captured.onPixelCopyFinished(PixelCopy.SUCCESS)

            // Test_ReaderPageSnapshot.kt leaves the destination unready: the complete old article stays on top.
            assertTrue(navigation.isPreparing)
            assertTrue(snapshotView.isCaptured)
            verify { pager.alpha = 1f / 255f }
            verify(exactly = 0) { content.removeView(any()) }
            verify(exactly = 0) { pager.bringToFront() }
            navigation.ready("unrelated")
            assertTrue(navigation.isPreparing)

            navigation.ready("destination")
            verify { pager.bringToFront() }
            verify { pager.translationX = 1080f }
            verify(exactly = 0) { anyConstructed<ImageView>().animate() }
            verify(exactly = 0) { content.removeView(any()) }
            animationEnd.captured.run()
            verify { content.removeView(snapshotView.captured) }
            verify { bitmap.recycle() }
        } finally {
            unmockkConstructor(Rect::class, Handler::class, ImageView::class, FrameLayout.LayoutParams::class, DecelerateInterpolator::class)
            unmockkStatic(Bitmap::class, Looper::class, PixelCopy::class, OneShotPreDrawListener::class, UIUtils::class)
        }
    }

    private fun bindingField(binding: ActivityReadingBinding, name: String, value: Any) {
        ActivityReadingBinding::class.java.getDeclaredField(name).apply {
            isAccessible = true
            set(binding, value)
        }
    }
}
