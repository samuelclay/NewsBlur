package com.newsblur.util

import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class StoryRowTypographyLayoutTest {
    private fun views(layout: String): Map<String, Element> {
        val document = Files.newInputStream(Paths.get("src/main/res/layout/$layout.xml")).use {
            DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it)
        }
        val nodes = document.getElementsByTagName("*")
        return (0 until nodes.length).map { nodes.item(it) as Element }
            .associateBy { it.getAttribute("android:id").removePrefix("@+id/") }
    }

    @Test
    fun storyTitleFollowsTheEntireScalableFeedHeadingWithRoomForTheFaviconAtSmallSizes() {
        val views = views("view_story_row")
        val title = views.getValue("story_item_title")
        val feed = views.getValue("story_item_feedtitle")
        val icon = views.getValue("story_item_feedicon")
        // StoryViewAdapter.kt changes feed font size; the title must follow its measured height.
        assertEquals("@id/story_item_feedtitle", title.getAttribute("android:layout_below"))
        assertEquals("wrap_content", feed.getAttribute("android:layout_height"))
        assertTrue(feed.getAttribute("android:minHeight").removeSuffix("dp").toFloat() >=
            icon.getAttribute("android:layout_height").removeSuffix("dp").toFloat())
    }

    @Test
    fun previewAndMetadataFollowMeasuredTextAndStayOutsideTheThumbnail() {
        val views = views("view_story_row")
        assertEquals("@id/story_item_title", views.getValue("story_item_content").getAttribute("android:layout_below"))
        val metadata = views.getValue("story_item_metadata")
        assertEquals("@id/story_item_content", metadata.getAttribute("android:layout_below"))
        assertEquals("@id/story_item_thumbnail_right", metadata.getAttribute("android:layout_toLeftOf"))
        assertEquals("horizontal", metadata.getAttribute("android:orientation"))
        for (id in listOf("story_item_date", "story_item_author")) {
            val view = views.getValue(id)
            assertEquals(metadata, view.parentNode)
            assertEquals("true", view.getAttribute("android:singleLine"))
            assertEquals("end", view.getAttribute("android:ellipsize"))
        }
        assertEquals("wrap_content", views.getValue("story_item_date").getAttribute("android:layout_width"))
        assertEquals("0dp", views.getValue("story_item_author").getAttribute("android:layout_width"))
        assertEquals("1", views.getValue("story_item_author").getAttribute("android:layout_weight"))
    }

    @Test
    fun tilesReserveTheMeasuredFeedAndDateHeightsBelowTheTitle() {
        val views = views("view_story_tile")
        assertEquals("@id/story_item_feedtitle", views.getValue("story_item_title").getAttribute("android:layout_above"))
        assertEquals("@id/story_item_date", views.getValue("story_item_feedtitle").getAttribute("android:layout_above"))
        assertEquals("wrap_content", views.getValue("story_item_feedtitle").getAttribute("android:layout_height"))
    }
}
