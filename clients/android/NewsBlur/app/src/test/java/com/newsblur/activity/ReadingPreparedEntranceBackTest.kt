package com.newsblur.activity

import android.view.View
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReadingPreparedEntranceBackTest {
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

    private class Fixture {
        val reading = mockk<Reading>(relaxed = true)
        val surface = mockk<View>(relaxed = true)
        val timeout = Runnable { reveal("timeout") }

        init {
            setField("waitingForPreparedEntrance", true)
            setField("preparedEntranceTimeout", timeout)
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
