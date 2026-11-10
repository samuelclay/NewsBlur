package com.newsblur.addsite

import com.newsblur.discover.DiscoveryViewModel

// AddSiteDescribeDecision.kt: a typed phrase with spaces that isn't an address reads as a description of the feeds
// to find, so AddSiteSheet.kt offers (and on submit runs) a Describe search instead of adding it as a URL.
object AddSiteDescribeDecision {
    private const val MIN_LENGTH = 3
    private val whitespace = Regex("\\s+")

    fun prompt(query: String): String? {
        val text = whitespace.replace(query.trim(), " ")
        if (text.length < MIN_LENGTH || !text.contains(' ')) return null
        if (DiscoveryViewModel.isAddress(text)) return null
        return text
    }
}
