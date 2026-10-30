package com.newsblur.listen

import com.google.gson.Gson
import com.google.gson.JsonParser
import com.newsblur.network.resolveListenAudioUrl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/** Test_ListenApiParsing.kt reads the Listen endpoints' JSON the way ListenApiImpl.kt does. */
class Test_ListenApiParsing {
    @Test
    fun test_filters_read_lists_and_per_language_accents() {
        val filters =
            ListenFilters.parse(
                JsonParser
                    .parseString(
                        """
                        {"gender": [{"value": "female", "label": "Female"}, {"value": "male", "label": "Male"}],
                         "sort": [{"value": "popular", "label": "Popular"}, {"value": "trending"}],
                         "accent": {"en": ["american", "british"], "fr": ["parisian"]}}
                        """.trimIndent(),
                    ).asJsonObject,
            )
        assertEquals(listOf("female", "male"), filters.options["gender"]!!.map { it.value })
        assertEquals("Female", filters.options["gender"]!!.first().label)
        assertEquals(null, filters.options["sort"]!![1].label)
        assertEquals(listOf("american", "british"), filters.accentsFor("en"))
        assertTrue(filters.accentsFor("de").isEmpty())
        assertTrue("accent" !in filters.options)
    }

    @Test
    fun test_accents_display_title_cased() {
        assertEquals("American", ListenFilters.displayAccent("american"))
        assertEquals("Us Southern", ListenFilters.displayAccent("us-southern"))
        assertEquals("Standard", ListenFilters.displayAccent("standard"))
    }

    @Test
    fun test_manifest_parses_with_numeric_feed_id() {
        val manifest =
            Gson().fromJson(
                """
                {"code": 1, "manifest_id": "abc", "expires_at": 1761000000, "story_hash": "1:abc", "feed_id": 123,
                 "voice": {"voice_id": "v1", "name": "George"}, "voice_fallback": true,
                 "paragraphs": [{"index": 0, "kind": "title", "text": "Title"}],
                 "segments": [{"index": 0, "paragraphs": [0], "characters": 5, "duration": 3.2, "estimated": true, "cached": false}],
                 "total_duration": 3.2, "preview": {"is_preview": true, "seconds": 30, "samples_used": 1, "samples_limit": 3}}
                """.trimIndent(),
                ListenManifest::class.java,
            )
        assertEquals("123", manifest.feedId)
        assertTrue(manifest.isPreview)
        assertTrue(manifest.paragraphs.first().isTitle)
        assertEquals(listOf(0), manifest.segments.first().paragraphs)
        assertEquals("George", manifest.voice?.name)
    }

    @Test
    fun test_relative_stream_urls_use_the_signed_in_server() {
        assertEquals(
            "https://localhost:8936/listen/stream/job.mp3",
            resolveListenAudioUrl("/listen/stream/job.mp3", "https://localhost:8936"),
        )
        assertEquals(
            "https://newsblur.com/listen/stream/job.mp3",
            resolveListenAudioUrl("listen/stream/job.mp3", "https://newsblur.com/"),
        )
        assertEquals(
            "https://s3.amazonaws.com/a.mp3?sig=1",
            resolveListenAudioUrl("https://s3.amazonaws.com/a.mp3?sig=1", "https://newsblur.com"),
        )
    }

    @Test
    fun test_voice_settings_start_on_the_device_language() {
        assertEquals("fr", ListenVoiceSettingsViewModel.languageFor(Locale.FRANCE))
        assertEquals(
            "pt-BR",
            ListenVoiceSettingsViewModel.languageFor(Locale.forLanguageTag("pt-PT")),
        )
        assertEquals(
            "zh-Hant",
            ListenVoiceSettingsViewModel.languageFor(Locale.TRADITIONAL_CHINESE),
        )
        assertEquals("zh-Hans", ListenVoiceSettingsViewModel.languageFor(Locale.SIMPLIFIED_CHINESE))
        assertEquals("en", ListenVoiceSettingsViewModel.languageFor(Locale.forLanguageTag("sw")))
    }
}
