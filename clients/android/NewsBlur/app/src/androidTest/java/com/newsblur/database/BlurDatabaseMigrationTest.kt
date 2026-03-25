package com.newsblur.database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BlurDatabaseMigrationTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val dbName = "blur-migration-test.db"

    @After
    fun tearDown() {
        context.deleteDatabase(dbName)
    }

    @Test
    fun opening_database_with_older_schema_version_recreates_local_cache() {
        seedDatabase(version = 3)

        val helper = BlurDatabase(context, dbName)
        val database = helper.readableDatabase

        assertEquals(BlurDatabase.VERSION, database.version)
        assertTrue(hasTable(database, DatabaseConstants.FEED_TABLE))
        assertFalse(hasColumn(database, DatabaseConstants.FEED_TABLE, "stale_marker"))
        assertTrue(hasColumn(database, DatabaseConstants.FEED_TABLE, DatabaseConstants.FEED_TITLE))
        assertTrue(hasTable(database, DatabaseConstants.CUSTOM_ICON_TABLE))

        helper.close()
    }

    @Test
    fun opening_database_with_newer_schema_version_recreates_local_cache() {
        seedDatabase(version = BlurDatabase.VERSION + 1)

        val helper = BlurDatabase(context, dbName)
        val database = helper.readableDatabase

        assertEquals(BlurDatabase.VERSION, database.version)
        assertTrue(hasTable(database, DatabaseConstants.FEED_TABLE))
        assertFalse(hasColumn(database, DatabaseConstants.FEED_TABLE, "stale_marker"))
        assertTrue(hasColumn(database, DatabaseConstants.FEED_TABLE, DatabaseConstants.FEED_TITLE))
        assertTrue(hasTable(database, DatabaseConstants.CUSTOM_ICON_TABLE))

        helper.close()
    }

    private fun seedDatabase(version: Int) {
        context.deleteDatabase(dbName)
        val dbFile = context.getDatabasePath(dbName)
        dbFile.parentFile?.mkdirs()

        val database = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
        database.execSQL("CREATE TABLE ${DatabaseConstants.FEED_TABLE} (stale_marker TEXT)")
        database.execSQL("INSERT INTO ${DatabaseConstants.FEED_TABLE} (stale_marker) VALUES ('old-cache')")
        database.version = version
        database.close()
    }

    private fun hasTable(database: SQLiteDatabase, tableName: String): Boolean =
        database.query(
            "sqlite_master",
            arrayOf("name"),
            "type = ? AND name = ?",
            arrayOf("table", tableName),
            null,
            null,
            null,
        ).use { cursor ->
            cursor.moveToFirst()
        }

    private fun hasColumn(database: SQLiteDatabase, tableName: String, columnName: String): Boolean =
        database.rawQuery("PRAGMA table_info($tableName)", null).use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow("name")
            while (cursor.moveToNext()) {
                if (cursor.getString(nameIndex) == columnName) {
                    return true
                }
            }
            false
        }
}
