package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StoryRowThumbnailLayoutTest {
    @Test
    fun rightLargeThumbnailsMatchTheMeasuredRowHeight() {
        val layout =
            ThumbnailStyle.RIGHT_LARGE.storyRowLayout(
                largeWidthPx = 120,
                smallWidthPx = 96,
                verticalMarginPx = 6,
                sideMarginPx = 8,
            )

        assertEquals(120, layout.widthPx)
        assertNull(layout.fixedHeightPx)
        assertEquals(StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT, layout.verticalMode)
        assertEquals(0, layout.topMarginPx)
        assertEquals(0, layout.bottomMarginPx)
    }

    @Test
    fun leftLargeThumbnailsMatchTheMeasuredRowHeight() {
        val layout =
            ThumbnailStyle.LEFT_LARGE.storyRowLayout(
                largeWidthPx = 120,
                smallWidthPx = 96,
                verticalMarginPx = 10,
                sideMarginPx = 8,
            )

        assertEquals(120, layout.widthPx)
        assertNull(layout.fixedHeightPx)
        assertEquals(StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT, layout.verticalMode)
        assertEquals(0, layout.topMarginPx)
        assertEquals(0, layout.bottomMarginPx)
    }

    @Test
    fun smallThumbnailsStayCenteredAndUseWebLikeWidthRatio() {
        val rightSmall =
            ThumbnailStyle.RIGHT_SMALL.storyRowLayout(
                largeWidthPx = 120,
                smallWidthPx = 96,
                verticalMarginPx = 10,
                sideMarginPx = 8,
            )
        val leftSmall =
            ThumbnailStyle.LEFT_SMALL.storyRowLayout(
                largeWidthPx = 120,
                smallWidthPx = 96,
                verticalMarginPx = 10,
                sideMarginPx = 8,
            )

        assertEquals(96, rightSmall.widthPx)
        assertNull(rightSmall.fixedHeightPx)
        assertEquals(8, rightSmall.rightMarginPx)
        assertEquals(StoryRowThumbnailVerticalMode.CENTERED, rightSmall.verticalMode)
        assertEquals(0.8f, rightSmall.rowHeightFraction)

        assertEquals(96, leftSmall.widthPx)
        assertNull(leftSmall.fixedHeightPx)
        assertEquals(8, leftSmall.leftMarginPx)
        assertEquals(StoryRowThumbnailVerticalMode.CENTERED, leftSmall.verticalMode)
        assertEquals(0.8f, leftSmall.rowHeightFraction)
    }
}
