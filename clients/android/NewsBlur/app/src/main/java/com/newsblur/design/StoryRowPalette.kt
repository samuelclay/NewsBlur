package com.newsblur.design

import com.newsblur.util.PrefConstants.ThemeValue

object StoryRowPalette {
    private data class TextColors(
        val feed: Int,
        val readFeed: Int,
        val heading: Int,
        val readHeading: Int,
        val metadata: Int,
        val read: Int,
    )

    fun feedTitleArgb(
        theme: ThemeValue,
        isRead: Boolean,
    ): Int {
        val colors = textColors(theme)
        return if (isRead) colors.readFeed else colors.feed
    }

    fun storyTitleArgb(theme: ThemeValue, isRead: Boolean): Int {
        val colors = textColors(theme)
        return if (isRead) colors.readHeading else colors.heading
    }

    fun metadataArgb(theme: ThemeValue, isRead: Boolean): Int {
        val colors = textColors(theme)
        return if (isRead) colors.read else colors.metadata
    }

    // FeedDetailTableCell.m keeps feed names secondary to headlines in its iOS palette.
    private fun textColors(theme: ThemeValue): TextColors =
        when (theme) {
            ThemeValue.SEPIA ->
                TextColors(
                    feed = 0xFF606060.toInt(),
                    readFeed = 0xFF808080.toInt(),
                    heading = 0xFF333333.toInt(),
                    readHeading = 0xFF585858.toInt(),
                    metadata = 0xFF404040.toInt(),
                    read = 0xFFB8B8B8.toInt(),
                )

            ThemeValue.DARK ->
                TextColors(
                    feed = 0xFFD0D0D0.toInt(),
                    readFeed = 0xFFB0B0B0.toInt(),
                    heading = 0xFFD0D0D0.toInt(),
                    readHeading = 0xFF989898.toInt(),
                    metadata = 0xFFC0C0C0.toInt(),
                    read = 0xFFA0A0A0.toInt(),
                )

            ThemeValue.BLACK ->
                TextColors(
                    feed = 0xFF909090.toInt(),
                    readFeed = 0xFF707070.toInt(),
                    heading = 0xFFCCCCCC.toInt(),
                    readHeading = 0xFF888888.toInt(),
                    metadata = 0xFFB0B0B0.toInt(),
                    read = 0xFF707070.toInt(),
                )

            else ->
                TextColors(
                    feed = 0xFF606060.toInt(),
                    readFeed = 0xFF808080.toInt(),
                    heading = 0xFF111111.toInt(),
                    readHeading = 0xFF585858.toInt(),
                    metadata = 0xFF404040.toInt(),
                    read = 0xFFB8B8B8.toInt(),
                )
        }
}
