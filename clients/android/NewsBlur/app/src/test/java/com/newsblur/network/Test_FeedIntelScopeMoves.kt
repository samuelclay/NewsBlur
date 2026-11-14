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
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URLDecoder

// Test_FeedIntelScopeMoves.kt: FeedApiImpl.updateFeedIntel moves classifiers between scopes against
// a server that keeps what it saved. Folder and global classifiers share feed_id 0, and a tag or
// author can exist there only once, so a move between those scopes removes the old copy before
// saving the new one and puts the original back if that save fails. A move to or from feed scope
// saves the new copy first.
class Test_FeedIntelScopeMoves {
    private val networkClient = mockk<NetworkClient>()
    private val feedApi = FeedApiImpl(Gson(), networkClient)
    private val server = FakeClassifierServer()

    init {
        coEvery { networkClient.post(any(), any<ValueMultimap>()) } answers {
            val answer = server.answer(form(secondArg()))
            val response = mockk<APIResponse>()
            every { response.getResponse(any(), NewsBlurResponse::class.java) } returns answer
            response
        }
    }

    /** A trainer that opened on [payload] and moved [key] of [type] to [scope], with a new [score] if given. */
    private fun moved(
        payload: String,
        type: Int,
        key: String,
        scope: ClassifierScope,
        score: Int? = null,
    ): Classifier {
        val classifier = Gson().fromJson(payload, Classifier::class.java)
        val original = classifier.snapshot()
        classifier.setScope(type, key, scope)
        if (score != null) classifier.scores(type)[key] = score
        classifier.recordChanges(original)
        return classifier
    }

    private val folderTag = """{"tags": {"tech": -2}, "tags_scope": {"tech": {"scope": "folder", "folder_name": "Tech"}}}"""

    private fun folderTagMovedToGlobal(score: Int? = null) = moved(folderTag, Classifier.TAG, "tech", ClassifierScope.GLOBAL_SCOPE, score)

