package com.newsblur.network

import com.newsblur.network.domain.DailyBriefingGenerateResponse
import com.newsblur.network.domain.DailyBriefingPreferencesResponse
import com.newsblur.network.domain.DailyBriefingStoriesResponse
import com.newsblur.network.domain.NewsBlurResponse

interface BriefingApi {
    suspend fun getStories(pageNumber: Int): DailyBriefingStoriesResponse?

    suspend fun getPreferences(): DailyBriefingPreferencesResponse?

    suspend fun savePreferences(parameters: Map<String, String>): NewsBlurResponse?

    suspend fun generate(): DailyBriefingGenerateResponse?
}
