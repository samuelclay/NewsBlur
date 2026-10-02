package com.newsblur.fragment

import android.widget.RelativeLayout
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.database.StoryViewAdapter
import com.newsblur.databinding.FragmentItemgridBinding
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ItemSetFragmentCommitTest {
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

        init {
            val binding = mockk<FragmentItemgridBinding>(relaxed = true)
            val grid = mockk<RecyclerView>(relaxed = true)
            FragmentItemgridBinding::class.java.getDeclaredField("itemgridfragmentGrid").apply { isAccessible = true }.set(binding, grid)
            FragmentItemgridBinding::class.java.getDeclaredField("emptyView").apply { isAccessible = true }.set(binding, mockk<RelativeLayout>(relaxed = true))
            setField("adapter", adapter)
            setField("binding", binding)
            setField("layoutManager", mockk<GridLayoutManager>(relaxed = true))
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
