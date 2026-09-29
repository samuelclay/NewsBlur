package com.newsblur.util

import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.FolderItemsList
import com.newsblur.activity.Main
import com.newsblur.activity.SocialFeedItemsList
import com.newsblur.domain.Feed
import com.newsblur.domain.SocialFeed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class LastStoryListTest {
    private val technology = Feed.getZeroFeed().apply { feedId = "42" }

    private fun roundTrip(
        storyListClass: Class<*>,
        feedSet: FeedSet,
        folderName: String? = null,
        socialFeed: SocialFeed? = null,
        findFeed: (String) -> Feed? = { null },
    ): LastStoryList.Destination? {
        val saved = LastStoryList.save(storyListClass, feedSet, folderName, socialFeed, isTryFeed = false)!!
        return LastStoryList.restore(saved, findFeed)
    }

    @Test
    fun test_feedList_reopensWithItsFeedAndFolder() {
        val destination =
            roundTrip(FeedItemsList::class.java, FeedSet.singleFeed("42"), folderName = "Tech") { feedId ->
                technology.takeIf { feedId == "42" }
            }!!
        assertEquals(FeedItemsList::class.java, destination.storyListClass)
        assertEquals(FeedSet.singleFeed("42"), destination.feedSet)
        assertSame(technology, destination.feed)
        assertEquals("Tech", destination.folderName)
    }

    @Test
    fun test_removedFeed_fallsBack() {
        assertNull(roundTrip(FeedItemsList::class.java, FeedSet.singleFeed("42"), folderName = "Tech") { null })
    }

    @Test
    fun test_folderList_keepsTheFolderItAdvancedTo() {
        // ItemsList.java passes the next session's folder name, not the launch intent's.
        val destination = roundTrip(FolderItemsList::class.java, FeedSet.folder("News", setOf("1", "2")), folderName = "News")!!
        assertEquals(FolderItemsList::class.java, destination.storyListClass)
        assertEquals("News", destination.folderName)
        assertEquals(FeedSet.folder("News", setOf("1", "2")), destination.feedSet)
    }

    @Test
    fun test_folderListWithoutAFolderName_fallsBack() {
        assertNull(roundTrip(FolderItemsList::class.java, FeedSet.folder("News", setOf("1")), folderName = null))
    }

    @Test
    fun test_tryFeeds_areNotRemembered() {
        assertNull(LastStoryList.save(FeedItemsList::class.java, FeedSet.singleFeed("42"), "Tech", null, isTryFeed = true))
    }

    @Test
    fun test_searchQuery_isDropped() {
        val search = FeedSet.allFeeds().apply { searchQuery = "android" }
        val destination = roundTrip(AllStoriesItemsList::class.java, search)!!
        assertNull(destination.feedSet.searchQuery)
        assertEquals(FeedSet.allFeeds(), destination.feedSet)
    }

    @Test
    fun test_socialFeedList_reopensWithItsSocialFeed() {
        val blurblog =
            SocialFeed().apply {
                userId = "7"
                username = "sam"
            }
        val destination = roundTrip(SocialFeedItemsList::class.java, FeedSet.singleSocialFeed("7", "sam"), socialFeed = blurblog)!!
        assertEquals("7", destination.socialFeed?.userId)
    }

    @Test
    fun test_socialFeedThatNoLongerMatchesTheFeedSet_fallsBack() {
        val stale =
            SocialFeed().apply {
                userId = "7"
                username = "sam"
            }
        assertNull(roundTrip(SocialFeedItemsList::class.java, FeedSet.singleSocialFeed("8", "other"), socialFeed = stale))
    }

    @Test
    fun test_classesThatAreNotStoryLists_fallBack() {
        assertNull(roundTrip(Main::class.java, FeedSet.allFeeds()))
        val unknown = LastStoryList.Saved("com.newsblur.activity.Gone", "{}", null, null)
        assertNull(LastStoryList.restore(unknown) { null })
    }

    @Test
    fun test_unreadableFeedSet_fallsBack() {
        val javaSerialized = LastStoryList.Saved(AllStoriesItemsList::class.java.name, "rO0ABXNyABtjb20ubmV3c2JsdXI=", null, null)
        assertNull(LastStoryList.restore(javaSerialized) { null })
        assertNull(LastStoryList.restore(LastStoryList.Saved(null, null, null, null)) { null })
    }

    @Test
    fun test_fallback_isAllSiteStories() {
        val fallback = LastStoryList.allSiteStories()
        assertEquals(AllStoriesItemsList::class.java, fallback.storyListClass)
        assertEquals(FeedSet.allFeeds(), fallback.feedSet)
    }
}
