package com.newsblur.util

import java.util.Locale

/** LanguageChooserRules.kt holds the language dialog's decisions without Android types, so they run in JVM unit tests. */
object LanguageChooserRules {
    enum class Gate { SHOW, MARK_SEEN, NONE }

    /**
     * LanguageChooserDialog.kt shows the dialog once, and only while the account language is Automatic. An explicit
     * language means the person already chose one, so the dialog is marked seen without showing. Debug builds can
     * force it with a language code for screenshots.
     */
    fun gate(
        seen: Boolean,
        selected: String,
        debugLanguage: String?,
    ): Gate =
        when {
            debugLanguage != null -> Gate.SHOW
            seen -> Gate.NONE
            selected != "auto" -> Gate.MARK_SEEN
            else -> Gate.SHOW
        }

    /**
     * Automatic follows the device's preferred languages in order, like Android's own resource matching, so the
     * first one NewsBlur ships is the language the interface is showing. English is the fallback.
     */
    fun detect(
        locales: List<Locale>,
        supported: Set<String> = LanguageSettings.names.keys,
    ): String = locales.firstNotNullOfOrNull { supportedCode(it, supported) } ?: "en"

    /** Matches a device locale such as de-AT, zh-TW or pt-BR to one of the bundled languages. */
    fun supportedCode(
        locale: Locale,
        supported: Set<String> = LanguageSettings.names.keys,
    ): String? {
        val tag = locale.toLanguageTag()
        val language = tag.substringBefore('-')
        val script = locale.script.ifEmpty { if (language == "zh") chineseScript(locale.country) else "" }
        return listOf(tag, "$language-$script", "$language-${locale.country}", language)
            .firstNotNullOfOrNull { candidate -> supported.firstOrNull { it.equals(candidate, ignoreCase = true) } }
    }

    // Chinese locales rarely name a script: Taiwan, Hong Kong and Macau read Traditional, everywhere else Simplified.
    private fun chineseScript(country: String) = if (country in setOf("TW", "HK", "MO")) "Hant" else "Hans"

    /** The English column names the detected language in English ("German"), falling back to its native name. */
    fun englishName(
        language: String,
        nativeName: String,
    ): String =
        Locale
            .forLanguageTag(language)
            .getDisplayName(Locale.ENGLISH)
            .takeIf { it.isNotBlank() && !it.equals(language, ignoreCase = true) }
            ?: nativeName
}
