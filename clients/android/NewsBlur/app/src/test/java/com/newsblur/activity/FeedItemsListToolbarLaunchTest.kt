package com.newsblur.activity

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.Test

class FeedItemsListToolbarLaunchTest {
    @Test
    fun fragmentContextWrapperKeepsHiddenToolbarThroughIntermediateFeedList() {
        mockkConstructor(Intent::class)
        try {
            every { anyConstructed<Intent>().putExtra(any<String>(), any<String>()) } answers { self as Intent }
            every { anyConstructed<Intent>().putExtra(any<String>(), any<java.io.Serializable>()) } answers { self as Intent }
            every { anyConstructed<Intent>().putExtra(any<String>(), any<Boolean>()) } answers { self as Intent }
            val reading = mockk<Reading>(relaxed = true)
            every { reading.isToolbarHidden() } returns true
            val wrapped = mockk<ContextWrapper>(relaxed = true)
            every { wrapped.baseContext } returns reading

            FeedItemsList.startStoryActivity(wrapped, mockk(), mockk(), "Blogs", "8077169:08e39e")

            verify { anyConstructed<Intent>().putExtra(Reading.EXTRA_TOOLBAR_HIDDEN, true) }
        } finally {
            unmockkConstructor(Intent::class)
        }
    }

    @Test
    fun relatedFeedLaunchCarriesReaderVisibilityButFreshListsStayVisible() {
        mockkConstructor(Intent::class)
        try {
            every { anyConstructed<Intent>().putExtra(any<String>(), any<String>()) } answers { self as Intent }
            every { anyConstructed<Intent>().putExtra(any<String>(), any<java.io.Serializable>()) } answers { self as Intent }
            every { anyConstructed<Intent>().putExtra(any<String>(), any<Boolean>()) } answers { self as Intent }
            val reading = mockk<Reading>(relaxed = true)
            val feedSet = mockk<FeedSet>()
            val feed = mockk<com.newsblur.domain.Feed>()
            for (hidden in listOf(true, false)) {
                every { reading.isToolbarHidden() } returns hidden
                FeedItemsList.startStoryActivity(reading, feedSet, feed, "Blogs", "related-$hidden")
                verify { anyConstructed<Intent>().putExtra(Reading.EXTRA_TOOLBAR_HIDDEN, hidden) }
            }
            val freshContext = mockk<Context>(relaxed = true)
            FeedItemsList.startStoryActivity(freshContext, feedSet, feed, "Blogs", "fresh")
            verify(exactly = 2) { anyConstructed<Intent>().putExtra(Reading.EXTRA_TOOLBAR_HIDDEN, false) }
        } finally {
            unmockkConstructor(Intent::class)
        }
    }
}
