package com.newsblur.database

import com.newsblur.design.StoryRowPalette
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryRowPaletteTest {
    @Test
    fun feedTitleColorsMatchIosStoryList() {
        assertEquals(0xFF606060.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.LIGHT, isRead = false))
        assertEquals(0xFF808080.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.LIGHT, isRead = true))
        assertEquals(0xFF606060.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.SEPIA, isRead = false))
        assertEquals(0xFF808080.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.SEPIA, isRead = true))
        assertEquals(0xFFD0D0D0.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.DARK, isRead = false))
        assertEquals(0xFFB0B0B0.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.DARK, isRead = true))
        assertEquals(0xFF909090.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.BLACK, isRead = false))
        assertEquals(0xFF707070.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.BLACK, isRead = true))
    }
}
