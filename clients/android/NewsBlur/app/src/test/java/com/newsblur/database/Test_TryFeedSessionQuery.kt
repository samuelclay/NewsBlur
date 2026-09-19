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

    private fun query(feedSet: FeedSet): String {
        val sql = slot<String>()
        val cursor = mockk<Cursor>(relaxed = true)
        every { cursor.moveToFirst() } returns true
        every { database.rawQuery(capture(sql), any(), any<CancellationSignal>()) } returns cursor
        helper.getActiveStoriesCursor(feedSet, filters, mockk()).close()
        return sql.captured
    }
}
