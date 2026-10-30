package com.newsblur.network

import com.google.gson.Gson
import com.google.gson.JsonParseException
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.UsageBillingHistoryResponse
import com.newsblur.network.domain.UsageBillingLimitResponse
import com.newsblur.network.domain.UsageBillingSessionResponse

class UsageBillingApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : UsageBillingApi {
    override suspend fun getHistory(): UsageBillingHistoryResponse? {
        val response = networkClient.get(APIConstants.buildUrl(APIConstants.PATH_USAGE_BILLING_HISTORY), ValueMultimap())
        return parse(response, null)
    }

    override suspend fun saveLimit(limit: String): UsageBillingLimitResponse {
        val values = ValueMultimap().apply { put(APIConstants.PARAMETER_LIMIT, limit.trim()) }
        val response = networkClient.post(APIConstants.buildUrl(APIConstants.PATH_SAVE_USAGE_BILLING_LIMIT), values)
        return parse(response, UsageBillingLimitResponse())
    }

    override suspend fun startSetup(platform: String): UsageBillingSessionResponse =
        startSession(APIConstants.PATH_SETUP_USAGE_BILLING, platform)

    override suspend fun openPortal(platform: String): UsageBillingSessionResponse =
        startSession(APIConstants.PATH_MANAGE_USAGE_BILLING, platform)

    private suspend fun startSession(
        path: String,
        platform: String,
    ): UsageBillingSessionResponse {
        val values = ValueMultimap().apply { put(APIConstants.PARAMETER_PLATFORM, platform) }
        val response = networkClient.post(APIConstants.buildUrl(path), values)
        return parse(response, UsageBillingSessionResponse())
    }

    // UsageBillingApiImpl.kt: failures fall back to code -1 with no message, so the billing
    // screen shows its own localized error.
    private inline fun <reified T> parse(
        response: APIResponse,
        fallback: T,
    ): T {
        if (response.isError || response.responseBody.isNullOrBlank()) return fallback
        return try {
            gson.fromJson(response.responseBody, T::class.java) ?: fallback
        } catch (_: JsonParseException) {
            fallback
        }
    }
}
