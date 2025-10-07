package com.newsblur.repository

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.FeedApi
import com.newsblur.network.UserApi
import javax.inject.Inject

class FeedRepositoryImpl
@Inject constructor(
        private val userApi: UserApi,
        private val feedApi: FeedApi,
        private val dbHelper: BlurDatabaseHelper,
) : FeedRepository {

    override suspend fun deleteFeed(feedId: String?, folderName: String?) {
        feedApi.deleteFeed(feedId, folderName)
        dbHelper.deleteFeed(feedId)
    }

    override suspend fun deleteSavedSearch(
            feedId: String?,
            query: String?,
    ): Result<Unit> = runCatching {
        val response = feedApi.deleteSearch(feedId, query)
        if (response == null || response.isError) {
            throw Exception(response?.message ?: "Failed to delete saved search")
        }
        dbHelper.deleteSavedSearch(feedId, query)
    }

    override suspend fun saveSearch(
            feedId: String?,
            query: String?,
    ): Result<Unit> = runCatching {
        val response = feedApi.saveSearch(feedId, query)
        if (response == null || response.isError) {
            throw Exception(response?.message ?: "Failed to save search")
        }
    }

    override suspend fun deleteSocialFeed(userId: String?): Result<Unit> = runCatching {
        userApi.unfollowUser(userId)
        // TODO: we can't check result.isError() because the delete call sets the .message property on all calls. find a better error check
        dbHelper.deleteSocialFeed(userId)
    }
}