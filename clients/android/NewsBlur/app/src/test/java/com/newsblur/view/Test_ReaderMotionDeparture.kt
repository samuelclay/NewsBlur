package com.newsblur.view

import android.animation.ValueAnimator
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import com.newsblur.util.ViewUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class Test_ReaderMotionDeparture {
    @Before fun setUp() {
        mockkStatic(Bitmap::class, ValueAnimator::class, ViewUtils::class)
        mockkConstructor(Canvas::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
    }

    @After fun tearDown() = unmockkAll()

    @Test fun test_allocation_failure_still_hides_the_original_view() {
        val fixture = Fixture()
        every { Bitmap.createBitmap(any<Int>(), any<Int>(), any<Bitmap.Config>()) } throws OutOfMemoryError("snapshot allocation")

        ReaderMotion.visibility(fixture.view, View.GONE)

        assertEquals(View.GONE, fixture.visibility)
        verify(exactly = 0) { fixture.parent.overlay }
    }

    @Test fun test_drawing_failure_releases_the_snapshot_and_still_hides_the_original_view() {
        val fixture = Fixture()
        val bitmap = mockk<Bitmap>(relaxed = true)
        every { Bitmap.createBitmap(any<Int>(), any<Int>(), any<Bitmap.Config>()) } returns bitmap
        every { fixture.view.draw(any()) } throws OutOfMemoryError("snapshot drawing")

        ReaderMotion.visibility(fixture.view, View.INVISIBLE)

        assertEquals(View.INVISIBLE, fixture.visibility)
        verify(exactly = 1) { bitmap.recycle() }
        verify(exactly = 0) { fixture.parent.overlay }
    }

    @Test fun test_large_departures_skip_bitmap_allocation() {
        val fixture = Fixture()
        every { fixture.view.width } returns 1001
        every { fixture.view.height } returns 1000
        every { Bitmap.createBitmap(any<Int>(), any<Int>(), any<Bitmap.Config>()) } throws AssertionError("oversized departure allocation")

        ReaderMotion.visibility(fixture.view, View.GONE)

        assertEquals(View.GONE, fixture.visibility)
        verify(exactly = 0) { Bitmap.createBitmap(any<Int>(), any<Int>(), any<Bitmap.Config>()) }
    }

    private class Fixture {
        val parent = mockk<ViewGroup>(relaxed = true)
        val view = mockk<View>(relaxed = true)
        var visibility = View.VISIBLE

        init {
            every { view.parent } returns parent
            every { view.isShown } returns true
            every { view.width } returns 100
            every { view.height } returns 100
            every { view.visibility } answers { visibility }
            every { view.visibility = any() } answers { visibility = firstArg() }
        }
    }
}
