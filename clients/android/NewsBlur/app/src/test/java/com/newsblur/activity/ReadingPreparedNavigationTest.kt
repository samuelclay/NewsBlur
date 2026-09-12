package com.newsblur.activity

import android.os.SystemClock
import android.util.Log
import androidx.viewpager.widget.ViewPager
import com.newsblur.database.ReadingAdapter
import com.newsblur.domain.Story
import com.newsblur.fragment.ReadingItemFragment
import com.newsblur.keyboard.KeyboardEvent
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ReadingPreparedNavigationTest {
    @Before
    fun mockTraceClock() {
        mockkStatic(SystemClock::class, Log::class)
        every { SystemClock.uptimeMillis() } returns 1000L
        every { Log.d(any(), any()) } returns 0
    }

    @After
    fun restoreTraceClock() {
        unmockkStatic(SystemClock::class, Log::class)
    }

    @Test
    fun farNextDoesNotAnimateAnUnpreparedWebViewOntoTheScreen() {
        val reading = mockk<Reading>(relaxed = true)
        val pager = mockk<ViewPager>(relaxed = true)
        val adapter = mockk<ReadingAdapter>(relaxed = true)
        val stories = (0..7).map { index ->
            Story().apply {
                id = "https://example.com/$index"
                feedId = "1"
                storyHash = "1:$index"
                read = index != 7
            }
        }
        every { pager.currentItem } returns 0
        every { adapter.count } returns stories.size
        every { adapter.getStory(any()) } answers { stories.getOrNull(firstArg()) }
        every { adapter.getExistingItem(any()) } returns null
        every { reading.runOnUiThread(any()) } answers { firstArg<Runnable>().run() }
        every { reading["nextUnread"]() } answers { callOriginal() }
        every { reading["clearCurrentStoryPins"]() } returns Unit
        every { reading["requestedReadingPosition"]() } answers { callOriginal() }
        every { reading["navigateToStory"](any<Int>(), any<Boolean>()) } answers { callOriginal() }
        every { reading["updateOverlayText"]() } returns Unit
        var captureStarted = false
        val navigation = PreparedReaderNavigation(
            capture = { captureStarted = true },
            prepare = {}, commit = {}, animate = { _, _ -> }, release = {}, captureFailed = {},
        )
        setField(reading, "pager", pager)
        setField(reading, "readingAdapter", adapter)
        setField(reading, "traverseBar", mockk<ReadingTraverseBar>(relaxed = true))
        setField(reading, "preparedPageNavigation", navigation)

        Reading::class.java.getDeclaredMethod("nextUnread").apply {
            isAccessible = true
            invoke(reading)
        }

        verify(exactly = 0) { pager.setCurrentItem(7, true) }
        assertTrue("Reading.kt must retain the outgoing rendered page before preparing the far target", captureStarted)
    }

    @Test
    fun hiddenDestinationCannotBeSharedOrMarkedReadBeforeReveal() {
        val reading = mockk<Reading>(relaxed = true)
        val adapter = mockk<ReadingAdapter>(relaxed = true)
        val destination = mockk<ReadingItemFragment>(relaxed = true)
        val navigation = PreparedReaderNavigation(
            capture = { it(true) }, prepare = {}, commit = {},
            animate = { _, _ -> }, release = {}, captureFailed = {},
        )
        every { adapter.getActiveItem() } returns destination
        every { reading getProperty "readingFragment" } returns destination
        every { reading.onKeyboardEvent(any()) } answers { callOriginal() }
        setField(reading, "pager", mockk<ViewPager>(relaxed = true))
        setField(reading, "readingAdapter", adapter)
        setField(reading, "preparedPageNavigation", navigation)
        navigation.request(ReaderPageTarget("1:0", 0), ReaderPageTarget("1:7", 7))

        reading.onKeyboardEvent(KeyboardEvent.ShareStory)
        reading.onKeyboardEvent(KeyboardEvent.ToggleReadUnread)

        verify(exactly = 0) { destination.openShareDialog() }
        verify(exactly = 0) { destination.switchMarkStoryReadState(any()) }
        navigation.ready("1:7")
        reading.onKeyboardEvent(KeyboardEvent.ShareStory)
        verify(exactly = 1) { destination.openShareDialog() }
    }

    private fun setField(target: Reading, name: String, value: Any) {
        Reading::class.java.getDeclaredField(name).apply {
            isAccessible = true
            set(target, value)
        }
    }
}
