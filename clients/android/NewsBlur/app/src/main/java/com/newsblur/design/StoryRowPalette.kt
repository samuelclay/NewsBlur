package com.newsblur.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.newsblur.util.PrefConstants.ThemeValue

object StoryRowPalette {
    private data class FeedTitleColors(
        val unread: Color,
        val read: Color,
    )

    fun feedTitleArgb(
        theme: ThemeValue,
        isRead: Boolean,
    ): Int {
        val colors = feedTitleColors(theme)
        return (if (isRead) colors.read else colors.unread).toArgb()
    }

    private fun feedTitleColors(theme: ThemeValue): FeedTitleColors =
        when (theme) {
            ThemeValue.SEPIA ->
                FeedTitleColors(
                    unread = Color(0xFF606060),
                    read = Color(0xFF808080),
                )

            // Matches the river/social siteTitle colors in clients/ios/Classes/FeedDetailTableCell.m.
            ThemeValue.DARK ->
                FeedTitleColors(
                    unread = Color(0xFFD0D0D0),
                    read = Color(0xFFB0B0B0),
                )

            ThemeValue.BLACK ->
                FeedTitleColors(
                    unread = Color(0xFF909090),
                    read = Color(0xFF707070),
                )

            else ->
                FeedTitleColors(
                    unread = Color(0xFF606060),
                    read = Color(0xFF808080),
                )
        }
}
