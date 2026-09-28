package com.newsblur.database

import com.newsblur.design.StoryRowPalette
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryRowPaletteTest {
    @Test
    fun feedNamesAndHeadlinesUseTheirReadAndUnreadThemeColors() {
        val expected = mapOf(
            ThemeValue.LIGHT to listOf(0x606060, 0x808080, 0x111111, 0xB0B0B0),
            ThemeValue.SEPIA to listOf(0x606060, 0x808080, 0x333333, 0xA8A8A8),
            ThemeValue.DARK to listOf(0xD0D0D0, 0xB0B0B0, 0xD0D0D0, 0x909090),
            ThemeValue.BLACK to listOf(0x909090, 0x707070, 0xCCCCCC, 0x808080),
        )
        expected.forEach { (theme, colors) ->
            assertEquals(colors[0] or 0xFF000000.toInt(), StoryRowPalette.feedTitleArgb(theme, false))
            assertEquals(colors[1] or 0xFF000000.toInt(), StoryRowPalette.feedTitleArgb(theme, true))
            assertEquals(colors[2] or 0xFF000000.toInt(), StoryRowPalette.storyTitleArgb(theme, false))
            assertEquals(colors[3] or 0xFF000000.toInt(), StoryRowPalette.storyTitleArgb(theme, true))
        }
    }

    @Test
    fun previewAndMetadataKeepTheirQuieterReadColors() {
        val expected = mapOf(
            ThemeValue.LIGHT to (0x404040 to 0xB8B8B8),
            ThemeValue.SEPIA to (0x404040 to 0xB8B8B8),
            ThemeValue.DARK to (0xC0C0C0 to 0xA0A0A0),
            ThemeValue.BLACK to (0xB0B0B0 to 0x707070),
        )
        expected.forEach { (theme, colors) ->
            assertEquals(colors.first or 0xFF000000.toInt(), StoryRowPalette.metadataArgb(theme, false))
            assertEquals(colors.second or 0xFF000000.toInt(), StoryRowPalette.metadataArgb(theme, true))
        }
    }
}
