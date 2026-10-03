package com.newsblur.onboarding

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import com.google.gson.JsonParser
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.discover.string
import java.util.Locale

// OnboardingCatalog.kt mirrors the audited identities and aliases in OnboardingIconCatalog.swift.
object OnboardingCatalog {
    val sources = listOf("rss", "newsletter", "youtube", "reddit", "podcast")
    private val aliases =
        mapOf(
            "cooking & food" to "food & cooking",
            "art & design" to "design",
            "automobiles" to "automotive",
            "fitness & health" to "health & fitness",
            "news & current events" to "news & politics",
            "travel & lifestyle" to "travel",
            "culture & lifestyle" to "lifestyle",
            "entertainment & comedy" to "comedy & humor",
            "finance & business" to "finance",
        )

    fun key(value: String) = value.lowercase(Locale.ROOT).let { aliases[it] ?: it }

    fun title(value: String): String =
        if (key(value) ==
            "food & cooking"
        ) {
            "Cooking & Food"
        } else {
            value.split(" ").joinToString(" ") { it.replaceFirstChar(Char::titlecase) }
        }

    fun categories(values: List<String>) = values.map(::key).distinct().sortedBy(::title)

    fun read(context: Context): Map<String, List<DiscoveryFeed>> {
        val json =
            context.assets
                .open("onboarding_catalog.json")
                .bufferedReader()
                .use { JsonParser.parseReader(it).asJsonObject }
        val entries =
            json.entrySet().associate { (key, list) ->
                key to
                    list.asJsonArray.map { value ->
                        val feed = value.asJsonObject
                        DiscoveryFeed(feed.string("url"), feed.string("title"), feed.string("id"))
                    }
            }
        return entries +
            (
                "" to
                    (0..2).flatMap { i ->
                        listOf(
                            "technology",
                            "science",
                            "food & cooking",
                            "arts & culture",
                            "travel",
                        ).mapNotNull { entries[it]?.getOrNull(i) }
                    }
            )
    }

    fun bitmap(encoded: String): Bitmap? =
        try {
            val data = Base64.decode(encoded.substringAfter(",", encoded), Base64.DEFAULT)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
            if (bounds.outWidth < 8 || bounds.outHeight < 8) {
                null
            } else {
                val options = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / 32) }
                BitmapFactory.decodeByteArray(data, 0, data.size, options)
            }
        } catch (_: Exception) {
            null
        }

    fun fingerprint(bitmap: Bitmap): Int? {
        val scaled = Bitmap.createScaledBitmap(bitmap, 32, 32, true)
        val pixels = IntArray(1024).also { scaled.getPixels(it, 0, 32, 0, 0, 32, 32) }
        val opaque = pixels.filter { (it ushr 24) > 32 }
        if (opaque.size < 32 || opaque.map { it and 0x00f0f0f0 }.distinct().size < 2) return null
        return pixels.map { it and 0xf8f8f8f8.toInt() }.hashCode()
    }
}

// OnboardingCatalog.kt appends arriving candidates without resetting deselections or the edited folder.
data class BundleChoices(
    val feeds: List<DiscoveryFeed> = emptyList(),
    val selected: Set<String> = emptySet(),
) {
    fun append(
        incoming: List<DiscoveryFeed>,
        unavailable: Set<String>,
    ): BundleChoices {
        val seen = feeds.map { it.url }.toSet()
        val added = incoming.distinctBy { it.url }.filter { it.url !in seen }.take((15 - feeds.size).coerceAtLeast(0))
        return copy(feeds = feeds + added, selected = selected + added.map { it.url }.filter { it !in unavailable })
    }

    fun toggle(url: String) = copy(selected = if (url in selected) selected - url else selected + url)
}
