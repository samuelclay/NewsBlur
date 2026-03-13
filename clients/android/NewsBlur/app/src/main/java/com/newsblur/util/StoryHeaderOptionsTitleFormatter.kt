package com.newsblur.util

object StoryHeaderOptionsTitleFormatter {
    fun format(
        filterText: String,
        orderText: String,
        defaultText: String,
        showReadFilter: Boolean,
        showOrder: Boolean,
    ): String =
        when {
            showReadFilter && showOrder -> "$filterText \u00B7 $orderText"
            showReadFilter -> filterText
            showOrder -> orderText
            else -> defaultText
        }
}
