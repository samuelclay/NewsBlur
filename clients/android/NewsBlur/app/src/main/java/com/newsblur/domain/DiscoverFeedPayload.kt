package com.newsblur.domain

import com.google.gson.annotations.SerializedName

data class DiscoverFeedPayload(
    @SerializedName("feed")
    val feed: Feed,
    @SerializedName("stories")
    val stories: List<DiscoverStory> = emptyList(),
)
