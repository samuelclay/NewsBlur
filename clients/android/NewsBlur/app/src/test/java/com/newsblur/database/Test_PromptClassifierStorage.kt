package com.newsblur.database

import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.text.TextUtils
import com.google.gson.Gson
import com.newsblur.domain.PromptClassifierMatch
import com.newsblur.domain.Story
import com.newsblur.fragment.ReaderMetadataSnapshot
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import java.sql.Connection
import java.sql.DriverManager
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

// Test_PromptClassifierStorage.kt: AI prompt matches arrive on the story API, survive the trip
// through the stories table so the reading header can show them offline, and get a column on
// upgrade without losing cached stories or queued offline actions.
class Test_PromptClassifierStorage {
    private lateinit var connection: Connection
    private lateinit var database: SQLiteDatabase
    private lateinit var helper: BlurDatabase

    private val apiStoryJson =
        """
        {
          "story_hash": "5719953:1b4552",
          "story_title": "[Sponsor] WorkOS",
          "story_authors": "Daring Fireball Department of Commerce",
          "intelligence": {"feed": 0, "author": -1, "prompt": 1},
          "prompt_classifiers": [
            {"prompt": "Non-apple related news", "score": 1, "include_images": false},
            {"prompt": "Photos of keynotes", "score": -1, "include_images": true}
          ]
        }
        """.trimIndent()

    @Before
    fun setUp() {
        connection = DriverManager.getConnection("jdbc:sqlite::memory:")
        database = mockk()
        helper = mockk()
        every { helper.onCreate(any()) } answers { callOriginal() }
        every { helper.onUpgrade(any(), any(), any()) } answers { callOriginal() }
        every { database.execSQL(any()) } answers {
            connection.createStatement().use { it.execute(firstArg<String>()) }
            Unit
        }
        every { database.query(any(), any(), any(), any(), any(), any(), any()) } answers {
            // Test_PromptClassifierStorage.kt executes production migration SQL in real SQLite.
            val columns = secondArg<Array<String>?>()?.joinToString(", ") ?: "*"
            val selection = thirdArg<String?>()?.let { " WHERE $it" } ?: ""
            val statement = connection.prepareStatement("SELECT $columns FROM ${firstArg<String>()}$selection")
            val result = statement.executeQuery()
            mockk<Cursor>().also { cursor ->
                every { cursor.moveToNext() } answers { result.next() }
                every { cursor.getString(any()) } answers { result.getString(firstArg<Int>() + 1) }
                every { cursor.close() } answers { result.close(); statement.close() }
            }
        }
        helper.onCreate(database)
    }

    @After
    fun tearDown() {
        connection.close()
        unmockkAll()
    }

    @Test
    fun test_story_api_prompt_classifiers_parse_into_story() {
        val story = Gson().fromJson(apiStoryJson, Story::class.java)

        assertEquals(2, story.promptClassifiers.size)
        assertEquals(PromptClassifierMatch("Non-apple related news", 1, false), story.promptClassifiers[0])
        assertEquals(PromptClassifierMatch("Photos of keynotes", -1, true), story.promptClassifiers[1])
        assertEquals("An AI focus match outranks the disliked author", 1, story.intelligence.calcTotalIntel())
    }

    @Test
    fun test_stories_without_prompt_classifiers_default_to_empty() {
        val story = Gson().fromJson("""{"story_hash": "1:a"}""", Story::class.java)

        assertEquals(0, story.promptClassifiers.size)
        assertEquals(null, PromptClassifierMatch.toJson(story.promptClassifiers))
        assertEquals(0, PromptClassifierMatch.fromJson(null).size)
        assertEquals(0, PromptClassifierMatch.fromJson("not json").size)
    }

    @Test
    fun test_sanitize_drops_null_and_blank_entries() {
        val cleaned =
            PromptClassifierMatch.sanitize(
                arrayOf(null, PromptClassifierMatch("", 1), PromptClassifierMatch("Kept", -1), PromptClassifierMatch("Zero", 0)),
            )

        assertArrayEquals(arrayOf(PromptClassifierMatch("Kept", -1)), cleaned)
    }

    @Test
    fun test_prompt_classifiers_round_trip_through_story_values_and_cursor() {
        val story = Gson().fromJson(apiStoryJson, Story::class.java)
        val saved = linkedMapOf<String, Any?>()
        mockkConstructor(ContentValues::class)
        every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } answers { saved[firstArg()] = secondArg<String?>() }
        every { anyConstructed<ContentValues>().put(any<String>(), any<Int>()) } answers { saved[firstArg()] = secondArg<Int?>() }
        every { anyConstructed<ContentValues>().put(any<String>(), any<Long>()) } answers { saved[firstArg()] = secondArg<Long?>() }
        every { anyConstructed<ContentValues>().put(any<String>(), any<Boolean>()) } answers {
            saved[firstArg()] = if (secondArg<Boolean?>() == true) 1 else 0
        }
        mockkStatic(TextUtils::class)
        every { TextUtils.split(any(), any<String>()) } answers { firstArg<String?>().orEmpty().split(",").filter { it.isNotEmpty() }.toTypedArray() }
        every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
        every { TextUtils.join(any(), any<Array<Any?>>()) } answers { secondArg<Array<Any?>>().joinToString(firstArg<CharSequence>()) }

