package com.newsblur.util

enum class StoryRowThumbnailVerticalMode {
    CENTERED,
    MATCH_ROW_HEIGHT,
}

data class StoryRowThumbnailLayout(
    val widthPx: Int,
    val fixedHeightPx: Int?,
    val leftMarginPx: Int,
    val topMarginPx: Int,
    val rightMarginPx: Int,
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
                leftMarginPx = sideMarginPx,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
                rowHeightFraction = 0.8f,
            )
        ThumbnailStyle.LEFT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = largeWidthPx,
                fixedHeightPx = null,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT,
            )
        ThumbnailStyle.RIGHT_SMALL ->
            StoryRowThumbnailLayout(
                widthPx = smallWidthPx,
                fixedHeightPx = null,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = sideMarginPx,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
                rowHeightFraction = 0.8f,
            )
        ThumbnailStyle.RIGHT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = largeWidthPx,
                fixedHeightPx = null,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT,
            )
        ThumbnailStyle.OFF ->
            StoryRowThumbnailLayout(
                widthPx = 0,
                fixedHeightPx = 0,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
            )
    }
