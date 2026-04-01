package com.newsblur.util

sealed interface StoryClusterNavigationTarget {
    data class DirectReading(
        val feedSet: FeedSet,
        val storyHash: String,
    ) : StoryClusterNavigationTarget

    data class FeedListReading(
        val feedSet: FeedSet,
        val folderName: String,
        val storyHash: String,
    ) : StoryClusterNavigationTarget
}

object StoryClusterNavigationDecision {
    fun resolve(
        currentFeedSet: FeedSet?,
        currentFolderName: String?,
        targetFeedId: String?,
        storyHash: String?,
    ): StoryClusterNavigationTarget? {
        if (targetFeedId.isNullOrBlank() || storyHash.isNullOrBlank()) return null

        val targetFeedSet = FeedSet.singleFeed(targetFeedId)
        if (currentFeedSet == targetFeedSet) {
            return StoryClusterNavigationTarget.DirectReading(
                feedSet = targetFeedSet,
                storyHash = storyHash,
            )
        }

        val folderName =
            when {
                currentFeedSet?.isFolder == true -> currentFeedSet.folderName ?: AppConstants.ROOT_FOLDER
                !currentFolderName.isNullOrBlank() -> currentFolderName
                else -> AppConstants.ROOT_FOLDER
            }

        return StoryClusterNavigationTarget.FeedListReading(
            feedSet = targetFeedSet,
            folderName = folderName,
            storyHash = storyHash,
        )
    }
}
