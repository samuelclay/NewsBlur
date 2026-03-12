package com.newsblur.network

import android.content.ContentValues
import com.google.gson.Gson
import com.newsblur.network.domain.AskAiQuestionResponse
import com.newsblur.network.domain.AskAiTranscriptionResponse
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import javax.inject.Inject

class AskAiApiImpl
    @Inject
    constructor(
        private val gson: Gson,
        private val networkClient: NetworkClient,
    ) : AskAiApi {
        override suspend fun sendQuestion(request: AskAiQuestionRequest): AskAiQuestionResponse {
            val values =
                ContentValues().apply {
                    put(APIConstants.PARAMETER_STORY_HASH, request.storyHash)
                    put(APIConstants.PARAMETER_QUESTION_ID, request.questionId)
                    put(APIConstants.PARAMETER_REQUEST_ID, request.requestId)
                    put(APIConstants.PARAMETER_MODEL, request.model)

                    if (!request.customQuestion.isNullOrBlank()) {
                        put(APIConstants.PARAMETER_CUSTOM_QUESTION, request.customQuestion)
                    }
                    if (request.conversationHistory.isNotEmpty()) {
                        put(APIConstants.PARAMETER_CONVERSATION_HISTORY, gson.toJson(request.conversationHistory))
                    }
                }

            val urlString = APIConstants.buildUrl(APIConstants.PATH_ASK_AI_QUESTION)
            val response = networkClient.post(urlString, values)
            if (response.isError) {
                return AskAiQuestionResponse(message = "Unable to contact Ask AI")
            }

            return parseBody(
                body = response.responseBody,
                fallback = AskAiQuestionResponse(message = "Unable to parse Ask AI response"),
            )
        }

        override suspend fun transcribeAudio(file: File): AskAiTranscriptionResponse {
            val body =
                MultipartBody
                    .Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart(
                        "audio",
                        file.name,
                        file.asRequestBody(contentType = null),
                    ).build()

            val urlString = APIConstants.buildUrl(APIConstants.PATH_ASK_AI_TRANSCRIBE)
            val response = networkClient.post(urlString, body)
            if (response.isError) {
                return AskAiTranscriptionResponse(message = "Unable to transcribe audio")
            }

            return parseBody(
                body = response.responseBody,
                fallback = AskAiTranscriptionResponse(message = "Unable to parse transcription response"),
            )
        }

        private inline fun <reified T> parseBody(
            body: String?,
            fallback: T,
        ): T =
            try {
                if (body.isNullOrBlank()) {
                    fallback
                } else {
                    gson.fromJson(body, T::class.java) ?: fallback
                }
            } catch (_: Exception) {
                fallback
            }
    }
