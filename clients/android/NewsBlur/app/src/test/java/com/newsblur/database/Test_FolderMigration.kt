package com.newsblur.database

import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.google.gson.Gson
import com.newsblur.util.AppConstants
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_FolderMigration {
    private val gson = Gson()
    private val columns = listOf(DatabaseConstants.FOLDER_NAME, DatabaseConstants.FOLDER_PARENT_NAMES,
        DatabaseConstants.FOLDER_CHILDREN_NAMES, DatabaseConstants.FOLDER_FEED_IDS)
    private val legacyRows = listOf(
        listOf("A ▸ B", gson.toJson(listOf(AppConstants.ROOT_FOLDER)), "[]", "[\"1\"]"),
        listOf("A", gson.toJson(listOf(AppConstants.ROOT_FOLDER)), "[\"B\"]", "[]"),
        listOf("B", gson.toJson(listOf(AppConstants.ROOT_FOLDER, "A")), "[]", "[\"2\"]"),
        listOf("Quotes \\\" ▸ back\\\\slash", "[]", "[]", "[\"3\"]"),
    )
    private val pendingValues = linkedMapOf<String, String>()

    @Before fun setUp() {
        mockkConstructor(ContentValues::class)
        every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } answers {
            pendingValues[firstArg()] = secondArg()
        }
    }

    @After fun tearDown() = unmockkConstructor(ContentValues::class)

    @Test fun test_version_six_migration_preserves_distinct_folders_with_the_same_display_path() = verifyMigration(6)

    @Test fun test_version_seven_migration_preserves_cached_folders_and_other_tables() = verifyMigration(7)

    @Test fun test_version_eight_migration_preserves_cached_folders_and_other_tables() = verifyMigration(8)

    private fun verifyMigration(previousVersion: Int) {
        val statements = mutableListOf<String>()
        val migrated = linkedMapOf<String, Map<String, String>>()
        val database = mockk<SQLiteDatabase>(relaxed = true)
        val helper = mockk<BlurDatabase>()
        every { helper.onUpgrade(any(), any(), any()) } answers { callOriginal() }
        every { database.execSQL(any()) } answers { statements.add(firstArg()) }
        every { database.query(any(), any(), any(), any(), any(), any(), any()) } answers {
            cursor(if (firstArg<String>() == "folders_legacy") legacyRows else emptyList())
        }
        every { database.insertOrThrow(DatabaseConstants.FOLDER_TABLE, null, any()) } answers {
            val schema = statements.last { it.startsWith("CREATE TABLE ${DatabaseConstants.FOLDER_TABLE} ") }
            val primaryKey = Regex("([a-z_]+) TEXT PRIMARY KEY").find(schema)!!.groupValues[1]
            val key = pendingValues.getValue(primaryKey)
            check(key !in migrated) { "UNIQUE constraint failed: folders.$primaryKey ($key)" }
            migrated[key] = pendingValues.toMap()
            pendingValues.clear()
            migrated.size.toLong()
        }

        helper.onUpgrade(database, previousVersion, BlurDatabase.VERSION)

        assertEquals(legacyRows.size, migrated.size)
        assertEquals(legacyRows.toSet(), migrated.values.map { values -> columns.map(values::getValue) }.toSet())
        assertEquals(2, migrated.values.count { it[DatabaseConstants.FOLDER_PATH] == "A ▸ B" })
        assertFalse(statements.any { it.startsWith("DROP TABLE IF EXISTS") })
        if (previousVersion < 8) {
            assertTrue(statements.any { it.startsWith("CREATE TABLE ${ClusterReadStore.MEMBERS}") && it.contains("child_timestamp INTEGER") })
            assertFalse(statements.any { it.startsWith("ALTER TABLE ${ClusterReadStore.MEMBERS}") })
        } else {
            assertEquals(3, statements.count { it.startsWith("ALTER TABLE ${ClusterReadStore.MEMBERS} ADD COLUMN") })
        }
    }

    private fun cursor(rows: List<List<String>>): Cursor {
        var position = -1
        return mockk<Cursor>(relaxed = true).also { cursor ->
            every { cursor.moveToNext() } answers { ++position < rows.size }
            every { cursor.isBeforeFirst } answers { position < 0 }
            every { cursor.getColumnIndex(any()) } answers { columns.indexOf(firstArg()) }
            every { cursor.getString(any()) } answers { rows[position][firstArg()] }
        }
    }
}
