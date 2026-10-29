package com.newsblur.domain

import android.content.ContentValues
import android.database.Cursor
import com.google.gson.Gson
import com.newsblur.database.DatabaseConstants
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkAll
import okio.Buffer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_ClassifierPrompts.kt: AI prompt classifiers parse from the classifier payload, map to the
// /classifier/save keys in apps/analyzer/views.py, and never resend a folder or global prompt at
// feed scope, which would create a duplicate prompt that runs and bills twice.
class Test_ClassifierPrompts {
    private val payload =
        """
        {
          "authors": {"Daring Fireball Department of Commerce": -1},
          "prompts": {"Non-apple related news": 1, "Sports": -1, "Crypto": 1},
          "image_prompts": {"Food photography": -1},
          "prompts_scope": {"Crypto": {"scope": "global", "folder_name": ""}},
          "image_prompts_scope": {"Food photography": {"scope": "folder", "folder_name": "Blogs - Tumblrs"}}
        }
        """.trimIndent()

    @After
    fun tearDown() = unmockkAll()

    private fun classifier(): Classifier = Gson().fromJson(payload, Classifier::class.java)

    @Test
    fun test_prompts_and_scopes_parse_from_classifier_payload() {
        val classifier = classifier()

        assertEquals(mapOf("Non-apple related news" to 1, "Sports" to -1, "Crypto" to 1), classifier.prompts)
        assertEquals(mapOf("Food photography" to -1), classifier.imagePrompts)
        assertEquals(ClassifierScope.GLOBAL_SCOPE, classifier.promptScope(false, "Crypto"))
        assertEquals(ClassifierScope.folder("Blogs - Tumblrs"), classifier.promptScope(true, "Food photography"))
        assertEquals(ClassifierScope.FEED_SCOPE, classifier.promptScope(false, "Sports"))
    }

    @Test
    fun test_classifier_payload_without_prompts_keeps_empty_maps() {
        val classifier = Gson().fromJson("""{"authors": {}}""", Classifier::class.java)

        assertTrue(classifier.prompts.isEmpty())
        assertTrue(classifier.imagePromptsScope.isEmpty())
        assertTrue(classifier.getScopedPromptRequests().isEmpty())
    }

    @Test
    fun test_feed_scoped_prompts_map_to_save_keys() {
        val classifier = classifier()
        classifier.prompts["Sports"] = Classifier.CLEAR_DISLIKE
        classifier.prompts["New topic"] = Classifier.DISLIKE
        classifier.imagePrompts["Charts"] = Classifier.LIKE
        classifier.imagePrompts["Memes"] = Classifier.CLEAR_LIKE

        val body = form(classifier.getAPITuples())

        assertTrue(body, "like_prompt=Non-apple+related+news" in body)
        assertTrue(body, "remove_dislike_prompt=Sports" in body)
        assertTrue(body, "dislike_prompt=New+topic" in body)
        assertTrue(body, "like_image_prompt=Charts" in body)
        assertTrue(body, "remove_like_image_prompt=Memes" in body)
        assertTrue("Folder and global prompts stay out of the feed save: $body", "Crypto" !in body && "Food+photography" !in body)
        assertTrue("Prompts have no super dislike key: $body", "super_dislike_prompt" !in body)
    }

    @Test
    fun test_unchanged_scoped_prompts_send_nothing() {
        val classifier = classifier()

        classifier.recordScopedPromptChanges(classifier.copyPrompts())

        assertTrue(classifier.scopedPromptSaves.isEmpty())
        assertTrue(classifier.getScopedPromptRequests().isEmpty())
    }

    @Test
    fun test_editing_a_global_prompt_saves_at_global_scope() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.prompts["Crypto"] = Classifier.DISLIKE
        classifier.imagePrompts["Food photography"] = Classifier.CLEAR_DISLIKE

        classifier.recordScopedPromptChanges(original)
        val requests = classifier.getScopedPromptRequests().associateBy { it.scope }

