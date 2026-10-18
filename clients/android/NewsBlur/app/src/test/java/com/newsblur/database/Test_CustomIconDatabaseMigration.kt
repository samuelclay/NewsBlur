package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import io.mockk.every
import io.mockk.mockk
import java.sql.Connection
import java.sql.DriverManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_CustomIconDatabaseMigration {
    private lateinit var connection: Connection
    private lateinit var database: SQLiteDatabase
    private lateinit var helper: BlurDatabase

    @Before
    fun setUp() {
        connection = DriverManager.getConnection("jdbc:sqlite::memory:")
        database = mockk()
        helper = mockk()
        every { helper.onCreate(any()) } answers { callOriginal() }
        every { helper.onUpgrade(any(), any(), any()) } answers { callOriginal() }
        every { helper["dropAndRecreateTables"](database) } answers { callOriginal() }
        every { database.execSQL(any()) } answers {
            connection.createStatement().use { it.execute(firstArg<String>()) }
            Unit
        }
        every { database.query(any(), any(), any(), any(), any(), any(), any()) } answers {
            // Test_CustomIconDatabaseMigration.kt executes production migration SQL in real SQLite.
            val columns = secondArg<Array<String>?>()?.joinToString(", ") ?: "*"
            val selection = thirdArg<String?>()?.let { " WHERE $it" } ?: ""
            val statement = connection.prepareStatement("SELECT $columns FROM ${firstArg<String>()}$selection")
            arg<Array<String>?>(3)?.forEachIndexed { index, value -> statement.setString(index + 1, value) }
            val result = statement.executeQuery()
            mockk<Cursor>().also { cursor ->
                every { cursor.moveToNext() } answers { result.next() }
                every { cursor.getString(any()) } answers { result.getString(firstArg<Int>() + 1) }
                every { cursor.close() } answers { result.close(); statement.close() }
            }
        }
        helper.onCreate(database)
        database.execSQL("INSERT INTO stories (story_hash, title) VALUES ('1:cached', 'Offline article')")
        database.execSQL("INSERT INTO story_actions (_id, time, action_params) VALUES (7, 1234, 'pending offline read')")
    }

    @After
    fun tearDown() {
        connection.close()
    }

    @Test
    fun test_version_six_repairs_missing_icons_without_losing_offline_state() = verifyMissingIcons(6)

    @Test
    fun test_version_seven_repairs_missing_icons_without_losing_offline_state() = verifyMissingIcons(7)

    @Test
    fun test_version_eight_repairs_missing_icons_without_losing_offline_state() = verifyMissingIcons(8)

    @Test
    fun test_version_nine_repairs_missing_icons_without_losing_offline_state() = verifyMissingIcons(9)

    @Test
    fun test_version_ten_repairs_missing_icons_without_losing_offline_state() = verifyMissingIcons(10)

    @Test
    fun test_version_ten_preserves_existing_icons_and_cluster_receipts() {
        database.execSQL("INSERT INTO custom_icons VALUES ('1', 1, 'emoji', 'star', '#ffffff', NULL)")
        database.execSQL("INSERT INTO story_cluster_read_state VALUES ('2:read', 1, 1234)")

        helper.onUpgrade(database, 10, 11)

        assertEquals("star", value("SELECT icon_data FROM custom_icons WHERE icon_id = '1'"))
        assertEquals("1234", value("SELECT updated_at FROM story_cluster_read_state WHERE story_hash = '2:read'"))
        assertOfflineStatePreserved()
    }

    private fun verifyMissingIcons(previousVersion: Int) {
        database.execSQL("DROP TABLE custom_icons")
        if (previousVersion < 10) {
            ClusterReadStore.dropTables(database)
            if (previousVersion >= 8) {
                // Test_CustomIconDatabaseMigration.kt restores the membership schema shipped in versions 8 and 9.
                database.execSQL("CREATE TABLE story_cluster_members (parent_hash TEXT NOT NULL, child_hash TEXT NOT NULL, PRIMARY KEY(parent_hash, child_hash))")
                database.execSQL("CREATE INDEX story_cluster_child ON story_cluster_members(child_hash)")
                database.execSQL("CREATE TABLE story_cluster_read_state (story_hash TEXT PRIMARY KEY NOT NULL, read INTEGER NOT NULL, updated_at INTEGER NOT NULL)")
            }
        }

        helper.onUpgrade(database, previousVersion, 11)

        // BlurDatabaseHelper.java immediately reads this table when the application or sync service starts.
        assertEquals("0", value("SELECT count(*) FROM custom_icons"))
        database.execSQL("INSERT INTO custom_icons VALUES ('1', 1, 'emoji', 'star', '#ffffff', NULL)")
        assertEquals("star", value("SELECT icon_data FROM custom_icons WHERE icon_id = '1'"))
        assertOfflineStatePreserved()
    }

    private fun assertOfflineStatePreserved() {
        assertEquals("Offline article", value("SELECT title FROM stories WHERE story_hash = '1:cached'"))
        assertEquals("pending offline read", value("SELECT action_params FROM story_actions WHERE _id = 7"))
    }

    private fun value(sql: String): String? = connection.createStatement().use { statement ->
        statement.executeQuery(sql).use { result ->
            assertTrue("Expected a preserved row: $sql", result.next())
            result.getString(1)
        }
    }
}
