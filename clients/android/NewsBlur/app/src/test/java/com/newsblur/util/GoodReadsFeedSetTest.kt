package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoodReadsFeedSetTest {
    @Test
    fun goodReadsBuildsTheGoodReadsTrendingRiver() {
        val feedSet = FeedSet.goodReads()

        assertTrue(feedSet.isGoodReads())
        assertEquals("good_reads", feedSet.trendingType)
        assertEquals("trending:good_reads", feedSet.trendingFeedId)
        assertEquals(PrefConstants.GOOD_READS_FOLDER_NAME, feedSet.trendingPreferenceName)
    }
}
