package com.newsblur.activity

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
    }

    @After
    fun restoreCoroutineExtensions() {
        unmockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
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
        every { fixture.pager.setCurrentItem(any(), true) } answers {
            fixture.reading.onPageSelected(firstArg())
        }

        fixture.previous()
        fixture.previous()

        verify(exactly = 1) { fixture.pager.setCurrentItem(3, true) }
        verify(exactly = 1) { fixture.pager.setCurrentItem(0, true) }
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

    private class Fixture {
        val reading = mockk<Reading>(relaxed = true)
        val pager = mockk<ViewPager>(relaxed = true)
        val traverseBar = mockk<ReadingTraverseBar>(relaxed = true)
        val history = mutableListOf<Story>()
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
            setField("readingAdapter", adapter)
            setField("pager", pager)
            setField("traverseBar", traverseBar)
            setField("pageHistory", history)
            val scope = mockk<androidx.lifecycle.LifecycleCoroutineScope>(relaxed = true)
            every { reading.lifecycleScope } returns scope
            every { scope.executeAsyncTask<Any?>(any(), any(), any()) } returns Job()
            every { reading.onPageSelected(any()) } answers { callOriginal() }
            every { reading["getLastReadPosition"](any<Boolean>()) } answers { callOriginal() }
            every { reading["overlayLeftClick"]() } answers { callOriginal() }
            every { reading["clearCurrentStoryPins"]() } returns Unit
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
