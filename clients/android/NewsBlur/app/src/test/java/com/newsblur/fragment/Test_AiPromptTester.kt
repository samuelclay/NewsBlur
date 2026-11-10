package com.newsblur.fragment

import com.newsblur.network.ClassifierApi
import com.newsblur.network.PromptTestRequest
import com.newsblur.network.domain.AiClassifierUsageResponse
import com.newsblur.network.domain.PromptTestResponse
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_AiPromptTester.kt: a trainer's prompt test result is only shown for the prompt text and
// focus or hidden direction it was sent with, even when the draft changes while the slow,
// billed apps/analyzer/views.py test_prompt request is still running.
class Test_AiPromptTester {
    /** Holds every test response until the test releases it, like a slow AI request. */
    private class DelayedClassifierApi : ClassifierApi {
        val response = CompletableDeferred<PromptTestResponse>()
        val requests = mutableListOf<PromptTestRequest>()

        override suspend fun testPrompt(request: PromptTestRequest): PromptTestResponse {
            requests += request
            return response.await()
        }

        override suspend fun getAiClassifierUsage(feedId: String?): AiClassifierUsageResponse = AiClassifierUsageResponse()
    }

    private val api = DelayedClassifierApi()
    private val matched = PromptTestResponse(code = 0, classification = 1)
    private var draft = AiPromptDraft("Apple rumors", hidden = false)
    private var finished: Pair<PromptTestResponse, Boolean>? = null

    private fun TestScope.startTest(): AiPromptTester {
        // backgroundScope stands in for the fragment's lifecycleScope, which cancels whatever is still running.
        val tester = AiPromptTester(backgroundScope, api, StandardTestDispatcher(testScheduler))
        val request = PromptTestRequest(draft.prompt, "1:a", "1", includeImages = false, hidden = draft.hidden)
        tester.run(request, currentDraft = { draft }) { response, isCurrent -> finished = response to isCurrent }
        runCurrent()
        assertEquals("The request is out and waiting", 1, api.requests.size)
        assertTrue(tester.isTesting)
        return tester
    }

    @Test
    fun test_an_unchanged_draft_shows_its_result() =
        runTest {
            val tester = startTest()

            api.response.complete(matched)
            runCurrent()

            assertEquals(matched to true, finished)
            assertFalse(tester.isTesting)
        }

    @Test
    fun test_editing_the_prompt_during_a_test_drops_its_result() =
        runTest {
            val tester = startTest()

            draft = draft.copy(prompt = "Apple rumors about the iPhone")
            api.response.complete(matched)
            runCurrent()

            assertEquals("The result arrives but isn't current", matched to false, finished)
            assertFalse(tester.isTesting)
        }

    @Test
    fun test_flipping_focus_to_hidden_during_a_test_drops_its_result() =
        runTest {
            startTest()

            draft = draft.copy(hidden = true)
            api.response.complete(matched)
            runCurrent()

            assertEquals(matched to false, finished)
        }

    @Test
    fun test_a_second_test_waits_for_the_first() =
        runTest {
            val tester = startTest()

            tester.run(PromptTestRequest("Other", "1:a", "1", includeImages = false, hidden = false), { draft }) { _, _ -> }
            runCurrent()

            assertEquals(1, api.requests.size)
            assertNull(finished)
        }
}
