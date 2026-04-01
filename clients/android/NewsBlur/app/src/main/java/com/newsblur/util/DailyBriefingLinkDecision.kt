package com.newsblur.util

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale

object DailyBriefingLinkDecision {
    private val supportedHosts = setOf("newsblur.com", "www.newsblur.com")

    @JvmStatic
    fun isSupported(url: String?): Boolean {
        val uri = parse(url) ?: return false
        val host = uri.host?.lowercase(Locale.US) ?: return false
        val path = uri.path ?: return false

        return supportedHosts.contains(host) && (path == "/briefing" || path.startsWith("/briefing/"))
    }

    @JvmStatic
    fun storyHash(url: String?): String? {
        if (!isSupported(url)) return null

        val query = parse(url)?.rawQuery ?: return null
        return query
            .split("&")
            .asSequence()
            .mapNotNull { pair ->
                val separatorIndex = pair.indexOf('=')
                if (separatorIndex <= 0) return@mapNotNull null

                val key = pair.substring(0, separatorIndex)
                if (key != "story") return@mapNotNull null

                URLDecoder.decode(pair.substring(separatorIndex + 1), StandardCharsets.UTF_8)
                    .takeIf { it.isNotBlank() }
            }.firstOrNull()
    }

    private fun parse(url: String?): URI? =
        url
            ?.takeIf { it.isNotBlank() }
            ?.let {
                try {
                    URI(it)
                } catch (_: Exception) {
                    null
                }
            }
}