    @Test
    fun test_a_folder_tag_moved_to_global_ends_with_one_global_copy() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)

            val result = feedApi.updateFeedIntel("42", folderTagMovedToGlobal())

            assertFalse("The move succeeded: ${result?.message} ${server.bodies}", result!!.isError)
            assertEquals(listOf(Stored("tag", "tech", "0", "global", "", -2)), server.stored)
        }

    @Test
    fun test_a_global_author_moved_to_a_folder_ends_with_one_folder_copy() =
        runTest {
            server.stored += Stored("author", "John Gruber", "0", "global", "", 1)
            val payload = """{"authors": {"John Gruber": 1}, "authors_scope": {"John Gruber": {"scope": "global", "folder_name": ""}}}"""

            val result = feedApi.updateFeedIntel("42", moved(payload, Classifier.AUTHOR, "John Gruber", ClassifierScope.folder("Tech")))

            assertFalse("The move succeeded: ${result?.message} ${server.bodies}", result!!.isError)
            assertEquals(listOf(Stored("author", "John Gruber", "0", "folder", "Tech", 1)), server.stored)
        }

    @Test
    fun test_a_tag_moved_between_folders_ends_with_one_copy_in_the_new_folder() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)

            val result = feedApi.updateFeedIntel("42", moved(folderTag, Classifier.TAG, "tech", ClassifierScope.folder("News")))

            assertFalse("The move succeeded: ${result?.message} ${server.bodies}", result!!.isError)
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "News", -2)), server.stored)
        }

    @Test
    fun test_a_refused_new_scope_save_restores_the_original_with_its_old_score() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)
            server.refused = { "scope=global" in it }

            val result = feedApi.updateFeedIntel("42", folderTagMovedToGlobal(Classifier.LIKE))

            assertEquals(FakeClassifierServer.ARCHIVE_REQUIRED, result?.message)
            assertFalse("A server message ends the action", result!!.isProtocolError)
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "Tech", -2)), server.stored)
            assertTrue("The restore went out after the refused save: ${server.bodies}", "super_dislike_tag=tech" in server.bodies.last())
        }

    @Test
    fun test_an_unreachable_new_scope_restores_the_original_and_retries_the_move() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)
            server.unreachable = { "scope=global" in it }
            val classifier = folderTagMovedToGlobal(Classifier.LIKE)

            val result = feedApi.updateFeedIntel("42", classifier)

            assertTrue("A network error keeps the action queued", result!!.isProtocolError)
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "Tech", -2)), server.stored)

            server.unreachable = { false }
            assertFalse(feedApi.updateFeedIntel("42", classifier)!!.isError)
            assertEquals(listOf(Stored("tag", "tech", "0", "global", "", 1)), server.stored)
        }

    @Test
    fun test_a_new_scope_save_whose_answer_was_lost_retries_to_a_single_copy() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)
            server.answerLost = { "scope=global" in it }
            val classifier = folderTagMovedToGlobal()

            val result = feedApi.updateFeedIntel("42", classifier)

            assertTrue("A network error keeps the action queued", result!!.isProtocolError)
            assertEquals(
                "The restore can't add a second copy beside the global one that landed",
                listOf(Stored("tag", "tech", "0", "global", "", -2)),
                server.stored,
            )

            server.answerLost = { false }
            assertFalse(feedApi.updateFeedIntel("42", classifier)!!.isError)
            assertEquals(listOf(Stored("tag", "tech", "0", "global", "", -2)), server.stored)
        }

    @Test
    fun test_a_title_whose_new_scope_answer_was_lost_retries_to_a_single_copy() =
        runTest {
            // Titles have no unique index, so the restore lands beside the global copy until the retry.
            server.stored += Stored("title", "[Sponsor]", "0", "global", "", -1)
            server.answerLost = { "scope=folder" in it }
            val payload = """{"titles": {"[Sponsor]": -1}, "titles_scope": {"[Sponsor]": {"scope": "global", "folder_name": ""}}}"""
            val classifier = moved(payload, Classifier.TITLE, "[Sponsor]", ClassifierScope.folder("Tech"))

            assertTrue(feedApi.updateFeedIntel("42", classifier)!!.isProtocolError)

            server.answerLost = { false }
            assertFalse(feedApi.updateFeedIntel("42", classifier)!!.isError)
            assertEquals(listOf(Stored("title", "[Sponsor]", "0", "folder", "Tech", -1)), server.stored)
        }

    @Test
    fun test_a_refused_removal_sends_nothing_else_for_the_move() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)
            server.refused = { "scope=folder" in it }

            val result = feedApi.updateFeedIntel("42", folderTagMovedToGlobal())

            assertEquals(FakeClassifierServer.ARCHIVE_REQUIRED, result?.message)
            assertFalse("Nothing went out at global: ${server.bodies}", server.bodies.any { "scope=global" in it })
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "Tech", -2)), server.stored)
        }

    @Test
    fun test_a_removal_whose_answer_was_lost_puts_the_original_back_and_retries() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)
            server.answerLost = { "remove_super_dislike_tag" in it }
            val classifier = folderTagMovedToGlobal()

            assertTrue(feedApi.updateFeedIntel("42", classifier)!!.isProtocolError)
            assertFalse("No global save follows a removal without an answer", server.bodies.any { "scope=global" in it })
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "Tech", -2)), server.stored)

            server.answerLost = { false }
            assertFalse(feedApi.updateFeedIntel("42", classifier)!!.isError)
            assertEquals(listOf(Stored("tag", "tech", "0", "global", "", -2)), server.stored)
        }

    @Test
    fun test_a_feed_tag_moved_to_a_folder_saves_the_folder_copy_first() =
        runTest {
            server.stored += Stored("tag", "tech", "42", "feed", "", 1)
            val classifier = moved("""{"tags": {"tech": 1}}""", Classifier.TAG, "tech", ClassifierScope.folder("Tech"))

            assertFalse(feedApi.updateFeedIntel("42", classifier)!!.isError)

            val folderSave = server.bodies.indexOfFirst { "like_tag=tech" in it && "scope=folder" in it }
            val feedRemoval = server.bodies.indexOfFirst { "remove_like_tag=tech" in it && "scope=feed" in it }
            assertTrue("The folder copy saves before the feed copy goes: ${server.bodies}", folderSave in 0 until feedRemoval)
            assertEquals(listOf(Stored("tag", "tech", "0", "folder", "Tech", 1)), server.stored)
        }

    @Test
    fun test_a_folder_tag_moved_to_feed_saves_the_feed_copy_first() =
        runTest {
            server.stored += Stored("tag", "tech", "0", "folder", "Tech", -2)

            assertFalse(feedApi.updateFeedIntel("42", moved(folderTag, Classifier.TAG, "tech", ClassifierScope.FEED_SCOPE))!!.isError)

            val feedSave = server.bodies.indexOfFirst { "super_dislike_tag=tech" in it && "scope=" !in it }
            val folderRemoval = server.bodies.indexOfFirst { "remove_super_dislike_tag=tech" in it && "scope=folder" in it }
            assertTrue("The feed copy saves before the folder copy goes: ${server.bodies}", feedSave in 0 until folderRemoval)
            assertEquals(listOf(Stored("tag", "tech", "42", "feed", "", -2)), server.stored)
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}

