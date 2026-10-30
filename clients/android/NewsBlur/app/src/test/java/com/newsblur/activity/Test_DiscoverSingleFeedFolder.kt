package com.newsblur.activity

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.Test

class Test_DiscoverSingleFeedFolder {
    @Test
    fun test_one_feed_folder_uses_folder_discovery_without_a_null_feed_lookup() {
        val activity = mockk<ItemsList>(relaxed = true)
        val database = mockk<BlurDatabaseHelper>()
        every { database.getFeed(any()) } answers {
            requireNotNull(firstArg<String?>()) { "the bind value at index 1 is null" }
            null
        }
        val feedSet = FeedSet.folder("Blogs", setOf("42"))
        ItemsList::class.java.getDeclaredField("fs").apply {
            isAccessible = true
            set(activity, feedSet)
        }
        ItemsList::class.java.getDeclaredField("dbHelper").apply {
            isAccessible = true
            set(activity, database)
        }
        every { activity["shouldShowDiscoverAction"]() } returns true
        every { activity.openDiscoverFeeds() } answers { callOriginal() }
        mockkObject(DiscoverFeedsActivity.Companion)
        try {
            every { DiscoverFeedsActivity.startForFeeds(activity, any()) } returns Unit
            activity.openDiscoverFeeds()
            verify(exactly = 1) { DiscoverFeedsActivity.startForFeeds(activity, setOf("42")) }
            verify(exactly = 0) { database.getFeed(any()) }
        } finally {
            unmockkObject(DiscoverFeedsActivity.Companion)
        }
    }
}
