package com.newsblur.activity

import android.os.SystemClock
import android.util.Log
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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class ReadingHistoryNavigationTest {
    @Before
    fun keepUnrelatedBackgroundReadWorkPending() {
        mockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        mockkStatic(SystemClock::class, Log::class)
        every { SystemClock.uptimeMillis() } returns 1000L
        every { Log.d(any(), any()) } returns 0
    }

    @After
    fun restoreCoroutineExtensions() {
        unmockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        unmockkStatic(SystemClock::class, Log::class)
    }

    @Test
    fun selectionEnablesPreviousBeforeAnyReadOrSyncUpdateArrives() {
        val fixture = Fixture()

        fixture.reading.onPageSelected(0)
        fixture.reading.onPageSelected(3)

        assertEquals(listOf(fixture.stories[0], fixture.stories[3]), fixture.history)
        verify(exactly = 1) { fixture.traverseBar.updatePreviousEnabled(true) }
    }

    @Test
    fun previousRetracesVisitedStoriesWithAnimationIncludingSkippedPages() {
        val fixture = Fixture()
        fixture.reading.onPageSelected(0)
        fixture.reading.onPageSelected(3)
        fixture.reading.onPageSelected(5)

        fixture.previous()
        fixture.previous()

        verify(exactly = 1) { fixture.pager.setCurrentItem(3, false) }
        verify(exactly = 1) { fixture.pager.setCurrentItem(0, false) }
        assertEquals(listOf(-1, -1), fixture.animationDirections)
        assertEquals(listOf(fixture.stories[0]), fixture.history)
        verify(atLeast = 1) { fixture.traverseBar.updatePreviousEnabled(false) }
    }

    @Test
    fun aRepeatedSelectionDoesNotAddADuplicateHistoryEntry() {
        val fixture = Fixture()

        fixture.reading.onPageSelected(0)
        fixture.reading.onPageSelected(3)
        fixture.reading.onPageSelected(3)

        assertEquals(listOf(fixture.stories[0], fixture.stories[3]), fixture.history)
    }

    @Test
    fun previousDoesNotTrimVisibleHistoryUntilItsPreparedPageIsRevealed() {
        val fixture = Fixture()
        fixture.reading.onPageSelected(0)
        fixture.reading.onPageSelected(3)
        fixture.reading.onPageSelected(5)
        fixture.completePreparationImmediately = false

        fixture.previous()

        assertEquals(listOf(fixture.stories[0], fixture.stories[3], fixture.stories[5]), fixture.history)
        fixture.navigation.ready(fixture.stories[3].storyHash)
        assertEquals(listOf(fixture.stories[0], fixture.stories[3]), fixture.history)
    }

    private class Fixture {
        val reading = mockk<Reading>(relaxed = true)
        val pager = mockk<ViewPager>(relaxed = true)
        val traverseBar = mockk<ReadingTraverseBar>(relaxed = true)
        val history = mutableListOf<Story>()
        val animationDirections = mutableListOf<Int>()
        var completePreparationImmediately = true
        val navigation: PreparedReaderNavigation
        val stories = (0..5).map { index ->
            Story().apply {
                id = "https://example.com/story/$index"
                feedId = "5523704"
                storyHash = "5523704:$index"
                read = true
            }
        }

        init {
            val adapter = mockk<ReadingAdapter>(relaxed = true)
            every { adapter.getStory(any()) } answers { stories.getOrNull(firstArg()) }
            every { adapter.getPosition(any()) } answers { stories.indexOf(firstArg()) }
            every { adapter.findHash(any()) } answers { stories.indexOfFirst { it.storyHash == firstArg<String>() } }
            every { adapter.getExistingItem(any()) } returns null
            setField("readingAdapter", adapter)
            setField("pager", pager)
            setField("traverseBar", traverseBar)
            setField("pageHistory", history)
            val scope = mockk<androidx.lifecycle.LifecycleCoroutineScope>(relaxed = true)
            every { reading.lifecycleScope } returns scope
            every { scope.executeAsyncTask<Any?>(any(), any(), any()) } returns Job()
            var currentPosition = 0
            every { pager.currentItem } answers { currentPosition }
            every { reading.onPageSelected(any()) } answers {
                currentPosition = firstArg()
                callOriginal()
            }
            every { pager.setCurrentItem(any(), any()) } answers { reading.onPageSelected(firstArg()) }
            every { reading["getLastReadPosition"](any<Boolean>()) } answers { callOriginal() }
            every { reading["overlayLeftClick"]() } answers { callOriginal() }
            every { reading["clearCurrentStoryPins"]() } returns Unit
            every { reading["navigateToStory"](any<Int>(), any<Boolean>()) } answers { callOriginal() }
            every { reading["trimHistoryToStory"](any<String>()) } answers { callOriginal() }
            every { reading["commitPreparedPage"](any<ReaderPageTarget>()) } answers { callOriginal() }
            lateinit var coordinator: PreparedReaderNavigation
            coordinator = PreparedReaderNavigation(
                capture = { it(true) },
                prepare = { target ->
                    pager.setCurrentItem(target.position, false)
                    if (completePreparationImmediately) coordinator.ready(target.storyHash)
                },
                commit = { target ->
                    Reading::class.java.getDeclaredMethod("commitPreparedPage", ReaderPageTarget::class.java).apply {
                        isAccessible = true
                        invoke(reading, target)
                    }
                },
                animate = { direction, completion ->
                    animationDirections.add(direction)
                    completion()
                },
                release = {},
                captureFailed = {},
            )
            navigation = coordinator
            setField("preparedPageNavigation", navigation)
        }

        fun previous() {
            Reading::class.java.getDeclaredMethod("overlayLeftClick").apply {
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
