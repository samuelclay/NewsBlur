package com.newsblur.util

import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo

object ClusterReadSelection {
    fun hashes(story: Story, prefs: PrefsRepo): List<String> {
        if (!prefs.isClusterMarkReadEnabled()) return listOf(story.storyHash)
        val titleOnly = StoryClusterDisplayDecision.clusterMode(prefs) == StoryClusterDisplayDecision.CLUSTER_MODE_TITLE
        return (listOf(story.storyHash) + story.clusterStories.orEmpty().filter {
            !titleOnly || StoryClusterDisplayDecision.normalizeClusterTier(it.clusterTier) == StoryClusterDisplayDecision.CLUSTER_TIER_TITLE
        }.mapNotNull { it.storyHash?.takeIf(String::isNotBlank) }).distinct()
    }
}
