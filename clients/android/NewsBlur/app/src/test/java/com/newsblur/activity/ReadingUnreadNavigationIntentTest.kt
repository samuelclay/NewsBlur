package com.newsblur.activity

import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.lifecycleScope
import androidx.viewpager.widget.ViewPager
import com.newsblur.database.ReadingAdapter
import com.newsblur.domain.Story
import com.newsblur.util.executeAsyncTask
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

class ReadingUnreadNavigationIntentTest {
    @Before
    fun setUp() {
        mockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        mockkStatic(SystemClock::class, Log::class, ItemsList::class)
        every { SystemClock.uptimeMillis() } returns 1000L
        every { Log.d(any(), any()) } returns 0
        every { Log.e(any(), any()) } returns 0
        every { ItemsList.peekReadingLaunchParent() } returns null
    }

    @After
    fun tearDown() {
        unmockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        unmockkStatic(SystemClock::class, Log::class, ItemsList::class)
    }

    @Test
    fun anOlderNextSearchCannotOverrideTheNewerPreviousRequest() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()
        fixture.deliverResults()
        assertEquals("1:14", fixture.navigation.requestedTarget?.storyHash)
        fixture.next()
        fixture.next()
        fixture.runBackground()
        fixture.deliverResults()
        fixture.previous()
        assertEquals("1:0", fixture.navigation.requestedTarget?.storyHash)

        fixture.runBackground()
        fixture.deliverResults()

        assertEquals("1:0", fixture.navigation.requestedTarget?.storyHash)
    }

    @Test
    fun aResultAlreadyQueuedOnMainCannotOverridePrevious() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()
        fixture.deliverResults()
        fixture.next()
        fixture.runBackground()
        fixture.previous()

        fixture.deliverResults()

        assertEquals("1:0", fixture.navigation.requestedTarget?.storyHash)
    }

    @Test
    fun committedBackRejectsAQueuedUnreadResult() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()
        fixture.invoke("completeInteractiveReaderBackSwipe")

        fixture.deliverResults()

        assertFalse(fixture.navigation.isActive)
    }

    @Test
    fun aManualPageDragRejectsAnOlderUnreadSearch() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()
        fixture.reading.onPageScrollStateChanged(ViewPager.SCROLL_STATE_DRAGGING)

        fixture.deliverResults()

        assertFalse(fixture.navigation.isActive)
    }

    @Test
    fun currentNextStillPreparesTheFoundUnreadStory() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()

        fixture.deliverResults()

        assertEquals("1:14", fixture.navigation.requestedTarget?.storyHash)
        verify(exactly = 1) { fixture.pager.setCurrentItem(14, false) }
    }

    @Test
    fun anAbandonedSearchCannotRequestMoreStoriesOrRearmThePagingRetry() {
        val fixture = Fixture()
        fixture.stories.forEach { it.read = true }
        fixture.next()
        fixture.previous()

        fixture.runBackground()
        fixture.deliverResults()

        assertFalse(fixture.unreadSearchActive())
        verify(exactly = 0) { fixture.reading["checkStoryCount"](any<Int>()) }
    }

    @Test
    fun aSyncReorderStillOpensTheUnreadStoryFoundByTheCurrentSearch() {
        val fixture = Fixture()
        fixture.next()
        fixture.runBackground()
        java.util.Collections.swap(fixture.stories, 14, 15)

        fixture.deliverResults()

        assertEquals("1:14", fixture.navigation.requestedTarget?.storyHash)
        verify(exactly = 1) { fixture.pager.setCurrentItem(15, false) }
    }

    private class Fixture {
        val reading = mockk<Reading>(relaxed = true)
        val pager = mockk<ViewPager>(relaxed = true)
        val adapter = mockk<ReadingAdapter>(relaxed = true)
        val stories = (0..16).map { index ->
            Story().apply {
                id = "https://example.com/$index"
                feedId = "1"
                storyHash = "1:$index"
                read = index < 14
            }
        }.toMutableList()
        val navigation = PreparedReaderNavigation(
            capture = { it(true) },
            prepare = { pager.setCurrentItem(it.position, false) },
            commit = {}, animate = { _, _ -> }, release = {}, captureFailed = {},
        )
        private val background = ArrayDeque<suspend () -> Unit>()
        private val uiResults = ArrayDeque<() -> Unit>()

        init {
            val scope = mockk<LifecycleCoroutineScope>(relaxed = true)
            every { reading.lifecycleScope } returns scope
            every { scope.executeAsyncTask<Any?>(any(), any(), any()) } answers {
                val work = thirdArg<suspend () -> Any?>()
                val completion = arg<(Any?) -> Unit>(3)
                background.add {
                    val result = work()
                    uiResults.add { completion(result) }
                }
                Job()
            }
            every { reading.runOnUiThread(any()) } answers {
                val runnable = firstArg<Runnable>()
                uiResults.add { runnable.run() }
            }
            var currentPosition = 0
            every { pager.currentItem } answers { currentPosition }
            every { pager.setCurrentItem(any(), any()) } answers { currentPosition = firstArg() }
            every { adapter.count } returns stories.size
            every { adapter.getStory(any()) } answers { stories.getOrNull(firstArg()) }
            every { adapter.findHash(any()) } answers { stories.indexOfFirst { it.storyHash == firstArg<String>() } }
            every { adapter.getExistingItem(any()) } returns null
            every { reading getProperty "unreadCount" } returns 3
            every { reading["overlayRightClick"]() } answers { callOriginal() }
            every { reading["nextUnread"]() } answers { callOriginal() }
            every { reading["findNextUnreadHash"](any<ReadingAdapter>(), any<Int>()) } answers { callOriginal() }
            every { reading["cancelUnreadSearch"]() } answers { callOriginal() }
            every { reading["requestedReadingPosition"]() } answers { callOriginal() }
            every { reading["navigateToStory"](any<Int>(), any<Boolean>()) } answers { callOriginal() }
            every { reading["overlayLeftClick"]() } answers { callOriginal() }
            every { reading["getLastReadPosition"](any<Boolean>()) } returns -1
            every { reading["clearCurrentStoryPins"]() } returns Unit
            every { reading["updateOverlayText"]() } returns Unit
            every { reading.onPageScrollStateChanged(any()) } answers { callOriginal() }
            every { reading["completeInteractiveReaderBackSwipe"]() } answers { callOriginal() }
            every { reading["interactiveBackSurface"]() } returns mockk<View>(relaxed = true) {
                every { width } returns 1080
            }
            setField("pager", pager)
            setField("readingAdapter", adapter)
            setField("preparedPageNavigation", navigation)
            setField("traverseBar", mockk<ReadingTraverseBar>(relaxed = true))
            setField("pageHistory", mutableListOf(stories[0]))
        }

        fun next() = invoke("overlayRightClick")
        fun previous() = invoke("overlayLeftClick")

        fun runBackground() = runBlocking { background.removeFirst().invoke() }

        fun deliverResults() {
            while (uiResults.isNotEmpty()) uiResults.removeFirst().invoke()
        }

        fun unreadSearchActive(): Boolean = Reading::class.java.getDeclaredField("unreadSearchActive").run {
            isAccessible = true
            getBoolean(reading)
        }

        fun invoke(name: String) {
            Reading::class.java.getDeclaredMethod(name).apply {
                isAccessible = true
                invoke(reading)
            }
        }

        private fun setField(name: String, value: Any) {
            Reading::class.java.getDeclaredField(name).apply {
                isAccessible = true
                set(reading, value)
            }
        }
    }
}
