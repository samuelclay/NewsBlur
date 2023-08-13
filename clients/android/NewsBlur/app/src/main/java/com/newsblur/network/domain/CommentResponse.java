package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

import com.newsblur.domain.Comment;
import com.newsblur.domain.UserProfile;

/**
 * API response binding for APIs that vend an updated Comment object.
 */
public class CommentResponse extends NewsBlurResponse {
    
    @SerializedName("comment")
    public Comment comment;
    
    @SerializedName("user_profiles")
    public UserProfile[] users;
    
}
