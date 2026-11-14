package com.newsblur.fragment

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Test

class ReaderClusterDetailTest {
    @Test fun detailIncludesMatchedAndRelatedStoriesOutsideSubscriptionsNewestFirst() {
        val fragment = ReadingItemFragment().apply {
            dbHelper = mockk<BlurDatabaseHelper> { every { allActiveFeeds } returns setOf("1") }
            prefsRepo = mockk<PrefsRepo> { every { getString(PrefConstants.CLUSTER_MODE, "related") } returns "title" }
        }
        val story = Story().apply {
            clusterStories = arrayOf(child("1", 100, "title"), child("2", 300, "related"), child("3", 200, "title"))
        }
        assertEquals(listOf("2", "3", "1"), detail(fragment, story, true).map { it.feedId })
        assertEquals(listOf("2"), detail(fragment, story, false).map { it.feedId })
    }

    @Test fun parentReadChangeRefreshesFooterWithoutRebuildingTheHeader() {
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val story = Story().apply { storyHash = "1:parent" }
        fragment.story = story
        ReadingItemFragment::class.java.getDeclaredField("lastMetadataSnapshot").apply {
            isAccessible = true
            set(fragment, ReaderMetadataSnapshot(story))
        }
        story.read = true
        every { fragment["setupItemMetadata"]() } answers { callOriginal() }
        ReadingItemFragment::class.java.getDeclaredMethod("setupItemMetadata").apply {
            isAccessible = true
            invoke(fragment)
        }
        verify(exactly = 1) { fragment["setupClusterStories"]() }
    }

    private fun child(feed: String, time: Long, tier: String) = Story.ClusterStory().apply {
        feedId = feed
        storyHash = "$feed:child"
        timestamp = time
        clusterTier = tier
    }

    @Suppress("UNCHECKED_CAST")
    private fun detail(fragment: ReadingItemFragment, story: Story, archive: Boolean): List<Story.ClusterStory> =
        ReadingItemFragment::class.java.getDeclaredMethod("clusterStoriesForDetail", Story::class.java, Boolean::class.javaPrimitiveType).run {
            isAccessible = true
            invoke(fragment, story, archive) as List<Story.ClusterStory>
        }
}
