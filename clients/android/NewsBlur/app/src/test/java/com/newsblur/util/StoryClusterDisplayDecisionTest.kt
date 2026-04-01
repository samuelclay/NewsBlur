package com.newsblur.util

import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryClusterDisplayDecisionTest {
    @Test
    fun filters_to_subscribed_feeds_and_sorts_newest_first() {
        val clusterStories =
            arrayOf(
                clusterStory(feedId = "2", timestamp = 2_000L),
                clusterStory(feedId = "3", timestamp = 3_000L),
                clusterStory(feedId = "1", timestamp = 1_000L),
            )

        val visible =
            StoryClusterDisplayDecision.visibleClusterStories(
                clusterStories = clusterStories,
                subscribedFeedIds = setOf("1", "3"),
                isPremiumArchive = true,
            )

        assertEquals(listOf("3", "1"), visible.map { it.feedId })
    }

    @Test
    fun limits_to_one_cluster_story_for_non_archive_users() {
        val visible =
            StoryClusterDisplayDecision.visibleClusterStories(
                clusterStories =
                    arrayOf(
                        clusterStory(feedId = "1", timestamp = 1_000L),
                        clusterStory(feedId = "2", timestamp = 2_000L),
                    ),
                subscribedFeedIds = setOf("1", "2"),
                isPremiumArchive = false,
            )

        assertEquals(listOf("2"), visible.map { it.feedId })
    }

    @Test
    fun story_clustering_preference_defaults_to_enabled() {
        val prefsRepo = mockk<PrefsRepo>()
        every { prefsRepo.getBoolean(PrefConstants.STORY_CLUSTERING, true) } returns true

        assertTrue(StoryClusterDisplayDecision.isStoryClusteringEnabled(prefsRepo))
    }

    @Test
    fun story_clustering_preference_can_be_disabled() {
        val prefsRepo = mockk<PrefsRepo>()
        every { prefsRepo.getBoolean(PrefConstants.STORY_CLUSTERING, true) } returns false

        assertFalse(StoryClusterDisplayDecision.isStoryClusteringEnabled(prefsRepo))
    }

    private fun clusterStory(
        feedId: String,
        timestamp: Long,
    ): Story.ClusterStory =
        Story.ClusterStory().apply {
            this.feedId = feedId
            this.timestamp = timestamp
        }
}
