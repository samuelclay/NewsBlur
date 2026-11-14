package com.newsblur.fragment

import com.newsblur.fragment.TrainerPhrase.RegexMatch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_TrainerRegexBudget.kt: TrainerPhrase.regexMatch gives up on a regex that backtracks past
// its budget, so a valid but pathological classifier can't hang the trainer while it opens
// (IntelTrainerSections.kt) or while someone types one (TrainerPhraseInput.kt).
class Test_TrainerRegexBudget {
    // Scheduling slack on a busy test machine. Without the budget these run for minutes.
    private val limitMillis = TrainerPhrase.REGEX_BUDGET_MILLIS * 2

    private fun timed(
        pattern: String,
        text: String,
    ): Pair<RegexMatch, Long> {
        val started = System.nanoTime()
        val match = TrainerPhrase.regexMatch(pattern, text)
        return match to (System.nanoTime() - started) / 1_000_000
    }

    @Test
    fun test_nested_quantifiers_on_long_nonmatching_text_finish_within_the_budget() {
        // The JVM's java.util.regex memoizes (a+)+$ and answers at once, but Android's ICU engine
        // backtracks on it, so either answer is fine as long as it's in time and not a match.
        val (match, millis) = timed("(a+)+$", "a".repeat(50_000) + "!")

        assertTrue("$match", match == RegexMatch.NO_MATCH || match == RegexMatch.TIMED_OUT)
        assertTrue("Took ${millis}ms", millis < limitMillis)
    }

    @Test
    fun test_a_regex_that_backtracks_past_the_budget_times_out() {
        // These backtrack on every engine: a backreference defeats the JVM's memoizing, and
        // eleven lazy groups try every way to split the commas.
        listOf(
            "(a+)+\\1$" to "a".repeat(50) + "!",
            "(.*?,){11}P" to "ab,".repeat(1_000) + "x",
        ).forEach { (pattern, text) ->
            val (match, millis) = timed(pattern, text)

            assertEquals(pattern, RegexMatch.TIMED_OUT, match)
            assertTrue("$pattern took ${millis}ms", millis < limitMillis)
        }
    }

    @Test
    fun test_an_ordinary_regex_still_matches_long_story_text() {
        val story = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ".repeat(2_000)

        assertEquals(RegexMatch.MATCH, TrainerPhrase.regexMatch("\\bsponsor(ed)?\\b", story + "This post is Sponsored."))
        assertEquals(RegexMatch.NO_MATCH, TrainerPhrase.regexMatch("\\bsponsor(ed)?\\b", story))
    }
}
