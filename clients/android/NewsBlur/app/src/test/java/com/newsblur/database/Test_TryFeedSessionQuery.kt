package com.newsblur.database

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.CancellationSignal
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.slot
import io.mockk.unmockkConstructor
import java.sql.DriverManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_TryFeedSessionQuery {
    private val database = mockk<SQLiteDatabase>(relaxed = true)
    private lateinit var helper: BlurDatabaseHelper
    private val filters = CursorFilters(StateFilter.ALL, ReadFilter.ALL, StoryOrder.NEWEST)

    @Before fun setUp() {
        mockkConstructor(BlurDatabase::class)
        every { anyConstructed<BlurDatabase>().ro } returns database
        every { anyConstructed<BlurDatabase>().rw } returns database
        every { database.query(any(), any(), any(), any(), any(), any(), any()) } returns mockk(relaxed = true)
        helper = BlurDatabaseHelper(mockk<Context>())
    }

    @After fun tearDown() = unmockkConstructor(BlurDatabase::class)

    @Test fun test_single_feed_stories_do_not_require_subscription_metadata() {
        val query = query(FeedSet.singleFeed("42"))

        assertTrue(query.contains("LEFT JOIN feeds ON stories.feed_id = feeds._id"))
        assertTrue(query.contains("story_hash IN ( SELECT DISTINCT session_story_hash FROM reading_session)"))
        assertTrue(query.endsWith("ORDER BY " + DatabaseConstants.getStorySortOrder(StoryOrder.NEWEST)))
    }

    @Test fun test_broader_queries_keep_their_existing_metadata_join_and_order() {
        for (feedSet in listOf(FeedSet.allFeeds(), FeedSet.folder("One feed folder", setOf("42")), FeedSet.singleSocialFeed("12", "user"))) {
            assertEquals(
                DatabaseConstants.SESSION_STORY_QUERY_BASE + " ORDER BY " + DatabaseConstants.getStorySortOrder(StoryOrder.NEWEST),
                query(feedSet),
            )
        }
        assertEquals(
            DatabaseConstants.SESSION_STORY_QUERY_BASE + " ORDER BY " + DatabaseConstants.READ_STORY_ORDER,
            query(FeedSet.allRead()),
        )
    }

    @Test fun test_open_saved_list_reflects_saves_and_removals_during_the_session() {
        DriverManager.getConnection("jdbc:sqlite::memory:").use { db ->
            db.createStatement().use { sql ->
                sql.execute(DatabaseConstants.FEED_SQL)
                sql.execute(DatabaseConstants.STORY_SQL)
                sql.execute(DatabaseConstants.READING_SESSION_SQL)
                sql.execute("INSERT INTO feeds (_id) VALUES (1)")
                sql.execute("INSERT INTO stories (story_hash, feed_id, starred, starred_date) VALUES ('1:old',1,1,100), ('1:recent',1,1,200), ('1:removed',1,0,0)")
                sql.execute("INSERT INTO reading_session VALUES ('1:old'), ('1:removed')")

                fun hashes(feedSet: FeedSet) = sql.executeQuery(query(feedSet)).use { rows ->
                    buildList { while (rows.next()) add(rows.getString("story_hash")) }
                }
                assertEquals(listOf("1:recent", "1:old"), hashes(FeedSet.allSaved()))
                // A saved search still restricts membership to its matching rows.
                sql.execute("DELETE FROM reading_session WHERE session_story_hash='1:removed'")
                val search = FeedSet.allSaved().apply { searchQuery = "economics" }
                assertEquals(listOf("1:old"), hashes(search))
            }
        }
    }

    @Test fun test_saved_reader_keeps_the_open_article_after_it_is_unsaved() {
        DriverManager.getConnection("jdbc:sqlite::memory:").use { db ->
            db.createStatement().use { sql ->
                sql.execute(DatabaseConstants.FEED_SQL)
                sql.execute(DatabaseConstants.STORY_SQL)
                sql.execute(DatabaseConstants.READING_SESSION_SQL)
                sql.execute("INSERT INTO feeds (_id) VALUES (1)")
                sql.execute("INSERT INTO stories (story_hash, feed_id, starred, starred_date, read) VALUES ('1:next',1,1,100,1), ('1:between',1,1,150,1), ('1:open',1,1,200,1), ('1:removed',1,0,175,1)")
                sql.execute("INSERT INTO reading_session VALUES ('1:next')")
                val feedSet = FeedSet.allSaved()
                val sessionCursor = mockk<Cursor>(relaxed = true)
                every { sessionCursor.moveToFirst() } returns true
                val search = FeedSet.allSaved().apply { searchQuery = "economics" }
                every { sessionCursor.getString(0) } returns search.toCompactSerial()
                every { database.query(DatabaseConstants.SYNC_METADATA_TABLE, null, any(), any(), null, null, null, null) } returns sessionCursor
                every { database.execSQL(any()) } answers { sql.executeUpdate(firstArg<String>()); Unit }
                helper.prepareSavedReadingSession(search, -1L, false)
                sql.executeQuery(query(search, reader = true)).use { rows ->
                    assertEquals(listOf("1:next"), buildList { while (rows.next()) add(rows.getString("story_hash")) })
                }
                sql.execute("INSERT INTO reading_session VALUES ('1:removed')")
                every { sessionCursor.getString(0) } returns feedSet.toCompactSerial()
                // Both saves arrived after the session started. The article next to the tapped one must also be swipeable.
                val version = helper.prepareSavedReadingSession(feedSet, -1L, false)
                helper.prepareSavedReadingSession(feedSet, version, false)
                sql.executeQuery(query(feedSet, reader = true)).use { rows ->
                    assertTrue(rows.next())
                    assertEquals("1:open", rows.getString("story_hash"))
                    assertTrue(rows.next())
                    assertEquals("1:between", rows.getString("story_hash"))
                }
                // Opening another reader against the same session must not duplicate the previous snapshot.
                helper.prepareSavedReadingSession(feedSet, -1L, false)
                sql.executeQuery("SELECT COUNT(*) FROM reading_session").use { count ->
                    assertTrue(count.next())
                    assertEquals(3, count.getInt(1))
                }
                sql.execute("UPDATE stories SET starred=0 WHERE story_hash='1:open'")
                helper.prepareSavedReadingSession(feedSet, version, false)
                helper.prepareSavedReadingSession(feedSet, -1L, true)
                sql.executeQuery(query(FeedSet.allSaved(), reader = true)).use { rows ->
                    assertEquals(listOf("1:open", "1:between", "1:next"), buildList { while (rows.next()) add(rows.getString("story_hash")) })
                }
            }
        }
    }

    private fun query(feedSet: FeedSet, reader: Boolean = false): String {
        val sql = slot<String>()
        val cursor = mockk<Cursor>(relaxed = true)
        every { cursor.moveToFirst() } returns true
        every { database.rawQuery(capture(sql), any(), any<CancellationSignal>()) } returns cursor
        if (reader) helper.getReadingStoriesCursor(feedSet, filters, mockk()).close()
        else helper.getStoryListCursor(feedSet, filters, mockk()).close()
        return sql.captured
    }
}
