package com.newsblur.util

import android.content.res.Configuration
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryUtilDirection {
    private suspend fun html(interfaceRtl: Boolean): String =
        StoryUtil.buildMinimalHtml(
            storyHtml = "<p>Hello, world!</p>",
            fontCss = "",
            themeValue = PrefConstants.ThemeValue.LIGHT,
            nightMask = Configuration.UI_MODE_NIGHT_NO,
            enableHighlights = false,
            interfaceRtl = interfaceRtl,
        )

    @Test
    fun test_story_takes_the_direction_of_its_own_text() =
        runTest {
            // Test_StoryUtilDirection.kt: an English story inside an Arabic interface still reads left to right.
            assertTrue(html(interfaceRtl = true).contains("<div class=\"NB-story\" dir=\"auto\">"))
            assertTrue(html(interfaceRtl = false).contains("<div class=\"NB-story\" dir=\"auto\">"))
        }

    @Test
    fun test_page_follows_the_interface_direction() =
        runTest {
            assertTrue(html(interfaceRtl = true).startsWith("<html dir=\"rtl\"><head>"))
            assertTrue(html(interfaceRtl = false).startsWith("<html><head>"))
        }
}
