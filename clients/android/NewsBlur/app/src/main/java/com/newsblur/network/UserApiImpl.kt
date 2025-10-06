package com.newsblur.network

import android.content.ContentValues
import android.content.Context
import com.google.gson.Gson
import com.newsblur.network.domain.ActivitiesResponse
import com.newsblur.network.domain.InteractionsResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.ProfileResponse
import com.newsblur.preference.PrefsRepo
import dagger.hilt.android.qualifiers.ApplicationContext
import okhttp3.RequestBody

class UserApiImpl(
        @param:ApplicationContext private val context: Context,
        private val gson: Gson,
        private val networkClient: NetworkClient,
        private val prefsRepo: PrefsRepo,
) : UserApi {

    override suspend fun updateUserProfile(): ProfileResponse? {
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MY_PROFILE)
        val response: APIResponse = networkClient.get(urlString)
        if (!response.isError) {
            val profileResponse = response.getResponse(gson, ProfileResponse::class.java)
            prefsRepo.saveUserDetails(context, profileResponse.user)
            return profileResponse
        } else {
            return null
        }
    }

    override suspend fun followUser(userId: String?): Boolean {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USERID, userId)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FOLLOW)
        val response: APIResponse = networkClient.post(urlString, values)
        return !response.isError
    }

    override suspend fun unfollowUser(userId: String?): Boolean {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USERID, userId)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_UNFOLLOW)
        val response: APIResponse = networkClient.post(urlString, values)
        return !response.isError
    }

    override suspend fun getUser(userId: String?): ProfileResponse? {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USERID, userId)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_USER_PROFILE)
        val response: APIResponse = networkClient.get(urlString, values)
        return if (!response.isError) {
            response.getResponse(gson, ProfileResponse::class.java)
        } else {
            null
        }
    }

    override suspend fun getActivities(userId: String, pageNumber: Int): ActivitiesResponse? {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USER_ID, userId)
            put(APIConstants.PARAMETER_LIMIT, "10")
            put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber.toString())
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_USER_ACTIVITIES)
        val response: APIResponse = networkClient.get(urlString, values)
        return if (!response.isError) {
            response.getResponse(gson, ActivitiesResponse::class.java)
        } else {
            null
        }
    }

    override suspend fun getInteractions(userId: String, pageNumber: Int): InteractionsResponse? {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USER_ID, userId)
            put(APIConstants.PARAMETER_LIMIT, "10")
            put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber.toString())
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_USER_INTERACTIONS)
        val response: APIResponse = networkClient.get(urlString, values)
        return if (!response.isError) {
            response.getResponse(gson, InteractionsResponse::class.java)
        } else {
            null
        }
    }

    override suspend fun saveReceipt(orderId: String?, productId: String?): NewsBlurResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_ORDER_ID, orderId)
        values.put(APIConstants.PARAMETER_PRODUCT_ID, productId)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SAVE_RECEIPT)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun importOpml(requestBody: RequestBody): NewsBlurResponse? {
        val urlString = APIConstants.buildUrl(APIConstants.PATH_IMPORT_OPML)
        val response: APIResponse = networkClient.post(urlString, requestBody)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }
}