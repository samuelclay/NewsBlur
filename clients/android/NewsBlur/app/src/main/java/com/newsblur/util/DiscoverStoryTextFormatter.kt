package com.newsblur.util

object DiscoverStoryTextFormatter {
    fun formatTitle(rawTitle: String): CharSequence = UIUtils.fromHtml(rawTitle)
}
