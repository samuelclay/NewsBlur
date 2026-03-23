package com.newsblur.domain

import com.google.gson.annotations.SerializedName

data class DiscoverStory(
    @SerializedName("story_hash")
    val storyHash: String,
    @SerializedName("story_title")
    val storyTitle: String = "",
    @SerializedName("story_authors")
    val storyAuthors: String = "",
    @SerializedName("story_date")
    val storyDate: String? = null,
    @SerializedName("story_permalink")
    val storyPermalink: String = "",
    @SerializedName("image_urls")
    val imageUrls: List<String> = emptyList(),
)
