package com.newsblur.util

enum class StoryRowThumbnailVerticalMode {
    CENTERED,
    FILL_ROW_HEIGHT,
}

data class StoryRowThumbnailLayout(
    val widthPx: Int,
    val fixedHeightPx: Int?,
    val leftMarginPx: Int,
    val topMarginPx: Int,
    val rightMarginPx: Int,
    val bottomMarginPx: Int,
    val verticalMode: StoryRowThumbnailVerticalMode,
)

fun ThumbnailStyle.storyRowLayout(
    sizePx: Int,
    verticalMarginPx: Int,
    sideMarginPx: Int,
): StoryRowThumbnailLayout =
    when (this) {
        ThumbnailStyle.LEFT_SMALL ->
            StoryRowThumbnailLayout(
                widthPx = sizePx,
                fixedHeightPx = sizePx,
                leftMarginPx = sideMarginPx,
                topMarginPx = verticalMarginPx,
                rightMarginPx = 0,
                bottomMarginPx = verticalMarginPx,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
            )
        ThumbnailStyle.LEFT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = sizePx,
                fixedHeightPx = null,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.FILL_ROW_HEIGHT,
            )
        ThumbnailStyle.RIGHT_SMALL ->
            StoryRowThumbnailLayout(
                widthPx = sizePx,
                fixedHeightPx = sizePx,
                leftMarginPx = 0,
                topMarginPx = verticalMarginPx,
                rightMarginPx = sideMarginPx,
                bottomMarginPx = verticalMarginPx,
                verticalMode = StoryRowThumbnailVerticalMode.CENTERED,
            )
        ThumbnailStyle.RIGHT_LARGE ->
            StoryRowThumbnailLayout(
                widthPx = sizePx,
                fixedHeightPx = null,
                leftMarginPx = 0,
                topMarginPx = 0,
                rightMarginPx = 0,
                bottomMarginPx = 0,
                verticalMode = StoryRowThumbnailVerticalMode.FILL_ROW_HEIGHT,
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
