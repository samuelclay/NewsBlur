package com.newsblur.network

import com.newsblur.network.domain.CommentResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.StarredStoryHashesResponse
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.StoryChangesResponse
import com.newsblur.network.domain.StoryTextResponse
import com.newsblur.network.domain.UnreadStoryHashesResponse
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryOrder

interface StoryApi {
    suspend fun getStories(
        fs: FeedSet,
        pageNumber: Int,
        order: StoryOrder,
        filter: ReadFilter,
        infrequentCutoff: Int,
    ): StoriesResponse?

    suspend fun getStoryText(
        feedId: String?,
        storyId: String,
    ): StoryTextResponse?

    suspend fun getStoryChanges(
        storyHash: String?,
        showChanges: Boolean,
    ): StoryChangesResponse?

    suspend fun markStoryHashUnread(hash: String?): NewsBlurResponse?

    suspend fun markStoryAsUnstarred(storyHash: String?): NewsBlurResponse?

    suspend fun getUnreadStoryHashes(): UnreadStoryHashesResponse

    suspend fun getStarredStoryHashes(): StarredStoryHashesResponse

    suspend fun getStoriesByHash(storyHashes: List<String>): StoriesResponse?

    suspend fun markStoryAsRead(storyHash: String): NewsBlurResponse?

    suspend fun markStoryAsStarred(
        storyHash: String,
        highlights: List<String>,
        userTags: List<String>,
    ): NewsBlurResponse?

    suspend fun shareStory(
        storyId: String?,
        feedId: String?,
        comment: String?,
        sourceUserId: String?,
    ): StoriesResponse?

    suspend fun unshareStory(
        storyId: String?,
        feedId: String?,
    ): StoriesResponse?

    suspend fun favouriteComment(
        storyId: String?,
        commentUserId: String?,
        feedId: String?,
    ): NewsBlurResponse?

    suspend fun unFavouriteComment(
        storyId: String?,
        commentUserId: String?,
        feedId: String?,
    ): NewsBlurResponse?

    suspend fun replyToComment(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        reply: String?,
    ): CommentResponse?

    suspend fun editReply(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        replyId: String?,
        reply: String?,
    ): CommentResponse?

    suspend fun deleteReply(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        replyId: String?,
    ): CommentResponse?

    suspend fun saveExternalStory(
        storyTitle: String,
        storyUrl: String,
    ): APIResponse

    suspend fun shareExternalStory(
        storyTitle: String,
        storyUrl: String,
        shareComments: String,
    ): APIResponse
}
