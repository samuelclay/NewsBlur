package com.newsblur.util

import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.Feed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiscoverFeedSanitizerTest {
    @Test
    fun filters_canonical_duplicate_with_matching_feed_address() {
        val sourceFeed =
            createFeed(
                feedId = "5523704",
                title = "Engadget",
                address = "https://www.engadget.com/rss.xml",
                feedLink = "http://www.engadget.com/uk/",
            )
        val duplicateFeed =
            createFeed(
                feedId = "4097",
                title = "Engadget is a web magazine with obsessive daily coverage of everything new in gadgets and consumer electronics",
                address = "https://www.engadget.com/rss.xml",
                feedLink = "https://www.engadget.com/",
            )
        val relatedFeed =
            createFeed(
                feedId = "576138",
                title = "The Verge",
                address = "https://www.theverge.com/rss/index.xml",
                feedLink = "https://www.theverge.com/",
            )

        val filteredFeeds =
            DiscoverFeedSanitizer.filterSourceDuplicates(
                sourceFeed,
                listOf(
                    DiscoverFeedPayload(duplicateFeed),
                    DiscoverFeedPayload(relatedFeed),
                ),
            )

        assertEquals(listOf(relatedFeed.feedId), filteredFeeds.map { it.feed.feedId })
    }

    @Test
    fun treats_same_host_and_same_title_as_same_site() {
        val sourceFeed =
            createFeed(
                feedId = "6257625",
                title = "Slashdot",
                address = "http://rss.slashdot.org/Slashdot/slashdot",
                feedLink = "https://slashdot.org/",
            )
        val duplicateFeed =
            createFeed(
                feedId = "6911251",
                title = "Slashdot",
                address = "http://rss.slashdot.org/Slashdot/slashdotMain",
                feedLink = "https://slashdot.org/",
            )

        assertTrue(DiscoverFeedSanitizer.isSameSite(sourceFeed, duplicateFeed))
    }

    @Test
    fun requests_next_page_when_filtered_page_only_contains_duplicate_results() {
        val sourceFeed =
            createFeed(
                feedId = "5523704",
                title = "Engadget",
                address = "https://www.engadget.com/rss.xml",
                feedLink = "http://www.engadget.com/uk/",
            )
        val duplicateFeed =
            createFeed(
                feedId = "4097",
                title = "Engadget is a web magazine with obsessive daily coverage of everything new in gadgets and consumer electronics",
                address = "https://www.engadget.com/rss.xml",
                feedLink = "https://www.engadget.com/",
            )

        val filteredFeeds =
            DiscoverFeedSanitizer.filterSourceDuplicates(
                sourceFeed,
                listOf(DiscoverFeedPayload(duplicateFeed)),
            )

        assertTrue(
            DiscoverFeedSanitizer.shouldLoadNextPage(
                filteredFeeds = filteredFeeds,
                rawCount = 1,
                pageNumber = 1,
                maxPage = 10,
            ),
        )
    }

    @Test
    fun keeps_unrelated_feed_on_different_host() {
        val sourceFeed =
            createFeed(
                feedId = "5523704",
                title = "Engadget",
                address = "https://www.engadget.com/rss.xml",
                feedLink = "http://www.engadget.com/uk/",
            )
        val candidateFeed =
            createFeed(
                feedId = "5719535",
                title = "The Verge",
                address = "https://www.theverge.com/rss/index.xml",
                feedLink = "https://www.theverge.com/",
            )

        assertFalse(DiscoverFeedSanitizer.isSameSite(sourceFeed, candidateFeed))
    }

    private fun createFeed(
        feedId: String,
        title: String,
        address: String,
        feedLink: String,
    ): Feed =
        Feed().apply {
            this.feedId = feedId
            this.title = title
            this.address = address
            this.feedLink = feedLink
        }
}
