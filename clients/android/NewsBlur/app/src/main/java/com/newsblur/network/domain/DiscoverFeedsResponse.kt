package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName
import com.newsblur.domain.DiscoverFeedPayload

class DiscoverFeedsResponse : NewsBlurResponse() {
    @SerializedName("discover_feeds")
    var discoverFeeds: LinkedHashMap<String, DiscoverFeedPayload>? = null
}
