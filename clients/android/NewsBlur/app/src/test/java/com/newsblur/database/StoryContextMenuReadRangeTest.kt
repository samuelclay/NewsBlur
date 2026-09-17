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
