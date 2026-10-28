package com.newsblur.network

import com.newsblur.network.domain.AiClassifierUsageResponse
import com.newsblur.network.domain.PromptTestResponse

data class PromptTestRequest(
    val prompt: String,
    val storyHash: String,
    val feedId: String?,
    val includeImages: Boolean,
    // ClassifierApi.kt: true previews a hidden prompt, false a focus prompt.
    val hidden: Boolean,
)

/** AI prompt classifier calls behind StoryIntelTrainerFragment.java's Content and Image Filter sections. */
interface ClassifierApi {
    suspend fun testPrompt(request: PromptTestRequest): PromptTestResponse

    suspend fun getAiClassifierUsage(feedId: String?): AiClassifierUsageResponse
}
