package com.newsblur.activity

import android.os.SystemClock
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewPropertyAnimator
import androidx.viewpager.widget.ViewPager
import com.newsblur.database.ReadingAdapter
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.domain.Story
import com.newsblur.fragment.ReadingItemFragment
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
    fun test_native_header_ready_enters_without_waiting_for_article_pixels() {
        mockkStatic(Log::class, SystemClock::class)
        every { Log.d(any(), any()) } returns 0
        every { SystemClock.uptimeMillis() } returns 1000L
        try {
            val fixture = Fixture()
            fixture.bindNativeHeader()
            fixture.reveal("native_ready")
            assertFalse("A laid-out title and controls must enter while the WebView is still preparing", fixture.waitingForEntrance())
            verify { fixture.surface.translationX = 1080f }
        } finally {
            unmockkStatic(Log::class, SystemClock::class)
        }
    }

    @Test
    fun elapsedLoadingDeadlineCannotRevealAnUnpreparedNativeHeader() {
        mockkStatic(Log::class, SystemClock::class)
        every { Log.d(any(), any()) } returns 0
        every { SystemClock.uptimeMillis() } returns 1000L
        try {
            val fixture = Fixture()
            fixture.timeout.run()
            assertTrue("Reading.kt must keep the titles visible until the native header is laid out", fixture.waitingForEntrance())
            verify(exactly = 0) { fixture.surface.alpha = 1f }
        } finally {
            unmockkStatic(Log::class, SystemClock::class)
        }
    }

    @Test
    fun slowTargetLoadingKeepsTheTitlesVisibleAndCancelExitsTheReader() {
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
        fixture.bindNativeHeader()

        fixture.reading.finish()

        fixture.assertEntranceCanceled()
        fixture.deliverAlreadyQueuedCallbacks()
        verify(exactly = 0) { fixture.surface.alpha = 1f }
    }

    @Test
    fun completingTheCustomBackGestureDisarmsBothQueuedEntranceCallbacks() {
        val fixture = Fixture()
        fixture.bindNativeHeader()

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

    @Test
    fun anUnlaidOutNativeTitleCannotEnter() {
        val fixture = Fixture()
        fixture.bindNativeHeader(ready = false)
        fixture.reveal("native_ready")
        assertTrue(fixture.waitingForEntrance())
    }

    @Test
    fun committedBackBeforeBodyFadeRejectsItsVisibilityCallback() {
        val fixture = Fixture()
        fixture.bindNativeHeader()
        fixture.setField("waitingForPreparedEntrance", false)
        every { fixture.reading.onReaderArticleVisible(any()) } answers { callOriginal() }
        fixture.invoke("completeInteractiveReaderBackSwipe")
        fixture.reading.onReaderArticleVisible("1:target")
        verify(exactly = 0) { fixture.reading["resumeStoryDwell"]() }
        verify(exactly = 0) { fixture.reading["resumeCurrentStoryReadTimeTracking"]() }
    }

    @Test
    fun aChangedPendingTargetCannotEnterFromAnOldHeaderCallback() {
        val fixture = Fixture()
        fixture.bindNativeHeader()
        fixture.setField("storyHash", "1:new-target")
        fixture.reveal("native_ready")
        assertTrue(fixture.waitingForEntrance())
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

        fun bindNativeHeader(ready: Boolean = true) {
            val adapter = mockk<ReadingAdapter>(relaxed = true)
            val pager = mockk<ViewPager>(relaxed = true)
            val fragment = mockk<ReadingItemFragment>(relaxed = true)
            val binding = mockk<ActivityReadingBinding>(relaxed = true)
            val animator = mockk<ViewPropertyAnimator>(relaxed = true)
            every { surface.animate() } returns animator
            every { animator.translationX(any()) } returns animator
            every { animator.setDuration(any()) } returns animator
            every { animator.setInterpolator(any()) } returns animator
            every { pager.currentItem } returns 0
            every { adapter.getStory(0) } returns Story().apply { storyHash = "1:target" }
            every { adapter.getExistingItem(0) } returns fragment
            every { fragment.isNativeHeaderReady("1:target") } returns ready
            every { fragment.isReadyForDisplay() } returns false
            every { fragment.isArticleVisible() } returns false
            setField("pager", pager)
            setField("readingAdapter", adapter)
            setField("binding", binding)
            setField("readerIsPaused", false)
            setField("waitingForInitialArticle", true)
        }

        fun assertEntranceCanceled() {
            assertFalse("Reading.kt must cancel preparation before the Back animation finishes", waitingForEntrance())
            verify(exactly = 1) { surface.removeCallbacks(timeout) }
        }

        fun deliverAlreadyQueuedCallbacks() {
            // Reading.kt can already have posted a native-header callback when Back is committed.
            timeout.run()
            reveal("native_ready")
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

        fun reveal(reason: String) {
            Reading::class.java.getDeclaredMethod("revealPreparedEntrance", String::class.java).run {
                isAccessible = true
                invoke(reading, reason)
            }
        }

        fun setField(name: String, value: Any) {
            Reading::class.java.getDeclaredField(name).run {
                isAccessible = true
                set(reading, value)
            }
        }
    }
}