        assertEquals(setOf(ClassifierScope.GLOBAL_SCOPE, ClassifierScope.folder("Blogs - Tumblrs")), requests.keys)
        assertEquals("dislike_prompt=Crypto", form(requests.getValue(ClassifierScope.GLOBAL_SCOPE).values))
        assertEquals("remove_dislike_image_prompt=Food+photography", form(requests.getValue(ClassifierScope.folder("Blogs - Tumblrs")).values))
    }

    @Test
    fun test_moving_a_feed_prompt_to_global_removes_the_feed_copy_once_global_saves() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.setPromptScope(false, "Non-apple related news", ClassifierScope.GLOBAL_SCOPE)

        classifier.recordScopedPromptChanges(original)

        assertTrue("The feed save leaves the feed copy alone", "Non-apple" !in form(classifier.getAPITuples()))
        assertEquals("like_prompt=Non-apple+related+news", form(classifier.getScopedPromptRequests().single().values))
        val removal = classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE, ClassifierScope.GLOBAL_SCOPE)).single()
        assertEquals(ClassifierScope.FEED_SCOPE, removal.scope)
        assertEquals("remove_like_prompt=Non-apple+related+news", form(removal.values))
        assertTrue(
            "A global save that failed keeps the feed copy",
            classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE)).isEmpty(),
        )
    }

    @Test
    fun test_moving_a_global_prompt_to_feed_removes_the_global_copy_once_the_feed_saves() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.setPromptScope(false, "Crypto", ClassifierScope.FEED_SCOPE)

        classifier.recordScopedPromptChanges(original)

        assertTrue("like_prompt=Crypto" in form(classifier.getAPITuples()))
        assertTrue(classifier.getScopedPromptRequests().isEmpty())
        val request = classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE)).single()
        assertEquals(ClassifierScope.GLOBAL_SCOPE, request.scope)
        assertEquals("remove_like_prompt=Crypto", form(request.values))
    }

    @Test
    fun test_a_prompt_moved_and_removed_drops_its_old_copy_right_away() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.setPromptScope(false, "Non-apple related news", ClassifierScope.GLOBAL_SCOPE)
        classifier.prompts["Non-apple related news"] = Classifier.CLEAR_LIKE
        classifier.setPromptScope(false, "Crypto", ClassifierScope.folder("News"))
        classifier.prompts["Crypto"] = Classifier.CLEAR_LIKE

        classifier.recordScopedPromptChanges(original)

        assertTrue("remove_like_prompt=Non-apple+related+news" in form(classifier.getAPITuples()))
        val globalRemoval = classifier.getScopedPromptRequests().single()
        assertEquals(ClassifierScope.GLOBAL_SCOPE, globalRemoval.scope)
        assertEquals("remove_like_prompt=Crypto", form(globalRemoval.values))
        assertTrue("Nothing waits on a new scope", classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE)).isEmpty())
    }

    @Test
    fun test_a_folder_scope_without_a_folder_keeps_the_prompt_where_it_was() {
        val classifier = classifier()
        val original = classifier.copyPrompts()

        // A top-level feed has no folder path, which would make a folder scope with an empty name.
        classifier.setPromptScope(false, "Non-apple related news", ClassifierScope.folder(""))
        classifier.recordScopedPromptChanges(original)

        assertEquals(ClassifierScope.FEED_SCOPE, classifier.promptScope(false, "Non-apple related news"))
        assertTrue(classifier.scopedPromptSaves.isEmpty())
        assertTrue("like_prompt=Non-apple+related+news" in form(classifier.getAPITuples()))
    }

    @Test
    fun test_a_folder_scope_without_a_folder_never_goes_out_or_removes_the_original() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        // Test_ClassifierPrompts.kt writes the map directly, past setPromptScope's guard.
        classifier.promptsScope["Sports"] = ClassifierScope.folder("")

        classifier.recordScopedPromptChanges(original)

        assertTrue(classifier.scopedPromptSaves.isEmpty())
        val everyScope = setOf(ClassifierScope.FEED_SCOPE, ClassifierScope.GLOBAL_SCOPE, ClassifierScope.folder(""))
        assertTrue(classifier.getMoveRemovalRequests(everyScope).isEmpty())
        assertTrue("Sports" !in form(classifier.getAPITuples()))

        // A queued save from before the guard is dropped rather than sent as a global prompt.
        classifier.scopedPromptSaves.add(ScopedPromptSave(ClassifierScope.folder(""), false, "Sports", Classifier.DISLIKE))
        assertTrue(classifier.getScopedPromptRequests().isEmpty())
    }

    @Test
    fun test_new_folder_prompt_saves_only_at_folder_scope() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.prompts["Local politics"] = Classifier.LIKE
        classifier.setPromptScope(false, "Local politics", ClassifierScope.folder("News"))

        classifier.recordScopedPromptChanges(original)

        assertTrue("Local" !in form(classifier.getAPITuples()))
        val request = classifier.getScopedPromptRequests().single()
        assertEquals(ClassifierScope.folder("News"), request.scope)
        assertEquals("like_prompt=Local+politics", form(request.values))
    }

    @Test
    fun test_scoped_saves_survive_the_queued_action_json() {
        val classifier = classifier()
        val original = classifier.copyPrompts()
        classifier.prompts["Crypto"] = Classifier.CLEAR_LIKE
        classifier.recordScopedPromptChanges(original)

        val restored = Gson().fromJson(Gson().toJson(classifier), Classifier::class.java)

        assertEquals(classifier.scopedPromptSaves, restored.scopedPromptSaves)
        assertEquals("remove_like_prompt=Crypto", form(restored.getScopedPromptRequests().single().values))
    }

    @Test
    fun test_prompts_and_scopes_round_trip_through_classifier_table() {
        val classifier = classifier().apply { feedId = "5719953" }
        // Test_ClassifierPrompts.kt: every row starts with its CLASSIFIER_ID, so the put sequence splits into rows.
        val rows = mutableListOf<MutableMap<String, Any?>>()
        fun store(key: String, value: Any?) {
            if (key == DatabaseConstants.CLASSIFIER_ID) rows.add(mutableMapOf())
            rows.last()[key] = value
        }
        mockkConstructor(ContentValues::class)
        every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } answers { store(firstArg(), secondArg<String?>()) }
        every { anyConstructed<ContentValues>().put(any<String>(), any<Int>()) } answers { store(firstArg(), secondArg<Int?>()) }

        val rowCount = classifier.getContentValues().size
        assertEquals(rowCount, rows.size)
        // Test_ClassifierPrompts.kt replays the rows the way SQLite's TEXT value column returns them.
        val columns = listOf(DatabaseConstants.CLASSIFIER_KEY, DatabaseConstants.CLASSIFIER_VALUE, DatabaseConstants.CLASSIFIER_TYPE)
        var position = -1
        val cursor = mockk<Cursor>()
        every { cursor.getColumnIndexOrThrow(any()) } answers { columns.indexOf(firstArg<String>()) }
        every { cursor.moveToNext() } answers { ++position < rows.size }
        every { cursor.getString(any()) } answers { rows[position][columns[firstArg()]]?.toString() }
        every { cursor.getInt(any()) } answers { rows[position][columns[firstArg()]].toString().toIntOrNull() ?: 0 }

        val restored = Classifier.fromCursor(cursor)

        assertEquals(classifier.prompts, restored.prompts)
        assertEquals(classifier.imagePrompts, restored.imagePrompts)
        assertEquals(classifier.promptsScope, restored.promptsScope)
        assertEquals(classifier.imagePromptsScope, restored.imagePromptsScope)
        assertEquals(classifier.authors, restored.authors)
    }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
