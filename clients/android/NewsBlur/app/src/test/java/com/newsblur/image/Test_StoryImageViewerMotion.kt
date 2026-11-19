package com.newsblur.image

import android.animation.Animator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.RectF
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import com.newsblur.util.ViewUtils
import com.newsblur.view.ReaderMotion
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class Test_StoryImageViewerMotion {
    private lateinit var viewer: StoryImageViewer
    private lateinit var transition: ImageView
    private lateinit var backdrop: View
    private lateinit var animator: ValueAnimator
    private val updates = mutableListOf<ValueAnimator.AnimatorUpdateListener>()
    private val endings = mutableListOf<Animator.AnimatorListener>()
    private var completed = false
    private var fraction = 0f
    private val sizes = mutableListOf<String>()

    @Before fun setup() {
        mockkStatic(ValueAnimator::class, ReaderMotion::class, ViewUtils::class)
        mockkConstructor(RectF::class, FrameLayout.LayoutParams::class,
            OvershootInterpolator::class, DecelerateInterpolator::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
        every { ReaderMotion.isReducedMotion(any()) } returns true
        animator = mockk(relaxed = true)
        every { ValueAnimator.ofFloat(0f, 1f) } returns animator
        every { animator.addUpdateListener(capture(updates)) } just Runs
        every { animator.addListener(capture(endings)) } just Runs
        every { animator.animatedValue } answers { fraction }
        viewer = mockk(relaxed = true)
        every { viewer.context } returns mockk<Context>(relaxed = true)
        transition = mockk(relaxed = true)
        // Android's mockable LayoutParams constructor does not retain width/height fields.
        // Test_StoryImageViewerMotion.kt tags each expected constructor to observe the bounds actually installed.
        every { transition.layoutParams = any() } answers { sizes.add(firstArg<FrameLayout.LayoutParams>().toString()) }
        backdrop = mockk(relaxed = true)
        every { backdrop.alpha } returns 1f
        val close = mockk<ImageButton>(relaxed = true)
        every { close.alpha } returns 1f
        for ((name, view) in mapOf(
            "transition" to transition, "backdrop" to backdrop, "close" to close,
            "image" to mockk<StoryImageView>(relaxed = true), "status" to mockk<LinearLayout>(relaxed = true),
            "hoverPanel" to mockk<ScrollView>(relaxed = true), "actionsPanel" to mockk<LinearLayout>(relaxed = true),
        )) {
            StoryImageViewer::class.java.getDeclaredField(name).apply { isAccessible = true }.set(viewer, view)
        }
        every { viewer["setPanelsAlpha"](any<Float>()) } answers { callOriginal() }
    }

    @After fun cleanup() = unmockkAll()

    // Test_StoryImageViewerMotion.kt protects the actual animator: gating all animations would
    // remove the fade, while leaving bounds interpolation enabled still zooms the photo.
    @Test fun test_reduced_open_fades_at_the_destination_without_zooming() {
        every { constructedWith<FrameLayout.LayoutParams>(EqMatcher(500), EqMatcher(600)).toString() } returns "destination bounds"
        animate("OPEN")
        sample(.25f)
        sample(.75f)
        verify(exactly = 2) { transition.x = 100f }
        verify(exactly = 2) { transition.y = 200f }
        assertEquals(listOf("destination bounds", "destination bounds"), sizes)
        verify { transition.alpha = .25f; transition.alpha = .75f }
        verify { backdrop.alpha = .25f; backdrop.alpha = .75f }
        verify { animator.duration = more(0L) }
        assertFalse(completed)
        endings.single().onAnimationEnd(animator)
        assertTrue(completed)
    }

    @Test fun test_reduced_close_fades_in_place_without_flying_back_to_the_thumbnail() {
        every { constructedWith<FrameLayout.LayoutParams>(EqMatcher(30), EqMatcher(50)).toString() } returns "original bounds"
        animate("CLOSE")
        sample(.25f)
        sample(.75f)
        verify(exactly = 2) { transition.x = 10f }
        verify(exactly = 2) { transition.y = 20f }
        assertEquals(listOf("original bounds", "original bounds"), sizes)
        verify { transition.alpha = .75f; transition.alpha = .25f }
        verify { backdrop.alpha = .75f; backdrop.alpha = .25f }
        assertFalse(completed)
        endings.single().onAnimationEnd(animator)
        assertTrue(completed)
    }

    @Test fun test_reduced_resize_completes_without_an_automatic_bounds_animation() {
        animate("RESIZE")
        assertTrue("The final image layout must be available immediately", completed)
        verify(exactly = 0) { animator.start() }
        verify(exactly = 0) { backdrop.alpha = any() }
    }

    @Test fun test_system_animation_off_or_power_save_settles_immediately() {
        for (powerSave in listOf(false, true)) {
            completed = false
            every { ValueAnimator.areAnimatorsEnabled() } returns powerSave
            every { ViewUtils.isPowerSaveMode(any()) } returns powerSave
            animate("OPEN")
            assertTrue(completed)
            verify { backdrop.alpha = 1f }
            verify(exactly = 0) { animator.start() }
        }
    }

    @Test fun test_normal_motion_still_interpolates_the_image_bounds() {
        every { ReaderMotion.isReducedMotion(any()) } returns false
        // Test_StoryImageViewerMotion.kt checks the rectangle the real update callback constructs
        // one quarter of the way from the thumbnail (10,20,40,70) to the viewer (100,200,600,800).
        every { constructedWith<RectF>(EqMatcher(32.5f), EqMatcher(65f), EqMatcher(180f), EqMatcher(252.5f)).width() } returns 147.5f
        every { constructedWith<RectF>(EqMatcher(32.5f), EqMatcher(65f), EqMatcher(180f), EqMatcher(252.5f)).height() } returns 187.5f
        animate("OPEN")
        sample(.25f)
        verify { constructedWith<RectF>(EqMatcher(32.5f), EqMatcher(65f), EqMatcher(180f), EqMatcher(252.5f)).width() }
        verify { constructedWith<RectF>(EqMatcher(32.5f), EqMatcher(65f), EqMatcher(180f), EqMatcher(252.5f)).height() }
        verify { transition.alpha = 1f }
        verify { animator.start() }
        assertFalse(completed)
    }

    private fun animate(name: String) {
        val modeClass = StoryImageViewer::class.java.declaredClasses.single { it.simpleName == "Mode" }
        val mode = requireNotNull(modeClass.enumConstants).single { (it as Enum<*>).name == name }
        val from = rectangle(10f, 20f, 40f, 70f)
        val to = rectangle(100f, 200f, 600f, 800f)
        every { viewer["animateImage"](any<RectF>(), any<RectF>(), mode, any<Function0<Unit>>()) } answers { callOriginal() }
        StoryImageViewer::class.java.getDeclaredMethod("animateImage", RectF::class.java, RectF::class.java,
            modeClass, Function0::class.java).apply { isAccessible = true }
            .invoke(viewer, from, to, mode, { completed = true })
    }

    private fun rectangle(left: Float, top: Float, right: Float, bottom: Float): RectF =
        mockk<RectF>().also { rect ->
            rect.left = left; rect.top = top; rect.right = right; rect.bottom = bottom
            every { rect.width() } returns right - left
            every { rect.height() } returns bottom - top
        }

    private fun sample(value: Float) {
        fraction = value
        updates.single().onAnimationUpdate(animator)
    }
}
