package com.newsblur.util

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.newsblur.domain.Classifier
import com.newsblur.util.ReadingAction.DeleteReply
import com.newsblur.util.ReadingAction.EditReply
import com.newsblur.util.ReadingAction.InstaFetch
import com.newsblur.util.ReadingAction.LikeComment
import com.newsblur.util.ReadingAction.MarkFeedRead
import com.newsblur.util.ReadingAction.MarkStoryRead
import com.newsblur.util.ReadingAction.MarkStoryUnread
import com.newsblur.util.ReadingAction.MuteFeeds
import com.newsblur.util.ReadingAction.RenameFeed
import com.newsblur.util.ReadingAction.ReplyToComment
import com.newsblur.util.ReadingAction.SaveStory
import com.newsblur.util.ReadingAction.SetNotify
import com.newsblur.util.ReadingAction.ShareStory
import com.newsblur.util.ReadingAction.UnlikeComment
import com.newsblur.util.ReadingAction.UnmuteFeeds
import com.newsblur.util.ReadingAction.UnsaveStory
import com.newsblur.util.ReadingAction.UnshareStory
import com.newsblur.util.ReadingAction.UpdateIntel

object ReadingActions {
    fun markStoryRead(hash: String) = MarkStoryRead(hash)

    fun markStoryUnread(hash: String) = MarkStoryUnread(hash)

    fun saveStory(
            hash: String,
            highlights: List<String>,
            userTags: List<String>,
    ) = SaveStory(hash, highlights, userTags)

    fun unsaveStory(hash: String) = UnsaveStory(hash)

    fun markFeedRead(
            fs: FeedSet,
            older: Long?,
            newer: Long?,
    ) = MarkFeedRead(fs, older, newer)

    fun shareStory(
            hash: String?,
            storyId: String?,
            feedId: String?,
            sourceUserId: String?,
            text: String?,
    ) = ShareStory(hash, storyId, feedId, sourceUserId, text)

    fun unshareStory(
            hash: String?,
            storyId: String?,
            feedId: String?,
    ) = UnshareStory(hash, storyId, feedId)

    fun likeComment(
            storyId: String?,
            userId: String?,
            feedId: String?,
    ) = LikeComment(storyId, userId, feedId)

    fun unlikeComment(
            storyId: String?,
            userId: String?,
            feedId: String?,
    ) = UnlikeComment(storyId, userId, feedId)

    fun replyToComment(
            storyId: String?,
            feedId: String?,
            userId: String?,
            text: String?,
    ) = ReplyToComment(storyId, feedId, userId, text)

    fun updateReply(
            storyId: String?,
            feedId: String?,
            userId: String?,
            replyId: String?,
            text: String?,
    ) = EditReply(storyId, feedId, userId, replyId, text)

    fun deleteReply(
            storyId: String?,
            feedId: String?,
            userId: String?,
            replyId: String?,
    ) = DeleteReply(storyId, feedId, userId, replyId)

    fun muteFeeds(
            active: Set<String>,
            modified: Set<String>,
    ) = MuteFeeds(active, modified)

    fun unmuteFeeds(
            active: Set<String>,
            modified: Set<String>,
    ) = UnmuteFeeds(active, modified)

    fun setNotify(
            feedId: String?,
            notifyTypes: List<String>?,
            filter: String?,
    ) = SetNotify(feedId, notifyTypes ?: emptyList(), filter)

    fun instaFetch(feedId: String?) = InstaFetch(feedId)

    fun updateIntel(
            feedId: String?,
            classifier: Classifier?,
            fs: FeedSet?,
    ) = UpdateIntel(feedId, classifier, fs)

    fun renameFeed(
            feedId: String?,
            newName: String?,
    ) = RenameFeed(feedId, newName)

    val gson: Gson by lazy {
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