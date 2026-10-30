package com.newsblur.fragment

import com.newsblur.domain.Classifier
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException

/**
 * The phrase sections of the trainer (IntelTrainerSections.kt): Title, Author, Text and URL. Each
 * has exact phrase classifiers and regex classifiers, like clients/ios/Classes/TrainerRegexInput.swift.
 */
enum class TrainerPhraseKind(
    // The Classifier.kt types of this section's phrases and regexes.
    val phraseType: Int,
    val regexType: Int,
) {
    TITLE(Classifier.TITLE, Classifier.TITLE_REGEX),
    AUTHOR(Classifier.AUTHOR, Classifier.AUTHOR_REGEX),
    TEXT(Classifier.TEXT, Classifier.TEXT_REGEX),
    URL(Classifier.URL, Classifier.URL_REGEX),
    ;

    fun phrases(classifier: Classifier): LinkedHashMap<String, Int> = classifier.scores(phraseType)

    fun regexes(classifier: Classifier): LinkedHashMap<String, Int> = classifier.scores(regexType)
}

object TrainerPhrase {
    private val whitespace = Regex("\\s+")

    /** TrainerView.swift titleWords: the story title's words, in order, for the word chips. */
    @JvmStatic
    fun words(title: String?): List<String> = title.orEmpty().split(whitespace).filter { it.isNotEmpty() }

    /** TrainerView.swift: the first tapped word starts the phrase and each later one joins after a space. */
    @JvmStatic
    fun appendWord(
        phrase: String,
        word: String,
    ): String = if (phrase.isEmpty()) word else "$phrase $word"

    sealed class RegexCheck {
        object Empty : RegexCheck()

        object Valid : RegexCheck()

        data class Invalid(
            val message: String,
        ) : RegexCheck()
    }

    /** TrainerRegexInput.swift validationResult: classifier regexes match case-insensitively. */
    @JvmStatic
    fun checkRegex(pattern: String): RegexCheck {
        val trimmed = pattern.trim()
        if (trimmed.isEmpty()) return RegexCheck.Empty
        return try {
            Pattern.compile(trimmed, Pattern.CASE_INSENSITIVE)
            RegexCheck.Valid
        } catch (e: PatternSyntaxException) {
            RegexCheck.Invalid(e.description.orEmpty())
        }
    }

    /** Whether [pattern] finds a match in [text], or null when it isn't a valid regex. */
    @JvmStatic
    fun regexMatches(
        pattern: String,
        text: String?,
    ): Boolean? {
        if (checkRegex(pattern) != RegexCheck.Valid) return null
        return Pattern.compile(pattern.trim(), Pattern.CASE_INSENSITIVE).matcher(text.orEmpty()).find()
    }

    /** Whether a saved phrase classifier applies to [text], ignoring case like apps/analyzer/models.py. */
    @JvmStatic
    fun phraseMatches(
        phrase: String,
        text: String?,
    ): Boolean = phrase.isNotEmpty() && text.orEmpty().contains(phrase, ignoreCase = true)
}
