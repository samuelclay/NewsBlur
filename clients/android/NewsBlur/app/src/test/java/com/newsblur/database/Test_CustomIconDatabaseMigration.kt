package com.newsblur.database

import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import java.sql.Connection
import java.sql.DriverManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
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

    @Test
    fun test_interrupted_account_reset_rolls_back_tables_and_pending_actions() {
        every { helper.dropAndRecreateTables() } answers { callOriginal() }
        every { helper.writableDatabase } returns database
        var successful = false
        every { database.beginTransaction() } answers {
            successful = false
            connection.autoCommit = false
        }
        every { database.setTransactionSuccessful() } answers { successful = true }
        every { database.endTransaction() } answers {
            if (successful) connection.commit() else connection.rollback()
            connection.autoCommit = true
        }
        // An out-of-space error during BlurDatabase.java's reset must leave the pre-reset database intact.
        val interrupted = IllegalStateException("out of space during table recreation")
        every { database.execSQL(DatabaseConstants.FEED_SQL) } throws interrupted andThenAnswer {
            connection.createStatement().use { it.execute(DatabaseConstants.FEED_SQL) }
            Unit
        }
        assertSame(interrupted, runCatching { helper.dropAndRecreateTables() }.exceptionOrNull())

        assertOfflineStatePreserved()
        assertEquals("0", value("SELECT count(*) FROM custom_icons"))

        helper.dropAndRecreateTables()
        assertEquals("0", value("SELECT count(*) FROM stories"))
        assertEquals("0", value("SELECT count(*) FROM story_actions"))
    }

    @Test
    fun test_repair_of_an_interrupted_version_twelve_reset_preserves_surviving_tables() {
        // These tables may be missing even though SQLiteOpenHelper still sees the current user_version.
        database.execSQL("DROP TABLE feeds")
        database.execSQL("DROP TABLE custom_icons")
        ClusterReadStore.dropTables(database)

        helper.onUpgrade(database, 12, BlurDatabase.VERSION)

        assertEquals("0", value("SELECT count(*) FROM feeds WHERE stories_last_month IS NULL"))
        assertEquals("0", value("SELECT count(*) FROM custom_icons"))
        assertEquals("0", value("SELECT count(*) FROM story_cluster_members"))
        assertOfflineStatePreserved()
    }

    @Test
    fun test_repair_recovers_missing_cluster_memberships_without_overwriting_newer_read_receipts() {
        val child = """[{"story_hash":"2:child","story_feed_id":"2","story_timestamp":100,"read_status":true}]"""
        database.execSQL("UPDATE stories SET cluster_stories = '$child' WHERE story_hash = '1:cached'")
        database.execSQL("INSERT INTO story_cluster_read_state VALUES ('2:child', 0, 150)")
        database.execSQL("DROP TABLE story_cluster_members")

        repairClusterTables()

        assertEquals("1:cached/2/100/1", value("SELECT parent_hash || '/' || feed_id || '/' || child_timestamp || '/' || child_read " +
            "FROM story_cluster_members WHERE child_hash = '2:child'"))
        assertEquals("0/150", value("SELECT read || '/' || updated_at FROM story_cluster_read_state WHERE story_hash = '2:child'"))
    }

    @Test
    fun test_missing_read_receipts_leave_the_surviving_membership_index_intact() {
        database.execSQL("DROP TABLE story_cluster_read_state")
        database.execSQL("INSERT INTO story_cluster_members VALUES ('1:cached', '2:child', 1, 100, '2')")
        val cached = """[{"story_hash":"2:child","story_feed_id":"2","story_timestamp":100,"read_status":false}]"""
        database.execSQL("UPDATE stories SET cluster_stories = '$cached' WHERE story_hash = '1:cached'")

        repairClusterTables()

        assertEquals("1", value("SELECT child_read FROM story_cluster_members WHERE child_hash = '2:child'"))
        assertEquals("0", value("SELECT count(*) FROM story_cluster_read_state"))
    }

    @Test
    fun test_version_eleven_with_missing_feeds_can_upgrade_without_losing_queued_actions() {
        database.execSQL("ALTER TABLE stories DROP COLUMN prompt_classifiers")
        database.execSQL("DROP TABLE feeds")

        helper.onUpgrade(database, 11, BlurDatabase.VERSION)

        database.execSQL("UPDATE stories SET prompt_classifiers = '[]' WHERE story_hash = '1:cached'")
        assertEquals("0", value("SELECT count(*) FROM feeds WHERE stories_last_month IS NULL"))
        assertOfflineStatePreserved()
    }

    private fun repairClusterTables() {
        // Bridge the Android ContentValues used by ClusterReadStore.kt to this test's real SQLite connection.
        mockkConstructor(ContentValues::class)
        try {
            val row = linkedMapOf<String, Any>()
            every { anyConstructed<ContentValues>().put(any<String>(), any<String>()) } answers { row[firstArg()] = secondArg<String>() }
            every { anyConstructed<ContentValues>().put(any<String>(), any<Boolean>()) } answers { row[firstArg()] = secondArg<Boolean>() }
            every { anyConstructed<ContentValues>().put(any<String>(), any<Long>()) } answers { row[firstArg()] = secondArg<Long>() }
            every { database.delete(any(), any(), any()) } answers {
                connection.prepareStatement("DELETE FROM ${firstArg<String>()} WHERE ${secondArg<String>()}").use {
                    it.setString(1, thirdArg<Array<String>>().single())
                    it.executeUpdate()
                }
            }
            every { database.insertWithOnConflict(any(), null, any(), SQLiteDatabase.CONFLICT_IGNORE) } answers {
                val columns = row.keys.joinToString()
                val binds = row.keys.joinToString { "?" }
                connection.prepareStatement("INSERT OR IGNORE INTO ${firstArg<String>()} ($columns) VALUES ($binds)").use {
                    row.values.forEachIndexed { index, cell -> it.setObject(index + 1, cell) }
                    it.executeUpdate().toLong()
                }
            }

            helper.onUpgrade(database, 12, BlurDatabase.VERSION)
        } finally {
            unmockkConstructor(ContentValues::class)
        }
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
