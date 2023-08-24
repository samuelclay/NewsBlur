package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName

data class StarredStoryHashesResponse(
        @SerializedName("starred_story_hashes")
        val starredStoryHashes: Set<String> = HashSet()) : NewsBlurResponse()