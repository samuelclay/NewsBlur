package com.newsblur.discover

import com.google.gson.JsonObject
import com.newsblur.domain.Feed

enum class DiscoveryTab(
    val title: String,
    val type: String = "all",
    val hint: String,
) {
    SEARCH("Search", hint = "Search sites or paste a URL"),
    WEB("Web Feed", hint = "Web page URL"),
    POPULAR("Popular", hint = "Search popular sites"),
    YOUTUBE("YouTube", "youtube", "Search channels or paste a URL"),
    REDDIT("Reddit", "reddit", "Search subreddits"),
    NEWSLETTERS("Newsletters", "newsletter", "Search newsletters or paste a URL"),
    PODCASTS("Podcasts", "podcast", "Search podcasts"),
    GOOGLE("Google News", hint = "Search a news topic"),
}

data class DiscoveryFeed(
    val url: String,
    val title: String,
    val id: String = "",
    val link: String = url,
    val image: String = "",
    val subscribers: Int = 0,
    val stories: List<String> = emptyList(),
) {
    fun asFeed(resolvedId: String = id) =
        Feed().also {
            it.feedId = resolvedId
            it.address = url
            it.title = title
            it.feedLink = link
            it.faviconUrl = image
            it.subscribers = subscribers.toString()
            it.active = true
        }

    companion object {
        fun parse(
            entry: JsonObject,
            autocomplete: Boolean = false,
        ): DiscoveryFeed? {
            val nested = entry.obj("feed")
            val feed = nested ?: entry

            fun first(vararg keys: String) =
                keys
                    .firstNotNullOfOrNull { key ->
                        feed.string(key).ifBlank { entry.string(key) }.takeIf { it.isNotBlank() }
                    }.orEmpty()
            val url = first("feed_address", "feed_url", "value")
            if (url.isBlank()) return null
            // DiscoveryModels.kt: catalog/source IDs are not NewsBlur feed IDs.
            val id =
                (nested?.string("id") ?: entry.string(if (autocomplete) "id" else "feed_id"))
                    .takeIf { (it.toLongOrNull() ?: 0) > 0 }
                    .orEmpty()
            return DiscoveryFeed(
                url = url,
                title = first("feed_title", "title", "name", "label").ifBlank { url },
                id = id,
                link = first("feed_link", "link", "itunes_url").ifBlank { url },
                image = first("favicon_url", "thumbnail_url", "thumbnail", "icon", "artwork"),
                subscribers = first("num_subscribers", "subscriber_count", "subscribers", "subs").toIntOrNull() ?: 0,
                stories =
                    entry
                        .objects(
                            "stories",
                        ).map { it.string("story_title").ifBlank { it.string("title") } }
                        .filter { it.isNotBlank() },
            )
        }
    }
}

data class DiscoveryCategory(
    val name: String,
    val subcategories: List<String>,
)

data class DiscoveryPage(
    val query: String = "",
    val category: String = "",
    val subcategory: String = "",
    val platform: String = "",
    val feeds: List<DiscoveryFeed> = emptyList(),
    val categories: List<DiscoveryCategory> = emptyList(),
    val platforms: List<String> = emptyList(),
    val loading: Boolean = false,
    val loaded: Boolean = false,
    val offset: Int = 0,
    val hasMore: Boolean = false,
    val error: String? = null,
)

data class WebVariant(
    val label: String,
    val paths: Map<String, String>,
    val stories: List<String>,
) {
    companion object {
        fun parse(json: JsonObject) =
            WebVariant(
                json.string("label"),
                listOf("story_container", "title", "link", "content", "image", "author", "date").associate { key ->
                    "${key}_xpath" to json.string("${key}_xpath").ifBlank { json.string(key) }
                },
                (json.objects("preview_stories").ifEmpty { json.objects("stories") }).map { it.string("title") },
            )
    }
}

data class WebDiscoveryState(
    val url: String = "",
    val hint: String = "",
    val analyzedUrl: String = "",
    val requestId: String = "",
    val loading: Boolean = false,
    val message: String = "",
    val error: String? = null,
    val variants: List<WebVariant> = emptyList(),
    val selected: Int = 0,
    val title: String = "",
    val htmlHash: String = "",
    val favicon: String = "",
    val detectedFeed: String = "",
    val staleness: Int = 30,
    val markUnread: Boolean = false,
)
