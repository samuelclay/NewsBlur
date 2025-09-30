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

    // TODO suspend
    fun getStories(
            fs: FeedSet,
            pageNumber: Int,
            order: StoryOrder,
            filter: ReadFilter,
            infrequentCutoff: Int,
    ): StoriesResponse?

    suspend fun getStoryText(feedId: String?, storyId: String): StoryTextResponse?

    suspend fun getStoryChanges(storyHash: String?, showChanges: Boolean): StoryChangesResponse?

    // TODO suspend
    fun markStoryHashUnread(hash: String?): NewsBlurResponse?

    // TODO suspend
    fun markStoryAsUnstarred(storyHash: String?): NewsBlurResponse?

    // TODO suspend
    fun getUnreadStoryHashes(): UnreadStoryHashesResponse

    // TODO suspend
    fun getStarredStoryHashes(): StarredStoryHashesResponse

    // TODO suspend
    fun getStoriesByHash(storyHashes: List<String>): StoriesResponse?

    // TODO suspend
    fun markStoryAsRead(storyHash: String): NewsBlurResponse?

    // TODO suspend
    fun markStoryAsStarred(storyHash: String, highlights: List<String>, userTags: List<String>): NewsBlurResponse?

    // TODO suspend
    fun shareStory(storyId: String?, feedId: String?, comment: String?, sourceUserId: String?): StoriesResponse?

    // TODO suspend
    fun unshareStory(storyId: String?, feedId: String?): StoriesResponse?

    // TODO suspend
    fun favouriteComment(storyId: String?, commentUserId: String?, feedId: String?): NewsBlurResponse?

    // TODO suspend
    fun unFavouriteComment(storyId: String?, commentUserId: String?, feedId: String?): NewsBlurResponse?

    // TODO suspend
    fun replyToComment(storyId: String?, storyFeedId: String?, commentUserId: String?, reply: String?): CommentResponse?

    // TODO suspend
    fun editReply(storyId: String?, storyFeedId: String?, commentUserId: String?, replyId: String?, reply: String?): CommentResponse?

    // TODO suspend
    fun deleteReply(storyId: String?, storyFeedId: String?, commentUserId: String?, replyId: String?): CommentResponse?

    suspend fun saveExternalStory(storyTitle: String, storyUrl: String): APIResponse

    suspend fun shareExternalStory(storyTitle: String, storyUrl: String, shareComments: String): APIResponse
}