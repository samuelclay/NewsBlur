package com.newsblur.fragment

import com.newsblur.domain.Classifier
import com.newsblur.fragment.TrainerScores.Level
import com.newsblur.fragment.TrainerScores.TapStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_TrainerScores.kt: the trainer capsules follow clients/ios/Classes/TrainerView.swift. Tapping
// an author, tag or publisher cycles neutral, like, dislike; tapping a title, text, URL or regex
// toggles a like; the inline buttons toggle a dislike or super dislike.
class Test_TrainerScores {
    @Test
    fun test_cycle_taps_go_neutral_like_dislike_neutral() {
        var score: Int? = null
        val seen = mutableListOf<Level>()
        repeat(4) {
            score = TrainerScores.afterTap(TapStyle.CYCLE, score, null)
            seen += TrainerScores.level(score)
        }

        assertEquals(listOf(Level.LIKE, Level.DISLIKE, Level.NEUTRAL, Level.LIKE), seen)
    }

    @Test
    fun test_a_cycle_tap_on_a_super_dislike_clears_it() {
        val score = TrainerScores.afterTap(TapStyle.CYCLE, Classifier.SUPER_DISLIKE, Classifier.SUPER_DISLIKE)

        assertEquals(Classifier.CLEAR_SUPER_DISLIKE, score)
    }

    @Test
    fun test_toggle_taps_turn_a_like_on_and_off() {
        assertEquals(Classifier.LIKE, TrainerScores.afterTap(TapStyle.TOGGLE_LIKE, null, null))
        assertNull(TrainerScores.afterTap(TapStyle.TOGGLE_LIKE, Classifier.LIKE, null))
        assertEquals(Classifier.CLEAR_LIKE, TrainerScores.afterTap(TapStyle.TOGGLE_LIKE, Classifier.LIKE, Classifier.LIKE))
        assertEquals(
            "A toggle tap on a dislike makes it a like, as NewsBlurAppDelegate.m toggleTitleClassifier does",
            Classifier.LIKE,
            TrainerScores.afterTap(TapStyle.TOGGLE_LIKE, Classifier.DISLIKE, Classifier.DISLIKE),
        )
    }

    @Test
    fun test_inline_buttons_toggle_their_own_level() {
        assertEquals(Classifier.DISLIKE, TrainerScores.afterDislike(Classifier.LIKE, Classifier.LIKE))
        assertEquals(Classifier.CLEAR_LIKE, TrainerScores.afterDislike(Classifier.DISLIKE, Classifier.LIKE))
        assertEquals(Classifier.DISLIKE, TrainerScores.afterDislike(Classifier.SUPER_DISLIKE, null))
        assertEquals(Classifier.SUPER_DISLIKE, TrainerScores.afterSuperDislike(Classifier.DISLIKE, Classifier.DISLIKE))
        assertEquals(Classifier.CLEAR_DISLIKE, TrainerScores.afterSuperDislike(Classifier.SUPER_DISLIKE, Classifier.DISLIKE))
        assertNull(TrainerScores.afterSuperDislike(Classifier.SUPER_DISLIKE, null))
    }

    @Test
    fun test_a_removed_opinion_shows_as_neutral() {
        listOf(Classifier.CLEAR_LIKE, Classifier.CLEAR_DISLIKE, Classifier.CLEAR_SUPER_DISLIKE, null).forEach {
            assertEquals(Level.NEUTRAL, TrainerScores.level(it))
        }
        assertEquals(
            "A removal stored locally by an earlier save stays as it was",
            Classifier.CLEAR_LIKE,
            TrainerScores.neutral(Classifier.CLEAR_LIKE),
        )
    }

    @Test
    fun test_store_takes_out_a_key_going_back_to_untrained() {
        val scores = linkedMapOf("WorkOS" to Classifier.LIKE)

        TrainerScores.store(scores, "WorkOS", null)
        TrainerScores.store(scores, "Sponsor", Classifier.DISLIKE)

        assertFalse("WorkOS" in scores)
        assertEquals(mapOf("Sponsor" to Classifier.DISLIKE), scores)
    }

    @Test
    fun test_title_words_skip_extra_whitespace() {
        assertEquals(listOf("[Sponsor]", "WorkOS:", "Ship"), TrainerPhrase.words("  [Sponsor]  WorkOS:\tShip "))
        assertTrue(TrainerPhrase.words(null).isEmpty())
    }

    @Test
    fun test_tapped_words_build_the_phrase_in_order() {
        val phrase = listOf("Build", "Your", "App").fold("", TrainerPhrase::appendWord)

        assertEquals("Build Your App", phrase)
    }

    @Test
    fun test_regex_checks() {
        assertEquals(TrainerPhrase.RegexCheck.Empty, TrainerPhrase.checkRegex("  "))
        assertEquals(TrainerPhrase.RegexCheck.Valid, TrainerPhrase.checkRegex("\\bsponsor(ed)?\\b"))
        assertTrue(TrainerPhrase.checkRegex("(unclosed") is TrainerPhrase.RegexCheck.Invalid)
        assertEquals(true, TrainerPhrase.regexMatches("^\\[sponsor\\]", "[Sponsor] WorkOS"))
        assertEquals(false, TrainerPhrase.regexMatches("^WorkOS", "[Sponsor] WorkOS"))
        assertNull(TrainerPhrase.regexMatches("(unclosed", "[Sponsor] WorkOS"))
    }

    @Test
    fun test_phrases_match_ignoring_case() {
        assertTrue(TrainerPhrase.phraseMatches("workos", "[Sponsor] WorkOS"))
        assertFalse(TrainerPhrase.phraseMatches("", "[Sponsor] WorkOS"))
        assertFalse(TrainerPhrase.phraseMatches("Dropbox", null))
    }
}
