package com.newsblur.viewModel

import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.domain.DailyBriefingStory
import org.junit.Assert.assertEquals
import org.junit.Test

class DailyBriefingViewModelTest {
    @Test
    fun toDisplayStory_usesFeedMetadataForNativeRows() {
        val payload =
            DailyBriefingStory(
                story =
                    Story().apply {
                        storyHash = "9407084:28c6f6"
                        feedId = "9407084"
                        title = "Why Heliocentrism Was Actually Wrong At First - Terence Tao"
                    },
                feedTitle = "Payload title",
                faviconColor = "cccccc",
                explicitFeedId = "9407084",
                isSummary = false,
            )
        val feed =
            Feed().apply {
                feedId = "9407084"
                title = "DwarkeshPatel's YouTube Videos"
                faviconUrl = "/rss_feeds/icon/9407084"
                faviconColor = "b0abad"
                faviconFade = "848081"
                faviconBorder = "848081"
                faviconText = "white"
            }

        val story =
            requireNotNull(payload.toDisplayStory(briefingFeedId = null) { requestedFeedId ->
                if (requestedFeedId == feed.feedId) feed else null
            })

        assertEquals("DwarkeshPatel's YouTube Videos", story.extern_feedTitle)
        assertEquals("/rss_feeds/icon/9407084", story.extern_faviconUrl)
        assertEquals("b0abad", story.extern_feedColor)
        assertEquals("848081", story.extern_feedFade)
        assertEquals("848081", story.extern_faviconBorderColor)
        assertEquals("white", story.extern_faviconTextColor)
    }

    @Test
    fun toDisplayStory_fallsBackToBriefingPayloadMetadataWhenFeedMissing() {
        val payload =
            DailyBriefingStory(
                story =
                    Story().apply {
                        storyHash = "9896641:24cbea"
                        title = "Evening Daily Briefing — March 27, 2026"
                    },
                feedTitle = "Daily Briefing",
                faviconColor = "95968E",
                explicitFeedId = "9896641",
                isSummary = true,
            )

        val story = requireNotNull(payload.toDisplayStory(briefingFeedId = "9896641") { null })

        assertEquals("Daily Briefing", story.extern_feedTitle)
        assertEquals("/rss_feeds/icon/9896641", story.extern_faviconUrl)
        assertEquals("95968E", story.extern_feedColor)
        assertEquals("95968E", story.extern_feedFade)
        assertEquals("95968E", story.extern_faviconBorderColor)
        assertEquals("FFFFFF", story.extern_faviconTextColor)
    }
}
