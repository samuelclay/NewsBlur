package com.newsblur.database

import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.StoryListStyle
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryViewAdapterClusterUnreadTest {
    @Test fun explicitlyUnreadChildStaysUnreadUnderAReadParent() {
        val fixture = Fixture()
        val displayed = fixture.displayedChild()
        assertFalse("An explicit unread choice must remain visible under a read parent", displayed.clusterStory.read)
    }

    @Test fun changingClusterMarkReadAfterReadingParentDoesNotChangeChildPresentation() {
        val fixture = Fixture()
        for (enabled in listOf(false, true, false)) {
            every { fixture.prefs.isClusterMarkReadEnabled() } returns enabled
            assertFalse(fixture.displayedChild().clusterStory.read)
        }
        fixture.child.read = true
        for (enabled in listOf(true, false, true)) {
            every { fixture.prefs.isClusterMarkReadEnabled() } returns enabled
            assertTrue(fixture.displayedChild().clusterStory.read)
        }
    }

    @Test fun explicitlyUnreadingChildProducesAnInPlaceReadStateUpdate() {
        val fixture = Fixture()
        fixture.child.read = true
        val before = fixture.displayedChild()
        fixture.child.read = false
        val after = fixture.displayedChild()
        val diff = StoryViewAdapter.DisplayItemDiffer(listOf(before), listOf(after))

        assertTrue(diff.areItemsTheSame(0, 0))
        assertFalse(diff.areContentsTheSame(0, 0))
        assertNotNull("StoryViewAdapter.kt must animate the child without replacing its row", diff.getChangePayload(0, 0))
        assertEquals(true, fixture.parent.read)
    }

    private class Fixture {
        val prefs = mockk<PrefsRepo>(relaxed = true)
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        val child = Story.ClusterStory().apply { storyHash = "2:child"; feedId = "2"; read = false }
        val parent = Story().apply { storyHash = "1:parent"; feedId = "1"; read = true; clusterStories = arrayOf(child) }

        init {
            every { prefs.getBoolean(any(), any()) } returns true
            every { prefs.getString(any(), any()) } returns "related"
            every { prefs.isClusterMarkReadEnabled() } returns true
            for ((name, value) in mapOf("prefsRepo" to prefs, "listStyle" to StoryListStyle.LIST)) {
                StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
            }
            every { adapter["subscribedFeedIds"]() } returns setOf("1", "2")
            every { adapter["isArchiveUser"]() } returns true
            every { adapter["buildDisplayItems"](any<List<Story>>()) } answers { callOriginal() }
        }

        fun displayedChild(): StoryViewAdapter.DisplayItem.ClusterRow {
            val method = StoryViewAdapter::class.java.getDeclaredMethod("buildDisplayItems", List::class.java).apply { isAccessible = true }
            val rows = method.invoke(adapter, listOf(parent)) as List<*>
            return rows.filterIsInstance<StoryViewAdapter.DisplayItem.ClusterRow>().single()
        }
    }
}
