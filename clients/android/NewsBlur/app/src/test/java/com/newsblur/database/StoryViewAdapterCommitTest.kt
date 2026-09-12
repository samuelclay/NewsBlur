package com.newsblur.database

import android.os.Parcelable
import android.os.SystemClock
import android.view.View
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
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
        every { SystemClock.elapsedRealtime() } returns 0L
        every { android.util.Log.d(any(), any()) } returns 0
        try {
            test(Fixture(this))
        } finally {
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
            every { adapter.submitStories(any(), any(), any(), any(), any(), any()) } answers { callOriginal() }
            every { adapter.updateFeedSet(any()) } answers { callOriginal() }
            every { adapter.clearStoriesNow() } answers { callOriginal() }
            every { adapter.notifyAllItemsChanged() } answers { callOriginal() }
            every { adapter.onDetachedFromRecyclerView(any()) } answers { callOriginal() }
            every { adapter.rawStoryCount } answers { callOriginal() }
            every { adapter.itemCount } answers { callOriginal() }
            every { adapter.setPendingScrollStoryHash(any()) } answers { callOriginal() }
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
                    builds.add(incoming.single().storyHash)
                    onBuild(incoming)
                }
                shape
            }
            adapter.updateFeedSet(FeedSet.singleFeed("1"))
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
