package com.newsblur.network

import android.content.ContentValues
import android.net.Uri
import androidx.core.net.toUri
import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.CommentResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.StarredStoryHashesResponse
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.StoryChangesResponse
import com.newsblur.network.domain.StoryTextResponse
import com.newsblur.network.domain.UnreadStoryHashesResponse
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.ReadTimeTracker
import com.newsblur.util.StoryOrder
import com.newsblur.widget.WidgetUtils
import java.lang.Boolean
import kotlin.IllegalStateException
import kotlin.Int
import kotlin.String
import kotlin.apply

class StoryApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
    private val readTimeTracker: ReadTimeTracker,
) : StoryApi {
    override suspend fun getStories(
        fs: FeedSet,
        pageNumber: Int,
        order: StoryOrder,
        filter: ReadFilter,
        infrequentCutoff: Int,
    ): StoriesResponse? {
        val uri: Uri
        val values = ValueMultimap()

        // create the URI and populate request params depending on what kind of stories we want
        if (fs.isForWidget) {
            uri = APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES).toUri()
            for (feedId in fs.allFeeds) values.put(APIConstants.PARAMETER_FEEDS, feedId)
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_FALSE)
            values.put(APIConstants.PARAMETER_INFREQUENT, APIConstants.VALUE_FALSE)
            values.put(APIConstants.PARAMETER_LIMIT, WidgetUtils.STORIES_LIMIT.toString())
        } else if (fs.getSingleFeed() != null) {
            uri =
                APIConstants
                    .buildUrl(APIConstants.PATH_FEED_STORIES)
                    .toUri()
                    .buildUpon()
                    .appendPath(fs.getSingleFeed())
                    .build()
            values.put(APIConstants.PARAMETER_FEEDS, fs.getSingleFeed())
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE)
            if (fs.isFilterSaved) values.put(APIConstants.PARAMETER_READ_FILTER, APIConstants.VALUE_STARRED)
        } else if (fs.multipleFeeds != null) {
            uri = APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES).toUri()
            for (feedId in fs.multipleFeeds) values.put(APIConstants.PARAMETER_FEEDS, feedId)
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE)
            if (fs.isFilterSaved) values.put(APIConstants.PARAMETER_READ_FILTER, APIConstants.VALUE_STARRED)
        } else if (fs.singleSocialFeed != null) {
            val feedId = fs.singleSocialFeed.key
            val username = fs.singleSocialFeed.value
            uri =
                APIConstants
                    .buildUrl(
                        APIConstants.PATH_SOCIALFEED_STORIES,
                    ).toUri()
                    .buildUpon()
                    .appendPath(feedId)
                    .appendPath(username)
                    .build()
            values.put(APIConstants.PARAMETER_USER_ID, feedId)
            values.put(APIConstants.PARAMETER_USERNAME, username)
        } else if (fs.multipleSocialFeeds != null) {
            uri = APIConstants.buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES).toUri()
            for (entry in fs.multipleSocialFeeds.entries) {
                values.put(APIConstants.PARAMETER_FEEDS, entry.key)
            }
        } else if (fs.isInfrequent) {
            uri = APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES).toUri()
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE)
            values.put(APIConstants.PARAMETER_INFREQUENT, infrequentCutoff.toString())
        } else if (fs.isAllNormal) {
            uri = APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES).toUri()
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE)
        } else if (fs.isAllSocial) {
            uri = APIConstants.buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES).toUri()
        } else if (fs.isAllRead) {
            uri = APIConstants.buildUrl(APIConstants.PATH_READ_STORIES).toUri()
        } else if (fs.isAllSaved) {
            uri = APIConstants.buildUrl(APIConstants.PATH_STARRED_STORIES).toUri()
        } else if (fs.getSingleSavedTag() != null) {
            uri = APIConstants.buildUrl(APIConstants.PATH_STARRED_STORIES).toUri()
            values.put(APIConstants.PARAMETER_TAG, fs.getSingleSavedTag())
        } else if (fs.isGlobalShared) {
            uri = APIConstants.buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES).toUri()
            values.put(APIConstants.PARAMETER_GLOBAL_FEED, Boolean.TRUE.toString())
        } else {
            throw IllegalStateException("Asked to get stories for FeedSet of unknown type.")
        }

        // request params common to most story sets
        values.put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber.toString())
        if (!(fs.isAllRead || fs.isAllSaved || fs.isFilterSaved)) {
            values.put(APIConstants.PARAMETER_READ_FILTER, filter.parameterValue)
        }
        if (!fs.isAllRead) {
            values.put(APIConstants.PARAMETER_ORDER, order.parameterValue)
        }
        if (fs.searchQuery != null) {
            values.put(APIConstants.PARAMETER_QUERY, fs.searchQuery)
        }

        val response: APIResponse = networkClient.get(uri.toString(), values)
        return response.getResponse<StoriesResponse?>(gson, StoriesResponse::class.java)
    }

    override suspend fun getStoryText(
        feedId: String?,
        storyId: String,
    ): StoryTextResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_FEEDID, feedId)
                put(APIConstants.PARAMETER_STORYID, storyId)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_STORY_TEXT)
        val response: APIResponse = networkClient.get(urlString, values)
        return if (!response.isError) {
            response.getResponse(gson, StoryTextResponse::class.java)
        } else {
            null
        }
    }

    override suspend fun getStoryChanges(
        storyHash: String?,
        showChanges: kotlin.Boolean,
    ): StoryChangesResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORY_HASH, storyHash)
                put(APIConstants.PARAMETER_SHOW_CHANGES, if (showChanges) APIConstants.VALUE_TRUE else APIConstants.VALUE_FALSE)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_STORY_CHANGES)
        val response: APIResponse = networkClient.get(urlString, values)
        return response.getResponse(gson, StoryChangesResponse::class.java)
    }

    override suspend fun markStoryHashUnread(hash: String?): NewsBlurResponse? {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_STORY_HASH, hash)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_STORY_HASH_UNREAD)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun markStoryAsUnstarred(storyHash: String?): NewsBlurResponse? {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_STORY_HASH, storyHash)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_STORY_AS_UNSTARRED)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun getUnreadStoryHashes(): UnreadStoryHashesResponse {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_INCLUDE_TIMESTAMPS, "1")
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_UNREAD_HASHES)
        val response: APIResponse = networkClient.get(urlString, values)
        return response.getResponse(gson, UnreadStoryHashesResponse::class.java)
    }

    override suspend fun getStarredStoryHashes(): StarredStoryHashesResponse {
        val urlString = APIConstants.buildUrl(APIConstants.PATH_STARRED_STORY_HASHES)
        val response: APIResponse = networkClient.get(urlString)
        return response.getResponse(gson, StarredStoryHashesResponse::class.java)
    }

    override suspend fun getStoriesByHash(storyHashes: List<String>): StoriesResponse? {
        val values =
            ValueMultimap().apply {
                for (hash in storyHashes) {
                    put(APIConstants.PARAMETER_H, hash)
                }
                put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES)
        val response: APIResponse = networkClient.get(urlString, values)
        return response.getResponse(gson, StoriesResponse::class.java)
    }

    override suspend fun markStoryAsRead(storyHash: String): NewsBlurResponse? {
        val readTimesJson = readTimeTracker.consumeQueuedReadTimesJSON()
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_STORY_HASH, storyHash)
                if (readTimesJson != null) {
                    put(APIConstants.PARAMETER_READ_TIMES, readTimesJson)
                }
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_STORIES_READ)
        val response: APIResponse = networkClient.post(urlString, values)
        val result = response.getResponse<NewsBlurResponse?>(gson, NewsBlurResponse::class.java)
        if ((result == null || result.isError) && readTimesJson != null) {
            readTimeTracker.restoreQueuedReadTimes(readTimesJson)
        }
        return result
    }

    override suspend fun markStoryAsStarred(
        storyHash: String,
        highlights: List<String>,
        userTags: List<String>,
    ): NewsBlurResponse? {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_STORY_HASH, storyHash)
                for (tag in userTags) {
                    put(APIConstants.PARAMETER_USER_TAGS, tag)
                }
                for (highlight in highlights) {
                    put(APIConstants.PARAMETER_HIGHLIGHTS, highlight)
                }
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_STORY_AS_STARRED)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun saveExternalStory(
        storyTitle: String,
        storyUrl: String,
    ): APIResponse {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_TITLE, storyTitle)
                put(APIConstants.PARAMETER_STORY_URL, storyUrl)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SAVE_EXTERNAL_STORY)
        return networkClient.post(urlString, values)
    }

    override suspend fun shareExternalStory(
        storyTitle: String,
        storyUrl: String,
        shareComments: String,
    ): APIResponse {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_TITLE, storyTitle)
                put(APIConstants.PARAMETER_STORY_URL, storyUrl)
                put(APIConstants.PARAMETER_SHARE_COMMENT, shareComments)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SHARE_EXTERNAL_STORY)
        return networkClient.post(urlString, values)
    }

    override suspend fun shareStory(
        storyId: String?,
        feedId: String?,
        comment: String?,
        sourceUserId: String?,
    ): StoriesResponse? {
        val values =
            ContentValues().apply {
                if (!comment.isNullOrEmpty()) {
                    put(APIConstants.PARAMETER_SHARE_COMMENT, comment)
                }
                if (!sourceUserId.isNullOrEmpty()) {
                    put(APIConstants.PARAMETER_SHARE_SOURCEID, sourceUserId)
                }

                put(APIConstants.PARAMETER_FEEDID, feedId)
                put(APIConstants.PARAMETER_STORYID, storyId)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SHARE_STORY)
        val response: APIResponse = networkClient.post(urlString, values)
        // this call returns a new copy of the story with all fields updated and some metadata
        return response.getResponse(gson, StoriesResponse::class.java)
    }

    override suspend fun unshareStory(
        storyId: String?,
        feedId: String?,
    ): StoriesResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_FEEDID, feedId)
                put(APIConstants.PARAMETER_STORYID, storyId)
            }

        val urlString = APIConstants.buildUrl(APIConstants.PATH_UNSHARE_STORY)
        val response: APIResponse = networkClient.post(urlString, values)
        // this call returns a new copy of the story with all fields updated and some metadata
        return response.getResponse<StoriesResponse?>(gson, StoriesResponse::class.java)
    }

    override suspend fun favouriteComment(
        storyId: String?,
        commentUserId: String?,
        feedId: String?,
    ): NewsBlurResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORYID, storyId)
                put(APIConstants.PARAMETER_STORY_FEEDID, feedId)
                put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_LIKE_COMMENT)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse<NewsBlurResponse?>(gson, NewsBlurResponse::class.java)
    }

    override suspend fun unFavouriteComment(
        storyId: String?,
        commentUserId: String?,
        feedId: String?,
    ): NewsBlurResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORYID, storyId)
                put(APIConstants.PARAMETER_STORY_FEEDID, feedId)
                put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_UNLIKE_COMMENT)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun replyToComment(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        reply: String?,
    ): CommentResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORYID, storyId)
                put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId)
                put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId)
                put(APIConstants.PARAMETER_REPLY_TEXT, reply)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_REPLY_TO)
        val response: APIResponse = networkClient.post(urlString, values)
        // this call returns a new copy of the comment with all fields updated
        return response.getResponse(gson, CommentResponse::class.java)
    }

    override suspend fun editReply(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        replyId: String?,
        reply: String?,
    ): CommentResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORYID, storyId)
                put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId)
                put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId)
                put(APIConstants.PARAMETER_REPLY_ID, replyId)
                put(APIConstants.PARAMETER_REPLY_TEXT, reply)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_EDIT_REPLY)
        val response: APIResponse = networkClient.post(urlString, values)
        // this call returns a new copy of the comment with all fields updated
        return response.getResponse(gson, CommentResponse::class.java)
    }

    override suspend fun deleteReply(
        storyId: String?,
        storyFeedId: String?,
        commentUserId: String?,
        replyId: String?,
    ): CommentResponse? {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_STORYID, storyId)
                put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId)
                put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId)
                put(APIConstants.PARAMETER_REPLY_ID, replyId)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_DELETE_REPLY)
        val response: APIResponse = networkClient.post(urlString, values)
        // this call returns a new copy of the comment with all fields updated
        return response.getResponse(gson, CommentResponse::class.java)
    }
}
