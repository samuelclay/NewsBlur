package com.newsblur.domain

import com.google.gson.annotations.SerializedName
import com.newsblur.network.APIConstants

data class FeedResult(
    @SerializedName("id")
    val id: Int = 0,
    @SerializedName("tagline")
    val tagline: String? = null,
    @SerializedName(value = "label", alternate = ["feed_title"])
    val label: String,
    @SerializedName("num_subscribers")
    val numberOfSubscriber: Int = 0,
    @SerializedName(value = "value", alternate = ["feed_address"])
    val url: String,
    @SerializedName("last_story_seconds_ago")
    val lastStorySecondsAgo: Long? = null,
) {
    val faviconUrl: String
        get() = "${APIConstants.buildUrl(APIConstants.PATH_FEED_FAVICON_URL)}$id"

    companion object {
        fun createFeedResultForUrl(url: String) =
            FeedResult(
                id = -1,
                tagline = "Add feed manually by URL",
                label = url,
                url = url,
            )
    }
}
