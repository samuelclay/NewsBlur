package com.newsblur.network.domain

data class AskAiQuestionResponse(
    val code: Int = -1,
    val message: String? = null,
    val request_id: String? = null,
    val story_hash: String? = null,
    val question_id: String? = null,
)

data class AskAiTranscriptionResponse(
    val code: Int = -1,
    val text: String? = null,
    val message: String? = null,
)
