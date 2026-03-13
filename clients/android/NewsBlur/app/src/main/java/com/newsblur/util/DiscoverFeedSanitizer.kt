package com.newsblur.util

import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.Feed
import java.net.URI
import java.util.Locale

object DiscoverFeedSanitizer {
    fun filterSourceDuplicates(
        sourceFeed: Feed?,
        payloads: List<DiscoverFeedPayload>,
    ): List<DiscoverFeedPayload> {
        if (sourceFeed == null) return payloads
        return payloads.filterNot { isSameSite(sourceFeed, it.feed) }
    }

    fun shouldLoadNextPage(
        filteredFeeds: List<DiscoverFeedPayload>,
        rawCount: Int,
        pageNumber: Int,
        maxPage: Int,
    ): Boolean = filteredFeeds.isEmpty() && rawCount > 0 && pageNumber < maxPage

    fun isSameSite(
        sourceFeed: Feed,
        candidateFeed: Feed,
    ): Boolean {
        if (sourceFeed.feedId == candidateFeed.feedId) {
            return true
        }

        val sourceAddress = normalizeUrl(sourceFeed.address)
        val candidateAddress = normalizeUrl(candidateFeed.address)
        if (sourceAddress != null && sourceAddress == candidateAddress) {
            return true
        }

        val sourceLink = normalizeUrl(sourceFeed.feedLink)
        val candidateLink = normalizeUrl(candidateFeed.feedLink)
        if (sourceLink != null && sourceLink == candidateLink) {
            return true
        }

        return titlesOverlap(sourceFeed.title, candidateFeed.title) &&
            (hostsMatch(sourceLink, candidateLink) || hostsMatch(sourceAddress, candidateAddress))
    }

    private fun hostsMatch(
        left: NormalizedUrl?,
        right: NormalizedUrl?,
    ): Boolean = left != null && right != null && left.host == right.host

    private fun titlesOverlap(
        left: String?,
        right: String?,
    ): Boolean {
        val normalizedLeft = normalizeTitle(left)
        val normalizedRight = normalizeTitle(right)
        if (normalizedLeft.length < 4 || normalizedRight.length < 4) {
            return false
        }
        return normalizedLeft == normalizedRight ||
            normalizedLeft.contains(normalizedRight) ||
            normalizedRight.contains(normalizedLeft)
    }

    private fun normalizeTitle(rawTitle: String?): String =
        rawTitle
            ?.lowercase(Locale.US)
            ?.replace(NON_ALPHANUMERIC_REGEX, " ")
            ?.replace(MULTIPLE_WHITESPACE_REGEX, " ")
            ?.trim()
            .orEmpty()

    private fun normalizeUrl(rawUrl: String?): NormalizedUrl? {
        if (rawUrl.isNullOrBlank()) return null

        val parsedUrl =
            runCatching { URI(rawUrl.trim()) }.getOrNull()
                ?: return null
        val host =
            parsedUrl.host
                ?.lowercase(Locale.US)
                ?.removePrefix("www.")
                ?: return null
        val path =
            parsedUrl.path
                ?.trim()
                ?.trimEnd('/')
                ?.lowercase(Locale.US)
                .orEmpty()

        return NormalizedUrl(
            host = host,
            path = if (path.isBlank()) "/" else path,
        )
    }

    private data class NormalizedUrl(
        val host: String,
        val path: String,
    )

    private val NON_ALPHANUMERIC_REGEX = Regex("[^a-z0-9]+")
    private val MULTIPLE_WHITESPACE_REGEX = Regex("\\s+")
}
