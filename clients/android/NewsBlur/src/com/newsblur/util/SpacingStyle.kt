package com.newsblur.util

import android.content.Context

enum class SpacingStyle {
    COMFORTABLE, // default
    COMPACT,
    ;

    fun getGroupTitleVerticalPadding(context: Context): Int = when (this) {
        COMFORTABLE -> UIUtils.dp2px(context, 9)
        COMPACT -> UIUtils.dp2px(context, 4)
    }

    fun getChildTitleVerticalPadding(context: Context): Int = when (this) {
        COMFORTABLE -> UIUtils.dp2px(context, 7)
        COMPACT -> UIUtils.dp2px(context, 3)
    }

    fun getStoryTitleVerticalPadding(context: Context): Int = when (this) {
        COMFORTABLE -> UIUtils.dp2px(context, 6)
        COMPACT -> UIUtils.dp2px(context, 1)
    }

    fun getStoryContentVerticalPadding(context: Context): Int = when (this) {
        COMFORTABLE -> UIUtils.dp2px(context, 6)
        COMPACT -> UIUtils.dp2px(context, 1)
    }
}