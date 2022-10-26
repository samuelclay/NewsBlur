package com.newsblur

import com.newsblur.domain.Feed
import com.newsblur.util.FeedSet
import com.newsblur.util.Session
import com.newsblur.util.SessionDataSource
import org.junit.Assert
import org.junit.Test

class SessionDataSourceTest {

    private val folders = listOf(
            "F1",
            "F2",
            "F3",
            "F4",
            "F5",
    )

    private val folderChildren = listOf(
            emptyList(),
            listOf(
                    createFeed("20"),
                    createFeed("21"),
                    createFeed("22"),
            ),
            listOf(
                    createFeed("30"),
            ),
            emptyList(),
            listOf(
                    createFeed("50"),
                    createFeed("51"),
            )
    )

    @Test
    fun `session constructor test`() {
        val feedSet = FeedSet.singleFeed("1")
        val session = Session(feedSet)
        Assert.assertEquals(feedSet, session.feedSet)
        Assert.assertNull(session.feed)
        Assert.assertNull(session.folderName)
    }

    @Test
    fun `session full constructor test`() {
        val feedSet = FeedSet.singleFeed("10")
        val feed = createFeed("10")
        val session = Session(feedSet, "folderName", feed)
        Assert.assertEquals(feedSet, session.feedSet)
        Assert.assertEquals("folderName", session.folderName)
        Assert.assertEquals(feed, session.feed)
    }

    @Test
    fun `next session for unknown feedId`() {
        val session = Session(FeedSet.singleFeed("123"))
        val sessionDs = SessionDataSource(session, folders, folderChildren)
        Assert.assertNull(sessionDs.getNextSession())
    }

    @Test
    fun `next session for empty folder`() {
        val feedSet = FeedSet.singleFeed("123")
        val feed = createFeed("123")
        val session = Session(feedSet, "F1", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        Assert.assertNull(sessionDs.getNextSession())
    }

    /**
     * Expected to return the next [Session] containing feed id 11
     * as the second feed in folder F2 after feed id 10
     */
    @Test
    fun `next session for F2 feedSet`() {
        val feedSet = FeedSet.singleFeed("20")
        val feed = createFeed("20")
        val session = Session(feedSet, "F2", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        sessionDs.getNextSession()?.let {
            Assert.assertEquals("F2", it.folderName)
            Assert.assertEquals("21", it.feed?.feedId)
            with(it.feedSet) {
                Assert.assertNotNull(this)
                Assert.assertTrue(it.feedSet.flatFeedIds.size == 1)
                Assert.assertEquals("21", it.feedSet.flatFeedIds.first())
            }
        } ?: Assert.fail("Next session was null")
    }

    /**
     * Expected to return a null [Session] because feed id 12
     * is the last feed id in folder F2
     */
    @Test
    fun `next session for end of F2 feedSet`() {
        val feedSet = FeedSet.singleFeed("22")
        val feed = createFeed("22")
        val session = Session(feedSet, "F2", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        Assert.assertNull(sessionDs.getNextSession())
    }

    @Test
    fun `next session for F2 feedSetFolder`() {
        val feedSet = FeedSet.folder("F2", setOf("21"))
        val feed = createFeed("21")
        val session = Session(feedSet, "F2", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        sessionDs.getNextSession()?.let {
            Assert.assertNull(it.feed)
            Assert.assertEquals("F3", it.folderName)
            Assert.assertEquals("F3", it.feedSet.folderName)
            Assert.assertEquals("30", it.feedSet.flatFeedIds.firstOrNull())
        } ?: Assert.fail("Next session is null for F2 feedSetFolder")
    }

    /**
     * Expected to return folder "F5" because folder "F3"
     * doesn't have any feeds
     */
    @Test
    fun `next session for F3 feedSetFolder`() {
        val feedSet = FeedSet.folder("F3", setOf("30"))
        val feed = createFeed("30")
        val session = Session(feedSet, "F3", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        sessionDs.getNextSession()?.let {
            Assert.assertNull(it.feed)
            Assert.assertEquals("F5", it.folderName)
            Assert.assertEquals("F5", it.feedSet.folderName)
            Assert.assertEquals("50", it.feedSet.flatFeedIds.firstOrNull())
        } ?: Assert.fail("Next session is null for F5 feedSetFolder")
    }

    /**
     * Expected to return session for F1 feedSetFolder
     */
    @Test
    fun `next session for F5 feedSetFolder`() {
        val feedSet = FeedSet.folder("F5", setOf("50"))
        val feed = createFeed("50")
        val session = Session(feedSet, "F5", feed)
        val sessionDs = SessionDataSource(session, folders, folderChildren)

        sessionDs.getNextSession()?.let {
            Assert.assertNull(it.feed)
            Assert.assertEquals("F2", it.folderName)
            Assert.assertEquals("F2", it.feedSet.folderName)
            Assert.assertEquals(setOf("20", "21", "22"), it.feedSet.flatFeedIds)
        } ?: Assert.fail("Next session is null for F5 feedSetFolder")
    }

    private fun createFeed(id: String) = Feed().apply {
        feedId = id
        title = "Feed #$id"
    }
}