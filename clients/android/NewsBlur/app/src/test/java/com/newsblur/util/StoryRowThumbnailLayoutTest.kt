package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StoryRowThumbnailLayoutTest {
    @Test
    fun rightLargeThumbnailsFillTheRowHeight() {
        val layout = ThumbnailStyle.RIGHT_LARGE.storyRowLayout(sizePx = 120, verticalMarginPx = 6, sideMarginPx = 8)

        assertEquals(120, layout.widthPx)
        assertNull(layout.fixedHeightPx)
        assertEquals(StoryRowThumbnailVerticalMode.FILL_ROW_HEIGHT, layout.verticalMode)
        assertEquals(0, layout.topMarginPx)
        assertEquals(0, layout.bottomMarginPx)
    }

    @Test
    fun leftLargeThumbnailsFillTheRowHeight() {
        val layout = ThumbnailStyle.LEFT_LARGE.storyRowLayout(sizePx = 120, verticalMarginPx = 10, sideMarginPx = 8)

        assertEquals(120, layout.widthPx)
        assertNull(layout.fixedHeightPx)
        assertEquals(StoryRowThumbnailVerticalMode.FILL_ROW_HEIGHT, layout.verticalMode)
        assertEquals(0, layout.topMarginPx)
        assertEquals(0, layout.bottomMarginPx)
    }

    @Test
    fun smallThumbnailsStayCenteredSquares() {
        val rightSmall = ThumbnailStyle.RIGHT_SMALL.storyRowLayout(sizePx = 54, verticalMarginPx = 10, sideMarginPx = 8)
        val leftSmall = ThumbnailStyle.LEFT_SMALL.storyRowLayout(sizePx = 54, verticalMarginPx = 10, sideMarginPx = 8)

        assertEquals(54, rightSmall.fixedHeightPx)
        assertEquals(8, rightSmall.rightMarginPx)
        assertEquals(StoryRowThumbnailVerticalMode.CENTERED, rightSmall.verticalMode)

        assertEquals(54, leftSmall.fixedHeightPx)
        assertEquals(8, leftSmall.leftMarginPx)
        assertEquals(StoryRowThumbnailVerticalMode.CENTERED, leftSmall.verticalMode)
        assertEquals(10, leftSmall.topMarginPx)
        assertEquals(10, leftSmall.bottomMarginPx)
    }
}
