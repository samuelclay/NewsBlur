package com.newsblur.database

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.Gson
import com.newsblur.domain.Story
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

    @Test
    fun opening_version_eight_preserves_cached_state_and_backfills_cluster_metadata() = verifyClusterMetadataMigration(8)

    @Test
    fun opening_version_nine_preserves_cached_state_and_backfills_cluster_metadata() = verifyClusterMetadataMigration(9)

    @Test
    fun known_read_members_do_not_decode_parent_payloads_on_repeated_unread_refreshes() {
        context.deleteDatabase(dbName)
        BlurDatabase(context, dbName).use { helper ->
            val database = helper.writableDatabase
            val store = ClusterReadStore(database)
            val story = Story().apply {
                storyHash = "1:parent"
                clusterStories = arrayOf(clusterChild("2:read", true, 1000L))
            }
            database.insertOrThrow(DatabaseConstants.STORY_TABLE, null, ContentValues().apply {
                put(DatabaseConstants.STORY_HASH, story.storyHash)
                // BlurDatabaseMigrationTest.kt makes any unnecessary parent JSON decode fail immediately.
                put(DatabaseConstants.STORY_CLUSTER_STORIES, "invalid parent payload")
            })
            store.registerStory(story)

            repeat(3) {
                assertEquals(ClusterReadStore.UnreadReconciliationStats(0, 0), store.reconcileServerUnread(emptyList(), 2000L))
            }
            database.rawQuery("SELECT COUNT(*) FROM ${ClusterReadStore.READ_STATE}", null).use {
                assertTrue(it.moveToFirst())
                assertEquals(0, it.getInt(0))
            }
        }
    }

    @Test
    fun replacing_parent_clusters_updates_indexed_read_feed_and_timestamp_metadata() {
        context.deleteDatabase(dbName)
        BlurDatabase(context, dbName).use { helper ->
            val database = helper.writableDatabase
            val store = ClusterReadStore(database)
            database.insertOrThrow(DatabaseConstants.STORY_TABLE, null, ContentValues().apply {
                put(DatabaseConstants.STORY_HASH, "1:parent")
            })
            store.registerStory(Story().apply {
                storyHash = "1:parent"
                clusterStories = arrayOf(clusterChild("2:old", false, 1000L))
            })

            store.setParentClusters("1:parent", arrayOf(clusterChild("3:new", true, 2000L)))

            database.rawQuery("SELECT child_hash, child_read, child_timestamp, feed_id FROM ${ClusterReadStore.MEMBERS}", null).use {
                assertTrue(it.moveToFirst())
                assertEquals("3:new", it.getString(0))
                assertEquals(1, it.getInt(1))
                assertEquals(2000L, it.getLong(2))
                assertEquals("3", it.getString(3))
                assertFalse(it.moveToNext())
            }
        }
    }

    private fun verifyClusterMetadataMigration(previousVersion: Int) {
        context.deleteDatabase(dbName)
        val dbFile = context.getDatabasePath(dbName)
        dbFile.parentFile?.mkdirs()
        val children = arrayOf(clusterChild("2:read", true, 1500L), clusterChild("3:unread", false, 2500L))
        val clusterJson = Gson().toJson(children)
        SQLiteDatabase.openOrCreateDatabase(dbFile, null).use { database ->
            BlurDatabase(context, dbName).use { it.onCreate(database) }
            ClusterReadStore.dropTables(database)
            // BlurDatabaseMigrationTest.kt reconstructs the v8/v9 membership schema before upgrading.
            database.execSQL("CREATE TABLE ${ClusterReadStore.MEMBERS} (parent_hash TEXT NOT NULL, child_hash TEXT NOT NULL, PRIMARY KEY(parent_hash, child_hash))")
            database.execSQL("CREATE INDEX story_cluster_child ON ${ClusterReadStore.MEMBERS}(child_hash)")
            database.execSQL("CREATE TABLE ${ClusterReadStore.READ_STATE} (story_hash TEXT PRIMARY KEY NOT NULL, read INTEGER NOT NULL, updated_at INTEGER NOT NULL)")
            database.execSQL("CREATE TRIGGER story_cluster_cleanup AFTER DELETE ON ${DatabaseConstants.STORY_TABLE} BEGIN " +
                "DELETE FROM ${ClusterReadStore.MEMBERS} WHERE parent_hash = OLD.story_hash; END")
            database.insertOrThrow(DatabaseConstants.STORY_TABLE, null, ContentValues().apply {
                put(DatabaseConstants.STORY_HASH, "1:parent")
                put(DatabaseConstants.STORY_TITLE, "Cached parent")
                put(DatabaseConstants.STORY_READ, true)
                put(DatabaseConstants.STORY_CLUSTER_STORIES, clusterJson)
            })
            database.execSQL("INSERT INTO ${ClusterReadStore.MEMBERS} (parent_hash, child_hash) VALUES ('1:parent', '2:read')")
            database.execSQL("INSERT INTO ${ClusterReadStore.READ_STATE} (story_hash, read, updated_at) VALUES ('2:read', 0, 3000)")
            database.insertOrThrow(DatabaseConstants.ACTION_TABLE, null, ContentValues().apply {
                put(DatabaseConstants.ACTION_ID, 7)
                put(DatabaseConstants.ACTION_TIME, 3000L)
                put(DatabaseConstants.ACTION_PARAMS, "preserved pending action")
            })
            database.version = previousVersion
        }

        BlurDatabase(context, dbName).use { helper ->
            val database = helper.writableDatabase
            assertEquals(BlurDatabase.VERSION, database.version)
            database.rawQuery("SELECT title, read, cluster_stories FROM ${DatabaseConstants.STORY_TABLE} WHERE story_hash = '1:parent'", null).use {
                assertTrue(it.moveToFirst())
                assertEquals("Cached parent", it.getString(0))
                assertEquals(1, it.getInt(1))
                assertEquals(clusterJson, it.getString(2))
            }
            database.rawQuery("SELECT ${DatabaseConstants.ACTION_ID}, ${DatabaseConstants.ACTION_TIME}, ${DatabaseConstants.ACTION_PARAMS} " +
                "FROM ${DatabaseConstants.ACTION_TABLE}", null).use {
                assertTrue(it.moveToFirst())
                assertEquals(7, it.getInt(0))
                assertEquals(3000L, it.getLong(1))
                assertEquals("preserved pending action", it.getString(2))
                assertFalse(it.moveToNext())
            }
            database.rawQuery("SELECT story_hash, read, updated_at FROM ${ClusterReadStore.READ_STATE}", null).use {
                assertTrue(it.moveToFirst())
                assertEquals("2:read", it.getString(0))
                assertEquals(0, it.getInt(1))
                assertEquals(3000L, it.getLong(2))
                assertFalse(it.moveToNext())
            }
            database.rawQuery("SELECT child_hash, child_read, child_timestamp, feed_id FROM ${ClusterReadStore.MEMBERS} ORDER BY child_hash", null).use {
                for (child in children) {
                    assertTrue(it.moveToNext())
                    assertEquals(child.storyHash, it.getString(0))
                    assertEquals(if (child.read) 1 else 0, it.getInt(1))
                    assertEquals(child.timestamp, it.getLong(2))
                    assertEquals(child.feedId, it.getString(3))
                }
                assertFalse(it.moveToNext())
            }
        }
    }

    private fun clusterChild(hash: String, read: Boolean, timestampMillis: Long) = Story.ClusterStory().apply {
        storyHash = hash
        feedId = hash.substringBefore(':')
        this.read = read
        timestamp = timestampMillis
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
