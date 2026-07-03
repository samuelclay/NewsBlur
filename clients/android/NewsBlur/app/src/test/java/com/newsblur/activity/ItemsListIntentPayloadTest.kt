package com.newsblur.activity

import java.nio.file.Files
import java.nio.file.Paths
import org.junit.Assert.assertFalse
import org.junit.Test

class ItemsListIntentPayloadTest {
    @Test
    fun sessionDataSourcesAreNotSerializedIntoActivityLaunchIntents() {
        val launchSources =
            listOf(
                Paths.get("src/main/java/com/newsblur/activity/FeedItemsList.kt"),
                Paths.get("src/main/java/com/newsblur/activity/ItemsList.java"),
                Paths.get("src/main/java/com/newsblur/fragment/FolderListFragment.java"),
            ).associateWith { String(Files.readAllBytes(it)) }

        launchSources.forEach { (path, source) ->
            assertFalse(
                "$path should not put SessionDataSource into an activity Intent",
                source.contains("putExtra(EXTRA_SESSION_DATA,") ||
                    source.contains("putExtra(ItemsList.EXTRA_SESSION_DATA,"),
            )
            assertFalse(
                "$path should not put story-list SessionDataSource into an activity Intent",
                source.contains("putExtra(EXTRA_STORY_LIST_SESSION_DATA,") ||
                    source.contains("putExtra(ItemsList.EXTRA_STORY_LIST_SESSION_DATA,"),
            )
        }
    }
}
