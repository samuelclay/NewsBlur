package com.newsblur.util

import android.content.ContentValues
import android.database.Cursor
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
import com.newsblur.domain.Classifier
import com.newsblur.network.FeedApi
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.CommentResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.NbSyncManager.UPDATE_INTEL
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_SOCIAL
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncServiceState
import com.newsblur.util.ReadingAction.Companion.toJson
import java.io.Serializable

sealed interface ReadingAction : Serializable {
    val time: Long
    val tried: Int

    data class MarkStoryRead(
            val storyHash: String,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class MarkStoryUnread(
            val storyHash: String,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class SaveStory(
            val storyHash: String,
            val highlights: List<String>,
            val userTags: List<String>,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class UnsaveStory(
            val storyHash: String,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class MarkFeedRead(
            val feedSet: FeedSet,
            val olderThan: Long? = null,
            val newerThan: Long? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class ShareStory(
            val storyHash: String? = null,
            val storyId: String? = null,
            val feedId: String? = null,
            val sourceUserId: String? = null,
            val commentReplyText: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class UnshareStory(
            val storyHash: String? = null,
            val storyId: String? = null,
            val feedId: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class LikeComment(
            val storyId: String? = null,
            val commentUserId: String? = null,
            val feedId: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class UnlikeComment(
            val storyId: String? = null,
            val commentUserId: String? = null,
            val feedId: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class ReplyToComment(
            val storyId: String? = null,
            val feedId: String? = null,
            val commentUserId: String? = null,
            val commentReplyText: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class EditReply(
            val storyId: String? = null,
            val feedId: String? = null,
            val commentUserId: String? = null,
            val replyId: String? = null,
            val commentReplyText: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class DeleteReply(
            val storyId: String? = null,
            val feedId: String? = null,
            val commentUserId: String? = null,
            val replyId: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class MuteFeeds(
            val activeFeedIds: Set<String>,
            val modifiedFeedIds: Set<String>,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class UnmuteFeeds(
            val activeFeedIds: Set<String>,
            val modifiedFeedIds: Set<String>,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class SetNotify(
            val feedId: String? = null,
            val notifyTypes: List<String> = emptyList(),
            val notifyFilter: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class InstaFetch(
            val feedId: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class UpdateIntel(
            val feedId: String? = null,
            val classifier: Classifier? = null,
            val feedSet: FeedSet? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    data class RenameFeed(
            val feedId: String? = null,
            val newFeedName: String? = null,
            override val time: Long = System.currentTimeMillis(),
            override val tried: Int = 0,
    ) : ReadingAction

    companion object {

        fun toJson(action: ReadingAction): String =
                gson.toJson(action, ReadingAction::class.java)

        fun fromJson(json: String): ReadingAction =
                gson.fromJson(json, ReadingAction::class.java)

        @JvmStatic
        fun toContentValues(action: ReadingAction): ContentValues = ContentValues().apply {
            put(DatabaseConstants.ACTION_TIME, action.time)
            put(DatabaseConstants.ACTION_TRIED, action.tried)
            put(DatabaseConstants.ACTION_PARAMS, toJson(action))
        }

        fun fromCursor(c: Cursor): ReadingAction {
            val time = c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TIME))
            val tried = c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TRIED))
            val params = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_PARAMS))
            val decoded = fromJson(params)

            return when (decoded) {
                is MarkStoryRead -> decoded.copy(time = time, tried = tried)
                is MarkStoryUnread -> decoded.copy(time = time, tried = tried)
                is SaveStory -> decoded.copy(time = time, tried = tried)
                is UnsaveStory -> decoded.copy(time = time, tried = tried)
                is MarkFeedRead -> decoded.copy(time = time, tried = tried)
                is ShareStory -> decoded.copy(time = time, tried = tried)
                is UnshareStory -> decoded.copy(time = time, tried = tried)
                is LikeComment -> decoded.copy(time = time, tried = tried)
                is UnlikeComment -> decoded.copy(time = time, tried = tried)
                is ReplyToComment -> decoded.copy(time = time, tried = tried)
                is EditReply -> decoded.copy(time = time, tried = tried)
                is DeleteReply -> decoded.copy(time = time, tried = tried)
                is MuteFeeds -> decoded.copy(time = time, tried = tried)
                is UnmuteFeeds -> decoded.copy(time = time, tried = tried)
                is SetNotify -> decoded.copy(time = time, tried = tried)
                is InstaFetch -> decoded.copy(time = time, tried = tried)
                is UpdateIntel -> decoded.copy(time = time, tried = tried)
                is RenameFeed -> decoded.copy(time = time, tried = tried)
            }
        }

        private val gson: Gson by lazy {
            val factory = RuntimeTypeAdapterFactory
                    .of(ReadingAction::class.java, "type")
                    .registerSubtype(MarkStoryRead::class.java, "MARK_READ_STORY")
                    .registerSubtype(MarkStoryUnread::class.java, "MARK_UNREAD_STORY")
                    .registerSubtype(MarkFeedRead::class.java, "MARK_READ_FEED")
                    .registerSubtype(SaveStory::class.java, "SAVE_STORY")
                    .registerSubtype(UnsaveStory::class.java, "UNSAVE_STORY")
                    .registerSubtype(ShareStory::class.java, "SHARE")
                    .registerSubtype(UnshareStory::class.java, "UNSHARE")
                    .registerSubtype(LikeComment::class.java, "LIKE_COMMENT")
                    .registerSubtype(UnlikeComment::class.java, "UNLIKE_COMMENT")
                    .registerSubtype(ReplyToComment::class.java, "REPLY")
                    .registerSubtype(EditReply::class.java, "EDIT_REPLY")
                    .registerSubtype(DeleteReply::class.java, "DELETE_REPLY")
                    .registerSubtype(MuteFeeds::class.java, "MUTE_FEEDS")
                    .registerSubtype(UnmuteFeeds::class.java, "UNMUTE_FEEDS")
                    .registerSubtype(SetNotify::class.java, "SET_NOTIFY")
                    .registerSubtype(InstaFetch::class.java, "INSTA_FETCH")
                    .registerSubtype(UpdateIntel::class.java, "UPDATE_INTEL")
                    .registerSubtype(RenameFeed::class.java, "RENAME_FEED")

            GsonBuilder()
                    .registerTypeAdapterFactory(factory)
                    .disableHtmlEscaping()
                    .create()
        }
    }
}

fun ReadingAction.toContentValues(): ContentValues = ContentValues().apply {
    put(DatabaseConstants.ACTION_TIME, time)
    put(DatabaseConstants.ACTION_TRIED, tried)
    put(DatabaseConstants.ACTION_PARAMS, toJson(this@toContentValues))
}

suspend fun ReadingAction.doRemote(
        syncServiceState: SyncServiceState,
        feedApi: FeedApi,
        storyApi: StoryApi,
        dbHelper: BlurDatabaseHelper,
        stateFilter: StateFilter
): NewsBlurResponse? {
    var result: NewsBlurResponse? = null
    var impact = 0

    suspend fun applyStoriesResponse(sr: StoriesResponse?) {
        if (sr != null) {
            result = sr
            if (sr.story != null) {
                dbHelper.updateStory(sr, stateFilter, true)
            } else {
                Log.w(this, "failed to refresh story data after action")
            }
            impact = impact or UPDATE_SOCIAL
        }
    }

    suspend fun applyCommentResponse(cr: CommentResponse?, storyId: String?) {
        if (cr != null) {
            result = cr
            if (cr.comment != null && storyId != null) {
                dbHelper.updateComment(cr, storyId)
            } else {
                Log.w(this, "failed to refresh comment data after action")
            }
            impact = impact or UPDATE_SOCIAL
        }
    }

    when (this) {
        // MARK_READ (story)
        is ReadingAction.MarkStoryRead ->
            result = storyApi.markStoryAsRead(storyHash)

        is ReadingAction.MarkStoryUnread ->
            result = storyApi.markStoryHashUnread(storyHash)

        is ReadingAction.SaveStory ->
            result = storyApi.markStoryAsStarred(storyHash, highlights, userTags)

        is ReadingAction.UnsaveStory ->
            result = storyApi.markStoryAsUnstarred(storyHash)

        // MARK_READ (feed range)
        is ReadingAction.MarkFeedRead ->
            result = feedApi.markFeedsAsRead(feedSet, olderThan, newerThan)

        is ReadingAction.ShareStory -> {
            val sr = storyApi.shareStory(storyId, feedId, commentReplyText, sourceUserId)
            applyStoriesResponse(sr)
        }

        is ReadingAction.UnshareStory -> {
            val sr = storyApi.unshareStory(storyId, feedId)
            applyStoriesResponse(sr)
        }

        is ReadingAction.LikeComment ->
            result = storyApi.favouriteComment(storyId, commentUserId, feedId)

        is ReadingAction.UnlikeComment ->
            result = storyApi.unFavouriteComment(storyId, commentUserId, feedId)

        is ReadingAction.ReplyToComment -> {
            val cr = storyApi.replyToComment(storyId, feedId, commentUserId, commentReplyText)
            applyCommentResponse(cr, storyId)
        }

        is ReadingAction.EditReply -> {
            val cr = storyApi.editReply(storyId, feedId, commentUserId, replyId, commentReplyText)
            applyCommentResponse(cr, storyId)
        }

        is ReadingAction.DeleteReply -> {
            val cr = storyApi.deleteReply(storyId, feedId, commentUserId, replyId)
            applyCommentResponse(cr, storyId)
        }

        is ReadingAction.MuteFeeds ->
            result = feedApi.saveFeedChooser(activeFeedIds)

        is ReadingAction.UnmuteFeeds ->
            result = feedApi.saveFeedChooser(activeFeedIds)

        is ReadingAction.SetNotify ->
            result = feedApi.updateFeedNotifications(feedId, notifyTypes, notifyFilter)

        is ReadingAction.InstaFetch -> {
            result = feedApi.instaFetch(feedId)
            feedId?.let {
                syncServiceState.addRecountCandidate(FeedSet.singleFeed(it))
                syncServiceState.flushRecounts()
            }
        }

        is ReadingAction.UpdateIntel -> {
            result = feedApi.updateFeedIntel(feedId, classifier)
            feedSet?.let { fs ->
                syncServiceState.resetFetchState(fs)
                syncServiceState.addRecountCandidate(fs)
            }
        }

        is ReadingAction.RenameFeed ->
            result = feedApi.renameFeed(feedId, newFeedName)
    }

    if (result != null && impact != 0) {
        result!!.impactCode = impact
    }

    return result
}

// TODO suspend
fun ReadingAction.doLocal(
        dbHelper: BlurDatabaseHelper,
        prefsRepo: PrefsRepo
): Int = doLocal(dbHelper, prefsRepo, isFollowup = false)

fun ReadingAction.doLocal(
        dbHelper: BlurDatabaseHelper,
        prefsRepo: PrefsRepo,
        isFollowup: Boolean
): Int {
    val userId = prefsRepo.getUserId()
    var impact = 0

    fun plus(flag: Int) {
        impact = impact or flag
    }

    when (this) {

        // MARK_READ (story)
        is ReadingAction.MarkStoryRead -> {
            dbHelper.setStoryReadState(storyHash, true)
            plus(UPDATE_METADATA)
            plus(UPDATE_STORY)
        }

        is ReadingAction.MarkStoryUnread -> {
            dbHelper.setStoryReadState(storyHash, false)
            plus(UPDATE_METADATA)
        }

        is ReadingAction.SaveStory -> {
            dbHelper.setStoryStarred(storyHash, highlights, userTags, true)
            plus(UPDATE_METADATA)
        }

        is ReadingAction.UnsaveStory -> {
            dbHelper.setStoryStarred(storyHash, emptyList(), emptyList(), false)
            plus(UPDATE_METADATA)
        }

        is ReadingAction.MarkFeedRead -> {
            dbHelper.markStoriesRead(feedSet, olderThan, newerThan)
            dbHelper.updateLocalFeedCounts(feedSet)
            plus(UPDATE_METADATA)
            plus(UPDATE_STORY)
        }

        is ReadingAction.ShareStory -> {
            if (!isFollowup) {
                // shares are only placeholders
                dbHelper.setStoryShared(storyHash, userId, true)
                dbHelper.insertCommentPlaceholder(storyId, userId, commentReplyText)
                plus(UPDATE_SOCIAL)
                plus(UPDATE_STORY)
            }
        }

        is ReadingAction.UnshareStory -> {
            dbHelper.setStoryShared(storyHash, userId, false)
            dbHelper.clearSelfComments(storyId, userId)
            plus(UPDATE_SOCIAL)
            plus(UPDATE_STORY)
        }

        is ReadingAction.LikeComment -> {
            dbHelper.setCommentLiked(storyId, commentUserId, userId, true)
            plus(UPDATE_SOCIAL)
        }

        is ReadingAction.UnlikeComment -> {
            dbHelper.setCommentLiked(storyId, commentUserId, userId, false)
            plus(UPDATE_SOCIAL)
        }

        is ReadingAction.ReplyToComment -> {
            if (!isFollowup) {
                dbHelper.insertReplyPlaceholder(storyId, userId, commentUserId, commentReplyText)
            }
        }

        is ReadingAction.EditReply -> {
            dbHelper.editReply(replyId, commentReplyText)
            plus(UPDATE_SOCIAL)
        }

        is ReadingAction.DeleteReply -> {
            dbHelper.deleteReply(replyId)
            plus(UPDATE_SOCIAL)
        }

        is ReadingAction.MuteFeeds -> {
            dbHelper.setFeedsActive(modifiedFeedIds, false)
            plus(UPDATE_METADATA)
        }

        is ReadingAction.UnmuteFeeds -> {
            dbHelper.setFeedsActive(modifiedFeedIds, true)
            plus(UPDATE_METADATA)
        }

        is ReadingAction.SetNotify -> {
            plus(UPDATE_METADATA)
        }

        // INSTA_FETCH: non-idempotent & purely graphical
        is ReadingAction.InstaFetch -> {
            if (!isFollowup && feedId != null) {
                dbHelper.setFeedFetchPending(feedId)
            }
        }

        is ReadingAction.UpdateIntel -> {
            dbHelper.clearClassifiersForFeed(feedId)
            classifier?.let { cls ->
                cls.feedId = feedId
                dbHelper.insertClassifier(cls)
            }
            plus(UPDATE_INTEL)
        }

        is ReadingAction.RenameFeed -> {
            dbHelper.renameFeed(feedId, newFeedName)
            plus(UPDATE_METADATA)
        }
    }

    return impact
}


