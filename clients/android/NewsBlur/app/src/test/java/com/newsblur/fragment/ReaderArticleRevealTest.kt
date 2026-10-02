package com.newsblur.fragment

import android.view.View
import android.view.ViewPropertyAnimator
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReaderArticleRevealTest {
    private class Fixture {
        var visible = 0
        val view = mockk<View>(relaxed = true)
        val animator = mockk<ViewPropertyAnimator>(relaxed = true)
        val ends = mutableListOf<Runnable>()
        val reveal = ReaderArticleReveal { visible++ }
        init {
            every { view.animate() } returns animator
            every { animator.alpha(any()) } returns animator
            every { animator.setDuration(any()) } returns animator
            every { animator.withEndAction(any()) } answers { ends.add(firstArg()); animator }
            reveal.prepare(view)
        }
    }

    @Test
    fun nativeEntryCanDrawWithoutExposingUnpreparedArticlePixels() {
        val fixture = Fixture()
        fixture.reveal.resume()
        verify { fixture.view.alpha = 1f / 255f }
        verify(exactly = 0) { fixture.animator.start() }
        assertFalse(fixture.reveal.isVisible)
        fixture.reveal.ready()
        verify(exactly = 1) { fixture.animator.start() }
        assertEquals(0, fixture.visible)
        fixture.ends.last().run()
        assertTrue(fixture.reveal.isVisible)
        assertEquals(1, fixture.visible)
    }

    @Test
    fun pixelsReadyBeforeResumeAreRevealedOnResume() {
        val fixture = Fixture()
        fixture.reveal.ready()
        verify(exactly = 0) { fixture.animator.start() }
        fixture.reveal.resume()
        fixture.ends.last().run()
        assertEquals(1, fixture.visible)
    }

    @Test
    fun pausedFadeCannotReportVisibleAndResumeRestartsIt() {
        val fixture = Fixture()
        fixture.reveal.resume()
        fixture.reveal.ready()
        val stale = fixture.ends.last()
        fixture.reveal.pause()
        stale.run()
        assertEquals(0, fixture.visible)
        fixture.reveal.resume()
        fixture.ends.last().run()
        assertEquals(1, fixture.visible)
    }

    @Test
    fun destroyedOrReplacedArticleRejectsLateAnimationCompletion() {
        for (replace in listOf(false, true)) {
            val fixture = Fixture()
            fixture.reveal.resume()
            fixture.reveal.ready()
            val stale = fixture.ends.last()
            if (replace) fixture.reveal.prepare(fixture.view) else fixture.reveal.release()
            stale.run()
            assertEquals(0, fixture.visible)
            assertFalse(fixture.reveal.isVisible)
        }
    }
}
