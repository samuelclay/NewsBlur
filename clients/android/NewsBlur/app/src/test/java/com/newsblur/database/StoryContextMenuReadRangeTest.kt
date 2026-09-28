package com.newsblur.database

import android.view.ContextMenu
import android.view.MenuInflater
import android.view.MenuItem
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.StoryOrder
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryContextMenuReadRangeTest {
    @Test
    fun openFeedIsHiddenInsideTheFeedItself() {
        val menu = mockk<ContextMenu>(relaxed = true)
        UIUtils.inflateStoryContextMenu(menu, mockk<MenuInflater>(relaxed = true), FeedSet.singleFeed("11"), Story(), StoryOrder.NEWEST)
        verify { menu.removeItem(R.id.menu_go_to_feed) }
    }

    @Test
    fun openFeedRemainsAvailableWhileReadingFolders() {
        for (scope in listOf(FeedSet.folder("Folder", setOf("11", "22")), FeedSet.folder("Only one feed", setOf("11")), FeedSet.allFeeds())) {
            val menu = mockk<ContextMenu>(relaxed = true)
            UIUtils.inflateStoryContextMenu(menu, mockk<MenuInflater>(relaxed = true), scope, Story(), StoryOrder.NEWEST)
            verify(exactly = 0) { menu.removeItem(R.id.menu_go_to_feed) }
        }
    }

    @Test
    fun openFeedIsHiddenInSpecialStoryLists() {
        val scopes = listOf(
            FeedSet.allSaved(),
            FeedSet.singleSavedTag("Saved tag"),
            FeedSet.singleSavedSearch("11", "search"),
            FeedSet.allRead(),
            FeedSet.infrequentFeeds(),
            FeedSet.dailyBriefing(),
            FeedSet.widelyReadStories(),
            FeedSet.longReads(),
            FeedSet.goodReads(),
            FeedSet.allSocialFeeds(),
            FeedSet.singleSocialFeed("42", "Reader"),
            FeedSet.globalShared(),
            FeedSet.widgetFeeds(null),
            FeedSet.allFeeds().apply { setFilterSaved(true) },
            FeedSet.folder("Folder", setOf("11", "22")).apply { setFilterSaved(true) },
        )
        for (scope in scopes) {
            for (order in StoryOrder.entries) {
                val menu = mockk<ContextMenu>(relaxed = true)
                UIUtils.inflateStoryContextMenu(menu, mockk<MenuInflater>(relaxed = true), scope, Story(), order)
                verify { menu.removeItem(R.id.menu_go_to_feed) }
            }
        }
    }

    @Test
    fun storyMenusHaveIconsAndSeparateReadSaveShareAndFeedGroups() {
        for (order in listOf("newest", "oldest")) {
            val document = Files.newInputStream(Paths.get("src/main/res/menu/context_story_$order.xml")).use {
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it)
            }
            val groups = document.getElementsByTagName("group")
            assertEquals(4, groups.length)
            val items = document.getElementsByTagName("item")
            for (index in 0 until items.length) {
                val attributes = items.item(index).attributes
                assertTrue("Every story action needs an icon", attributes.getNamedItem("android:icon").nodeValue.startsWith("@drawable/"))
                if (attributes.getNamedItem("android:id").nodeValue == "@+id/menu_go_to_feed") {
                    assertEquals("@string/story_menu_open_feed", attributes.getNamedItem("android:title").nodeValue)
                }
            }
            val readActions = groups.item(0).childNodes
            val directions = (0 until readActions.length).mapNotNull { index ->
                readActions.item(index).attributes?.getNamedItem("android:id")?.nodeValue
            }.filter { it.contains("stories_as_read") }
            assertEquals(
                if (order == "newest") listOf("newer", "older") else listOf("older", "newer"),
                directions.map { if (it.contains("newer")) "newer" else "older" },
            )
        }
    }

    @Test
    fun bothMenuResourcesIncludeOlderAndNewerActionsWithOrderSpecificLabels() {
        for (order in listOf("newest", "oldest")) {
            val document = Files.newInputStream(Paths.get("src/main/res/menu/context_story_$order.xml")).use {
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it)
            }
            val items = document.getElementsByTagName("item")
            val titles = (0 until items.length).associate { index ->
                val attributes = items.item(index).attributes
                attributes.getNamedItem("android:id").nodeValue to attributes.getNamedItem("android:title").nodeValue
            }
            for (direction in listOf("older", "newer")) {
                assertEquals(
                    "@string/menu_${order}_mark_${direction}_stories_as_read",
                    titles["@+id/menu_mark_${direction}_stories_as_read"],
                )
            }
        }
    }

    @Test
    fun feedFolderAndAllStoriesKeepBothReadRangeActionsInEitherOrder() {
        for (feedSet in scopes()) {
            for (order in StoryOrder.entries) {
                val menu = mockk<ContextMenu>(relaxed = true)
                val inflater = mockk<MenuInflater>(relaxed = true)

                UIUtils.inflateStoryContextMenu(menu, inflater, feedSet, Story(), order)

                val resource = if (order == StoryOrder.NEWEST) R.menu.context_story_newest else R.menu.context_story_oldest
                verify { inflater.inflate(resource, menu) }
                verify(exactly = 0) { menu.removeItem(R.id.menu_mark_older_stories_as_read) }
                verify(exactly = 0) { menu.removeItem(R.id.menu_mark_newer_stories_as_read) }
            }
        }
    }

    @Test
    fun olderReadUsesSelectedStoryTimestampAndCurrentListScope() {
        for (feedSet in scopes()) {
            val fixture = Fixture(feedSet)

            assertTrue(fixture.click(R.id.menu_mark_older_stories_as_read))

            verify(exactly = 1) {
                fixture.feedUtils.markRead(fixture.activity, feedSet, fixture.story.timestamp, null, R.array.mark_older_read_options)
            }
        }
    }

    @Test
    fun newerReadUsesSelectedStoryTimestampAndCurrentListScope() {
        for (feedSet in scopes()) {
            val fixture = Fixture(feedSet)

            assertTrue(fixture.click(R.id.menu_mark_newer_stories_as_read))

            verify(exactly = 1) {
                fixture.feedUtils.markRead(fixture.activity, feedSet, null, fixture.story.timestamp, R.array.mark_newer_read_options)
            }
        }
    }

    private fun scopes() = listOf(FeedSet.singleFeed("11"), FeedSet.folder("Folder", setOf("11", "22")), FeedSet.allFeeds())

    private class Fixture(feedSet: FeedSet) {
        val activity = mockk<NbActivity>(relaxed = true)
        val feedUtils = mockk<FeedUtils>(relaxed = true)
        val story = Story().apply {
            storyHash = "11:chosen"
            feedId = "11"
            timestamp = 1_789_650_123_000L
        }
        private val adapter = mockk<StoryViewAdapter>(relaxed = true)
        private val holder = mockk<StoryViewAdapter.StoryViewHolder>(relaxed = true)

        init {
            // StoryViewAdapter.kt callbacks run without constructing the Android row and its image loaders.
            for ((name, value) in mapOf("context" to activity, "feedUtils" to feedUtils, "fs" to feedSet)) {
                StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
            }
            for ((name, value) in mapOf("this\$0" to adapter, "story" to story)) {
                StoryViewAdapter.StoryViewHolder::class.java.getDeclaredField(name).apply { isAccessible = true }.set(holder, value)
            }
            every { holder.onMenuItemClick(any()) } answers { callOriginal() }
        }

        fun click(id: Int): Boolean {
            val item = mockk<MenuItem> { every { itemId } returns id }
            return holder.onMenuItemClick(item)
        }
    }
}
