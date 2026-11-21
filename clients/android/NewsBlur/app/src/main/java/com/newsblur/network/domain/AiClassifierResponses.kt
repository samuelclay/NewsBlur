package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName

// AiClassifierResponses.kt: response bodies for the AI prompt classifier endpoints in apps/analyzer/views.py.

/** POST /classifier/test_prompt. image_results has one 1 (match) or 0 entry per story image. */
data class PromptTestResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("message")
    val message: String? = null,
    @SerializedName("classification")
    val classification: Int = 0,
    @SerializedName("image_results")
    val imageResults: List<Int>? = null,
) {
    val isSuccess: Boolean
        get() = code == 0

    val matched: Boolean
        get() = classification != 0

    fun imageMatched(index: Int): Boolean = imageResults?.getOrNull(index) == 1

    val imageMatchCount: Int
        get() = imageResults?.count { it == 1 } ?: 0
}
