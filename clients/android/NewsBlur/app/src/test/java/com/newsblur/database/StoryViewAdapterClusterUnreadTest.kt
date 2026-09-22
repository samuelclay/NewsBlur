package com.newsblur.database

import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.StoryListStyle
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertFalse
import org.junit.Test

class StoryViewAdapterClusterUnreadTest {
    @Test fun explicitlyUnreadChildStaysUnreadUnderAReadParent() {
        val prefs = mockk<PrefsRepo>(relaxed = true)
        every { prefs.getBoolean(any(), any()) } returns true
        every { prefs.getString(any(), any()) } returns "related"
        every { prefs.isClusterMarkReadEnabled() } returns true
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        for ((name, value) in mapOf("prefsRepo" to prefs, "listStyle" to StoryListStyle.LIST)) {
            StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
        }
        every { adapter["subscribedFeedIds"]() } returns setOf("1", "2")
        every { adapter["isArchiveUser"]() } returns true
        every { adapter["buildDisplayItems"](any<List<Story>>()) } answers { callOriginal() }
        val child = Story.ClusterStory().apply { storyHash = "2:child"; feedId = "2"; read = false }
        val parent = Story().apply { storyHash = "1:parent"; feedId = "1"; read = true; clusterStories = arrayOf(child) }

        // StoryViewAdapter.kt must display the repository's reconciled child state.
        val method = StoryViewAdapter::class.java.getDeclaredMethod("buildDisplayItems", List::class.java).apply { isAccessible = true }
        val rows = method.invoke(adapter, listOf(parent)) as List<*>
        val displayed = rows.filterIsInstance<StoryViewAdapter.DisplayItem.ClusterRow>().single()

        assertFalse("An explicit unread choice must remain visible under a read parent", displayed.clusterStory.read)
    }
}
