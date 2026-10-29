package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.Classifier
import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.NewsBlurResponse
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_FeedIntelScopedSaves.kt: FeedApiImpl.updateFeedIntel sends folder and global AI prompt
// changes only after the feed save lands, tries every scope even when one fails, and removes a
// moved prompt's old copy only once its new scope saved.
class Test_FeedIntelScopedSaves {
    private val networkClient = mockk<NetworkClient>()
    private val feedApi = FeedApiImpl(Gson(), networkClient)
    private val bodies = mutableListOf<String>()

    private val ok = NewsBlurResponse()
    private val networkError = NewsBlurResponse().apply { isProtocolError = true }
    private val archiveRequired = NewsBlurResponse().apply { message = "Premium Archive required for folder and global classifiers" }

    /** Answers each /classifier/save request with [answer] for its form body. */
    private fun respond(answer: (String) -> NewsBlurResponse) {
        coEvery { networkClient.post(any(), any<ValueMultimap>()) } answers {
            val body = form(secondArg())
            bodies += body
            val response = mockk<APIResponse>()
            every { response.getResponse(any(), NewsBlurResponse::class.java) } returns answer(body)
            response
        }
    }

    /**
     * A trainer save with a feed prompt moved to global, an edit to a global prompt and a removal
     * of a folder prompt: a feed save, then a global and a folder request.
     */
    private fun classifier(): Classifier {
        val classifier =
            Gson().fromJson(
                """
                {
                  "prompts": {"Feed prompt": 1, "Crypto": 1, "Local politics": -1},
                  "prompts_scope": {
                    "Crypto": {"scope": "global", "folder_name": ""},
                    "Local politics": {"scope": "folder", "folder_name": "News"}
                  }
                }
                """.trimIndent(),
                Classifier::class.java,
            )
        val original = classifier.copyPrompts()
        classifier.setPromptScope(false, "Feed prompt", ClassifierScope.GLOBAL_SCOPE)
        classifier.prompts["Crypto"] = Classifier.DISLIKE
        classifier.prompts["Local politics"] = Classifier.CLEAR_DISLIKE
        classifier.recordScopedPromptChanges(original)
        return classifier
    }

    private fun isFeedSave(body: String) = "scope=" !in body

    private fun isGlobal(body: String) = "scope=global" in body

    private fun isFolder(body: String) = "scope=folder" in body

    @Test
    fun test_a_failed_feed_save_sends_no_scoped_saves() =
        runTest {
            respond { body -> if (isFeedSave(body)) networkError else ok }

            val result = feedApi.updateFeedIntel("42", classifier())

            assertSame(networkError, result)
            assertEquals("Only the feed save went out: $bodies", 1, bodies.size)

            bodies.clear()
            respond { body -> if (isFeedSave(body)) archiveRequired else ok }

            assertSame(archiveRequired, feedApi.updateFeedIntel("42", classifier()))
            assertEquals("Only the feed save went out: $bodies", 1, bodies.size)
        }

    @Test
    fun test_a_failed_scoped_save_still_runs_the_others_and_reports_its_error() =
        runTest {
            respond { body -> if (isFolder(body)) archiveRequired else ok }

            val result = feedApi.updateFeedIntel("42", classifier())

            assertSame("The folder failure surfaces after the rest ran", archiveRequired, result)
            assertTrue(isFeedSave(bodies[0]))
            val global = bodies.single(::isGlobal)
            assertTrue(global, "dislike_prompt=Crypto" in global && "like_prompt=Feed+prompt" in global)
            val folder = bodies.single(::isFolder)
            assertTrue(folder, "remove_dislike_prompt=Local+politics" in folder && "folder_name=News" in folder)
            val removal = bodies.last()
            assertTrue("The moved prompt left the feed once global saved: $removal", "scope=feed" in removal)
            assertTrue(removal, "remove_like_prompt=Feed+prompt" in removal && "feed_id=42" in removal)
            assertEquals(4, bodies.size)
        }

    @Test
    fun test_a_prompt_whose_new_scope_failed_keeps_its_original() =
        runTest {
            respond { body -> if (isGlobal(body)) archiveRequired else ok }

            val result = feedApi.updateFeedIntel("42", classifier())

            assertSame(archiveRequired, result)
            assertEquals("The folder save still ran: $bodies", 1, bodies.count(::isFolder))
            assertFalse(
                "The feed copy stays while its global copy didn't save: $bodies",
                bodies.any { "remove_like_prompt=Feed+prompt" in it },
            )
        }

    @Test
    fun test_a_network_error_is_reported_over_a_server_message_so_the_action_retries() =
        runTest {
            respond { body ->
                when {
                    isGlobal(body) -> archiveRequired
                    isFolder(body) -> networkError
                    else -> ok
                }
            }

            val result = feedApi.updateFeedIntel("42", classifier())

            assertSame(networkError, result)
            assertEquals(3, bodies.size)
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
