package com.newsblur.database

import com.newsblur.design.StoryRowPalette
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryRowPaletteTest {
    @Test
    fun readMetadataAndHeadingsUseOneColorInEveryTheme() {
        listOf(ThemeValue.LIGHT, ThemeValue.SEPIA, ThemeValue.DARK, ThemeValue.BLACK).forEach { theme ->
            assertEquals(StoryRowPalette.feedTitleArgb(theme, true), StoryRowPalette.metadataArgb(theme, true))
        }
    }

    @Test
    fun feedTitleColorsMatchTheUnifiedIosHeadingPalette() {
        assertEquals(0xFF111111.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.LIGHT, isRead = false))
        assertEquals(0xFFB8B8B8.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.LIGHT, isRead = true))
        assertEquals(0xFF333333.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.SEPIA, isRead = false))
        assertEquals(0xFFB8B8B8.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.SEPIA, isRead = true))
        assertEquals(0xFFD0D0D0.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.DARK, isRead = false))
        assertEquals(0xFFA0A0A0.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.DARK, isRead = true))
        assertEquals(0xFFCCCCCC.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.BLACK, isRead = false))
        assertEquals(0xFF707070.toInt(), StoryRowPalette.feedTitleArgb(ThemeValue.BLACK, isRead = true))
    }
}
