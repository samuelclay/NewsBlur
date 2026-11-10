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

// Test_FeedIntelScopedSaves.kt: FeedApiImpl.updateFeedIntel sends folder and global classifier
// changes (AI prompts, titles, authors, tags, text and URLs) only after the feed save lands, tries
// every scope even when one fails, and removes a moved classifier's old copy only once its new
// scope saved.
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
        val original = classifier.snapshot()
        classifier.setPromptScope(false, "Feed prompt", ClassifierScope.GLOBAL_SCOPE)
        classifier.prompts["Crypto"] = Classifier.DISLIKE
        classifier.prompts["Local politics"] = Classifier.CLEAR_DISLIKE
        classifier.recordChanges(original)
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

    @Test
    fun test_a_folder_scope_without_a_folder_never_reaches_the_server() =
        runTest {
            respond { ok }
            val classifier = Gson().fromJson("""{"prompts": {"Feed prompt": 1}}""", Classifier::class.java)
            val original = classifier.snapshot()
            // Test_FeedIntelScopedSaves.kt writes the map directly, past setPromptScope's guard.
            classifier.promptsScope["Feed prompt"] = ClassifierScope.folder("")
            classifier.recordChanges(original)

            feedApi.updateFeedIntel("42", classifier)

            assertEquals("Only the feed save went out: $bodies", 1, bodies.size)
            assertFalse(bodies.single(), "scope=" in bodies.single() || "remove_like_prompt" in bodies.single())
        }

    /**
     * Titles, authors and tags take the same path: a global title edit, a feed author moved to a
     * folder, and an untouched global tag that must not go out at all.
     */
    private fun phraseClassifier(): Classifier {
        val classifier =
            Gson().fromJson(
                """
                {
                  "titles": {"[Sponsor]": -2},
                  "authors": {"John Gruber": 1},
                  "tags": {"tech": -1},
                  "titles_scope": {"[Sponsor]": {"scope": "global", "folder_name": ""}},
                  "tags_scope": {"tech": {"scope": "global", "folder_name": ""}}
                }
                """.trimIndent(),
                Classifier::class.java,
            )
        val original = classifier.snapshot()
        classifier.title["[Sponsor]"] = Classifier.DISLIKE
        classifier.setScope(Classifier.AUTHOR, "John Gruber", ClassifierScope.folder("Tech"))
        classifier.recordChanges(original)
        return classifier
    }

    @Test
    fun test_scoped_titles_and_authors_go_out_at_their_scope_after_the_feed_save() =
        runTest {
            respond { ok }

            assertSame(ok, feedApi.updateFeedIntel("42", phraseClassifier()))

            assertTrue(isFeedSave(bodies[0]))
            val feedSave = bodies[0]
            assertFalse("Nothing scoped is sent at feed scope: $feedSave", listOf("Sponsor", "Gruber", "tech").any { it in feedSave })
            val global = bodies.single(::isGlobal)
            assertTrue(global, "dislike_title=%5BSponsor%5D" in global)
            assertFalse("The untouched global tag isn't sent: $global", "tech" in global)
            val folder = bodies.single(::isFolder)
            assertTrue(folder, "like_author=John+Gruber" in folder && "folder_name=Tech" in folder)
            val removal = bodies.last()
            assertTrue("The moved author left the feed once its folder saved: $removal", "scope=feed" in removal)
            assertTrue(removal, "remove_like_author=John+Gruber" in removal)
            assertEquals(4, bodies.size)
        }

    @Test
    fun test_a_failed_folder_save_keeps_the_feed_author_and_reports_after_the_rest() =
        runTest {
            respond { body -> if (isFolder(body)) archiveRequired else ok }

            val result = feedApi.updateFeedIntel("42", phraseClassifier())

            assertSame(archiveRequired, result)
            assertEquals("The global title still saved: $bodies", 1, bodies.count(::isGlobal))
            assertFalse("The feed copy stays: $bodies", bodies.any { "remove_like_author" in it })
        }

    @Test
    fun test_a_failed_feed_save_sends_no_scoped_titles_or_authors() =
        runTest {
            respond { body -> if (isFeedSave(body)) networkError else ok }

            assertSame(networkError, feedApi.updateFeedIntel("42", phraseClassifier()))
            assertEquals("Only the feed save went out: $bodies", 1, bodies.size)
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
