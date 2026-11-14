package com.newsblur.network

import com.google.gson.Gson
import com.google.gson.JsonParseException
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.AiClassifierUsageResponse
import com.newsblur.network.domain.PromptTestResponse

class ClassifierApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : ClassifierApi {
    override suspend fun testPrompt(request: PromptTestRequest): PromptTestResponse {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_PROMPT, request.prompt)
                put(APIConstants.PARAMETER_STORY_HASH, request.storyHash)
                put(APIConstants.PARAMETER_INCLUDE_IMAGES, if (request.includeImages) APIConstants.VALUE_TRUE else APIConstants.VALUE_FALSE)
                put(APIConstants.PARAMETER_CLASSIFIER_TYPE, if (request.hidden) "hidden" else "focus")
                put(APIConstants.PARAMETER_FEEDID, request.feedId ?: "0")
            }
        // ClassifierApiImpl.kt: apps/analyzer/views.py test_prompt_classifier bills every run, and
        // a timed out or 504'd run may still have finished and billed, so one tap is one request.
        // The retrying post would send it up to three times.
        val response =
            networkClient.postWithoutRetry(
                APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_TEST_PROMPT),
                values,
                PROMPT_TEST_TIMEOUT_SECONDS,
            )
        return parse(response, PromptTestResponse())
    }

    override suspend fun getAiClassifierUsage(feedId: String?): AiClassifierUsageResponse {
        val values = ValueMultimap().apply { put(APIConstants.PARAMETER_FEEDID, feedId ?: "0") }
        val response = networkClient.get(APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_AI_USAGE), values)
        return parse(response, AiClassifierUsageResponse())
    }

    // ClassifierApiImpl.kt: a failed or unreadable response becomes the fallback, whose code -1
    // and empty message let the trainer show its own localized error.
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

    companion object {
        // An image test downloads every story image one at a time, up to 10 seconds each in
        // utils/ai_functions.py, before classifying them. config/gunicorn_conf.py stops a request
        // at 120 seconds, so waiting that long never gives up on a run the server is still doing.
        const val PROMPT_TEST_TIMEOUT_SECONDS = 120L
    }
}
