package com.newsblur.activity

import com.newsblur.domain.Feed
import io.mockk.every
import io.mockk.mockk
import io.mockk.spyk
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_NotificationsAdapter {
    @Test
    fun test_replayed_and_replaced_feeds_keep_recycler_count_in_sync() {
        val adapter = spyk(NotificationsAdapter(mockk(), mockk()))
        var recyclerCount = 0
        every { adapter.notifyItemRangeInserted(any(), any()) } answers { recyclerCount += secondArg<Int>() }
        every { adapter.notifyItemRangeRemoved(any(), any()) } answers { recyclerCount -= secondArg<Int>() }
        every { adapter.notifyDataSetChanged() } answers { recyclerCount = adapter.itemCount }

        val feeds = listOf(Feed().apply { feedId = "1" }, Feed().apply { feedId = "2" })
        // NotificationsActivity.kt collects the same StateFlow again each time it returns to STARTED.
        for (snapshot in listOf(feeds, feeds, feeds.takeLast(1), emptyList())) {
            adapter.refreshFeeds(snapshot)
            assertEquals(snapshot.size, adapter.itemCount)
            assertEquals(adapter.itemCount, recyclerCount)
        }
    }
}
