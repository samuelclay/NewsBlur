package com.newsblur.util

import com.newsblur.domain.Feed
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionDataSourceRegistryTest {
    @After
    fun tearDown() {
        SessionDataSourceRegistry.clearForTests()
    }

    @Test
    fun registerReturnsSmallKeyForSessionSources() {
        val feed = createFeed("1")
        val nextFeed = createFeed("2")
        val session = Session(FeedSet.singleFeed(feed.feedId), "Folder", feed)
        val folders = listOf("Folder")
        val folderChildren = listOf(listOf(feed, nextFeed))
        val sessionDataSource = SessionDataSource(session, folders, folderChildren)
        val storyListSessionDataSource =
            SessionDataSource(
                session,
                folders,
                folderChildren,
                StateFilter.ALL,
                emptySet(),
            )

        val key = SessionDataSourceRegistry.register(sessionDataSource, storyListSessionDataSource)

        assertNotNull(key)
        assertTrue(key!!.length < 16)
        SessionDataSourceRegistry.get(key).let { entry ->
            assertSame(sessionDataSource, entry?.sessionDataSource)
            assertSame(storyListSessionDataSource, entry?.storyListSessionDataSource)
        }
    }

    @Test
    fun removeClearsRegisteredSessionSources() {
        val feed = createFeed("1")
        val session = Session(FeedSet.singleFeed(feed.feedId), "Folder", feed)
        val sessionDataSource = SessionDataSource(session, listOf("Folder"), listOf(listOf(feed)))
        val key = SessionDataSourceRegistry.register(sessionDataSource, null)

        SessionDataSourceRegistry.remove(key)

        assertNull(SessionDataSourceRegistry.get(key))
    }

    @Test
    fun registerReturnsNullWhenNoSessionSourcesExist() {
        assertNull(SessionDataSourceRegistry.register(null, null))
    }

    private fun createFeed(id: String) =
        Feed().apply {
            feedId = id
            title = "Feed #$id"
        }
}
