package com.newsblur.repository

import com.newsblur.domain.Story

interface StoryRepository {
    // TODO suspend once UI supports it
    fun likeComment(
        story: Story,
        commentUserId: String?,
    )

    // TODO suspend once UI supports it
    fun unlikeComment(
        story: Story,
        commentUserId: String?,
    )

    suspend fun shareStory(
        story: Story,
        comment: String,
        sourceUserIdString: String?,
    )

    suspend fun unshareStory(story: Story)

    suspend fun setStoryReadStateExternal(
        storyHash: String,
        read: Boolean,
    )
}
