package com.newsblur.database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import com.newsblur.domain.Feed
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.slot
import io.mockk.unmockkConstructor
import java.sql.DriverManager
import java.sql.Statement
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class Test_NotifyStoryQueries {
    private val database = mockk<SQLiteDatabase>(relaxed = true)
    private lateinit var helper: BlurDatabaseHelper

    @Before fun setUp() {
        mockkConstructor(BlurDatabase::class)
        every { anyConstructed<BlurDatabase>().ro } returns database
        every { anyConstructed<BlurDatabase>().rw } returns database
        helper = BlurDatabaseHelper(mockk<Context>())
    }

    @After fun tearDown() = unmockkConstructor(BlurDatabase::class)

    @Test fun test_stories_notify_only_from_feeds_set_to_android() {
        withNotificationFeeds { sql ->
            assertEquals(listOf("2:story"), storyHashes(sql, DatabaseConstants.NOTIFY_UNREAD_STORY_QUERY))
            assertEquals(listOf("4:story"), storyHashes(sql, DatabaseConstants.NOTIFY_FOCUS_STORY_QUERY))
        }
    }

    @Test fun test_background_sync_downloads_only_feeds_set_to_android() {
        withNotificationFeeds { sql ->
            val query = slot<String>()
            every { database.rawQuery(capture(query), any()) } returns mockk(relaxed = true)

            helper.getNotifyFeeds()

            val feedIds = sql.executeQuery(query.captured).use { rows -> buildSet { while (rows.next()) add(rows.getString(1)) } }
            assertEquals(setOf("2", "4"), feedIds)
        }
    }

    /** Every feed has a filter, as the server sends for any channel. Only feeds 2 and 4 chose Android. */
    private fun withNotificationFeeds(block: (Statement) -> Unit) {
        val feeds =
            listOf(
                Triple(1, Feed.NOTIFY_FILTER_UNREAD, listOf("ios")),
                Triple(2, Feed.NOTIFY_FILTER_UNREAD, listOf("ios", "android")),
                Triple(3, Feed.NOTIFY_FILTER_FOCUS, listOf("email", "web")),
                Triple(4, Feed.NOTIFY_FILTER_FOCUS, listOf("android")),
                Triple(5, Feed.NOTIFY_FILTER_UNREAD, null),
            )
        DriverManager.getConnection("jdbc:sqlite::memory:").use { db ->
            db.createStatement().use { sql ->
                sql.execute(DatabaseConstants.FEED_SQL)
                sql.execute(DatabaseConstants.STORY_SQL)
                for ((feedId, filter, types) in feeds) {
                    // Feed.java stores the channel list through DatabaseConstants.flattenStringList.
                    val storedTypes = types?.let { "'" + DatabaseConstants.flattenStringList(it) + "'" } ?: "NULL"
                    sql.execute(
                        "INSERT INTO ${DatabaseConstants.FEED_TABLE} (${DatabaseConstants.FEED_ID}, " +
                            "${DatabaseConstants.FEED_NOTIFICATION_FILTER}, ${DatabaseConstants.FEED_NOTIFICATION_TYPES}) " +
                            "VALUES ($feedId, '$filter', $storedTypes)",
                    )
                    sql.execute(
                        "INSERT INTO ${DatabaseConstants.STORY_TABLE} (${DatabaseConstants.STORY_HASH}, " +
                            "${DatabaseConstants.STORY_FEED_ID}, ${DatabaseConstants.STORY_INTELLIGENCE_TOTAL}) " +
                            "VALUES ('$feedId:story', $feedId, 1)",
                    )
                }
                block(sql)
            }
        }
    }

    private fun storyHashes(
        sql: Statement,
        query: String,
    ): List<String> =
        sql.executeQuery(query).use { rows ->
            buildList { while (rows.next()) add(rows.getString(DatabaseConstants.STORY_HASH)) }
        }
}
