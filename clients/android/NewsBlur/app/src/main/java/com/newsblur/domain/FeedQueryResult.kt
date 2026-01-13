package com.newsblur.domain

data class FeedQueryResult(
    val feeds: LinkedHashMap<String, Feed>,
    val feedNeutCounts: Map<String, Int>,
    val feedPosCounts: Map<String, Int>,
    val totalNeutCount: Int,
    val totalPosCount: Int,
    val totalActiveFeedCount: Int,
)
