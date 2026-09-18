package com.newsblur.util

data class StoryRowTypography(
    val feedSp: Float,
    val titleSp: Float,
    val previewSp: Float,
    val metadataSp: Float,
) {
    companion object {
        // FeedDetailTableCell.m uses this hierarchy; TextView keeps Android system font scaling.
        fun forScale(scale: Float): StoryRowTypography {
            val feed = when (ListTextSize.fromSize(scale)) {
                ListTextSize.XS -> 11f
                ListTextSize.S -> 13f
                ListTextSize.M -> 14f
                ListTextSize.L -> 16f
                ListTextSize.XL -> 18f
                ListTextSize.XXL -> 24f
            }
            return StoryRowTypography(feed, feed + 1f, feed - 1f, 11f)
        }
    }
}
