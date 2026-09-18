package com.newsblur.activity

import android.view.View
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.lifecycleScope
import androidx.viewpager.widget.ViewPager
import com.newsblur.MainDispatcherRule
import com.newsblur.database.ReadingAdapter
import com.newsblur.domain.Story
import com.newsblur.util.MarkStoryReadBehavior
import com.newsblur.util.executeAsyncTask
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ReadingDwellBehaviorTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Before
    fun setUp() {
        mockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
        mockkStatic(Dispatchers::class)
        every { Dispatchers.Default } returns mainDispatcherRule.dispatcher
    }

    @After
    fun tearDown() {
        unmockkStatic(Dispatchers::class)
        unmockkStatic("androidx.lifecycle.LifecycleOwnerKt", "com.newsblur.util.ExtensionsKt")
    }

    @Test
    fun fiveSecondDwellMarksOnlyAtTheConfiguredDeadline() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()

        advanceTimeBy(4_999)
        runCurrent()
        assertTrue(fixture.marked.isEmpty())
        advanceTimeBy(1)
        runCurrent()
        assertEquals(listOf("1:0"), fixture.marked)
    }

    @Test
    fun leavingThePageBeforeItsDeadlineCancelsThatStoryImmediately() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()
        advanceTimeBy(4_999)

        fixture.select(1)
        // Reading.kt must cancel the old dwell now, even when later selection work is still queued.
        advanceTimeBy(1)
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
        fixture.deliverSelectionWork()
        advanceTimeBy(5_000)
        runCurrent()
        assertEquals(listOf("1:1"), fixture.marked)
    }

    @Test
    fun outOfOrderSelectionWorkCannotMarkThePreviousStoryOrStealTheNewDwell() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        fixture.select(1)

        fixture.deliverSelectionWork(inReverse = true)
        runCurrent()
        advanceTimeBy(5_000)
        runCurrent()

        assertEquals(listOf("1:1"), fixture.marked)
    }

    @Test
    fun pausingBeforeTheDwellDeadlineDoesNotReadAnOffscreenStory() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()
        advanceTimeBy(4_999)

        fixture.pauseBeforeFrameworkDispatch()
        advanceTimeBy(10_000)
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
    }

    @Test
    fun committedBackCancelsDwellBeforeTheExitAnimationFinishes() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()
        advanceTimeBy(4_999)

        fixture.invoke("completeInteractiveReaderBackSwipe")
        advanceTimeBy(1)
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
    }

    @Test
    fun anUnrenderedEntranceDoesNotUseUpTheStoryDwell() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.setField("waitingForPreparedEntrance", true)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()

        advanceTimeBy(10_000)
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
    }

    @Test
    fun nativeEntranceDoesNotStartDwellWhileArticleRemainsHidden() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.setField("waitingForInitialArticle", true)
        fixture.select(0)
        advanceTimeBy(10_000)
        runCurrent()
        assertTrue(fixture.marked.isEmpty())
        fixture.setField("waitingForInitialArticle", false)
        fixture.invoke("resumeStoryDwell")
        runCurrent()
        advanceTimeBy(4_999)
        runCurrent()
        assertTrue(fixture.marked.isEmpty())
        advanceTimeBy(1)
        runCurrent()
        assertEquals(listOf("1:0"), fixture.marked)
    }

    @Test
    fun returningFromHomeStartsANewFullDwellOnTheSameVisibleStory() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.select(0)
        runCurrent()
        advanceTimeBy(2_000)
        fixture.pauseBeforeFrameworkDispatch()
        advanceTimeBy(10_000)
        fixture.setField("readerIsPaused", false)

        fixture.invoke("resumeStoryDwell")
        runCurrent()
        advanceTimeBy(4_999)
        runCurrent()
        assertTrue(fixture.marked.isEmpty())
        advanceTimeBy(1)
        runCurrent()
        assertEquals(listOf("1:0"), fixture.marked)
    }

    @Test
    fun aPreparedEntranceStartsItsFullDwellWhenTheArticleBecomesVisible() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.SECONDS_5)
        fixture.setField("waitingForPreparedEntrance", true)
        fixture.select(0)
        advanceTimeBy(10_000)
        fixture.setField("waitingForPreparedEntrance", false)

        fixture.invoke("resumeStoryDwell")
        runCurrent()
        advanceTimeBy(4_999)
        runCurrent()
        assertTrue(fixture.marked.isEmpty())
        advanceTimeBy(1)
        runCurrent()
        assertEquals(listOf("1:0"), fixture.marked)
    }

    @Test
    fun immediatePreferenceMarksEachActuallySelectedStoryWithoutADwell() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.IMMEDIATELY)
        fixture.select(0)
        runCurrent()
        fixture.select(1)
        runCurrent()

        assertEquals(listOf("1:0", "1:1"), fixture.marked)
    }

    @Test
    fun manualPreferenceNeverAutomaticallyMarksASelectedStory() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.MANUALLY)
        fixture.select(0)
        fixture.deliverSelectionWork()

        advanceTimeBy(120_000)
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
    }

    @Test
    fun restoringThePagerCannotImmediatelyMarkItsTemporarySelection() = runTest {
        val fixture = Fixture(MarkStoryReadBehavior.IMMEDIATELY)
        fixture.setField("isRestoringState", true)
        fixture.select(0)
        fixture.deliverSelectionWork()
        runCurrent()

        assertTrue(fixture.marked.isEmpty())
    }

    @Test
    fun anOldReadPinCannotReplaceTheActuallyVisibleStoryOnReturn() {
        val fixture = Fixture(MarkStoryReadBehavior.MANUALLY)
        fixture.setField("recentlyMarkedReadStory", fixture.stories[0].copyForBundle().apply { read = true })
        fixture.select(1)

        assertEquals("1:1", fixture.currentStory()?.storyHash)
    }

    @Test
    fun aMatchingManualReadPinPreservesItsUpdatedStateBeforeTheDatabasePublishes() {
        val fixture = Fixture(MarkStoryReadBehavior.MANUALLY)
        fixture.select(0)
        fixture.setField("recentlyMarkedReadStory", fixture.stories[0].copyForBundle().apply { read = true })

        assertEquals("1:0", fixture.currentStory()?.storyHash)
        assertTrue(fixture.currentStory()?.read == true)
    }

    private inner class Fixture(behavior: MarkStoryReadBehavior) {
        val reading = mockk<Reading>(relaxed = true)
        val marked = mutableListOf<String>()
        val stories = (0..1).map { index ->
            Story().apply {
                id = "https://example.com/$index"
                storyHash = "1:$index"
                feedId = "1"
                read = false
            }
        }
        private val selectionWork = mutableListOf<suspend () -> Unit>()
        private val pauseBoundary = IllegalStateException("Framework lifecycle boundary outside Reading.kt")
        private var currentPosition = 0

        init {
            val adapter = mockk<ReadingAdapter>(relaxed = true)
            val pager = mockk<ViewPager>(relaxed = true)
            val scope = mockk<LifecycleCoroutineScope>(relaxed = true)
            every { scope.coroutineContext } returns (mainDispatcherRule.dispatcher + SupervisorJob())
            every { reading.lifecycleScope } returns scope
            every { scope.executeAsyncTask<Any?>(any(), any(), any()) } answers {
                val work = thirdArg<suspend () -> Any?>()
                val completion = arg<(Any?) -> Unit>(3)
                selectionWork.add { completion(work()) }
                Job()
            }
            every { pager.currentItem } answers { currentPosition }
            every { adapter.getStory(any()) } answers { stories.getOrNull(firstArg()) }
            every { adapter.getActiveStory() } answers { stories[currentPosition] }
            every { reading.onPageSelected(any()) } answers { callOriginal() }
            every { reading["triggerMarkStoryReadBehavior"](any<Story>()) } answers { callOriginal() }
            every { reading["cancelStoryDwell"](any<Boolean>()) } answers { callOriginal() }
            every { reading["resumeStoryDwell"]() } answers { callOriginal() }
            every { reading["createMarkStoryReadJob"](any<Story>(), any<Long>()) } answers { callOriginal() }
            every { reading["currentReadingStory"]() } answers { callOriginal() }
            every { reading["activeReadingStory"]() } answers { callOriginal() }
            every { reading["pagerReadingStory"]() } answers { callOriginal() }
            every { reading.markStoryAsRead(any()) } answers { marked.add(firstArg<Story>().storyHash) }
            every { reading["onPause"]() } answers { callOriginal() }
            every { reading["flushAndStopReadTimeTracking"]() } throws pauseBoundary
            every { reading["completeInteractiveReaderBackSwipe"]() } answers { callOriginal() }
            every { reading["interactiveBackSurface"]() } returns mockk<View>(relaxed = true) {
                every { width } returns 1080
            }
            setField("pager", pager)
            setField("readingAdapter", adapter)
            setField("markStoryReadBehavior", behavior)
            setField("traverseBar", mockk<ReadingTraverseBar>(relaxed = true))
            setField("pageHistory", mutableListOf<Story>())
        }

        fun select(position: Int) {
            currentPosition = position
            reading.onPageSelected(position)
        }

        suspend fun deliverSelectionWork(inReverse: Boolean = false) {
            val pending = selectionWork.toList()
            selectionWork.clear()
            (if (inReverse) pending.reversed() else pending).forEach { it() }
        }

        fun pauseBeforeFrameworkDispatch() {
            assertEquals(pauseBoundary, runCatching { invoke("onPause") }.exceptionOrNull()?.cause)
        }

        fun currentStory(): Story? = invoke("currentReadingStory") as? Story

        fun invoke(name: String): Any? = Reading::class.java.getDeclaredMethod(name).run {
            isAccessible = true
            invoke(reading)
        }

        fun setField(name: String, value: Any) {
            Reading::class.java.getDeclaredField(name).apply {
                isAccessible = true
                set(reading, value)
            }
        }
    }
}
