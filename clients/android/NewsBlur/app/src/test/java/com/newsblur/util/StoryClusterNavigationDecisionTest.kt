package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryClusterNavigationDecisionTest {
    @Test
    fun routes_same_feed_cluster_story_directly_to_reading() {
        val decision =
            StoryClusterNavigationDecision.resolve(
                currentFeedSet = FeedSet.singleFeed("1"),
                currentFolderName = AppConstants.ROOT_FOLDER,
                targetFeedId = "1",
                storyHash = "1:cluster-story",
            )

        assertTrue(decision is StoryClusterNavigationTarget.DirectReading)
        decision as StoryClusterNavigationTarget.DirectReading
        assertEquals("1", decision.feedSet.singleFeed)
        assertEquals("1:cluster-story", decision.storyHash)
    }

    @Test
    fun routes_cross_feed_cluster_story_through_feed_list() {
        val decision =
            StoryClusterNavigationDecision.resolve(
                currentFeedSet = FeedSet.singleFeed("1"),
                currentFolderName = AppConstants.ROOT_FOLDER,
                targetFeedId = "2",
                storyHash = "2:cluster-story",
            )

        assertTrue(decision is StoryClusterNavigationTarget.FeedListReading)
        decision as StoryClusterNavigationTarget.FeedListReading
        assertEquals("2", decision.feedSet.singleFeed)
        assertEquals(AppConstants.ROOT_FOLDER, decision.folderName)
        assertEquals("2:cluster-story", decision.storyHash)
    }
}
