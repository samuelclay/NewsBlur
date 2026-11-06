package com.newsblur.fragment

import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
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

    enum class RegexMatch { MATCH, NO_MATCH, INVALID, TIMED_OUT }

    /**
     * How long the trainer waits for one regex. A valid pattern like (a+)+$ can backtrack for
     * minutes on long story text, so apps/analyzer/models.py safe_regex_match gives up after
     * 100ms and scores it as no match. A phone is slower, so the trainer waits a little longer.
     */
    const val REGEX_BUDGET_MILLIS = 250L

    /**
     * Whether [pattern] finds a match in [text] within [budgetMillis], TIMED_OUT when it takes
     * longer. This waits up to the budget, so call it off the main thread.
     */
    @JvmStatic
    fun regexMatch(
        pattern: String,
        text: String?,
        budgetMillis: Long = REGEX_BUDGET_MILLIS,
    ): RegexMatch {
        if (checkRegex(pattern) != RegexCheck.Valid) return RegexMatch.INVALID
        val matcher = Pattern.compile(pattern.trim(), Pattern.CASE_INSENSITIVE)
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(budgetMillis)
        val search =
            try {
                regexThreads.submit(Callable { matcher.matcher(DeadlineText(text.orEmpty(), deadline)).find() })
            } catch (_: RejectedExecutionException) {
                // Both threads are still stuck on earlier patterns, so this one can't be checked.
                return RegexMatch.TIMED_OUT
            }
        return try {
            if (search.get(budgetMillis, TimeUnit.MILLISECONDS)) RegexMatch.MATCH else RegexMatch.NO_MATCH
        } catch (_: TimeoutException) {
            search.cancel(true)
            RegexMatch.TIMED_OUT
        } catch (_: ExecutionException) {
            // DeadlineText stopped the search at the deadline, or the engine gave up on its own,
            // like the StackOverflowError deep backtracking can throw on long text.
            RegexMatch.TIMED_OUT
        }
    }

    // TrainerPhrase.kt: a search past its budget can't always be stopped. Android's
    // java.util.regex hands a copy of the text to ICU, which runs until it's done, so a search
    // the trainer gave up on keeps its thread. Two low priority threads at most keep a run of
    // pathological patterns from taking over the CPU; a pattern that finds both busy times out.
    private val regexThreads =
        ThreadPoolExecutor(0, 2, 30, TimeUnit.SECONDS, SynchronousQueue()) { runnable ->
            Thread(runnable, "TrainerRegex").apply {
                isDaemon = true
                priority = Thread.MIN_PRIORITY
            }
        }

    /**
     * Text that ends a search at [deadline]. The JVM's java.util.regex reads every character
     * through charAt, so there an abandoned search stops and frees its thread right away.
     */
    private class DeadlineText(
        private val text: CharSequence,
        private val deadline: Long,
    ) : CharSequence {
        override val length: Int
            get() = text.length

        override fun get(index: Int): Char {
            if (System.nanoTime() > deadline) throw RegexTimeout()
            return text[index]
        }

        override fun subSequence(
            startIndex: Int,
            endIndex: Int,
        ): CharSequence = DeadlineText(text.subSequence(startIndex, endIndex), deadline)

        override fun toString(): String = text.toString()
    }

    private class RegexTimeout : RuntimeException(null, null, false, false)

    /** Whether a saved phrase classifier applies to [text], ignoring case like apps/analyzer/models.py. */
    @JvmStatic
    fun phraseMatches(
        phrase: String,
        text: String?,
    ): Boolean = phrase.isNotEmpty() && text.orEmpty().contains(phrase, ignoreCase = true)

    /** TrainerRegexInput.swift storyMatchResult: the part of [story] a [kind] section classifies. */
    @JvmStatic
    fun storyText(
        kind: TrainerPhraseKind,
        story: Story,
    ): String? =
        when (kind) {
            TrainerPhraseKind.TITLE -> story.title
            TrainerPhraseKind.AUTHOR -> story.authors
            TrainerPhraseKind.TEXT -> story.content
            TrainerPhraseKind.URL -> story.permalink
        }

    /**
     * The phrases the story trainer lists in a [kind] section, as TrainerView.swift does with the
     * story's own classifiers: the [saved] phrases [story] matches. A story has a single author,
     * trained or not.
     */
    @JvmStatic
    fun storyPhrases(
        kind: TrainerPhraseKind,
        saved: Collection<String>,
        story: Story,
    ): List<String> =
        when (kind) {
            TrainerPhraseKind.AUTHOR -> listOfNotNull(story.authors?.takeIf { it.isNotBlank() })
            else -> saved.filter { phraseMatches(it, storyText(kind, story)) }
        }

    /**
     * [story] with its text, for StoryIntelTrainerFragment.java's Story Text section. The story
     * list's and reader's stories leave the text out (Story.fromCursor, Story.copyForBundle), so
     * [loadContent] reads it by story hash. The copy keeps the text out of the fragment's
     * arguments, which the saved state parcels.
     */
    @JvmStatic
    fun withStoryContent(
        story: Story,
        loadContent: (String?) -> String?,
    ): Story {
        if (story.content != null) return story
        val copy = story.copyForBundle()
        copy.content = loadContent(story.storyHash)
        return copy
    }
}
