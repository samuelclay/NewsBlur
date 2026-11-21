package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_AiClassifierApis.kt: ClassifierApiImpl.kt sends what apps/analyzer/views.py expects and
// reads its mocked responses. No request here reaches a server.
class Test_AiClassifierApis {
    private val networkClient = mockk<NetworkClient>()
    private val classifierApi = ClassifierApiImpl(Gson(), networkClient)
    private val urls = mutableListOf<String>()
    private val bodies = mutableListOf<ValueMultimap>()

    private fun respond(body: String?) {
        val response = mockk<APIResponse>()
        every { response.isError } returns (body == null)
        every { response.responseBody } returns body
        coEvery { networkClient.post(capture(urls), capture(bodies)) } returns response
        coEvery { networkClient.postWithoutRetry(capture(urls), capture(bodies), any()) } returns response
        coEvery { networkClient.get(capture(urls), capture(bodies)) } returns response
    }

    @Test
    fun test_text_prompt_test_posts_prompt_and_reads_match() =
        runTest {
            respond("""{"code": 0, "classification": 1, "description": "Apple news"}""")

            val result =
                classifierApi.testPrompt(
                    PromptTestRequest("Non-apple related news", "5719953:1b4552", "5719953", includeImages = false, hidden = false),
                )

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_TEST_PROMPT), urls.single())
            val body = form(bodies.single())
            assertTrue(body, "prompt=Non-apple+related+news" in body)
            assertTrue(body, "story_hash=5719953%3A1b4552" in body)
            assertTrue(body, "include_images=false" in body)
            assertTrue(body, "classifier_type=focus" in body)
            assertTrue(body, "feed_id=5719953" in body)
            assertTrue(result.isSuccess)
            assertTrue(result.matched)
        }

    @Test
    fun test_image_prompt_test_reads_per_image_results() =
        runTest {
            respond("""{"code": 0, "classification": 1, "image_results": [0, 1, 1]}""")

            val result = classifierApi.testPrompt(PromptTestRequest("Charts", "1:a", "1", includeImages = true, hidden = true))

            val body = form(bodies.single())
            assertTrue(body, "include_images=true" in body)
            assertTrue(body, "classifier_type=hidden" in body)
            assertFalse(result.imageMatched(0))
            assertTrue(result.imageMatched(1))
            assertFalse("A missing index never counts as a match", result.imageMatched(5))
            assertEquals(2, result.imageMatchCount)
        }

    @Test
    fun test_prompt_test_errors_keep_the_server_message_or_fall_back() =
        runTest {
            respond("""{"code": -1, "message": "Story not found"}""")
            val refused = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(refused.isSuccess)
            assertEquals("Story not found", refused.message)
            assertTrue("A missing feed id is sent as 0", "feed_id=0" in form(bodies.last()))

            respond(null)
            val offline = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(offline.isSuccess)
            assertNull(offline.message)

            respond("<html>502</html>")
            assertFalse(classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false)).isSuccess)
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
