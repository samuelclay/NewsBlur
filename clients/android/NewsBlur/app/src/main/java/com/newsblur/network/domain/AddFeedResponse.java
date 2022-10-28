package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

import com.newsblur.domain.Feed;

public class AddFeedResponse extends NewsBlurResponse {
    
    @SerializedName("feed")
    public Feed feed;
    
}
