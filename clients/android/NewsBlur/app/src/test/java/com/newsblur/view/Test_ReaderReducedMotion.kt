package com.newsblur.view

import android.animation.ValueAnimator
import android.content.Context
import android.content.SharedPreferences
import android.util.DisplayMetrics
import android.view.View
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.AnimationSet
import android.view.animation.OvershootInterpolator
import android.view.animation.ScaleAnimation
import android.view.animation.TranslateAnimation
import com.newsblur.util.ViewUtils
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class Test_ReaderReducedMotion {
    private var reduceMotion = false
    private val parts = mutableListOf<Animation>()
    private lateinit var view: View

    @Before fun setup() {
        mockkStatic(ValueAnimator::class, ViewUtils::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
        mockkObject(ThemeTransition)
        every { ThemeTransition.isRevealing(any()) } returns false
        mockkConstructor(AnimationSet::class, AlphaAnimation::class, TranslateAnimation::class,
            ScaleAnimation::class, OvershootInterpolator::class, DisplayMetrics::class)
        every { anyConstructed<AnimationSet>().addAnimation(capture(parts)) } just Runs
        every { anyConstructed<AlphaAnimation>().setDuration(any()) } just Runs
        every { anyConstructed<TranslateAnimation>().setDuration(any()) } just Runs
        every { anyConstructed<ScaleAnimation>().setDuration(any()) } just Runs
        every { anyConstructed<AnimationSet>().setStartOffset(any()) } just Runs
        every { anyConstructed<TranslateAnimation>().setInterpolator(any()) } just Runs
        every { anyConstructed<ScaleAnimation>().setInterpolator(any()) } just Runs
        val preferences = mockk<SharedPreferences>()
        every { preferences.getBoolean("reduce_motion", false) } answers { reduceMotion }
        val context = mockk<Context>(relaxed = true)
        every { context.getSharedPreferences("preferences", Context.MODE_PRIVATE) } returns preferences
        val metrics = DisplayMetrics().apply { density = 1f }
        view = mockk(relaxed = true)
        every { view.context } returns context
        every { view.resources.displayMetrics } returns metrics
        every { view.isAttachedToWindow } returns true
        every { view.isShown } returns true
        every { view.windowVisibility } returns View.VISIBLE
        every { view.visibility } returns View.VISIBLE
        every { view.alpha } returns 1f
        every { view.parent } returns null
    }

    @After fun cleanup() = unmockkAll()

    // Test_ReaderReducedMotion.kt protects all three reader surfaces through their shared entrance:
    // treating Reduce motion as an all-animation gate would lose the fade; ignoring it retains the lift.
    @Test fun test_reduced_motion_keeps_fade_without_feed_title_or_article_movement() {
        reduceMotion = true
        for (distance in listOf(12f, 16f, 9f)) {
            parts.clear()
            assertTrue(ReaderMotion.enter(view, 35, distance))
            assertEquals(1, parts.filterIsInstance<AlphaAnimation>().size)
            assertTrue("Reduced entrances must never translate", parts.none { it is TranslateAnimation })
        }
        verify(exactly = 3) { view.startAnimation(any()) }
        verify(atLeast = 1) { anyConstructed<AlphaAnimation>().setDuration(more(0L)) }
    }

    @Test fun test_changing_preference_applies_to_next_entrance_and_restores_normal_motion() {
        for (reduced in listOf(false, true, false)) {
            reduceMotion = reduced
            parts.clear()
            assertTrue(ReaderMotion.enter(view, 0, 16f))
            assertTrue(parts.any { it is AlphaAnimation })
            assertEquals(!reduced, parts.any { it is TranslateAnimation })
        }
    }

    @Test fun test_reduced_motion_removes_action_button_scale() {
        reduceMotion = true
        ReaderMotion.pop(view)
        verify(exactly = 0) { view.startAnimation(ofType<ScaleAnimation>()) }
    }
}
