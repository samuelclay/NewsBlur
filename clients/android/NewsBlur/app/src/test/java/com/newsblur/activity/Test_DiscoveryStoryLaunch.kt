package com.newsblur.activity

import android.content.Context
import android.content.Intent
import com.newsblur.domain.Feed
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test

class Test_DiscoveryStoryLaunch {
    private val context = mockk<Context>(relaxed = true)
    private val feed = Feed().apply {
        feedId = "42"
        address = "https://example.com/rss"
        title = "Example"
    }

    @Before fun setUp() {
        mockkConstructor(Intent::class)
        every { anyConstructed<Intent>().putExtra(any<String>(), any<String>()) } answers { self as Intent }
        every { anyConstructed<Intent>().putExtra(any<String>(), any<java.io.Serializable>()) } answers { self as Intent }
        every { anyConstructed<Intent>().putExtra(any<String>(), any<Boolean>()) } answers { self as Intent }
    }

    @After fun tearDown() = unmockkConstructor(Intent::class)

    @Test fun test_unsubscribed_story_opens_exact_hash_in_existing_try_feed_flow() {
        FeedItemsList.startTryFeedActivity(context, feed, "42:second")
        verify {
            anyConstructed<Intent>().putExtra(FeedItemsList.EXTRA_FEED, feed)
            anyConstructed<Intent>().putExtra(FeedItemsList.EXTRA_TRY_FEED_URL, feed.address)
            anyConstructed<Intent>().putExtra(FeedItemsList.EXTRA_IS_TRY_FEED, true)
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_STORY_HASH, "42:second")
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_AUTO_OPEN_STORY, true)
            context.startActivity(any())
        }
    }

    @Test fun test_try_button_still_opens_feed_list_without_an_exact_story() {
        FeedItemsList.startTryFeedActivity(context, feed)
        verify { anyConstructed<Intent>().putExtra(FeedItemsList.EXTRA_IS_TRY_FEED, true) }
        verify(exactly = 0) {
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_STORY_HASH, any<String>())
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_AUTO_OPEN_STORY, any<Boolean>())
        }
    }

    @Test fun test_subscribed_story_keeps_regular_feed_routing() {
        FeedItemsList.startStoryActivity(context, FeedSet.singleFeed(feed.feedId), feed, AppConstants.ROOT_FOLDER, "42:second")
        verify {
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_STORY_HASH, "42:second")
            anyConstructed<Intent>().putExtra(ItemsList.EXTRA_AUTO_OPEN_STORY, true)
        }
        verify(exactly = 0) { anyConstructed<Intent>().putExtra(FeedItemsList.EXTRA_IS_TRY_FEED, any<Boolean>()) }
    }
}
