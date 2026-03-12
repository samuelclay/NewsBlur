package com.newsblur.network

import com.newsblur.askai.AskAiMessage
import com.newsblur.network.domain.AskAiQuestionResponse
import com.newsblur.network.domain.AskAiTranscriptionResponse
import java.io.File

data class AskAiQuestionRequest(
    val storyHash: String,
    val questionId: String,
    val requestId: String,
    val model: String,
    val customQuestion: String? = null,
    val conversationHistory: List<AskAiMessage> = emptyList(),
)

interface AskAiApi {
    suspend fun sendQuestion(request: AskAiQuestionRequest): AskAiQuestionResponse

    suspend fun transcribeAudio(file: File): AskAiTranscriptionResponse
}
