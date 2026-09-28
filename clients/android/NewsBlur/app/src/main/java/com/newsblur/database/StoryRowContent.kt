package com.newsblur.database

import com.newsblur.domain.Story

// StoryViewAdapter.kt retains values, rather than mutable Story references, when diffing rows.
internal data class StoryRowContent(
    val title: String?,
    val authors: String?,
    val preview: String?,
    val timestamp: Long,
    val thumbnail: String?,
    val feedId: String?,
    val feedTitle: String?,
    val feedColor: String?,
    val feedFade: String?,
    val favicon: String?,
    val score: Int,
    val starred: Boolean,
    val sharedUserIds: List<String>,
    val briefingSummary: Boolean,
) {
    constructor(story: Story) : this(
        story.title,
        story.authors,
        story.shortContent,
        story.timestamp,
        story.thumbnailUrl,
        story.feedId,
        story.extern_feedTitle,
        story.extern_feedColor,
        story.extern_feedFade,
        story.extern_faviconUrl,
        story.extern_intelTotalScore,
        story.starred,
        story.sharedUserIds?.toList().orEmpty(),
        story.isBriefingSummary,
    )
}

internal data class ClusterRowContent(
    val title: String?,
    val timestamp: Long,
    val feedId: String?,
    val score: Int,
    val tier: String?,
    val thumbnail: String?,
) {
    constructor(story: Story.ClusterStory) : this(
        story.title,
        story.timestamp,
        story.feedId,
        story.score,
        story.clusterTier,
        story.thumbnailUrl,
    )
}
