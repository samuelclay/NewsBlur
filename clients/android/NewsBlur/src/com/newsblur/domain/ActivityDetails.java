package com.newsblur.domain;

import androidx.annotation.Nullable;

import com.google.gson.annotations.SerializedName;

public class ActivityDetails {

    public Category category;
    public String content;
    public String title;

    @SerializedName("feed_id")
    public String feedId;

    @SerializedName("time_since")
    public String timeSince;

    @Nullable
    @SerializedName("with_user")
    public WithUser user;

    @SerializedName("with_user_id")
    public String withUserId;

    @SerializedName("story_hash")
    public String storyHash;

    public static class WithUser {
        public String username;

        @SerializedName("photo_url")
        public String photoUrl;

    }

    public enum Category {
        @SerializedName("feedsub")
        FEED_SUBSCRIPTION,
        @SerializedName("signup")
        SIGNUP,
        @SerializedName("comment_like")
        COMMENT_LIKE,
        @SerializedName("comment_reply")
        COMMENT_REPLY,
        @SerializedName("sharedstory")
        SHARED_STORY,
        @SerializedName("follow")
        FOLLOW,
        @SerializedName("star")
        STAR,
        @SerializedName("story_reshare")
        STORY_RESHARE,
        @SerializedName("reply_reply")
        REPLY_REPLY
    }
}

