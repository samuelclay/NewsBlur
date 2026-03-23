package com.newsblur.viewModel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.askai.AskAiMessage
import com.newsblur.askai.AskAiProvider
import com.newsblur.askai.AskAiQuestionType
import com.newsblur.askai.AskAiResponseBlock
import com.newsblur.askai.AskAiStory
import com.newsblur.askai.AskAiUiState
import com.newsblur.network.AskAiApi
import com.newsblur.network.AskAiQuestionRequest
import com.newsblur.network.NewsBlurSocketClient
import com.newsblur.preference.PrefsRepo
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class AskAiViewModel
    @Inject
    constructor(
        private val askAiApi: AskAiApi,
        private val prefsRepo: PrefsRepo,
        private val socketClient: NewsBlurSocketClient,
    ) : ViewModel() {
        private val _uiState = MutableStateFlow(AskAiUiState())
        val uiState: StateFlow<AskAiUiState> = _uiState.asStateFlow()

        private val conversationHistory = mutableListOf<AskAiMessage>()
        private var pendingHistoryQuestion: AskAiMessage? = null
        private var socketSubscribed = false
        private var timeoutJob: Job? = null
        private var streamingTimeoutJob: Job? = null

        fun initialize(
            storyHash: String,
            storyTitle: String,
        ) {
            val currentStory = _uiState.value.story
            if (currentStory?.storyHash == storyHash) return

            conversationHistory.clear()
            pendingHistoryQuestion = null
            _uiState.value =
                AskAiUiState(
                    story = AskAiStory(storyHash = storyHash, storyTitle = storyTitle),
                    selectedModel = AskAiProvider.fromRawValue(prefsRepo.getAskAiModel()),
                    showAskAi = prefsRepo.isShowAskAi(),
                    isArchiveTier = prefsRepo.getIsArchive() || prefsRepo.getIsPro(),
                )

            setupSocketHandlers()
            prefsRepo.getUserName()?.let { socketClient.connect(username = it) }
        }

        fun updateCustomQuestion(question: String) {
            _uiState.update { it.copy(customQuestion = question) }
        }

        fun selectModel(model: AskAiProvider) {
            prefsRepo.setAskAiModel(model.rawValue)
            _uiState.update { it.copy(selectedModel = model) }
        }

        fun sendQuestion(type: AskAiQuestionType) {
            val customQuestion = _uiState.value.customQuestion.trim()
            val questionText =
                if (type == AskAiQuestionType.CUSTOM) {
                    customQuestion
                } else {
                    type.questionDescription
                }
            sendQuestion(
                questionId = type.rawValue,
                questionText = questionText,
                clearCustomQuestion = type == AskAiQuestionType.CUSTOM,
            )
        }

        fun sendFollowUp() {
            sendQuestion(AskAiQuestionType.CUSTOM)
        }

        fun reaskWithModel(model: AskAiProvider) {
            selectModel(model)
            val state = _uiState.value
            conversationHistory.clear()
            pendingHistoryQuestion = null
            sendQuestion(
                questionId = state.currentQuestionId,
                questionText = state.currentQuestionText,
                clearCustomQuestion = false,
            )
        }

        fun cancelRequest() {
            timeoutJob?.cancel()
            streamingTimeoutJob?.cancel()
            pendingHistoryQuestion = null
            _uiState.update { it.copy(isStreaming = false) }
        }

        fun setRecording(isRecording: Boolean) {
            _uiState.update {
                it.copy(
                    isRecording = isRecording,
                    isTranscribing = if (isRecording) false else it.isTranscribing,
                    errorMessage = if (isRecording) null else it.errorMessage,
                )
            }
        }

        fun setVoiceError(message: String) {
            _uiState.update {
                it.copy(
                    isRecording = false,
                    isTranscribing = false,
                    errorMessage = message,
                )
            }
        }

        fun transcribeAudio(file: File) {
            _uiState.update {
                it.copy(
                    isRecording = false,
                    isTranscribing = true,
                    errorMessage = null,
                )
            }

            viewModelScope.launch {
                val response =
                    withContext(Dispatchers.IO) {
                        askAiApi.transcribeAudio(file)
                    }
                file.delete()

                if (response.code == 1 && !response.text.isNullOrBlank()) {
                    _uiState.update {
                        it.copy(
                            customQuestion = response.text,
                            isTranscribing = false,
                        )
                    }
                    sendQuestion(AskAiQuestionType.CUSTOM)
                } else {
                    _uiState.update {
                        it.copy(
                            isTranscribing = false,
                            errorMessage = response.message ?: "Transcription failed",
                        )
                    }
                }
            }
        }

        override fun onCleared() {
            timeoutJob?.cancel()
            streamingTimeoutJob?.cancel()
            pendingHistoryQuestion = null
            socketClient.unsubscribe(EVENT_START)
            socketClient.unsubscribe(EVENT_CHUNK)
            socketClient.unsubscribe(EVENT_COMPLETE)
            socketClient.unsubscribe(EVENT_USAGE)
            socketClient.unsubscribe(EVENT_ERROR)
            super.onCleared()
        }

        private fun setupSocketHandlers() {
            if (socketSubscribed) return

            socketClient.subscribe(EVENT_START, ::handleStart)
            socketClient.subscribe(EVENT_CHUNK, ::handleChunk)
            socketClient.subscribe(EVENT_COMPLETE, ::handleComplete)
            socketClient.subscribe(EVENT_USAGE, ::handleUsage)
            socketClient.subscribe(EVENT_ERROR, ::handleError)
            socketSubscribed = true
        }

        private fun handleStart(data: Any?) {
            val payload = data.asPayload() ?: return
            if (!matchesCurrentRequest(payload)) return

            _uiState.update { it.copy(errorMessage = null) }
            startStreamingTimeout()
        }

        private fun handleChunk(data: Any?) {
            val payload = data.asPayload() ?: return
            if (!matchesCurrentRequest(payload)) return

            val chunk = payload["chunk"] as? String ?: return
            _uiState.update {
                it.copy(
                    currentResponseText = it.currentResponseText + chunk,
                    errorMessage = null,
                    isStreaming = true,
                )
            }
            startStreamingTimeout()
        }

        private fun handleComplete(data: Any?) {
            val payload = data.asPayload() ?: return
            if (!matchesCurrentRequest(payload)) return
            completeCurrentResponse()
        }

        private fun handleUsage(data: Any?) {
            val payload = data.asPayload() ?: return
            if (!matchesCurrentRequest(payload)) return

            _uiState.update { it.copy(usageMessage = payload["message"] as? String) }
        }

        private fun handleError(data: Any?) {
            val payload = data.asPayload() ?: return
            if (!matchesCurrentRequest(payload)) return

            timeoutJob?.cancel()
            streamingTimeoutJob?.cancel()
            pendingHistoryQuestion = null
            _uiState.update {
                it.copy(
                    isStreaming = false,
                    errorMessage = payload["error"] as? String ?: "Request failed",
                )
            }
        }

        private fun completeCurrentResponse() {
            timeoutJob?.cancel()
            streamingTimeoutJob?.cancel()

            val state = _uiState.value
            if (state.currentQuestionText.isBlank() && state.currentResponseText.isBlank()) return

            val block =
                AskAiResponseBlock(
                    questionText = state.currentQuestionText,
                    model = state.selectedModel,
                    responseText = state.currentResponseText,
                    isFollowUp = state.completedBlocks.isNotEmpty(),
                )

            pendingHistoryQuestion?.let { conversationHistory += it }
            if (state.currentResponseText.isNotBlank()) {
                conversationHistory += AskAiMessage(role = "assistant", content = state.currentResponseText)
            }
            pendingHistoryQuestion = null

            _uiState.update {
                it.copy(
                    completedBlocks = it.completedBlocks + block,
                    currentResponseText = "",
                    isStreaming = false,
                    isComplete = true,
                )
            }
        }

        private fun startTimeout() {
            timeoutJob?.cancel()
            timeoutJob =
                viewModelScope.launch {
                    kotlinx.coroutines.delay(REQUEST_TIMEOUT_MS)
                    val state = _uiState.value
                    if (state.isStreaming && state.currentResponseText.isBlank()) {
                        pendingHistoryQuestion = null
                        _uiState.update {
                            it.copy(
                                isStreaming = false,
                                errorMessage = "Request timed out",
                            )
                        }
                    }
                }
        }

        private fun startStreamingTimeout() {
            streamingTimeoutJob?.cancel()
            streamingTimeoutJob =
                viewModelScope.launch {
                    kotlinx.coroutines.delay(STREAMING_TIMEOUT_MS)
                    val state = _uiState.value
                    if (!state.isStreaming) return@launch

                    if (state.currentResponseText.isNotBlank()) {
                        completeCurrentResponse()
                    } else {
                        pendingHistoryQuestion = null
                        _uiState.update {
                            it.copy(
                                isStreaming = false,
                                errorMessage = "Stream interrupted",
                            )
                        }
                    }
                }
        }

        private fun matchesCurrentRequest(payload: Map<String, Any?>): Boolean {
            val state = _uiState.value
            val storyHash = payload["story_hash"] as? String
            val requestId = payload["request_id"] as? String
            return storyHash == state.story?.storyHash && requestId == state.currentRequestId
        }

        private fun sendQuestion(
            questionId: String,
            questionText: String,
            clearCustomQuestion: Boolean,
        ) {
            val story = _uiState.value.story ?: return
            if (questionId.isBlank() || questionText.isBlank()) return

            val requestId = UUID.randomUUID().toString()
            val selectedModel = _uiState.value.selectedModel
            val requestConversationHistory =
                if (conversationHistory.isNotEmpty()) {
                    val userMessage = AskAiMessage(role = "user", content = questionText)
                    pendingHistoryQuestion = userMessage
                    conversationHistory.toList() + userMessage
                } else {
                    pendingHistoryQuestion = null
                    emptyList()
                }

            _uiState.update {
                it.copy(
                    currentQuestionId = questionId,
                    currentQuestionText = questionText,
                    currentRequestId = requestId,
                    currentResponseText = "",
                    isStreaming = true,
                    isComplete = false,
                    hasAskedQuestion = true,
                    errorMessage = null,
                    usageMessage = null,
                    customQuestion = if (clearCustomQuestion) "" else it.customQuestion,
                )
            }
            startTimeout()

            viewModelScope.launch {
                val response =
                    withContext(Dispatchers.IO) {
                        askAiApi.sendQuestion(
                            AskAiQuestionRequest(
                                storyHash = story.storyHash,
                                questionId = questionId,
                                requestId = requestId,
                                model = selectedModel.rawValue,
                                customQuestion = questionText.takeIf { questionId == AskAiQuestionType.CUSTOM.rawValue },
                                conversationHistory = requestConversationHistory,
                            ),
                        )
                    }

                if (response.code != 1) {
                    timeoutJob?.cancel()
                    pendingHistoryQuestion = null
                    _uiState.update {
                        it.copy(
                            isStreaming = false,
                            errorMessage = response.message ?: "Request failed",
                        )
                    }
                }
            }
        }

        @Suppress("UNCHECKED_CAST")
        private fun Any?.asPayload(): Map<String, Any?>? = this as? Map<String, Any?>

        companion object {
            private const val EVENT_START = "ask_ai:start"
            private const val EVENT_CHUNK = "ask_ai:chunk"
            private const val EVENT_COMPLETE = "ask_ai:complete"
            private const val EVENT_USAGE = "ask_ai:usage"
            private const val EVENT_ERROR = "ask_ai:error"

            private const val REQUEST_TIMEOUT_MS = 15_000L
            private const val STREAMING_TIMEOUT_MS = 20_000L
        }
    }
