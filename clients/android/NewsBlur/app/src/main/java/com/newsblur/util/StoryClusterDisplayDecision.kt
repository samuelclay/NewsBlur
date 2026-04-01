package com.newsblur.util

import com.newsblur.R
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo

object StoryClusterDisplayDecision {
    fun isStoryClusteringEnabled(prefsRepo: PrefsRepo): Boolean =
        prefsRepo.getBoolean(PrefConstants.STORY_CLUSTERING, true)

    fun visibleClusterStories(
        clusterStories: Array<Story.ClusterStory>?,
        subscribedFeedIds: Set<String>,
        isPremiumArchive: Boolean,
    ): List<Story.ClusterStory> {
        if (clusterStories.isNullOrEmpty()) return emptyList()

        val visibleClusterStories =
            clusterStories
                .filter { !it.feedId.isNullOrEmpty() && subscribedFeedIds.contains(it.feedId) }
                .sortedByDescending { it.timestamp }

        return if (isPremiumArchive) {
            visibleClusterStories
        } else {
            visibleClusterStories.take(1)
        }
    }

    fun indicatorDrawableRes(score: Int): Int =
        when {
            score < 0 -> R.drawable.ic_indicator_hidden
            score > 0 -> R.drawable.ic_indicator_focus
            else -> R.drawable.ic_indicator_unread
        }
}
