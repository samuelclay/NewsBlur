package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryRowTypographyTest {
    @Test
    fun eachVisibleSizeMatchesIosAndKeepsTheHeadlineLargerThanTheFeed() {
        val feedSizes = listOf(11f, 13f, 14f, 16f, 18f)
        ListTextSize.entries.take(5).zip(feedSizes).forEach { (size, feedSp) ->
            val typography = StoryRowTypography.forScale(size.size)
            assertEquals(feedSp, typography.feedSp)
            assertEquals(feedSp + 1f, typography.titleSp)
            assertEquals(feedSp - 1f, typography.previewSp)
            assertEquals(11f, typography.metadataSp)
        }
    }

    @Test
    fun legacyExtraExtraLargeRemainsLargerWithoutGrowingDateAndAuthorIntoTheHeadline() {
        val xl = StoryRowTypography.forScale(ListTextSize.XL.size)
        val legacy = StoryRowTypography.forScale(ListTextSize.XXL.size)
        assertTrue(legacy.feedSp > xl.feedSp)
        assertTrue(legacy.titleSp > legacy.feedSp)
        assertTrue(legacy.previewSp > xl.previewSp)
        assertEquals(xl.metadataSp, legacy.metadataSp)
    }
}
