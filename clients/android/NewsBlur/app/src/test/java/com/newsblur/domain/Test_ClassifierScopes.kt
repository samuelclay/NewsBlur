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

// Test_ClassifierScopes.kt: titles, authors, tags, text and URLs carry the folder and global scopes
// from apps/analyzer/models.py get_classifiers_for_user, like clients/ios/Classes/TrainerView.swift
// shows them. A folder or global classifier is never sent at feed scope (which used to make the
// server add a feed copy of it), and a scope move saves at the new scope before removing the old copy.
class Test_ClassifierScopes {
    private val payload =
        """
        {
          "feeds": {"42": 1},
          "authors": {"John Gruber": 1, "Daring Fireball Department of Commerce": -1},
          "titles": {"[Sponsor]": -2, "Apple": 1},
          "title_regex": {"^Linked": 1},
          "tags": {"tech": -1},
          "texts": {"WorkOS": -1},
          "urls": {"/linked/": 1},
          "titles_scope": {
            "[Sponsor]": {"scope": "global", "folder_name": ""},
            "^Linked": {"scope": "folder", "folder_name": "Tech - Apple"}
          },
          "authors_scope": {"Daring Fireball Department of Commerce": {"scope": "folder", "folder_name": "Tech"}},
          "tags_scope": {"tech": {"scope": "global", "folder_name": ""}},
          "texts_scope": {"WorkOS": {"scope": "folder", "folder_name": "Tech"}},
          "urls_scope": {}
        }
        """.trimIndent()

    @After
    fun tearDown() = unmockkAll()

    private fun classifier(): Classifier = Gson().fromJson(payload, Classifier::class.java)

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()

    @Test
    fun test_scopes_parse_from_the_classifier_payload() {
        val classifier = classifier()

        assertEquals(ClassifierScope.GLOBAL_SCOPE, classifier.scope(Classifier.TITLE, "[Sponsor]"))
        assertEquals(
            "A regex reads the titles scope too",
            ClassifierScope.folder("Tech - Apple"),
            classifier.scope(Classifier.TITLE_REGEX, "^Linked"),
        )
        assertEquals(ClassifierScope.folder("Tech"), classifier.scope(Classifier.AUTHOR, "Daring Fireball Department of Commerce"))
        assertEquals(ClassifierScope.GLOBAL_SCOPE, classifier.scope(Classifier.TAG, "tech"))
        assertEquals(ClassifierScope.folder("Tech"), classifier.scope(Classifier.TEXT, "WorkOS"))
        assertEquals(ClassifierScope.FEED_SCOPE, classifier.scope(Classifier.URL, "/linked/"))
        assertEquals(ClassifierScope.FEED_SCOPE, classifier.scope(Classifier.TITLE, "Apple"))
    }

    @Test
    fun test_untouched_scoped_classifiers_are_never_sent() {
        val classifier = classifier()

        classifier.recordChanges(classifier.snapshot())

        assertEquals("", form(classifier.getAPITuples()))
        assertTrue(classifier.getScopedRequests().isEmpty())
    }

    @Test
    fun test_editing_scoped_classifiers_saves_them_only_at_their_scope() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.title["[Sponsor]"] = Classifier.DISLIKE
        classifier.authors["Daring Fireball Department of Commerce"] = Classifier.CLEAR_DISLIKE
        classifier.tags["tech"] = Classifier.SUPER_DISLIKE
        classifier.titleRegex["^Linked"] = Classifier.CLEAR_LIKE
        classifier.authors["John Gruber"] = Classifier.DISLIKE

        classifier.recordChanges(original)
        val requests = classifier.getScopedRequests().associate { it.scope to form(it.values) }

