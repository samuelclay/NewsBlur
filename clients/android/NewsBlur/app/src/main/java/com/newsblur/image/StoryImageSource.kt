package com.newsblur.image

import com.google.gson.JsonParser
import java.net.URI

data class StoryImageSource(
    val generation: Long,
    val token: String,
    val url: String,
    val title: String,
    val naturalWidth: Float,
    val naturalHeight: Float,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val viewportWidth: Float,
) {
    companion object {
        const val READER_ORIGIN = "https://appassets.androidplatform.net"

        fun parse(json: String): StoryImageSource? =
            runCatching {
                val body = JsonParser.parseString(json).asJsonObject
                val rect = body.getAsJsonObject("rect")
                StoryImageSource(
                    body["generation"].asLong,
                    body["token"].asString,
                    body["src"].asString,
                    body["title"]
                        ?.asString
                        ?.take(500)
                        .orEmpty()
                        .ifBlank { "Story image" },
                    body["naturalWidth"].asFloat,
                    body["naturalHeight"].asFloat,
                    rect["x"].asFloat,
                    rect["y"].asFloat,
                    rect["width"].asFloat,
                    rect["height"].asFloat,
                    rect["viewportWidth"].asFloat,
                ).takeIf { source ->
                    source.token.matches(Regex("[0-9]{1,12}")) &&
                        isAllowedUrl(source.url) &&
                        listOf(
                            source.x,
                            source.y,
                            source.width,
                            source.height,
                            source.viewportWidth,
                            source.naturalWidth,
                            source.naturalHeight,
                        ).all { it.isFinite() } &&
                        source.naturalWidth > 1 &&
                        source.naturalHeight > 1 &&
                        source.width > 0 &&
                        source.height > 0 &&
                        source.viewportWidth > 0
                }
            }.getOrNull()

        fun isAllowedUrl(url: String): Boolean {
            if (url.startsWith("data:image/", ignoreCase = true)) return url.length <= 44 * 1024 * 1024
            return runCatching {
                val uri = URI(url)
                uri.scheme?.lowercase() in setOf("http", "https") &&
                    !uri.host.isNullOrBlank() &&
                    (uri.host != "appassets.androidplatform.net" || cachedFileName(url) != null)
            }.getOrDefault(false)
        }

        fun cachedFileName(url: String): String? =
            runCatching {
                val uri = URI(url)
                val name = uri.path.removePrefix("/images/")
                name.takeIf {
                    uri.scheme == "https" &&
                        uri.host == "appassets.androidplatform.net" &&
                        uri.port in setOf(-1, 443) &&
                        uri.path.startsWith("/images/") &&
                        it.matches(Regex("[A-Za-z0-9_-]+\\.[A-Za-z0-9]+"))
                }
            }.getOrNull()
    }
}
