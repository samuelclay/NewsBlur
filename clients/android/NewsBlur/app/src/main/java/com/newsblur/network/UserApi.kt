package com.newsblur.network

import com.newsblur.network.domain.ActivitiesResponse
import com.newsblur.network.domain.InteractionsResponse
import com.newsblur.network.domain.ProfileResponse

interface UserApi {
    suspend fun updateUserProfile(): ProfileResponse?
    suspend fun getUser(userId: String?): ProfileResponse?

    suspend fun followUser(userId: String?): Boolean
    suspend fun unfollowUser(userId: String?): Boolean

    suspend fun getActivities(userId: String, pageNumber: Int): ActivitiesResponse?
    suspend fun getInteractions(userId: String, pageNumber: Int): InteractionsResponse?
}