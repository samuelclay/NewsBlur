package com.newsblur.util

import androidx.window.embedding.ActivityEmbeddingController
import com.newsblur.NbApplication
import com.newsblur.activity.FeedListDrawer
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_LegacyTabletFeedNavigation {
    @Test
    fun test_opening_feed_drawer_on_legacy_tablet_does_not_invalidate_unsupported_stacks() = withEmbedding(false) { activity, embedding ->
        StorySplitView.prepareFeedList(activity, true)
        verify(exactly = 0) { embedding.invalidateVisibleActivityStacks() }
    }

    @Test
    fun test_returning_to_titles_on_legacy_tablet_does_not_invalidate_unsupported_stacks() = withEmbedding(false) { activity, embedding ->
        StorySplitView.showStoryTitles(activity)
        verify(exactly = 0) { embedding.invalidateVisibleActivityStacks() }
    }

    @Test
    fun test_supported_tablet_keeps_feed_focus_and_refreshes_existing_split() = withEmbedding(true) { activity, embedding ->
        StorySplitView.prepareFeedList(activity, true)
        assertTrue(StorySplitView.isFeedListFullscreen(activity))
        StorySplitView.prepareFeedList(activity, false)
        assertFalse(StorySplitView.isFeedListFullscreen(activity))
        StorySplitView.showStoryTitles(activity)
        verify(exactly = 3) { embedding.invalidateVisibleActivityStacks() }
    }

    private fun withEmbedding(supported: Boolean, block: (FeedListDrawer, ActivityEmbeddingController) -> Unit) {
        val support = StorySplitView::class.java.getDeclaredField("readerFullscreenSupported").apply { isAccessible = true }
        val request = StorySplitView::class.java.getDeclaredField("feedFullscreenRequested").apply { isAccessible = true }
        val originalSupport = support.getBoolean(null)
        val originalRequest = request.get(null)
        mockkObject(ActivityEmbeddingController.Companion)
        try {
            support.setBoolean(null, supported)
            val application = mockk<NbApplication>(relaxed = true)
            val activity = mockk<FeedListDrawer>(relaxed = true)
            every { activity.applicationContext } returns application
            every { application.prefsRepo.get().isFeedListFullscreenEnabled() } returns true
            every { application.prefsRepo.get().isStoryListFullscreenEnabled() } returns false
            val embedding = mockk<ActivityEmbeddingController>(relaxed = true)
            every { ActivityEmbeddingController.getInstance(any()) } returns embedding
            if (!supported) {
                // Test_LegacyTabletFeedNavigation.kt mirrors EmbeddingCompat's extension 3 requirement.
                every { embedding.invalidateVisibleActivityStacks() } throws UnsupportedOperationException("Requires extension version 3")
            }
            block(activity, embedding)
        } finally {
            support.setBoolean(null, originalSupport)
            request.set(null, originalRequest)
            unmockkObject(ActivityEmbeddingController.Companion)
        }
    }
}
