package com.newsblur.util

enum class StoryRowThumbnailVerticalMode {
    CENTERED,
    MATCH_ROW_HEIGHT,
}

// StoryRowThumbnailLayout.kt uses start and end margins, so a "left" thumbnail sits on the
// reading start side (the right) in right-to-left languages.
data class StoryRowThumbnailLayout(
    val widthPx: Int,
    val fixedHeightPx: Int?,
    val startMarginPx: Int,
    val topMarginPx: Int,
    val endMarginPx: Int,
    val bottomMarginPx: Int,
    val verticalMode: StoryRowThumbnailVerticalMode,
    val rowHeightFraction: Float = 1f,
)

fun ThumbnailStyle.storyRowLayout(
    largeWidthPx: Int,
    smallWidthPx: Int,
    verticalMarginPx: Int,
    sideMarginPx: Int,
): StoryRowThumbnailLayout =
    when (this) {
        ThumbnailStyle.LEFT_SMALL ->
            StoryRowThumbnailLayout(
                widthPx = smallWidthPx,
                fixedHeightPx = null,
                startMarginPx = sideMarginPx,
                topMarginPx = 0,
                endMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
                rowHeightFraction = 0.8f,
            )
        ThumbnailStyle.LEFT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = largeWidthPx,
                fixedHeightPx = null,
                startMarginPx = 0,
                topMarginPx = 0,
                endMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT,
            )
        ThumbnailStyle.RIGHT_SMALL ->
            StoryRowThumbnailLayout(
                widthPx = smallWidthPx,
                fixedHeightPx = null,
                startMarginPx = 0,
                topMarginPx = 0,
                endMarginPx = sideMarginPx,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
                rowHeightFraction = 0.8f,
            )
        ThumbnailStyle.RIGHT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = largeWidthPx,
                fixedHeightPx = null,
                startMarginPx = 0,
                topMarginPx = 0,
                endMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT,
            )
        ThumbnailStyle.OFF ->
            StoryRowThumbnailLayout(
                widthPx = 0,
                fixedHeightPx = 0,
                startMarginPx = 0,
                topMarginPx = 0,
                endMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
            )
    }
