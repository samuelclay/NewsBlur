package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.spyk
import io.mockk.verify
import java.sql.Connection
import java.sql.DriverManager
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * Test_BulkReadReplay.kt covers the mark-all-read that SyncService.kt replays after each page of
 * stories loads. Forum #13927: the replay marked the first page of a reopened folder as read.
 */
class Test_BulkReadReplay {
    private lateinit var connection: Connection
    private lateinit var store: ClusterReadStore

    @Before
    fun setUp() {
        connection = DriverManager.getConnection("jdbc:sqlite::memory:")
        connection.createStatement().use {
            it.execute("CREATE TABLE stories (story_hash TEXT, story_feed_id TEXT, timestamp INTEGER, read INTEGER)")
            it.execute("INSERT INTO stories VALUES ('2:seen-before-mark', '2', 1000, 0)")
            it.execute("INSERT INTO stories VALUES ('2:published-after-mark', '2', 3000, 0)")
            it.execute("INSERT INTO stories VALUES ('3:other-feed', '3', 1000, 0)")
        }
        val database = mockk<SQLiteDatabase>()
        every { database.query(DatabaseConstants.STORY_TABLE, any(), any(), any(), any(), any(), any()) } answers {
            // Test_BulkReadReplay.kt runs the production story selection in real SQLite.
            val selection = thirdArg<String?>()?.let { " WHERE $it" } ?: ""
            val statement = connection.prepareStatement("SELECT story_hash FROM stories$selection")
            val result = statement.executeQuery()
            mockk<Cursor>().also { cursor ->
                every { cursor.moveToNext() } answers { result.next() }
                every { cursor.getString(0) } answers { result.getString(1) }
                every { cursor.close() } answers { result.close(); statement.close() }
            }
        }
        store = spyk(ClusterReadStore(database))
        every { store.storedStory(any()) } answers { ClusterReadRepository.State(firstArg<String>().substringBefore(':'), 0, false) }
        every { store.localReadState(any()) } returns null
        every { store.localReadChangedAt(any()) } returns null
        every { store.parentsReferencing(any()) } returns emptyMap()
        every { store.setLocalReadState(any(), any(), any()) } just runs
        every { store.setStoredReadState(any(), any()) } just runs
    }

    @After
    fun tearDown() {
        connection.close()
    }

    @Test
    fun test_replayed_mark_all_read_leaves_stories_published_after_it_unread() {
        store.applyBulkRead("story_feed_id IN (2)", 2000L, true)

        verify(exactly = 1) { store.setStoredReadState("2:seen-before-mark", true) }
        verify(exactly = 0) { store.setStoredReadState("2:published-after-mark", any()) }
        verify(exactly = 0) { store.setStoredReadState("3:other-feed", any()) }
    }

    @Test
    fun test_first_mark_all_read_covers_every_story_on_screen_even_if_dated_after_the_device_clock() {
        store.applyBulkRead("story_feed_id IN (2)", 2000L, false)

        verify(exactly = 1) { store.setStoredReadState("2:seen-before-mark", true) }
        verify(exactly = 1) { store.setStoredReadState("2:published-after-mark", true) }
    }

    @Test
    fun test_replayed_mark_all_read_across_all_feeds_is_also_bounded() {
        store.applyBulkRead(null, 2000L, true)

        verify(exactly = 1) { store.setStoredReadState("3:other-feed", true) }
        verify(exactly = 0) { store.setStoredReadState("2:published-after-mark", any()) }
    }
}
