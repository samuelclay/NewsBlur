package com.newsblur.domain

data class SavedStoryCountsQueryResult(
    val starredCountsByTag: List<StarredCount>,
    val feedSavedCounts: Map<String, Int>,
    val savedStoriesTotalCount: Int? = null,
)
