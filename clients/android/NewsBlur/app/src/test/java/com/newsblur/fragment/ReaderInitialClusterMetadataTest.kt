package com.newsblur.fragment

import android.os.Bundle
import android.view.View
import com.newsblur.domain.Story
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Test

class ReaderInitialClusterMetadataTest {
    @Test fun recreatedReaderAppliesLoadedMetadataAndRefreshesItsVisibleFooter() {
        val restored = Story().apply { storyHash = "1:parent" }
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        fragment.story = restored
        every { fragment.view } returns mockk<View>()
        val clusters = arrayOf(Story.ClusterStory().apply { storyHash = "2:match" })
        restore(fragment, restored, clusters)
        assertEquals("2:match", fragment.story?.clusterStories?.firstOrNull()?.storyHash)
        verify(exactly = 1) { fragment["setupItemMetadata"]() }
    }

    @Test fun delayedRestorationDoesNotReplaceMetadataFromAFresherPagerUpdate() {
        val restored = Story().apply { storyHash = "1:parent" }
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        fragment.story = Story().apply {
            storyHash = "1:parent"
            clusterStories = arrayOf(Story.ClusterStory().apply { storyHash = "3:new" })
        }
        restore(fragment, restored, arrayOf(Story.ClusterStory().apply { storyHash = "2:stale" }))
        assertEquals("3:new", fragment.story?.clusterStories?.firstOrNull()?.storyHash)
        verify(exactly = 0) { fragment["setupItemMetadata"]() }
    }

    private fun restore(fragment: ReadingItemFragment, story: Story, clusters: Array<Story.ClusterStory>) {
        every { fragment["applyRestoredClusterMetadata"](any<Story>(), any<Array<Story.ClusterStory>>()) } answers { callOriginal() }
        ReadingItemFragment::class.java.getDeclaredMethod("applyRestoredClusterMetadata", Story::class.java, Array<Story.ClusterStory>::class.java).apply {
            isAccessible = true
            invoke(fragment, story, clusters)
        }
    }

    @Test
    fun newReaderKeepsRelatedMetadataInMemoryWithoutEnlargingSavedState() {
        mockkConstructor(Bundle::class)
        try {
            var bundledStory: Story? = null
            every { anyConstructed<Bundle>().putSerializable(any(), any()) } just Runs
            every { anyConstructed<Bundle>().putSerializable("story", any()) } answers {
                bundledStory = secondArg<Story>()
            }
            every { anyConstructed<Bundle>().putString(any(), any()) } just Runs
            every { anyConstructed<Bundle>().putBoolean(any(), any()) } just Runs
            every { anyConstructed<Bundle>().putFloat(any(), any()) } just Runs
            val source = Story().apply {
                storyHash = "1:parent"
                clusterStories = arrayOf(Story.ClusterStory().apply {
                    storyHash = "2:match"
                    feedId = "2"
                    title = "Matched story"
                })
            }
            val fragment = ReadingItemFragment.newInstance(source, "Feed", null, null, null, null, null, null, true, null)
            assertEquals("2:match", fragment.story?.clusterStories?.firstOrNull()?.storyHash)
            assertEquals(0, source.copyForBundle().clusterStories.size)
            assertEquals(0, bundledStory?.clusterStories?.size)
        } finally {
            unmockkConstructor(Bundle::class)
        }
    }
}
