package com.newsblur.fragment

import android.widget.RelativeLayout
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.database.StoryViewAdapter
import com.newsblur.databinding.FragmentItemgridBinding
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.clearMocks
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.Before
import org.junit.After

class ItemSetFragmentCommitTest {
    @Before
    fun prepareInterpolators() = mockkConstructor(LinearInterpolator::class, DecelerateInterpolator::class)

    @After
    fun releaseInterpolators() = unmockkConstructor(LinearInterpolator::class, DecelerateInterpolator::class)
    @Test
    fun readerFollowPassesTheLastUnreadWithoutBeingStoppedByTheScrollListener() {
        val fixture = Fixture()
        fixture.startFollowingStory()

        fixture.listener.onScrolled(fixture.grid, 0, 30)

        verify(exactly = 0) { fixture.grid.stopScroll() }
        assertEquals("Following must not consume the user's fling boundary", 5, fixture.fragment.indexOfLastUnread)
    }

    @Test
    fun readerFollowCanReachTheFinalStoryWithoutTheFooterFlingStop() {
        val fixture = Fixture()
        fixture.startFollowingStory()
        every { fixture.layoutManager.findLastCompletelyVisibleItemPosition() } returns 20

        fixture.listener.onScrolled(fixture.grid, 0, 30)

        verify(exactly = 0) { fixture.grid.stopScroll() }
    }

    @Test
    fun userScrollingStillStopsAtTheLastUnreadAfterFollowingEndsOrIsInterrupted() {
        for (nextState in listOf(RecyclerView.SCROLL_STATE_IDLE, RecyclerView.SCROLL_STATE_DRAGGING)) {
            val fixture = Fixture()
            fixture.startFollowingStory()
            fixture.listener.onScrollStateChanged(fixture.grid, nextState)

            fixture.listener.onScrolled(fixture.grid, 0, 30)

            verify(exactly = 1) { fixture.grid.stopScroll() }
            assertEquals(-1, fixture.fragment.indexOfLastUnread)
        }
    }

    @Test
    fun submittingStoriesDoesNotRequestAnotherPageUsingTheOldEmptyAdapter() {
        val fixture = Fixture()
        val stories = listOf(Story().apply { storyHash = "1:cached" })
        ItemSetFragment::class.java.getDeclaredMethod("updateAdapter", List::class.java, Long::class.javaObjectType, Int::class.javaPrimitiveType).apply {
            isAccessible = true
        }.invoke(fixture.fragment, stories, 1L, -1)

        // ItemSetFragment.java must wait for the diff commit before sending a count to SyncServiceState.kt.
        assertTrue("No paging demand before the adapter commit", fixture.fragment.requestedCounts.isEmpty())
    }

    @Test
    fun scrollingDuringAPendingDiffDoesNotReportItsOlderRowCount() {
        val fixture = Fixture()
        every { fixture.adapter.rawStoryCount } returns 30
        every { fixture.adapter.isUpdatingStories } returns true
        fixture.ensureSufficientStories()
        assertTrue(fixture.fragment.requestedCounts.isEmpty())

        every { fixture.adapter.rawStoryCount } returns 2396
        every { fixture.adapter.isUpdatingStories } returns false
        fixture.ensureSufficientStories()
        assertEquals(listOf(2396), fixture.fragment.requestedCounts)
    }

    private class Fixture {
        val fragment = RecordingFragment()
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        val grid = mockk<RecyclerView>(relaxed = true)
        val layoutManager = mockk<GridLayoutManager>(relaxed = true)
        val listener = ItemSetFragment::class.java.getDeclaredField("storyScrollListener").apply { isAccessible = true }
            .get(fragment) as RecyclerView.OnScrollListener

        init {
            val binding = mockk<FragmentItemgridBinding>(relaxed = true)
            FragmentItemgridBinding::class.java.getDeclaredField("itemgridfragmentGrid").apply { isAccessible = true }.set(binding, grid)
            FragmentItemgridBinding::class.java.getDeclaredField("emptyView").apply { isAccessible = true }.set(binding, mockk<RelativeLayout>(relaxed = true))
            setField("adapter", adapter)
            setField("binding", binding)
            setField("layoutManager", layoutManager)
            setField("prefsRepo", mockk<PrefsRepo>(relaxed = true))
        }

        fun startFollowingStory() {
            setField("dataSeenYet", true)
            fragment.indexOfLastUnread = 5
            StoryViewAdapter::class.java.getDeclaredField("stories").apply { isAccessible = true }
                .set(adapter, mutableListOf(Story().apply { storyHash = "1:target" }))
            every { grid.adapter } returns adapter
            every { grid.layoutManager } returns layoutManager
            every { layoutManager.findViewByPosition(any()) } returns null
            every { grid.findViewHolderForAdapterPosition(any()) } returns null
            every { layoutManager.findFirstVisibleItemPosition() } returns 0
            every { layoutManager.findLastVisibleItemPosition() } returns 4
            every { layoutManager.findFirstCompletelyVisibleItemPosition() } returns 3
            every { layoutManager.findLastCompletelyVisibleItemPosition() } returns 7
            every { adapter.storyCount } returns 20
            every { adapter.getDisplayPositionForStoryHash("1:target") } returns 12
            every { adapter.followReadingStory(any(), any()) } answers { callOriginal() }
            every { adapter.isFollowingReadingStory } answers { callOriginal() }
            every { adapter.onStoryListScrollStateChanged(any()) } answers { callOriginal() }
            every { adapter["queueStoryReturn"](any<String>(), any<RecyclerView>(), any<Boolean>(), any<Boolean>()) } answers { callOriginal() }
            every { adapter.applyPendingStoryReturn(any(), any(), any()) } answers { callOriginal() }

            fragment.followReadingStory("1:target")
            verify { layoutManager.startSmoothScroll(match { it.targetPosition == 11 }) }
            listener.onScrollStateChanged(grid, RecyclerView.SCROLL_STATE_SETTLING)
            clearMocks(grid, answers = false, recordedCalls = true)
        }

        fun ensureSufficientStories() {
            ItemSetFragment::class.java.getDeclaredMethod("ensureSufficientStories").apply { isAccessible = true }.invoke(fragment)
        }

        private fun setField(name: String, value: Any) {
            ItemSetFragment::class.java.getDeclaredField(name).apply { isAccessible = true }.set(fragment, value)
        }
    }

    private class RecordingFragment : ItemSetFragment() {
        val requestedCounts = mutableListOf<Int?>()
        override fun getFeedSet(): FeedSet = FeedSet.singleFeed("1")
        override fun triggerRefresh(desiredStoryCount: Int, totalSeen: Int?) { requestedCounts.add(totalSeen) }
    }
}
