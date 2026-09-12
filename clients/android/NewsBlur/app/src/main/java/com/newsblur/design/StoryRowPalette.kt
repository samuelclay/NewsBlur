package com.newsblur.design

import com.newsblur.util.PrefConstants.ThemeValue

object StoryRowPalette {
    private data class TextColors(
        val heading: Int,
        val metadata: Int,
        val read: Int,
    )

    fun feedTitleArgb(
        theme: ThemeValue,
        isRead: Boolean,
    ): Int {
        val colors = textColors(theme)
        return if (isRead) colors.read else colors.heading
    }

    fun metadataArgb(theme: ThemeValue, isRead: Boolean): Int {
        val colors = textColors(theme)
        return if (isRead) colors.read else colors.metadata
    }

    // StoryRowPalette.kt shares the unified heading/read colors from iOS FeedDetailTableCell.m.
    private fun textColors(theme: ThemeValue): TextColors =
        when (theme) {
            ThemeValue.SEPIA ->
                TextColors(
                    heading = 0xFF333333.toInt(),
                    metadata = 0xFF404040.toInt(),
                    read = 0xFFB8B8B8.toInt(),
                )

            ThemeValue.DARK ->
                TextColors(
                    heading = 0xFFD0D0D0.toInt(),
                    metadata = 0xFFC0C0C0.toInt(),
                    read = 0xFFA0A0A0.toInt(),
                )

            ThemeValue.BLACK ->
                TextColors(
                    heading = 0xFFCCCCCC.toInt(),
                    metadata = 0xFFB0B0B0.toInt(),
                    read = 0xFF707070.toInt(),
                )

            else ->
                TextColors(
                    heading = 0xFF111111.toInt(),
                    metadata = 0xFF404040.toInt(),
                    read = 0xFFB8B8B8.toInt(),
                )
        }
}
