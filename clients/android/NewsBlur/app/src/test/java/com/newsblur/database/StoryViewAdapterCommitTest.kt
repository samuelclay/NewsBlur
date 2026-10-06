package com.newsblur.database

import android.os.Parcelable
import android.os.SystemClock
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearSmoothScroller
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.clearMocks
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class StoryViewAdapterCommitTest {
    @Test
    fun followingAPartlyClippedRowRepositionsItNearTheTopInBothDirections() = runTest {
        for ((position, top, bottom) in listOf(Triple(5, 820, 940), Triple(0, 60, 180))) {
            withFixture { fixture ->
                fixture.submitRows(20)
                runCurrent()
                fixture.followViewport(0, 5)
                fixture.attachRow(position, top, bottom)

                fixture.adapter.followReadingStory("1:row$position", fixture.grid)

                fixture.assertSmoothTarget((position - 1).coerceAtLeast(0))
            }
        }
    }

    @Test
    fun followingWithFourVisibleRowsTargetsTheSelectedRowItself() = runTest {
        withFixture { fixture ->
            fixture.submitRows(20)
            runCurrent()
            fixture.followViewport(2, 5)
            fixture.attachRow(5, 820, 940)

            fixture.adapter.followReadingStory("1:row5", fixture.grid)

            fixture.assertSmoothTarget(5)
        }
    }

    @Test
    fun severalFullyContainedSelectionsKeepTheTitlesStill() = runTest {
        withFixture { fixture ->
            fixture.submitRows(20)
            runCurrent()
            fixture.followViewport(2, 7)
            for (position in 3..5) {
                fixture.attachRow(position, 140 + (position - 3) * 160, 280 + (position - 3) * 160)
                fixture.adapter.followReadingStory("1:row$position", fixture.grid)
            }

            verify(exactly = 0) { fixture.layoutManager.startSmoothScroll(any()) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(any(), any()) }
            verify(exactly = 0) { fixture.grid.smoothScrollToPosition(any()) }
        }
    }

    @Test
    fun followingAnUnattachedRowUsesAnAnimatedTopSnapWithOnePrecedingRow() = runTest {
        withFixture { fixture ->
            fixture.submitRows(20)
            runCurrent()
            fixture.followViewport(0, 4)

            fixture.adapter.followReadingStory("1:row8", fixture.grid)

            val scroller = fixture.assertSmoothTarget(7)
            // StoryViewAdapterCommitTest.kt runs the native final action after the target is laid out.
            val targetRow = fixture.attachRow(7, 900, 1060)
            RecyclerView.SmoothScroller::class.java.getDeclaredField("mLayoutManager").apply { isAccessible = true }
                .set(scroller, fixture.layoutManager)
            val action = RecyclerView.SmoothScroller.Action(0, 0)
            LinearSmoothScroller::class.java.getDeclaredMethod(
                "onTargetFound", View::class.java, RecyclerView.State::class.java, RecyclerView.SmoothScroller.Action::class.java,
            ).apply { isAccessible = true }.invoke(scroller, targetRow, mockk<RecyclerView.State>(), action)

            assertEquals("The target's decorated top must move from 900 to the viewport top at 100", 800, action.dy)
            assertTrue("The native final alignment must animate", action.duration > 0)
            assertEquals("Do not jump to the selected row", -1, RecyclerView.SmoothScroller.Action::class.java
                .getDeclaredField("mJumpToPosition").apply { isAccessible = true }.getInt(action))
        }
    }

    @Test
    fun followingAnOffscreenStoryScrollsSmoothlyInsteadOfJumping() = runTest {
        withFixture { fixture ->
            fixture.submit("1:reading", 1)
            runCurrent()
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 10
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 15
            clearMocks(fixture.layoutManager, answers = false, recordedCalls = true)

            fixture.adapter.followReadingStory("1:reading", fixture.grid)

            fixture.assertSmoothTarget(0)
        }
    }

    @Test
    fun followingAVisibleStoryCancelsThePreviousScrollWithoutMovingTheList() = runTest {
        withFixture { fixture ->
            fixture.submit("1:reading", 1)
            runCurrent()
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 0
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 5
            every { fixture.grid.height } returns 1000
            fixture.attachRow(0, 100, 200)
            clearMocks(fixture.layoutManager, answers = false, recordedCalls = true)

            fixture.adapter.followReadingStory("1:reading", fixture.grid)

            verify(exactly = 1) { fixture.grid.stopScroll() }
            verify(exactly = 0) { fixture.grid.smoothScrollToPosition(any()) }
            verify(exactly = 0) { fixture.layoutManager.startSmoothScroll(any()) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(any(), any()) }
        }
    }

    @Test
    fun reversingToAVisibleStoryStopsTheOlderOffscreenScroll() = runTest {
        withFixture { fixture ->
            fixture.showRelatedRow = true
            fixture.submit("1:reading", 1)
            runCurrent()
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 0
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 0
            every { fixture.grid.height } returns 1000
            fixture.attachRow(0, 100, 200)
            clearMocks(fixture.layoutManager, answers = false, recordedCalls = true)

            fixture.adapter.followReadingStory("2:related", fixture.grid)
            fixture.adapter.followReadingStory("1:reading", fixture.grid)

            verify(exactly = 2) { fixture.grid.stopScroll() }
            fixture.assertSmoothTarget(1)
            verify(exactly = 0) { fixture.grid.smoothScrollToPosition(0) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(any(), any()) }
        }
    }

    @Test
    fun followingRapidStoryChangesDuringADiffOnlyScrollsToTheLatestSelection() = runTest {
        withFixture { fixture ->
            fixture.submit("1:old", 1)
            runCurrent()
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 10
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 15
            clearMocks(fixture.layoutManager, answers = false, recordedCalls = true)
            fixture.submit("1:new", 2)

            fixture.adapter.followReadingStory("1:old", fixture.grid)
            fixture.adapter.followReadingStory("1:new", fixture.grid)
            verify(exactly = 0) { fixture.grid.smoothScrollToPosition(any()) }
            runCurrent()

            verify(exactly = 2) { fixture.grid.stopScroll() }
            fixture.assertSmoothTarget(0)
        }
    }

    @Test
    fun followingBeforeTheInitialLoadStillPositionsTheListImmediately() = runTest {
        withFixture { fixture ->
            fixture.adapter.followReadingStory("1:reading", fixture.grid)
            fixture.submit("1:reading", 1)
            runCurrent()

            verify(exactly = 1) { fixture.layoutManager.scrollToPositionWithOffset(0, 0) }
            verify(exactly = 0) { fixture.grid.smoothScrollToPosition(any()) }
        }
    }

    @Test
    fun anIdenticalRefreshSchedulesPresentationAfterReturnWaitedForTheDiff() = runTest {
        withFixture { fixture ->
            fixture.submit("1:already-read", 1)
            runCurrent()
            fixture.showBoundStory("1:already-read")

            fixture.submit("1:already-read", 2)
            fixture.adapter.requestStoryReturn("1:already-read", fixture.grid, true)
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
            clearMocks(fixture.grid, answers = false, recordedCalls = true)

            runCurrent()

            verify(atLeast = 1) { fixture.grid.invalidate() }
        }
    }

    @Test
    fun returningAfterTheLastCommitScrollsImmediatelyAndWaitsForVisiblePresentationToFade() = runTest {
        withFixture { fixture ->
            fixture.submit("1:last-viewed", 1)
            runCurrent()
            fixture.showBoundStory("1:last-viewed")
            every { fixture.grid.height } returns 1000
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 10
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 15
            every { fixture.grid.hasWindowFocus() } returns false

            fixture.adapter.requestStoryReturn("1:last-viewed", fixture.grid, false)
            verify { fixture.layoutManager.scrollToPositionWithOffset(0, 150) }
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }

            every { fixture.grid.hasWindowFocus() } returns true
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }

            fixture.adapter.requestStoryReturn("1:last-viewed", fixture.grid, true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 1) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
        }
    }

    @Test
    fun highlightingWaitsForTheCorrectHolderAfterLayoutAndLaterBatches() = runTest {
        withFixture { fixture ->
            fixture.adapter.requestStoryReturn("1:last-viewed", fixture.grid, true)
            fixture.submit("1:earlier-page", 1)
            runCurrent()
            fixture.submit("1:last-viewed", 2)
            runCurrent()
            val holder = fixture.showBoundStory("1:earlier-page")
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }

            every { holder.story } returns Story().apply { storyHash = "1:last-viewed" }
            every { fixture.grid.isLayoutRequested } returns true
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
            every { fixture.grid.isLayoutRequested } returns false
            fixture.adapter.applyPendingStoryReturn(fixture.grid, presentationFrame = true)
            verify(exactly = 1) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
        }
    }

    @Test
    fun aCoveredStoryListDoesNotStartTheReturnHighlightFade() = runTest {
        withFixture { fixture ->
            every { fixture.grid.hasWindowFocus() } returns false
            fixture.adapter.setPendingHighlightStoryHash("1:last-viewed")
            fixture.submit("1:last-viewed", 1)
            runCurrent()

            verify(exactly = 0) { fixture.adapter["animateReturnHighlight"](fixture.grid, 0) }
        }
    }

    @Test
    fun aPartialBatchDoesNotLoseTheReturnedStoryBeforeItsPageArrives() = runTest {
        withFixture { fixture ->
            fixture.adapter.setPendingScrollStoryHash("1:last-viewed")
            fixture.adapter.setPendingHighlightStoryHash("1:last-viewed")
            fixture.submit("1:earlier-page", 1)
            runCurrent()
            every { fixture.grid.height } returns 1000
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 10
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 15
            fixture.submit("1:last-viewed", 2)
            runCurrent()

            verify(exactly = 1) { fixture.layoutManager.scrollToPositionWithOffset(0, 150) }
        }
    }

    @Test
    fun firstStoriesReplaceTheFooterAnchorWithTheTopStoryOnlyOnce() = runTest {
        withFixture { fixture ->
            assertEquals("The empty list already contains a full-height footer", 1, fixture.adapter.itemCount)
            assertEquals(0, fixture.adapter.rawStoryCount)
            fixture.submit("1:first", 1)
            runCurrent()
            fixture.submit("1:updated", 2)
            runCurrent()

            verify(exactly = 1) { fixture.layoutManager.scrollToPositionWithOffset(0, 0) }
        }
    }

    @Test
    fun anExplicitSavedPositionTakesPriorityOverTheInitialFooterAnchor() = runTest {
        withFixture { fixture ->
            val state = mockk<Parcelable>()
            fixture.submit("1:first", 1, state)
            runCurrent()

            verify(exactly = 1) { fixture.layoutManager.onRestoreInstanceState(state) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(any(), any()) }
        }
    }

    @Test
    fun anEmptyPrimingBatchDoesNotConsumeExplicitRestorationBeforeStoriesArrive() = runTest {
        withFixture { fixture ->
            val state = mockk<Parcelable>()
            fixture.adapter.submitStories(emptyList(), 0, fixture.grid, state, false, null)
            runCurrent()
            verify(exactly = 0) { fixture.layoutManager.onRestoreInstanceState(state) }

            fixture.submit("1:first", 1)
            runCurrent()
            verify(exactly = 1) { fixture.layoutManager.onRestoreInstanceState(state) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(0, 0) }
        }
    }

    @Test
    fun aReturnedStoryTargetUsesItsOwnOffsetEvenWhenTheOldFooterOccupiedItsPosition() = runTest {
        withFixture { fixture ->
            fixture.adapter.setPendingScrollStoryHash("1:first")
            every { fixture.grid.height } returns 1000
            every { fixture.layoutManager.findFirstVisibleItemPosition() } returns 0
            every { fixture.layoutManager.findLastVisibleItemPosition() } returns 0
            fixture.submit("1:first", 1)
            runCurrent()

            verify(exactly = 1) { fixture.layoutManager.scrollToPositionWithOffset(0, 150) }
            verify(exactly = 0) { fixture.layoutManager.scrollToPositionWithOffset(0, 0) }
        }
    }

    @Test
    fun refreshesWhileTheFirstDiffIsRunningCommitThatSnapshotThenTheNewestPendingOne() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    // StoryViewAdapter.kt can receive several batches before an expensive initial diff commits.
                    fixture.submit("1:middle", 2)
                    fixture.submit("1:last", 3)
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals(listOf("1:first", "1:last"), fixture.commits)
            assertEquals(listOf("1:first", "1:last"), fixture.builds)
            assertEquals(listOf(true, false), fixture.pendingAtCommit)
            assertEquals(1, fixture.adapter.rawStoryCount)
        }
    }

    @Test
    fun aSupersededBatchDoesNotLoseItsExplicitScrollRestoration() = runTest {
        withFixture { fixture ->
            val state = mockk<Parcelable>()
            val layoutManager = fixture.grid.layoutManager!!
            val pendingAtRestoration = mutableListOf<Boolean>()
            every { layoutManager.onRestoreInstanceState(state) } answers {
                pendingAtRestoration.add(fixture.adapter.isUpdatingStories)
            }
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    fixture.submit("1:middle", 2, state)
                    fixture.submit("1:last", 3)
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            verify(exactly = 1) { layoutManager.onRestoreInstanceState(state) }
            assertEquals("An older partial snapshot must not consume a pending saved position", listOf(false), pendingAtRestoration)
            assertEquals(listOf("1:first", "1:last"), fixture.commits)
        }
    }

    @Test
    fun rebuildingTheRowStyleDuringAnInitialDiffKeepsTheBatchAndUsesTheNewShape() = runTest {
        withFixture { fixture ->
            var changedStyle = false
            fixture.onBuild = {
                if (!changedStyle) {
                    changedStyle = true
                    fixture.showRelatedRow = true
                    fixture.adapter.notifyAllItemsChanged()
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals("The pending first batch must survive the synchronous row rebuild", listOf("1:first"), fixture.commits)
            assertEquals("The older row shape must not overwrite the new related-story preference", 2, fixture.items.size)
        }
    }

    @Test
    fun rebuildingTheRowStyleRetainsOnlyTheNewestQueuedBatch() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    fixture.submit("1:middle", 2)
                    fixture.submit("1:last", 3)
                    fixture.showRelatedRow = true
                    fixture.adapter.notifyAllItemsChanged()
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals(listOf("1:last"), fixture.commits)
            assertEquals(listOf("1:first", "1:last"), fixture.builds)
            assertEquals(2, fixture.items.size)
            assertFalse(fixture.adapter.isUpdatingStories)
        }
    }

    @Test
    fun equivalentFolderFeedSetsDoNotCancelAnActiveDiffWhenTheirIdOrderChanges() = runTest {
        withFixture { fixture ->
            fixture.adapter.updateFeedSet(FeedSet.folder("Folder", linkedSetOf("1", "2")))
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    fixture.adapter.updateFeedSet(FeedSet.folder("Folder", linkedSetOf("2", "1")))
                    fixture.submit("1:last", 2)
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals(listOf("1:first", "1:last"), fixture.commits)
        }
    }

    @Test
    fun changingFeedInvalidatesTheRunningDiffAndItsCommitCallback() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    fixture.adapter.updateFeedSet(FeedSet.singleFeed("2"))
                    fixture.submit("2:next", 2)
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals(listOf("2:next"), fixture.commits)
            assertFalse(fixture.adapter.isUpdatingStories)
        }
    }

    @Test
    fun resettingDuringADiffKeepsTheListEmptyAndDoesNotRunItsCommitCallback() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { fixture.adapter.clearStoriesNow() }
            fixture.submit("1:first", 1)
            runCurrent()

            assertTrue(fixture.commits.isEmpty())
            assertEquals(0, fixture.adapter.rawStoryCount)
            assertFalse(fixture.adapter.isUpdatingStories)
        }
    }

    @Test
    fun aReplacedRecyclerViewDoesNotReceiveAnOldCommitCallback() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { every { fixture.grid.adapter } returns null }
            fixture.submit("1:first", 1)
            runCurrent()

            assertTrue(fixture.commits.isEmpty())
            assertEquals(0, fixture.adapter.rawStoryCount)
        }
    }

    @Test
    fun detachingCancelsTheOldDiffWithoutDisablingTheReusedAdapter() = runTest {
        withFixture { fixture ->
            fixture.onBuild = { incoming ->
                if (incoming.single().storyHash == "1:first") {
                    fixture.adapter.onDetachedFromRecyclerView(fixture.grid)
                    fixture.submit("1:reattached", 2)
                }
            }
            fixture.submit("1:first", 1)
            runCurrent()

            assertEquals(listOf("1:reattached"), fixture.commits)
            assertFalse(fixture.adapter.isUpdatingStories)
        }
    }

    private fun TestScope.withFixture(test: (Fixture) -> Unit) {
        mockkStatic(SystemClock::class, android.util.Log::class)
        mockkConstructor(LinearInterpolator::class, DecelerateInterpolator::class)
        every { SystemClock.elapsedRealtime() } returns 0L
        every { android.util.Log.d(any(), any()) } returns 0
        try {
            test(Fixture(this))
        } finally {
            unmockkConstructor(LinearInterpolator::class, DecelerateInterpolator::class)
            unmockkStatic(SystemClock::class, android.util.Log::class)
        }
    }

    private class Fixture(scope: TestScope) {
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        val grid = mockk<RecyclerView>(relaxed = true)
        val layoutManager = mockk<GridLayoutManager>(relaxed = true)
        val commits = mutableListOf<String>()
        val builds = mutableListOf<String>()
        val pendingAtCommit = mutableListOf<Boolean>()
        val items = mutableListOf<StoryViewAdapter.DisplayItem>()
        var showRelatedRow = false
        var onBuild: (List<Story>) -> Unit = {}

        init {
            setField("returnPresentationReady", true)
            setField("adapterScope", scope.backgroundScope)
            setField("diffDispatcher", StandardTestDispatcher(scope.testScheduler))
            setField("clusterThumbnailUrls", mutableMapOf<String, String?>())
            setField("stories", mutableListOf<Story>())
            setField("displayItems", items)
            setField("storyDisplayPositions", mutableListOf<Int>())
            setField("footerViews", mutableListOf(mockk<View>(relaxed = true)))
            setField("titleCache", StoryTitleCache { it })
            every { grid.adapter } returns adapter
            every { grid.layoutManager } returns layoutManager
            every { grid.context.resources.displayMetrics } returns mockk<android.util.DisplayMetrics>(relaxed = true).apply { densityDpi = 160 }
            every { layoutManager.findViewByPosition(any()) } returns null
            every { adapter.submitStories(any(), any(), any(), any(), any(), any()) } answers { callOriginal() }
            every { adapter.updateFeedSet(any()) } answers { callOriginal() }
            every { adapter.clearStoriesNow() } answers { callOriginal() }
            every { adapter.notifyAllItemsChanged() } answers { callOriginal() }
            every { adapter.onDetachedFromRecyclerView(any()) } answers { callOriginal() }
            every { adapter.rawStoryCount } answers { callOriginal() }
            every { adapter.itemCount } answers { callOriginal() }
            every { adapter.applyPendingStoryReturn(any(), any(), any()) } answers { callOriginal() }
            every { adapter.requestStoryReturn(any(), any(), any()) } answers { callOriginal() }
            every { adapter.followReadingStory(any(), any()) } answers { callOriginal() }
            every { adapter["queueStoryReturn"](any<String>(), any<RecyclerView>(), any<Boolean>(), any<Boolean>()) } answers { callOriginal() }
            every { adapter["boundStoryHash"](any<RecyclerView.ViewHolder>()) } answers { callOriginal() }
            every { adapter.setPendingScrollStoryHash(any()) } answers { callOriginal() }
            every { adapter.setPendingHighlightStoryHash(any()) } answers { callOriginal() }
            every { adapter.getDisplayPositionForStoryHash(any()) } answers { callOriginal() }
            every { adapter.isUpdatingStories } answers { callOriginal() }
            every { adapter["invalidateStoryDiffs"]() } answers { callOriginal() }
            every { adapter["newDiffRunner"]() } answers { callOriginal() }
            every { adapter["calculateStoryDiff"](any<StoryViewAdapter.StorySubmission>()) } answers { callOriginal() }
            every { adapter["commitStoryDiff"](any<StoryViewAdapter.StoryDifference>()) } answers { callOriginal() }
            every { adapter["rebuildDisplayItemsFromCurrentStories"]() } answers { callOriginal() }
            every { adapter["visibleDisplayItemCount"]() } answers { items.size }
            every { adapter["applySkipBackfill"](any<List<Story>>(), any<Boolean>()) } answers { firstArg<List<Story>>() }
            every { adapter["buildDisplayItems"](any<List<Story>>()) } answers {
                val incoming = firstArg<List<Story>>()
                val shape = incoming.flatMapIndexed { index, story ->
                    val rows = mutableListOf<StoryViewAdapter.DisplayItem>(StoryViewAdapter.DisplayItem.StoryRow(story, index))
                    if (showRelatedRow) {
                        val related = Story.ClusterStory().apply { storyHash = "2:related"; feedId = "2"; title = "Related" }
                        rows.add(StoryViewAdapter.DisplayItem.ClusterRow(related, index, story.storyHash))
                    }
                    rows
                }
                if (incoming.isNotEmpty()) {
                    builds.add(incoming.first().storyHash)
                    onBuild(incoming)
                }
                shape
            }
            adapter.updateFeedSet(FeedSet.singleFeed("1"))
        }

        fun submitRows(count: Int) {
            val stories = (0 until count).map { Story().apply { storyHash = "1:row$it"; feedId = "1"; title = storyHash; sharedUserIds = emptyArray() } }
            adapter.submitStories(stories, 1, grid, null, false, null)
        }

        fun followViewport(first: Int, last: Int) {
            every { grid.height } returns 1000
            every { grid.paddingTop } returns 100
            every { grid.paddingBottom } returns 100
            every { layoutManager.height } returns 1000
            every { layoutManager.paddingTop } returns 100
            every { layoutManager.paddingBottom } returns 100
            every { layoutManager.canScrollVertically() } returns true
            every { layoutManager.findFirstVisibleItemPosition() } returns first
            every { layoutManager.findLastVisibleItemPosition() } returns last
            every { layoutManager.findViewByPosition(any()) } returns null
            every { grid.context.resources.displayMetrics } returns mockk<android.util.DisplayMetrics>(relaxed = true).apply { densityDpi = 160 }
            clearMocks(layoutManager, answers = false, recordedCalls = true)
        }

        fun attachRow(position: Int, top: Int, bottom: Int): View {
            val row = mockk<View>(relaxed = true)
            every { row.layoutParams } returns mockk<RecyclerView.LayoutParams>(relaxed = true)
            every { layoutManager.findViewByPosition(position) } returns row
            every { layoutManager.getDecoratedTop(row) } returns top
            every { layoutManager.getDecoratedBottom(row) } returns bottom
            return row
        }

        fun assertSmoothTarget(position: Int): LinearSmoothScroller {
            val captured = slot<RecyclerView.SmoothScroller>()
            verify(exactly = 1) { layoutManager.startSmoothScroll(capture(captured)) }
            verify(exactly = 0) { layoutManager.scrollToPositionWithOffset(any(), any()) }
            verify(exactly = 0) { grid.smoothScrollToPosition(any()) }
            assertEquals(position, captured.captured.targetPosition)
            val scroller = captured.captured as LinearSmoothScroller
            assertEquals(LinearSmoothScroller.SNAP_TO_START, LinearSmoothScroller::class.java
                .getDeclaredMethod("getVerticalSnapPreference").apply { isAccessible = true }.invoke(scroller))
            return scroller
        }

        fun showBoundStory(hash: String): StoryViewAdapter.StoryViewHolder {
            val holder = mockk<StoryViewAdapter.StoryViewHolder>(relaxed = true)
            val row = mockk<View>(relaxed = true)
            RecyclerView.ViewHolder::class.java.getDeclaredField("itemView").apply {
                isAccessible = true
                set(holder, row)
            }
            every { holder.story } returns Story().apply { storyHash = hash }
            every { grid.findViewHolderForAdapterPosition(0) } returns holder
            every { row.isLaidOut } returns true
            every { grid.hasWindowFocus() } returns true
            every { grid.isShown } returns true
            return holder
        }

        fun submit(hash: String, loadId: Long, scrollState: Parcelable? = null) {
            val story = Story().apply {
                storyHash = hash
                feedId = hash.substringBefore(':')
                title = hash
                sharedUserIds = emptyArray()
            }
            adapter.submitStories(listOf(story), loadId, grid, scrollState, false, Runnable {
                commits.add(hash)
                pendingAtCommit.add(adapter.isUpdatingStories)
            })
        }

        private fun setField(name: String, value: Any) {
            StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
        }
    }
}
