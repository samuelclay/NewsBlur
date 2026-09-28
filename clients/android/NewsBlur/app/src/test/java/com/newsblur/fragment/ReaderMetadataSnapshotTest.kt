package com.newsblur.fragment

import com.newsblur.domain.Story
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ReaderMetadataSnapshotTest {
    @Test fun footerTracksChildReadChangesIndependentlyOfItsParentInEveryTheme() {
        for (theme in listOf(ThemeValue.LIGHT, ThemeValue.DARK, ThemeValue.BLACK, ThemeValue.SEPIA)) {
            val child = Story.ClusterStory()
            val story = Story().apply { storyHash = "1:parent"; clusterStories = arrayOf(child) }
            val unread = ReaderClusterSnapshot(story, true, theme)
            story.read = true
            assertEquals("theme=$theme: Reading the parent alone must not rebuild its unread child", unread, ReaderClusterSnapshot(story, true, theme))
            child.read = true
            val read = ReaderClusterSnapshot(story, true, theme)
            assertNotEquals("theme=$theme: Reading the child must invalidate the footer", unread, read)
            child.read = false
            val explicitlyUnread = ReaderClusterSnapshot(story, true, theme)
            assertNotEquals("theme=$theme: An explicit unread action must invalidate the footer", read, explicitlyUnread)
            assertEquals("theme=$theme: Marking unread must restore the original child state", unread, explicitlyUnread)
        }
    }

    @Test fun footerStillRefreshesWhenThemeOrArchiveAccessChanges() {
        val story = Story().apply { storyHash = "1:parent" }
        val snapshot = ReaderClusterSnapshot(story, true, ThemeValue.LIGHT)
        assertNotEquals(snapshot, ReaderClusterSnapshot(story, false, ThemeValue.LIGHT))
        assertNotEquals(snapshot, ReaderClusterSnapshot(story, true, ThemeValue.DARK))
    }

    @Test
    fun markingReadDoesNotRebuildTheArticleHeaderAndRelatedStories() {
        val story =
            Story().apply {
                title = "A story"
                tags = arrayOf("News")
            }
        val before = ReaderMetadataSnapshot(story)
        story.read = true
        story.lastReadTimestamp = 123L
        assertEquals(before, ReaderMetadataSnapshot(story))
    }

    @Test
    fun metadataChangesAreDetectedEvenWhenTheSameStoryObjectIsMutated() {
        val story =
            Story().apply {
                tags = arrayOf("News")
                userTags = arrayOf("Later")
            }
        val before = ReaderMetadataSnapshot(story)
        story.tags[0] = "Technology"
        assertNotEquals(before, ReaderMetadataSnapshot(story))
        val afterTag = ReaderMetadataSnapshot(story)
        story.starred = true
        assertNotEquals(afterTag, ReaderMetadataSnapshot(story))
    }

    @Test
    fun relatedStoryReadAndThumbnailChangesStillRefreshTheRelatedSection() {
        val cluster =
            Story.ClusterStory().apply {
                imageUrls = arrayOf("http://image")
                secureImageThumbnails = hashMapOf("http://image" to "https://first")
            }
        val story = Story().apply { clusterStories = arrayOf(cluster) }
        val before = ReaderMetadataSnapshot(story)
        cluster.read = true
        assertNotEquals(before, ReaderMetadataSnapshot(story))
        val afterRead = ReaderMetadataSnapshot(story)
        cluster.secureImageThumbnails["http://image"] = "https://second"
        assertNotEquals(afterRead, ReaderMetadataSnapshot(story))
    }
}