        assertEquals("Only the feed author goes out at feed scope", "dislike_author=John+Gruber", form(classifier.getAPITuples()))
        val global = requests.getValue(ClassifierScope.GLOBAL_SCOPE)
        assertTrue(global, "dislike_title=%5BSponsor%5D" in global && "super_dislike_tag=tech" in global)
        assertEquals("remove_dislike_author=Daring+Fireball+Department+of+Commerce", requests.getValue(ClassifierScope.folder("Tech")))
        assertEquals("remove_like_title_regex=%5ELinked", requests.getValue(ClassifierScope.folder("Tech - Apple")))
    }

    @Test
    fun test_moving_a_feed_author_to_a_folder_removes_the_feed_copy_once_the_folder_saves() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.setScope(Classifier.AUTHOR, "John Gruber", ClassifierScope.folder("Tech"))

        classifier.recordChanges(original)

        assertEquals("The feed save leaves the feed copy alone", "", form(classifier.getAPITuples()))
        val save = classifier.getScopedRequests().single()
        assertEquals(ClassifierScope.folder("Tech"), save.scope)
        assertEquals("like_author=John+Gruber", form(save.values))
        val removal = classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE, ClassifierScope.folder("Tech"))).single()
        assertEquals(ClassifierScope.FEED_SCOPE, removal.scope)
        assertEquals("remove_like_author=John+Gruber", form(removal.values))
        assertTrue(
            "A folder save that failed keeps the feed copy",
            classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE)).isEmpty(),
        )
    }

    @Test
    fun test_moving_a_global_title_to_feed_saves_at_feed_then_removes_the_global_copy() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.setScope(Classifier.TITLE, "[Sponsor]", ClassifierScope.FEED_SCOPE)

        classifier.recordChanges(original)

        assertEquals("super_dislike_title=%5BSponsor%5D", form(classifier.getAPITuples()))
        assertTrue(classifier.getScopedRequests().isEmpty())
        val removal = classifier.getMoveRemovalRequests(setOf(ClassifierScope.FEED_SCOPE)).single()
        assertEquals(ClassifierScope.GLOBAL_SCOPE, removal.scope)
        assertEquals("remove_super_dislike_title=%5BSponsor%5D", form(removal.values))
    }

    @Test
    fun test_a_classifier_moved_and_cleared_drops_its_old_copy_right_away() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.setScope(Classifier.TEXT, "WorkOS", ClassifierScope.GLOBAL_SCOPE)
        classifier.texts["WorkOS"] = Classifier.CLEAR_DISLIKE

        classifier.recordChanges(original)

        val removal = classifier.getScopedRequests().single()
        assertEquals(ClassifierScope.folder("Tech"), removal.scope)
        assertEquals("remove_dislike_text=WorkOS", form(removal.values))
        assertTrue("Nothing waits on a new scope", classifier.getMoveRemovalRequests(setOf(ClassifierScope.GLOBAL_SCOPE)).isEmpty())
    }

    @Test
    fun test_a_new_classifier_saves_at_the_scope_it_was_given() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.urls["/sponsor/"] = Classifier.DISLIKE
        classifier.setScope(Classifier.URL, "/sponsor/", ClassifierScope.GLOBAL_SCOPE)

        classifier.recordChanges(original)

        assertEquals("", form(classifier.getAPITuples()))
        assertEquals("dislike_url=%2Fsponsor%2F", form(classifier.getScopedRequests().single().values))
    }

    @Test
    fun test_a_scope_change_on_a_classifier_without_an_opinion_sends_nothing() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.setScope(Classifier.TAG, "apple", ClassifierScope.GLOBAL_SCOPE)

        classifier.recordChanges(original)

        assertTrue(classifier.changes.isEmpty())
    }

    @Test
    fun test_the_publisher_and_a_folderless_folder_scope_stay_at_feed_scope() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.setScope(Classifier.FEED, "42", ClassifierScope.GLOBAL_SCOPE)
        // A top-level feed has no folder path, which would make a folder scope with an empty name.
        classifier.setScope(Classifier.AUTHOR, "John Gruber", ClassifierScope.folder(""))

        classifier.recordChanges(original)

        assertEquals(ClassifierScope.FEED_SCOPE, classifier.scope(Classifier.FEED, "42"))
        assertEquals(ClassifierScope.FEED_SCOPE, classifier.scope(Classifier.AUTHOR, "John Gruber"))
        assertTrue(classifier.changes.isEmpty())
        assertTrue(Classifier.canScope(Classifier.TITLE_REGEX))
        assertTrue(!Classifier.canScope(Classifier.FEED))
    }

    @Test
    fun test_scopes_round_trip_through_classifier_table() {
        val classifier = classifier().apply { feedId = "42" }
        // Test_ClassifierScopes.kt: every row starts with its CLASSIFIER_ID, so the put sequence splits into rows.
        val rows = mutableListOf<MutableMap<String, Any?>>()

        fun store(
            key: String,
            value: Any?,
        ) {
            if (key == DatabaseConstants.CLASSIFIER_ID) rows.add(mutableMapOf())
            rows.last()[key] = value
        }
        mockkConstructor(ContentValues::class)
        every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } answers { store(firstArg(), secondArg<String?>()) }
        every { anyConstructed<ContentValues>().put(any<String>(), any<Int>()) } answers { store(firstArg(), secondArg<Int?>()) }

        classifier.getContentValues()
        // Test_ClassifierScopes.kt replays the rows the way SQLite's TEXT value column returns them.
        val columns = listOf(DatabaseConstants.CLASSIFIER_KEY, DatabaseConstants.CLASSIFIER_VALUE, DatabaseConstants.CLASSIFIER_TYPE)
        var position = -1
        val cursor = mockk<Cursor>()
        every { cursor.getColumnIndexOrThrow(any()) } answers { columns.indexOf(firstArg<String>()) }
        every { cursor.moveToNext() } answers { ++position < rows.size }
        every { cursor.getString(any()) } answers { rows[position][columns[firstArg()]]?.toString() }
        every { cursor.getInt(any()) } answers { rows[position][columns[firstArg()]].toString().toIntOrNull() ?: 0 }

        val restored = Classifier.fromCursor(cursor)

        assertEquals(classifier.titlesScope, restored.titlesScope)
        assertEquals(classifier.authorsScope, restored.authorsScope)
        assertEquals(classifier.tagsScope, restored.tagsScope)
        assertEquals(classifier.textsScope, restored.textsScope)
        assertEquals(classifier.title, restored.title)
        assertEquals(classifier.titleRegex, restored.titleRegex)
        assertEquals(classifier.authors, restored.authors)
    }
}
