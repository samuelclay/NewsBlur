package com.newsblur.discover

import com.google.gson.JsonObject
import com.newsblur.domain.Feed
import com.newsblur.util.DiscoverFeedFreshnessFormatter

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
    val stories: List<DiscoveryStory> = emptyList(),
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
                        ).mapNotNull(DiscoveryStory::parse),
            )
        }
    }
}

data class DiscoveryStory(
    val title: String,
    val authors: String = "",
    val timestamp: Long? = null,
    val excerpt: String = "",
    val imageUrl: String = "",
) {
    companion object {
        private val hiddenContent = Regex("<(script|style)\\b[^>]*>.*?</\\1\\s*>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
        private val tags = Regex("<[^>]+>")
        private val blockTags = Regex("</?(?:p|div|br|li|h[1-6]|blockquote|tr|td|section|article)\\b[^>]*>", RegexOption.IGNORE_CASE)
        private val whitespace = Regex("\\s+")
        private val contentImage = Regex("<img\\b[^>]*\\bsrc\\s*=\\s*[\"']([^\"']+)[\"']", RegexOption.IGNORE_CASE)

        fun parse(json: JsonObject): DiscoveryStory? {
            val title = json.string("story_title").ifBlank { json.string("title") }
            if (title.isBlank()) return null
            val content = hiddenContent.replace(json.string("story_content").ifBlank { json.string("content") }, " ")
            val images = json.get("image_urls")?.takeIf { it.isJsonArray }?.asJsonArray
                ?.filter { it.isJsonPrimitive && it.asJsonPrimitive.isString }
                ?.map { it.asString }.orEmpty()
            val original = images.firstOrNull { imageAddress(it).isNotEmpty() }
                ?: contentImage.find(content)?.groupValues?.get(1).orEmpty()
            val image = listOf(
                json.obj("secure_image_thumbnails")?.string(original).orEmpty(),
                json.obj("secure_image_urls")?.string(original).orEmpty(),
                original,
            ).firstNotNullOfOrNull { imageAddress(it).takeIf(String::isNotEmpty) }.orEmpty()
            return DiscoveryStory(
                title = title,
                authors = json.string("story_authors").ifBlank { json.string("authors") },
                timestamp = json.string("story_timestamp").toLongOrNull()?.takeIf { it > 0 && it <= Long.MAX_VALUE / 1000 }
                    ?: DiscoverFeedFreshnessFormatter.parseApiDateMillis(json.string("story_date"))?.div(1000)?.takeIf { it > 0 },
                // DiscoveryModels.kt: preserve entities for Android's HTML decoder in DiscoveryStoryRow.
                excerpt = whitespace.replace(tags.replace(blockTags.replace(content, " "), ""), " ").trim().take(320),
                imageUrl = image,
            )
        }

        private fun imageAddress(value: String): String {
            val url = value.trim()
            return when {
                url.startsWith("//") -> "https:$url"
                url.startsWith("https://") || url.startsWith("http://") -> url
                else -> ""
            }
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
