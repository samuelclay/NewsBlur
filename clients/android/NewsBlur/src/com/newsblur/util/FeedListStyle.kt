package com.newsblur.util

import android.content.Context

enum class FeedListStyle {
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
}