/** One classifier the fake server holds. A folder or global classifier has feed_id 0. */
private data class Stored(
    val type: String,
    val value: String,
    val feedId: String,
    val scope: String,
    val folderName: String,
    val score: Int,
)

/**
 * Test_FeedIntelScopeMoves.kt: apps/analyzer/views.py save_classifier for authors, tags and titles,
 * keeping what it saved. It enforces the unique index on (user_id, feed_id, social_user_id, value)
 * that MClassifierTag declares and production Mongo keeps for MClassifierAuthor, answering a
 * duplicate with that view's code -1 scope conflict.
 */
private class FakeClassifierServer {
    val stored = mutableListOf<Stored>()
    val bodies = mutableListOf<String>()

    // Requests this matches never reach the server and come back as network errors.
    var unreachable: (String) -> Boolean = { false }

    // Requests this matches are saved, but their answer is lost to a network error.
    var answerLost: (String) -> Boolean = { false }

    // Requests this matches are refused before saving anything, like the Premium Archive gate.
    var refused: (String) -> Boolean = { false }

    fun answer(body: String): NewsBlurResponse {
        bodies += body
        if (unreachable(body)) return NewsBlurResponse().apply { isProtocolError = true }
        if (refused(body)) return serverMessage(ARCHIVE_REQUIRED)
        val conflicts = save(params(body))
        if (answerLost(body)) return NewsBlurResponse().apply { isProtocolError = true }
        if (conflicts.isEmpty()) return NewsBlurResponse().apply { message = "OK" }
        return serverMessage(
            "\"${conflicts.first()}\" is already trained for all sites or in another folder. " +
                "Change the scope on that classifier instead.",
        )
    }

    private fun serverMessage(text: String): NewsBlurResponse =
        NewsBlurResponse().apply {
            code = -1
            message = text
        }

    private fun params(body: String): List<Pair<String, String>> =
        body.split("&").filter { it.isNotEmpty() }.map { pair ->
            val (key, value) = pair.split("=", limit = 2)
            URLDecoder.decode(key, "UTF-8") to URLDecoder.decode(value, "UTF-8")
        }

    /** Saves every opinion in [params] the way save_classifier does, returning the values that conflicted. */
    private fun save(params: List<Pair<String, String>>): List<String> {
        val scope = params.firstOrNull { it.first == "scope" }?.second ?: "feed"
        val feedId = if (scope == "feed") params.first { it.first == "feed_id" }.second else "0"
        val folderName = if (scope == "folder") params.first { it.first == "folder_name" }.second else ""
        val conflicts = mutableListOf<String>()
        for ((key, value) in params) {
            val (score, type) = opinion(key) ?: continue
            val saved = Stored(type, value, feedId, scope, folderName, score)
            val existing = stored.firstOrNull { it.copy(score = score) == saved }
            when {
                existing == null && score == 0 -> Unit
                existing == null && type in UNIQUE_TYPES && stored.any { it.sharesUniqueIndexWith(saved) } -> conflicts += value
                existing == null -> stored += saved
                score == 0 -> stored.remove(existing)
                else -> stored[stored.indexOf(existing)] = saved
            }
        }
        return conflicts
    }

    // The unique index leaves out scope and folder_name, which is what makes folder and global collide.
    private fun Stored.sharesUniqueIndexWith(other: Stored): Boolean = type == other.type && value == other.value && feedId == other.feedId

    private fun opinion(key: String): Pair<Int, String>? =
        OPINIONS.firstOrNull { (prefix, _) -> key.startsWith(prefix) }?.let { (prefix, score) -> score to key.removePrefix(prefix) }

    companion object {
        const val ARCHIVE_REQUIRED = "Premium Archive required for folder and global classifiers"

        private val UNIQUE_TYPES = setOf("tag", "author")

        // Longest prefixes first, so remove_like_ isn't read as like_.
        private val OPINIONS =
            listOf(
                "remove_super_dislike_" to 0,
                "remove_dislike_" to 0,
                "remove_like_" to 0,
                "super_dislike_" to -2,
                "dislike_" to -1,
                "like_" to 1,
            )
    }
}
