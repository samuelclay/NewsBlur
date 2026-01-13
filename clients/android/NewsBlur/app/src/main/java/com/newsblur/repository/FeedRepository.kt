package com.newsblur.repository

interface FeedRepository {
    suspend fun deleteFeed(
        feedId: String?,
        folderName: String?,
    )

    suspend fun deleteSavedSearch(
        feedId: String?,
        query: String?,
    ): Result<Unit>

    suspend fun saveSearch(
        feedId: String?,
        query: String?,
    ): Result<Unit>

    suspend fun deleteSocialFeed(userId: String?): Result<Unit>
}
