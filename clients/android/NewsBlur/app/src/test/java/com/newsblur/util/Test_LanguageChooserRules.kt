package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class Test_LanguageChooserRules {
    private fun detect(vararg tags: String) = LanguageChooserRules.detect(tags.map(Locale::forLanguageTag))

    @Test
    fun test_dialog_shows_once_and_only_while_automatic() {
        assertEquals(LanguageChooserRules.Gate.SHOW, LanguageChooserRules.gate(seen = false, selected = "auto", debugLanguage = null))
        assertEquals(LanguageChooserRules.Gate.NONE, LanguageChooserRules.gate(seen = true, selected = "auto", debugLanguage = null))
        // Someone who already picked a language is never asked; the flag is set so the check stops running.
        assertEquals(LanguageChooserRules.Gate.MARK_SEEN, LanguageChooserRules.gate(seen = false, selected = "de", debugLanguage = null))
        assertEquals(LanguageChooserRules.Gate.SHOW, LanguageChooserRules.gate(seen = true, selected = "de", debugLanguage = "ja"))
    }

    @Test
    fun test_detection_matches_regional_device_locales_to_bundled_languages() {
        assertEquals("de", detect("de-AT"))
        assertEquals("pt-BR", detect("pt-BR"))
        assertEquals("zh-Hant", detect("zh-TW"))
        assertEquals("zh-Hant", detect("zh-HK"))
        assertEquals("zh-Hans", detect("zh-CN"))
        assertEquals("zh-Hant", detect("zh-Hant-SG"))
        // Android still reports Hebrew and Indonesian with their legacy codes.
        assertEquals("he", LanguageChooserRules.detect(listOf(Locale("iw", "IL"))))
        assertEquals("id", LanguageChooserRules.detect(listOf(Locale("in", "ID"))))
    }

    @Test
    fun test_detection_walks_preferred_languages_then_falls_back_to_english() {
        assertEquals("fr", detect("sw-KE", "fr-CA"))
        assertEquals("en", detect("sw-KE", "pt-PT"))
        assertEquals("en", LanguageChooserRules.detect(emptyList()))
    }

    @Test
    fun test_english_column_names_the_detected_language_in_english() {
        assertEquals("German", LanguageChooserRules.englishName("de", "Deutsch"))
        assertEquals("Portuguese (Brazil)", LanguageChooserRules.englishName("pt-BR", "Português (Brasil)"))
        assertEquals("Chinese (Traditional)", LanguageChooserRules.englishName("zh-Hant", "繁體中文"))
    }
}
