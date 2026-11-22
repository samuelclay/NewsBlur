package com.newsblur.fragment

import com.newsblur.network.ClassifierApi
import com.newsblur.network.PromptTestRequest
import com.newsblur.network.domain.PromptTestResponse
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** The prompt text, direction and Text or Images mode the trainer's AI filter card shows, see AiPromptTester.kt. */
data class AiPromptDraft(
    val prompt: String,
    val hidden: Boolean,
    val imagePrompt: Boolean = false,
) {
    fun matches(request: PromptTestRequest): Boolean =
        prompt == request.prompt && hidden == request.hidden && imagePrompt == request.includeImages
}

/**
 * Runs the Test button's request for AiClassifierSections.kt. The prompt stays editable while a
 * test runs, so by the time the response arrives the draft may have new text, the other
 * direction or the other mode, and apps/analyzer/views.py test_prompt only answered for the
 * draft it was sent.
 */
class AiPromptTester(
    private val scope: CoroutineScope,
    private val classifierApi: ClassifierApi,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    var isTesting = false
        private set

    /**
     * Tests [request] and hands [onFinished] the response along with whether [currentDraft] still
     * matches the request's prompt and direction. A stale result must not be shown.
     */
    fun run(
        request: PromptTestRequest,
        currentDraft: () -> AiPromptDraft,
        onFinished: (response: PromptTestResponse, isCurrent: Boolean) -> Unit,
    ) {
        if (isTesting) return
        isTesting = true
        scope.launch {
            val response = withContext(ioDispatcher) { classifierApi.testPrompt(request) }
            isTesting = false
            onFinished(response, currentDraft().matches(request))
        }
    }
}
