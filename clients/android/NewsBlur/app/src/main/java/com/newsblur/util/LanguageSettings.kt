package com.newsblur.util

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

/** Account language cache; the shared list is generated from localization/languages.json. */
object LanguageSettings {
    const val KEY = "language"
    private const val PENDING = "language_pending"

    fun selected(context: Context): String = prefs(context).getString(KEY, "auto") ?: "auto"
    fun pending(context: Context): Boolean = prefs(context).getBoolean(PENDING, false)
    private fun prefs(context: Context) = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)

    fun select(context: Context, language: String, pending: Boolean = false) {
        if (language != "auto" && language !in names) return
        prefs(context).edit().putString(KEY, language).putBoolean(PENDING, pending).apply()
        Handler(Looper.getMainLooper()).post {
            AppCompatDelegate.setApplicationLocales(
                LocaleListCompat.forLanguageTags(if (language == "auto") "" else language),
            )
        }
    }

    // Generated from localization/languages.json; keep labels in their own language.
    val names = linkedMapOf(
        "en" to "English", "es" to "Español", "fr" to "Français", "de" to "Deutsch",
        "pt-BR" to "Português (Brasil)", "it" to "Italiano", "nl" to "Nederlands", "pl" to "Polski",
        "tr" to "Türkçe", "ru" to "Русский", "uk" to "Українська", "ar" to "العربية", "he" to "עברית",
        "hi" to "हिन्दी", "id" to "Bahasa Indonesia", "vi" to "Tiếng Việt", "th" to "ไทย",
        "ja" to "日本語", "ko" to "한국어", "zh-Hans" to "简体中文", "zh-Hant" to "繁體中文",
    )
}
