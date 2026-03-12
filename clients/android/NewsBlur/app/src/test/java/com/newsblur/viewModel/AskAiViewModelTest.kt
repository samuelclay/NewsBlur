package com.newsblur.viewModel

import com.newsblur.MainDispatcherRule
import com.newsblur.askai.AskAiMessage
import com.newsblur.askai.AskAiProvider
import com.newsblur.askai.AskAiQuestionType
import com.newsblur.askai.AskAiResponseBlock
import com.newsblur.network.AskAiApi
import com.newsblur.network.AskAiQuestionRequest
import com.newsblur.network.NewsBlurSocketClient
import com.newsblur.network.domain.AskAiQuestionResponse
import com.newsblur.network.domain.AskAiTranscriptionResponse
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.slot
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.verify
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class AskAiViewModelTest {
    @get:Rule
    val dispatcherRule = MainDispatcherRule()

    private val askAiApi = mockk<AskAiApi>()
    private val prefsRepo = mockk<PrefsRepo>()
    private val socketClient = mockk<NewsBlurSocketClient>(relaxed = true)

    @Test
    fun sendQuestionCompletesStreamingConversation() =
        runTest {
            val startHandler = slot<(Any?) -> Unit>()
            val chunkHandler = slot<(Any?) -> Unit>()
            val completeHandler = slot<(Any?) -> Unit>()
            val usageHandler = slot<(Any?) -> Unit>()
            val errorHandler = slot<(Any?) -> Unit>()

            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe("ask_ai:start", capture(startHandler)) } just runs
            every { socketClient.subscribe("ask_ai:chunk", capture(chunkHandler)) } just runs
            every { socketClient.subscribe("ask_ai:complete", capture(completeHandler)) } just runs
            every { socketClient.subscribe("ask_ai:usage", capture(usageHandler)) } just runs
            every { socketClient.subscribe("ask_ai:error", capture(errorHandler)) } just runs
            coEvery { askAiApi.sendQuestion(any()) } returns AskAiQuestionResponse(code = 1, message = "Processing question")

            val viewModel = AskAiViewModel(askAiApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.sendQuestion(AskAiQuestionType.BULLETS)
            advanceUntilIdle()

            val requestId = viewModel.uiState.value.currentRequestId
            startHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to requestId,
                ),
            )
            chunkHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to requestId,
                    "chunk" to "First chunk. ",
                ),
            )
            chunkHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to requestId,
                    "chunk" to "Second chunk.",
                ),
            )
            completeHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to requestId,
                ),
            )
            usageHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to requestId,
                    "message" to "You have 0 Ask AI requests remaining this week.",
                ),
            )
            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertTrue(state.hasAskedQuestion)
            assertTrue(state.isComplete)
            assertFalse(state.isStreaming)
            assertEquals("You have 0 Ask AI requests remaining this week.", state.usageMessage)
            assertEquals(
                listOf(
                    AskAiResponseBlock(
                        questionText = "Summarize in bullet points",
                        model = AskAiProvider.OPUS,
                        responseText = "First chunk. Second chunk.",
                        isFollowUp = false,
                    ),
                ),
                state.completedBlocks,
            )
        }

    @Test
    fun sendQuestionShowsImmediateApiError() =
        runTest {
            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe(any(), any()) } just runs
            coEvery { askAiApi.sendQuestion(any()) } returns
                AskAiQuestionResponse(code = -1, message = "You've used your Ask AI request this week.")

            val viewModel = AskAiViewModel(askAiApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.sendQuestion(AskAiQuestionType.CONTEXT)
            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertFalse(state.isStreaming)
            assertEquals("You've used your Ask AI request this week.", state.errorMessage)
        }

    @Test
    fun streamingTimeoutCompletesWhenTextAlreadyArrived() =
        runTest {
            val chunkHandler = slot<(Any?) -> Unit>()

            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe("ask_ai:start", any()) } just runs
            every { socketClient.subscribe("ask_ai:chunk", capture(chunkHandler)) } just runs
            every { socketClient.subscribe("ask_ai:complete", any()) } just runs
            every { socketClient.subscribe("ask_ai:usage", any()) } just runs
            every { socketClient.subscribe("ask_ai:error", any()) } just runs
            coEvery { askAiApi.sendQuestion(any()) } returns AskAiQuestionResponse(code = 1, message = "Processing question")

            val viewModel = AskAiViewModel(askAiApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.sendQuestion(AskAiQuestionType.ARGUMENTS)
            advanceUntilIdle()

            chunkHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to viewModel.uiState.value.currentRequestId,
                    "chunk" to "The main argument is margin pressure.",
                ),
            )

            dispatcherRule.dispatcher.scheduler.advanceTimeBy(20_001L)
            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertTrue(state.isComplete)
            assertFalse(state.isStreaming)
            assertEquals(1, state.completedBlocks.size)
            assertEquals("The main argument is margin pressure.", state.completedBlocks.first().responseText)
        }

    @Test
    fun reaskWithModelResendsPreviousCustomQuestion() =
        runTest {
            val completeHandler = slot<(Any?) -> Unit>()
            val requests = mutableListOf<AskAiQuestionRequest>()

            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe("ask_ai:start", any()) } just runs
            every { socketClient.subscribe("ask_ai:chunk", any()) } just runs
            every { socketClient.subscribe("ask_ai:complete", capture(completeHandler)) } just runs
            every { socketClient.subscribe("ask_ai:usage", any()) } just runs
            every { socketClient.subscribe("ask_ai:error", any()) } just runs
            coEvery { askAiApi.sendQuestion(capture(requests)) } returns AskAiQuestionResponse(code = 1, message = "Processing question")

            val viewModel = AskAiViewModel(askAiApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.updateCustomQuestion("What changed in the leadership team?")
            viewModel.sendFollowUp()
            advanceUntilIdle()

            completeHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to viewModel.uiState.value.currentRequestId,
                ),
            )
            advanceUntilIdle()

            viewModel.reaskWithModel(AskAiProvider.GEMINI)
            advanceUntilIdle()

            assertEquals(2, requests.size)
            assertEquals("What changed in the leadership team?", requests[0].customQuestion)
            assertEquals("What changed in the leadership team?", requests[1].customQuestion)
            assertTrue(requests[0].conversationHistory.isEmpty())
            assertTrue(requests[1].conversationHistory.isEmpty())
            assertEquals(AskAiProvider.GEMINI.rawValue, requests[1].model)
            coVerify(exactly = 2) { askAiApi.sendQuestion(any()) }
        }

    @Test
    fun sendFollowUpAppendsLatestUserMessageToConversationHistory() =
        runTest {
            val completeHandler = slot<(Any?) -> Unit>()
            val chunkHandler = slot<(Any?) -> Unit>()
            val requests = mutableListOf<AskAiQuestionRequest>()

            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe("ask_ai:start", any()) } just runs
            every { socketClient.subscribe("ask_ai:chunk", capture(chunkHandler)) } just runs
            every { socketClient.subscribe("ask_ai:complete", capture(completeHandler)) } just runs
            every { socketClient.subscribe("ask_ai:usage", any()) } just runs
            every { socketClient.subscribe("ask_ai:error", any()) } just runs
            coEvery { askAiApi.sendQuestion(capture(requests)) } returns AskAiQuestionResponse(code = 1, message = "Processing question")

            val viewModel = AskAiViewModel(askAiApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.sendQuestion(AskAiQuestionType.SENTENCE)
            advanceUntilIdle()

            chunkHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to viewModel.uiState.value.currentRequestId,
                    "chunk" to "Initial answer.",
                ),
            )
            completeHandler.captured(
                mapOf(
                    "story_hash" to "story-hash",
                    "request_id" to viewModel.uiState.value.currentRequestId,
                ),
            )
            advanceUntilIdle()

            viewModel.updateCustomQuestion("What else matters here?")
            viewModel.sendFollowUp()
            advanceUntilIdle()

            assertEquals(2, requests.size)
            assertEquals(emptyList<AskAiMessage>(), requests[0].conversationHistory)
            assertEquals(
                listOf(
                    AskAiMessage(role = "assistant", content = "Initial answer."),
                    AskAiMessage(role = "user", content = "What else matters here?"),
                ),
                requests[1].conversationHistory,
            )
        }

    @Test
    fun sendQuestionCallsApiOffMainThread() =
        runTest {
            val apiThread = CompletableDeferred<Thread>()

            every { prefsRepo.getAskAiModel() } returns AskAiProvider.OPUS.rawValue
            every { prefsRepo.isShowAskAi() } returns true
            every { prefsRepo.getIsArchive() } returns false
            every { prefsRepo.getIsPro() } returns false
            every { prefsRepo.getUserName() } returns "sclay"
            every { prefsRepo.setAskAiModel(any()) } just runs
            every { socketClient.subscribe(any(), any()) } just runs

            val dispatchCheckingApi =
                object : AskAiApi {
                    override suspend fun sendQuestion(request: AskAiQuestionRequest): AskAiQuestionResponse {
                        apiThread.complete(Thread.currentThread())
                        return AskAiQuestionResponse(code = 1, message = "Processing question")
                    }

                    override suspend fun transcribeAudio(file: File): AskAiTranscriptionResponse =
                        AskAiTranscriptionResponse(code = 1, text = "transcribed")
                }

            val testThread = Thread.currentThread()
            val viewModel = AskAiViewModel(dispatchCheckingApi, prefsRepo, socketClient)
            viewModel.initialize(storyHash = "story-hash", storyTitle = "Atlassian story")
            viewModel.sendQuestion(AskAiQuestionType.BULLETS)
            advanceUntilIdle()

            assertNotSame(testThread, apiThread.await())
        }
}
