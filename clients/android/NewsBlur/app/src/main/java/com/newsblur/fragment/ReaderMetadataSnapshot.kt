package com.newsblur.fragment

import com.newsblur.domain.Story
import com.newsblur.util.PrefConstants.ThemeValue

// ReadingItemFragment.kt caches the footer independently so parent read updates don't rebuild the article header.
internal data class ReaderClusterSnapshot(
    val storyHash: String?,
    val clusters: List<List<Any?>>,
    val archive: Boolean,
    val theme: ThemeValue,
) {
    constructor(story: Story, archive: Boolean, theme: ThemeValue) : this(
        storyHash = story.storyHash,
        clusters = ReaderMetadataSnapshot(story).clusters,
        archive = archive,
        theme = theme,
    )
}

/** Fields that require rebuilding ReadingItemFragment.kt's title, tags, and related-story section. */
internal data class ReaderMetadataSnapshot(
    val title: String?,
    val authors: String?,
    val timestamp: Long,
    val tags: List<String>,
    val userTags: List<String>,
    val starred: Boolean,
    val starredTimestamp: Long,
    val hasModifications: Boolean,
    val clusters: List<List<Any?>>,
) {
    constructor(story: Story) : this(
        title = story.title,
        authors = story.authors,
        timestamp = story.timestamp,
        tags = story.tags?.toList().orEmpty(),
        userTags = story.userTags?.toList().orEmpty(),
        starred = story.starred,
        starredTimestamp = story.starredTimestamp,
        hasModifications = story.hasModifications,
        clusters =
            story.clusterStories.orEmpty().map { cluster ->
                listOf(
                    cluster.storyHash,
                    cluster.feedId,
                    cluster.title,
                    cluster.authors,
                    cluster.timestamp,
                    cluster.read,
                    cluster.score,
                    cluster.clusterTier,
                    cluster.imageUrls?.toList(),
                    cluster.secureImageThumbnails?.toMap(),
                )
            },
    )
}