        story.getValues()
        val json = saved[DatabaseConstants.STORY_PROMPT_CLASSIFIERS] as String
        assertTrue("Matches are stored as JSON text: $json", json.contains("Non-apple related news"))

        // Test_PromptClassifierStorage.kt stores the saved row in real SQLite and reads it back.
        val columns = saved.keys.toList()
        connection.prepareStatement(
            "INSERT INTO stories (${columns.joinToString(", ")}) VALUES (${columns.joinToString(", ") { "?" }})",
        ).use { insert ->
            columns.forEachIndexed { index, column -> insert.setObject(index + 1, saved[column]) }
            insert.executeUpdate()
        }
        val restored = readStory("5719953:1b4552")

        assertArrayEquals(story.promptClassifiers, restored.promptClassifiers)
        assertEquals("Reading the story back must not rebuild the header", ReaderMetadataSnapshot(story).promptClassifiers, ReaderMetadataSnapshot(restored).promptClassifiers)
    }

    @Test
    fun test_reader_header_snapshot_changes_when_prompt_matches_change() {
        val story = Gson().fromJson(apiStoryJson, Story::class.java)
        val before = ReaderMetadataSnapshot(story)

        story.promptClassifiers = arrayOf(PromptClassifierMatch("Non-apple related news", -1, false))

        assertNotEquals(before, ReaderMetadataSnapshot(story))
    }

    @Test
    fun test_version_eleven_adds_columns_and_keeps_offline_state() = verifyUpgrade(11)

    @Test
    fun test_version_ten_chains_icon_repair_and_new_columns() = verifyUpgrade(10)

    @Test
    fun test_version_six_chains_every_step_and_new_columns() = verifyUpgrade(6)

    private fun verifyUpgrade(previousVersion: Int) {
        restoreVersionElevenStoryAndFeedTables()
        if (previousVersion < 11) database.execSQL("DROP TABLE custom_icons")
        if (previousVersion < 10) ClusterReadStore.dropTables(database)
        database.execSQL("INSERT INTO stories (story_hash, title) VALUES ('1:cached', 'Offline article')")
        database.execSQL("INSERT INTO feeds (_id, feed_name) VALUES (7, 'Daring Fireball')")
        database.execSQL("INSERT INTO story_actions (_id, time, action_params) VALUES (7, 1234, 'pending offline read')")

        helper.onUpgrade(database, previousVersion, BlurDatabase.VERSION)

        assertEquals("Offline article", value("SELECT title FROM stories WHERE story_hash = '1:cached'"))
        assertEquals("Daring Fireball", value("SELECT feed_name FROM feeds WHERE _id = 7"))
        assertEquals("pending offline read", value("SELECT action_params FROM story_actions WHERE _id = 7"))
        assertEquals("0", value("SELECT count(*) FROM custom_icons"))
        database.execSQL("UPDATE stories SET prompt_classifiers = '[{\"prompt\":\"AI\",\"score\":1}]' WHERE story_hash = '1:cached'")
        database.execSQL("UPDATE feeds SET stories_last_month = 42 WHERE _id = 7")
        assertEquals("AI", PromptClassifierMatch.fromJson(value("SELECT prompt_classifiers FROM stories WHERE story_hash = '1:cached'"))[0].prompt)
        assertEquals("42", value("SELECT stories_last_month FROM feeds WHERE _id = 7"))
    }

    private fun restoreVersionElevenStoryAndFeedTables() {
        // Test_PromptClassifierStorage.kt rebuilds the tables as version 11 shipped them, before the new columns.
        val storySql = DatabaseConstants.STORY_SQL.replace(", prompt_classifiers TEXT", "")
        val feedSql = DatabaseConstants.FEED_SQL.replace(", stories_last_month INTEGER", "")
        assertNotEquals(DatabaseConstants.STORY_SQL, storySql)
        assertNotEquals(DatabaseConstants.FEED_SQL, feedSql)
        database.execSQL("DROP TABLE stories")
        database.execSQL("DROP TABLE feeds")
        database.execSQL(storySql)
        database.execSQL(feedSql)
    }

    private fun readStory(storyHash: String): Story {
        val statement = connection.prepareStatement("SELECT * FROM stories WHERE story_hash = ?")
        statement.setString(1, storyHash)
        val result = statement.executeQuery()
        assertTrue(result.next())
        val columnNames = (1..result.metaData.columnCount).map { result.metaData.getColumnName(it) }
        val cursor = mockk<Cursor>()
        every { cursor.isBeforeFirst } returns false
        every { cursor.getColumnIndex(any()) } answers { columnNames.indexOf(firstArg<String>()) }
        every { cursor.getString(any()) } answers { result.getString(firstArg<Int>() + 1) }
        every { cursor.getInt(any()) } answers { result.getInt(firstArg<Int>() + 1) }
        every { cursor.getLong(any()) } answers { result.getLong(firstArg<Int>() + 1) }
        return Story.fromCursor(cursor).also {
            result.close()
            statement.close()
        }
    }

    private fun value(sql: String): String? =
        connection.createStatement().use { statement ->
            statement.executeQuery(sql).use { result ->
                assertTrue("Expected a preserved row: $sql", result.next())
                result.getString(1)
            }
        }
}
