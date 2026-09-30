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
import org.junit.Assert.assertTrue
import org.junit.Test

class LastStoryListTest {
    private val technology = Feed.getZeroFeed().apply { feedId = "42" }

    private fun roundTrip(
        storyListClass: Class<*>,
        feedSet: FeedSet,
        folderName: String? = null,
        socialFeed: SocialFeed? = null,
        findFolder: (String) -> FeedSet? = { null },
        findFeed: (String) -> Feed? = { null },
    ): LastStoryList.Destination? {
        val saved = LastStoryList.save(storyListClass, feedSet, folderName, socialFeed, isTryFeed = false)!!
        return LastStoryList.restore(saved, findFolder = findFolder, findFeed = findFeed)
    }

    private fun restore(saved: LastStoryList.Saved): LastStoryList.Destination? =
        LastStoryList.restore(saved, findFolder = { null }, findFeed = { null })

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
    fun test_feedListWithoutAFolderName_fallsBack() {
        assertNull(roundTrip(FeedItemsList::class.java, FeedSet.singleFeed("42"), folderName = null) { technology })
    }

    @Test
    fun test_folderList_keepsTheFolderItAdvancedTo() {
        // ItemsList.java passes the next session's folder name, not the launch intent's.
        val destination =
            roundTrip(FolderItemsList::class.java, FeedSet.folder("News", setOf("1", "2")), folderName = "News", findFolder = { name ->
                FeedSet.folder(name, setOf("1", "2")).takeIf { name == "News" }
            })!!
        assertEquals(FolderItemsList::class.java, destination.storyListClass)
        assertEquals("News", destination.folderName)
        assertEquals(FeedSet.folder("News", setOf("1", "2")), destination.feedSet)
    }

    @Test
    fun test_folderList_reopensWithTheFeedsTheFolderHasNow() {
        // A feed added to the folder on the web since the list was saved shows up at launch.
        val destination =
            roundTrip(FolderItemsList::class.java, FeedSet.folder("News", setOf("1", "2")), folderName = "News", findFolder = { name ->
                FeedSet.folder(name, setOf("1", "2", "3"))
            })!!
        assertEquals(FeedSet.folder("News", setOf("1", "2", "3")), destination.feedSet)
    }

    @Test
    fun test_folderOpenedInSavedView_keepsItsSavedFilter() {
        // FolderListAdapter.java sets isFilterSaved on a folder opened while the Saved filter is on.
        val savedView = FeedSet.folder("News", setOf("1")).apply { isFilterSaved = true }
        val destination =
            roundTrip(FolderItemsList::class.java, savedView, folderName = "News", findFolder = { name ->
                FeedSet.folder(name, setOf("1", "2"))
            })!!
        assertTrue(destination.feedSet.isFilterSaved)
        assertEquals(setOf("1", "2"), destination.feedSet.allFeeds)
    }

    @Test
    fun test_deletedFolder_fallsBack() {
        // BlurDatabaseHelper.feedSetFromFolderName returns an empty set for a folder that is gone.
        assertNull(
            roundTrip(FolderItemsList::class.java, FeedSet.folder("News", setOf("1")), folderName = "News", findFolder = { name ->
                FeedSet.folder(name, emptySet())
            }),
        )
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
        assertNull(restore(unknown))
    }

    @Test
    fun test_unreadableFeedSet_fallsBack() {
        val javaSerialized = LastStoryList.Saved(AllStoriesItemsList::class.java.name, "rO0ABXNyABtjb20ubmV3c2JsdXI=", null, null)
        assertNull(restore(javaSerialized))
        assertNull(restore(LastStoryList.Saved(null, null, null, null)))
    }

    @Test
    fun test_feedSetSavedUnderOtherFieldNames_fallsBack() {
        // A release build written before R8 renamed FeedSet's fields: Gson skips the unknown keys
        // and hands back a set that matches no story list type.
        val renamed = LastStoryList.Saved(AllStoriesItemsList::class.java.name, """{"a":[],"b":null}""", null, null)
        assertNull(restore(renamed))
    }

    @Test
    fun test_fallback_isAllSiteStories() {
        val fallback = LastStoryList.allSiteStories()
        assertEquals(AllStoriesItemsList::class.java, fallback.storyListClass)
        assertEquals(FeedSet.allFeeds(), fallback.feedSet)
    }
}
