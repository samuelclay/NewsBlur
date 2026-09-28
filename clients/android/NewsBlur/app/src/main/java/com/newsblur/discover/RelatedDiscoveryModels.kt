package com.newsblur.discover

import com.google.gson.Gson
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.DiscoverStory
import com.newsblur.domain.Feed

private val relatedDiscoveryJson = Gson()

fun DiscoverFeedPayload.asDiscoveryFeed(): DiscoveryFeed {
    // RelatedDiscoveryModels.kt tolerates null fields from Gson despite the API model's Kotlin types.
    val source: Feed? = feed
    val relatedStories: List<DiscoverStory?>? = stories
    val url = source?.address.orEmpty().ifBlank { source?.feedLink.orEmpty() }
    return DiscoveryFeed(
        url = url,
        title = source?.title.orEmpty().ifBlank { url },
        id = source?.feedId.orEmpty(),
        link = source?.feedLink.orEmpty().ifBlank { url },
        image = source?.faviconUrl.orEmpty(),
        subscribers = source?.subscribers?.toIntOrNull() ?: 0,
        stories = relatedStories.orEmpty().mapNotNull { story ->
            // RelatedDiscoveryModels.kt shares DiscoveryStory's text, date, and image normalization.
            story?.let { DiscoveryStory.parse(relatedDiscoveryJson.toJsonTree(it).asJsonObject) }
        },
    )
}
