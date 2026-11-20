package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteBlobTooBigException
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDoneException
import android.database.sqlite.SQLiteStatement
import io.mockk.every
import io.mockk.mockk
import java.sql.Connection
import java.sql.DriverManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class Test_LargeStoryContent {
    private lateinit var connection: Connection
    private lateinit var helper: BlurDatabaseHelper

    @Before
    fun setUp() {
        connection = DriverManager.getConnection("jdbc:sqlite::memory:")
        connection.createStatement().use {
            it.execute("CREATE TABLE stories (story_hash TEXT PRIMARY KEY, content TEXT)")
            it.execute("CREATE TABLE storytext (story_hash TEXT PRIMARY KEY, story_text TEXT)")
        }
        val database = mockk<SQLiteDatabase>()
        helper = mockk()
        BlurDatabaseHelper::class.java.getDeclaredField("dbRO").apply {
            isAccessible = true
            set(helper, database)
        }
        every { helper.getStoryContent(any()) } answers { callOriginal() }
        every { helper.getStoryText(any()) } answers { callOriginal() }
        every { helper["readStoryString"](any<String>(), any<String>()) } answers { callOriginal() }
        every { database.rawQuery(any(), any()) } answers {
            val query = connection.prepareStatement(firstArg<String>())
            secondArg<Array<String>>().forEachIndexed { index, value -> query.setString(index + 1, value) }
            val rows = query.executeQuery()
            mockk<Cursor>().also { cursor ->
                every { cursor.moveToFirst() } answers {
                    val exists = rows.next()
                    // Test_LargeStoryContent.kt models Android's 2 MiB CursorWindow limit over real SQLite results.
                    if (exists && (rows.getString(1)?.toByteArray()?.size ?: 0) > 2 * 1024 * 1024) {
                        throw mockk<SQLiteBlobTooBigException>(relaxed = true).also { error ->
                            every { error.cause } returns null
                            every { error.message } returns "Row too big to fit into CursorWindow"
                        }
                    }
                    exists
                }
                every { cursor.getColumnIndexOrThrow(any()) } returns 0
                every { cursor.getString(0) } answers { rows.getString(1) }
                every { cursor.close() } answers { rows.close(); query.close() }
            }
        }
        every { database.compileStatement(any()) } answers {
            val query = connection.prepareStatement(firstArg<String>())
            mockk<SQLiteStatement>().also { statement ->
                every { statement.bindString(any(), any()) } answers {
                    query.setString(firstArg(), secondArg())
                }
                every { statement.simpleQueryForString() } answers {
                    query.executeQuery().use { rows ->
                        if (!rows.next()) throw mockk<SQLiteDoneException>(relaxed = true).also { error ->
                            every { error.cause } returns null
                        }
                        rows.getString(1)
                    }
                }
                every { statement.close() } answers { query.close() }
            }
        }
    }

    @After
    fun tearDown() = connection.close()

    @Test
    fun test_large_cached_article_is_returned_without_truncation() {
        val content = "<p>漢字🚀</p>".repeat(160_000)
        insert("stories", "content", content)
        assertEquals(content, helper.getStoryContent("42:large"))
    }

    @Test
    fun test_large_cached_text_view_is_returned_without_truncation() {
        val content = "<p>Full text</p>".repeat(160_000)
        insert("storytext", "story_text", content)
        assertEquals(content, helper.getStoryText("42:large"))
    }

    @Test
    fun test_missing_article_and_text_remain_cache_misses() {
        assertNull(helper.getStoryContent("42:missing"))
        assertNull(helper.getStoryText("42:missing"))
    }

    private fun insert(table: String, column: String, content: String) {
        connection.prepareStatement("INSERT INTO $table (story_hash, $column) VALUES (?, ?)").use {
            it.setString(1, "42:large")
            it.setString(2, content)
            it.executeUpdate()
        }
    }
}
