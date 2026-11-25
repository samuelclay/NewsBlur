package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName
import com.newsblur.domain.StarredCount

/** apps/reader/views.py starred_counts: the saved story total and per-tag/per-feed counts. */
data class StarredCountsResponse(
    @SerializedName("starred_count")
    val starredCount: Int = 0,
    @SerializedName("starred_counts")
    val starredCounts: List<StarredCount> = emptyList(),
) : NewsBlurResponse()
