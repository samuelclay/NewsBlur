package com.newsblur.activity

import android.os.SystemClock
import android.os.Looper
import android.util.Log
import android.view.View
import com.google.android.material.snackbar.Snackbar
import com.newsblur.R
import com.newsblur.util.PrefConstants.ThemeValue
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReadingPreparedEntranceBackTest {
    @Test
    fun elapsedLoadingDeadlineCannotRevealAnUnpreparedArticle() {
        mockkStatic(Log::class, SystemClock::class)
        every { Log.d(any(), any()) } returns 0
        every { SystemClock.uptimeMillis() } returns 1000L
        try {
            val fixture = Fixture()
            fixture.timeout.run()
            assertTrue("Reading.kt must keep the titles visible until article layout is ready", fixture.waitingForEntrance())
            verify(exactly = 0) { fixture.surface.alpha = 1f }
        } finally {
            unmockkStatic(Log::class, SystemClock::class)
        }
    }

    @Test
    fun slowLoadingKeepsTheTitlesVisibleAndCancelExitsTheReader() {
        mockkStatic(Looper::class)
        every { Looper.getMainLooper() } returns mockk(relaxed = true)
        mockkStatic(Snackbar::class)
        try {
            for (theme in listOf(ThemeValue.LIGHT, ThemeValue.DARK, ThemeValue.BLACK, ThemeValue.SEPIA)) {
                val fixture = Fixture(theme)
                val snackbar = mockk<Snackbar>(relaxed = true)
                val cancel = slot<View.OnClickListener>()
                every { Snackbar.make(fixture.surface, R.string.loading, Snackbar.LENGTH_INDEFINITE) } returns snackbar
                every { snackbar.setAction(android.R.string.cancel, capture(cancel)) } returns snackbar
                every { snackbar.setActionTextColor(any<Int>()) } returns snackbar
                every { snackbar.setTextColor(any<Int>()) } returns snackbar
                every { snackbar.setBackgroundTint(any()) } returns snackbar
                every { fixture.reading["showPreparedEntranceLoading"]() } answers { callOriginal() }
                fixture.invoke("showPreparedEntranceLoading")
                assertTrue(fixture.waitingForEntrance())
                verify(exactly = 1) { snackbar.show() }
                verify(exactly = 0) { fixture.surface.alpha = 1f }
                verify(exactly = 1) { snackbar.setActionTextColor(fixture.traverseBar.palette.tintColor) }
                verify(exactly = 1) { snackbar.setTextColor(fixture.traverseBar.palette.tintColor) }
                verify(exactly = 1) { snackbar.setBackgroundTint(fixture.traverseBar.palette.groupBackgroundColor) }

                cancel.captured.onClick(mockk(relaxed = true))
                fixture.assertEntranceCanceled()
                verify(exactly = 1) { snackbar.dismiss() }
            }
        } finally {
            unmockkStatic(Snackbar::class)
            unmockkStatic(Looper::class)
        }
    }

    @Test
    fun committedBackDisarmsBothQueuedEntranceCallbacksBeforeAnimatingOut() {
        val fixture = Fixture()

        fixture.reading.finish()

        fixture.assertEntranceCanceled()
        fixture.deliverAlreadyQueuedCallbacks()
        verify(exactly = 0) { fixture.surface.alpha = 1f }
    }

    @Test
    fun completingTheCustomBackGestureDisarmsBothQueuedEntranceCallbacks() {
        val fixture = Fixture()

        fixture.invoke("completeInteractiveReaderBackSwipe")

        fixture.assertEntranceCanceled()
        fixture.deliverAlreadyQueuedCallbacks()
        verify(exactly = 0) { fixture.surface.alpha = 1f }
    }

    @Test
    fun cancelingThePredictiveGestureKeepsTheNormalEntrancePending() {
        val fixture = Fixture()

        fixture.invoke("cancelInteractiveReaderBackSwipe")

        assertTrue(fixture.waitingForEntrance())
        verify(exactly = 0) { fixture.surface.removeCallbacks(fixture.timeout) }
    }

    private class Fixture(theme: ThemeValue = ThemeValue.LIGHT) {
        val reading = mockk<Reading>(relaxed = true)
        val traverseBar = ReadingTraverseBar(reading, mockk(relaxed = true), theme)
        val surface = mockk<View>(relaxed = true)
        val timeout = Runnable { reveal("timeout") }

        init {
            setField("waitingForPreparedEntrance", true)
            setField("preparedEntranceTimeout", timeout)
            setField("traverseBar", traverseBar)
            every { surface.width } returns 1080
            every { reading.finish() } answers { callOriginal() }
            every { reading["shouldAnimateReaderBackFinish"]() } returns true
            every { reading["interactiveBackSurface"]() } returns surface
            every { reading["completeInteractiveReaderBackSwipe"]() } answers { callOriginal() }
            every { reading["cancelInteractiveReaderBackSwipe"]() } answers { callOriginal() }
            every { reading["revealPreparedEntrance"](any<String>()) } answers { callOriginal() }
        }

        fun assertEntranceCanceled() {
            assertFalse("Reading.kt must cancel preparation before the Back animation finishes", waitingForEntrance())
            verify(exactly = 1) { surface.removeCallbacks(timeout) }
        }

        fun deliverAlreadyQueuedCallbacks() {
            // Reading.kt can already have posted a visual-ready callback when Back is committed.
            timeout.run()
            reveal("visual_ready")
        }

        fun waitingForEntrance(): Boolean =
            Reading::class.java.getDeclaredField("waitingForPreparedEntrance").run {
                isAccessible = true
                getBoolean(reading)
            }

        fun invoke(name: String) {
            Reading::class.java.getDeclaredMethod(name).run {
                isAccessible = true
                invoke(reading)
            }
        }

        private fun reveal(reason: String) {
            Reading::class.java.getDeclaredMethod("revealPreparedEntrance", String::class.java).run {
                isAccessible = true
                invoke(reading, reason)
            }
        }

        private fun setField(name: String, value: Any) {
            Reading::class.java.getDeclaredField(name).run {
                isAccessible = true
                set(reading, value)
            }
        }
    }
}
