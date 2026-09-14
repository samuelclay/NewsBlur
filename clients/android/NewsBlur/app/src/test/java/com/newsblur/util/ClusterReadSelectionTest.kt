package com.newsblur.util

import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class ClusterReadSelectionTest {
    private val prefs = mockk<PrefsRepo>(relaxed = true)
    private val parent = Story().apply {
        storyHash = "1:parent"
        clusterStories = arrayOf(
            Story.ClusterStory().apply { storyHash = "2:match"; clusterTier = "title" },
            Story.ClusterStory().apply { storyHash = "3:related"; clusterTier = "related" },
        )
    }

    @Test fun settingOffOnlyMarksParent() {
        assertEquals(listOf("1:parent"), ClusterReadSelection.hashes(parent, prefs))
    }

    @Test fun titleModeOnlyIncludesMatchingTitles() {
        every { prefs.isClusterMarkReadEnabled() } returns true
        every { prefs.getString(PrefConstants.CLUSTER_MODE, any()) } returns "title"
        assertEquals(listOf("1:parent", "2:match"), ClusterReadSelection.hashes(parent, prefs))
    }

    @Test fun relatedModeIncludesAllChildrenRegardlessOfFeedSubscriptionVisibility() {
        every { prefs.isClusterMarkReadEnabled() } returns true
        every { prefs.getString(PrefConstants.CLUSTER_MODE, any()) } returns "related"
        assertEquals(listOf("1:parent", "2:match", "3:related"), ClusterReadSelection.hashes(parent, prefs))
    }
}
