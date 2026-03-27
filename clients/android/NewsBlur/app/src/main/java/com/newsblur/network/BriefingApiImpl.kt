package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.Story
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.DailyBriefingBriefing
import com.newsblur.network.domain.DailyBriefingGenerateResponse
import com.newsblur.network.domain.DailyBriefingPreferencesResponse
import com.newsblur.network.domain.DailyBriefingStory
import com.newsblur.network.domain.DailyBriefingStoriesResponse
import com.newsblur.network.domain.DailyBriefingStoriesResponseRaw
import com.newsblur.network.domain.NewsBlurResponse

class BriefingApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : BriefingApi {
    override suspend fun getStories(pageNumber: Int): DailyBriefingStoriesResponse? {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber.toString())
            }
        val response: APIResponse = networkClient.get(APIConstants.buildUrl(APIConstants.PATH_BRIEFING_STORIES), values)
        val rawResponse =
            response.getResponse(
                gson,
                DailyBriefingStoriesResponseRaw::class.java,
            ) ?: return null

        return DailyBriefingStoriesResponse(
            briefings =
                rawResponse.briefings.map { rawBriefing ->
                    DailyBriefingBriefing(
                        briefingId = rawBriefing.briefingId ?: "",
                        briefingDate = rawBriefing.briefingDate,
                        frequency = rawBriefing.frequency,
                        slot = rawBriefing.slot,
                        summaryStory =
                            rawBriefing.summaryStory?.let { json ->
                                jsonToStory(json)?.let { story ->
                                    DailyBriefingStory(
                                        story = story,
                                        feedTitle = "Daily Briefing",
                                        faviconColor = null,
                                        explicitFeedId = rawResponse.briefingFeedId,
                                        isSummary = true,
                                    )
                                }
                            },
                        curatedStories =
                            rawBriefing.curatedStories.mapNotNull { json ->
                                val story = jsonToStory(json) ?: return@mapNotNull null
                                DailyBriefingStory(
                                    story = story,
                                    feedTitle = json.get("feed_title")?.takeIf { !it.isJsonNull }?.asString,
                                    faviconColor = json.get("favicon_color")?.takeIf { !it.isJsonNull }?.asString,
                                    explicitFeedId = json.get("feed_id")?.takeIf { !it.isJsonNull }?.asString,
                                    isSummary = false,
                                )
                            },
                    )
                },
            isPreview = rawResponse.isPreview,
            briefingFeedId = rawResponse.briefingFeedId,
            enabled = rawResponse.enabled,
            sectionDefinitions = rawResponse.sectionDefinitions,
            hasNextPage = rawResponse.hasNextPage,
            page = rawResponse.page,
            preferences = rawResponse.preferences,
        ).also {
            it.authenticated = rawResponse.authenticated
            it.code = rawResponse.code
            it.message = rawResponse.message
            it.errors = rawResponse.errors
            it.readTime = rawResponse.readTime
            it.impactCode = rawResponse.impactCode
            it.isProtocolError = rawResponse.isProtocolError
        }
    }

    override suspend fun getPreferences(): DailyBriefingPreferencesResponse? {
        val response: APIResponse = networkClient.get(APIConstants.buildUrl(APIConstants.PATH_BRIEFING_PREFERENCES))
        return response.getResponse(gson, DailyBriefingPreferencesResponse::class.java)
    }

    override suspend fun savePreferences(parameters: Map<String, String>): NewsBlurResponse? {
        val values =
            ValueMultimap().apply {
                parameters.forEach { (key, value) ->
                    put(key, value)
                }
            }
        val response: APIResponse = networkClient.post(APIConstants.buildUrl(APIConstants.PATH_BRIEFING_PREFERENCES), values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun generate(): DailyBriefingGenerateResponse? {
        val response: APIResponse = networkClient.post(APIConstants.buildUrl(APIConstants.PATH_BRIEFING_GENERATE), ValueMultimap())
        return response.getResponse(gson, DailyBriefingGenerateResponse::class.java)
    }

    private fun jsonToStory(json: com.google.gson.JsonObject): Story? =
        runCatching {
            gson.fromJson(json, Story::class.java)
        }.getOrNull()
}
