package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class Test_TryFeedMetadata {
    @Test fun test_reader_can_resolve_preview_metadata_before_first_feed_fetch() {
        val db = mockk<BlurDatabaseHelper>()
        every { db.getFeed(any()) } returns null
        val preview = Feed().apply { feedId = "42"; title = "Preview" }
        val store = TryFeedStore().apply { set(preview) }
        val utils = FeedUtils(db, mockk(), mockk(), mockk(), store, mockk())
        assertSame(preview, utils.getFeed("42"))
        assertNull(utils.getFeed("99"))
        store.clear()
        assertNull(utils.getFeed("42"))
    }

    @Test fun test_subscribed_metadata_takes_precedence_over_preview() {
        val subscribed = Feed().apply { feedId = "42"; title = "Subscribed" }
        val db = mockk<BlurDatabaseHelper>()
        every { db.getFeed("42") } returns subscribed
        val store = TryFeedStore().apply { set(Feed().apply { feedId = "42"; title = "Old preview" }) }
        val utils = FeedUtils(db, mockk(), mockk(), mockk(), store, mockk())
        assertSame(subscribed, utils.getFeed("42"))
    }
}
