package com.newsblur.util

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.LocaleList
import android.os.Looper
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.app.LocaleManagerCompat
import androidx.core.os.LocaleListCompat
import com.newsblur.R
import okhttp3.Request
import java.util.Locale

/** Account language cache; the shared list is generated from localization/languages.json. */
object LanguageSettings {
    const val KEY = "language"
    private const val PENDING = "language_pending"

    fun selected(context: Context): String = prefs(context).getString(KEY, "auto") ?: "auto"

    fun pending(context: Context): Boolean = prefs(context).getBoolean(PENDING, false)

    fun requestLanguages(context: Context): String =
        selected(context).let { if (it == "auto") context.resources.configuration.locales.toLanguageTags() else it }

    /** LanguageSettings.kt sends the app language with API requests so server messages, including login and signup errors, match the interface. */
    fun addLanguageHeader(
        request: Request.Builder,
        context: Context,
    ): Request.Builder = request.header("Accept-Language", requestLanguages(context))

    private fun prefs(context: Context) = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)

    /** LanguageSettings.kt labels Automatic in the system language, so someone who picked a language they can't read still recognizes the way back. */
    fun automaticLabel(context: Context): String {
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocales(LocaleManagerCompat.getSystemLocales(context).unwrap() as LocaleList)
        return context.createConfigurationContext(configuration).getString(R.string.language_automatic)
    }

    /** LanguagePicker.kt and SettingsScreen.kt list Automatic first, then every language in its own script. */
    fun options(automaticLabel: String): Map<String, String> = linkedMapOf("auto" to automaticLabel) + names

    fun select(
        context: Context,
        language: String,
        pending: Boolean = false,
    ) {
        if (language != "auto" && language !in names) return
        prefs(context).edit().putString(KEY, language).putBoolean(PENDING, pending).apply()
        applyLocales(context, language)
    }

    /**
     * InitActivity.kt calls this once AppCompat has restored its stored locale, so the language pref and
     * the per-app locale agree. Android 13+ lets people change the app language in system Settings, so
     * that choice wins and is marked pending for SyncService.kt to save to the account. Older versions
     * only know the language through AppCompat, so the saved choice is applied again.
     */
    fun reconcile(context: Context) {
        val appLocales = AppCompatDelegate.getApplicationLocales()
        val applied = if (appLocales.isEmpty) "auto" else appLocales[0]?.let(::supported)
        val selected = selected(context)
        if (applied == selected) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (applied != null) prefs(context).edit().putString(KEY, applied).putBoolean(PENDING, true).apply()
        } else {
            applyLocales(context, selected)
        }
    }

    /**
     * Notifications and the widget render outside any AppCompat activity, which only localizes its own
     * context before Android 13. LanguageSettings.kt gives them a context in the app language.
     */
    fun localizedContext(context: Context): Context {
        // Android 13+ applies the per-app language to every context in the process.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return context
        val language = selected(context)
        if (language == "auto") return context
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(configuration)
    }

    private fun applyLocales(
        context: Context,
        language: String,
    ) {
        val tags = if (language == "auto") "" else language
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // LanguageSettings.kt sets the framework locale directly: AppCompat drops the call when
            // SyncService.kt applies the account language from a job with no activity alive.
            context.getSystemService(LocaleManager::class.java).applicationLocales = LocaleList.forLanguageTags(tags)
            return
        }
        Handler(Looper.getMainLooper()).post {
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tags))
        }
    }

    /** Matches a locale from system Settings, such as zh-Hans-CN or fr-CA, to one of the bundled languages. */
    private fun supported(locale: Locale): String? {
        val tag = locale.toLanguageTag()
        val language = tag.substringBefore('-')
        return listOf(tag, "$language-${locale.script}", "$language-${locale.country}", language)
            .firstNotNullOfOrNull { candidate -> names.keys.firstOrNull { it.equals(candidate, ignoreCase = true) } }
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
