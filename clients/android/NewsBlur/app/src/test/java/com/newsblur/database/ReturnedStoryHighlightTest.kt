package com.newsblur.database

import android.animation.ValueAnimator
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.view.View
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class ReturnedStoryHighlightTest {
    @Test
    fun highlightWaitsForPresentationAndKeepsItsProgressWhenTheSameStoryRebinds() {
        withFixture { fixture ->
            fixture.highlight.hold()
            verify(exactly = 0) { fixture.animation.start() }
            fixture.highlight.fade()
            fixture.frame(123)
            fixture.highlight.beforeRebind()
            assertSame(fixture.initialBackground, fixture.background)
            val refreshedBackground = mockk<Drawable>()
            fixture.background = refreshedBackground
            fixture.highlight.afterRebind()
            fixture.highlight.fade()
            fixture.frame(456)
            verify(exactly = 1) { fixture.animation.start() }
            verify { fixture.view.setBackgroundColor(456) }
            fixture.highlight.cancel()
            assertSame(refreshedBackground, fixture.background)
        }
    }

    @Test
    fun recycledHolderStopsAnimatingAndRestoresBeforeItsNewBinding() {
        withFixture { fixture ->
            fixture.highlight.hold()
            fixture.highlight.fade()
            fixture.highlight.cancel()
            assertSame(fixture.initialBackground, fixture.background)
            verify { fixture.animation.removeAllUpdateListeners() }
            verify { fixture.animation.cancel() }
            fixture.hash = "different-story"
            val newBackground = mockk<Drawable>()
            fixture.background = newBackground
            fixture.highlight.cancel()
            assertSame(newBackground, fixture.background)
            assertTrue(fixture.highlight.isFinished)
        }
    }

    @Test
    fun aLateAnimationFrameCannotPaintADifferentStoryOrRestoreItsOldBackground() {
        withFixture { fixture ->
            fixture.highlight.hold()
            fixture.highlight.fade()
            fixture.hash = "different-story"
            val newBackground = mockk<Drawable>()
            fixture.background = newBackground
            fixture.frame(123)
            verify(exactly = 0) { fixture.view.setBackgroundColor(any()) }
            verify { fixture.animation.cancel() }
            fixture.highlight.cancel()
            assertSame(newBackground, fixture.background)
        }
    }

    private fun withFixture(test: (Fixture) -> Unit) {
        mockkConstructor(ColorDrawable::class)
        try {
            test(Fixture())
        } finally {
            unmockkConstructor(ColorDrawable::class)
        }
    }

    private class Fixture {
        val view = mockk<View>(relaxed = true)
        val initialBackground = mockk<Drawable>()
        var background: Drawable? = initialBackground
        val animation = mockk<ValueAnimator>(relaxed = true)
        val update = slot<ValueAnimator.AnimatorUpdateListener>()
        var hash = "last-viewed-story"
        val highlight: ReturnedStoryHighlight

        init {
            every { view.background } answers { background }
            every { view.background = any() } answers { background = firstArg() }
            every { animation.addUpdateListener(capture(update)) } answers { }
            highlight = ReturnedStoryHighlight(view, hash, { hash }, 1, 2) { animation }
        }

        fun frame(color: Int) {
            every { animation.animatedValue } returns color
            update.captured.onAnimationUpdate(animation)
        }
    }
}
