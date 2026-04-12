package com.newsblur.util

import com.newsblur.R
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo

object StoryClusterDisplayDecision {
    const val CLUSTER_MODE_TITLE = "title"
    const val CLUSTER_MODE_RELATED = "related"

    const val DISPLAY_MODE_TITLE_ONLY = "title_only"
    const val DISPLAY_MODE_TITLE_MATCH_ONLY = "title_match_only"
    const val DISPLAY_MODE_TITLE_MATCH_PLUS_RELATED = "title_match_plus_related"

    const val CLUSTER_TIER_TITLE = "title"
    const val CLUSTER_TIER_RELATED = "related"

    fun isStoryClusteringEnabled(prefsRepo: PrefsRepo): Boolean =
        prefsRepo.getBoolean(PrefConstants.STORY_CLUSTERING, true)

    fun clusterMode(prefsRepo: PrefsRepo): String =
        normalizeClusterMode(
            prefsRepo.getString(PrefConstants.CLUSTER_MODE, CLUSTER_MODE_RELATED),
        )

    fun displayMode(prefsRepo: PrefsRepo): String =
        when {
            !isStoryClusteringEnabled(prefsRepo) -> DISPLAY_MODE_TITLE_ONLY
            clusterMode(prefsRepo) == CLUSTER_MODE_TITLE -> DISPLAY_MODE_TITLE_MATCH_ONLY
            else -> DISPLAY_MODE_TITLE_MATCH_PLUS_RELATED
        }

    fun visibleClusterStories(
        clusterStories: Array<Story.ClusterStory>?,
        subscribedFeedIds: Set<String>,
        isPremiumArchive: Boolean,
        clusterMode: String = CLUSTER_MODE_RELATED,
    ): List<Story.ClusterStory> {
        if (clusterStories.isNullOrEmpty()) return emptyList()

        val visibleClusterStories =
            clusterStories
                .filter {
                    normalizeClusterMode(clusterMode) != CLUSTER_MODE_TITLE || normalizeClusterTier(it.clusterTier) == CLUSTER_TIER_TITLE
                }.filter { !it.feedId.isNullOrEmpty() && subscribedFeedIds.contains(it.feedId) }
                .sortedByDescending { it.timestamp }

        return if (isPremiumArchive) {
            visibleClusterStories
        } else {
            visibleClusterStories.take(1)
        }
    }

    fun normalizeClusterTier(clusterTier: String?): String =
        if (clusterTier == CLUSTER_TIER_TITLE) CLUSTER_TIER_TITLE else CLUSTER_TIER_RELATED

    private fun normalizeClusterMode(clusterMode: String?): String =
        if (clusterMode == CLUSTER_MODE_TITLE) CLUSTER_MODE_TITLE else CLUSTER_MODE_RELATED

    fun indicatorDrawableRes(score: Int): Int =
        when {
            score < 0 -> R.drawable.ic_indicator_hidden
            score > 0 -> R.drawable.ic_indicator_focus
            else -> R.drawable.ic_indicator_unread
        }
}
