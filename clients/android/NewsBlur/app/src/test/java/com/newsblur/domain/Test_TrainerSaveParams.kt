package com.newsblur.domain

import com.google.gson.Gson
import com.newsblur.fragment.TrainerPhrase
import com.newsblur.fragment.TrainerScores
import com.newsblur.fragment.TrainerScores.TapStyle
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Test

// Test_TrainerSaveParams.kt pins the /classifier/save form that the story and site trainers send
// for each choice the old row-based trainer offered (util/UIUtils.java setupIntelDialogRow's like,
// dislike, super dislike and clear buttons, and the story title selection), then makes the same
// choices with the redesigned trainer's capsules (fragment/TrainerScores.kt) and expects exactly
// the same parameters.
class Test_TrainerSaveParams {
    private val payload =
        """
        {
          "feeds": {"1234": 1},
          "authors": {"John Gruber": 1, "Daring Fireball Department of Commerce": -1},
          "author_regex": {"^Sponsor": -1},
          "titles": {"[Sponsor]": -2},
          "title_regex": {"\\bApple\\b": 1},
          "tags": {"tech": 1},
          "texts": {"WorkOS": -1},
          "text_regex": {"sponsor(ed)?": -1},
          "urls": {"/linked/": 1},
          "url_regex": {"/\\d{4}/": 1}
        }
        """.trimIndent()

    private fun classifier(): Classifier = Gson().fromJson(payload, Classifier::class.java)

    /** The form fields as sorted name=value pairs, since ValueMultimap.java keeps no order. */
    private fun fields(classifier: Classifier): List<String> =
        Buffer()
            .also { classifier.getAPITuples().asFormEncodedRequestBody().writeTo(it) }
            .readUtf8()
            .split("&")
            .filter { it.isNotEmpty() }
            .sorted()

    /** What an untouched classifier sends: every non-regex opinion again, plus author regexes. */
    private val untouched =
        listOf(
            "dislike_author=Daring+Fireball+Department+of+Commerce",
            "dislike_author_regex=%5ESponsor",
            "dislike_text=WorkOS",
            "like_author=John+Gruber",
            "like_feed=1234",
            "like_tag=tech",
            "like_url=%2Flinked%2F",
            "super_dislike_title=%5BSponsor%5D",
        )

    /** The untouched fields with each (sent before, sent now) swap, where "" means a new field. */
    private fun with(vararg changed: Pair<String, String>): List<String> {
        val fields = untouched.toMutableList()
        for ((old, new) in changed) {
            if (old.isNotEmpty()) check(fields.remove(old)) { "$old was not sent before" }
            fields.add(new)
        }
        return fields.sorted()
    }

    @Test
    fun test_an_untouched_trainer_resends_every_opinion_but_title_text_and_url_regexes() {
        assertEquals(untouched.sorted(), fields(classifier()))
    }

    @Test
    fun test_liking_disliking_and_super_disliking_rows() {
        val classifier = classifier()
        // Old trainer: the like button on a new tag, dislike on an author, super dislike on another.
        classifier.tags["apple"] = Classifier.LIKE
        classifier.authors["John Gruber"] = Classifier.DISLIKE
        classifier.authors["Daring Fireball Department of Commerce"] = Classifier.SUPER_DISLIKE

        assertEquals(
            with(
                "like_author=John+Gruber" to "dislike_author=John+Gruber",
                "dislike_author=Daring+Fireball+Department+of+Commerce" to
                    "super_dislike_author=Daring+Fireball+Department+of+Commerce",
                "" to "like_tag=apple",
            ),
            fields(classifier),
        )
    }

    @Test
    fun test_clearing_rows_removes_the_opinion_they_had() {
        val classifier = classifier()
        // Old trainer: the clear button turns each opinion into its matching removal.
        classifier.authors["John Gruber"] = Classifier.CLEAR_LIKE
        classifier.authors["Daring Fireball Department of Commerce"] = Classifier.CLEAR_DISLIKE
        classifier.title["[Sponsor]"] = Classifier.CLEAR_SUPER_DISLIKE
        classifier.feeds["1234"] = Classifier.CLEAR_LIKE

        assertEquals(
            with(
                "like_author=John+Gruber" to "remove_like_author=John+Gruber",
                "dislike_author=Daring+Fireball+Department+of+Commerce" to
                    "remove_dislike_author=Daring+Fireball+Department+of+Commerce",
                "super_dislike_title=%5BSponsor%5D" to "remove_super_dislike_title=%5BSponsor%5D",
                "like_feed=1234" to "remove_like_feed=1234",
            ),
            fields(classifier),
        )
    }

    @Test
    fun test_training_a_selected_title_phrase() {
        val classifier = classifier()
        // Old story trainer: a selected title phrase saves with the chosen opinion.
        classifier.title["WorkOS"] = Classifier.SUPER_DISLIKE

        assertEquals(with("" to "super_dislike_title=WorkOS"), fields(classifier))
    }

    @Test
    fun test_disliking_the_publisher() {
        val classifier = classifier()
        classifier.feeds["1234"] = Classifier.DISLIKE

        assertEquals(with("like_feed=1234" to "dislike_feed=1234"), fields(classifier))
    }

    /** A capsule press in the redesigned trainer, applied against the classifier the trainer opened with. */
    private fun press(
        scores: MutableMap<String, Int>,
        original: Map<String, Int>,
        key: String,
        change: (current: Int?, original: Int?) -> Int?,
    ) = TrainerScores.store(scores, key, change(scores[key], original[key]))

    private fun tap(style: TapStyle) = { current: Int?, original: Int? -> TrainerScores.afterTap(style, current, original) }

    private val dislike = { current: Int?, original: Int? -> TrainerScores.afterDislike(current, original) }

    private val superDislike = { current: Int?, original: Int? -> TrainerScores.afterSuperDislike(current, original) }

    @Test
    fun test_capsules_like_dislike_and_super_dislike_like_the_old_rows() {
        val classifier = classifier()
        val original = classifier()
        press(classifier.tags, original.tags, "apple", tap(TapStyle.CYCLE))
        // A liked author's capsule cycles on to a dislike, the same as the old dislike button.
        press(classifier.authors, original.authors, "John Gruber", tap(TapStyle.CYCLE))
        press(classifier.authors, original.authors, "Daring Fireball Department of Commerce", superDislike)

        val oldRows = classifier()
        oldRows.tags["apple"] = Classifier.LIKE
        oldRows.authors["John Gruber"] = Classifier.DISLIKE
        oldRows.authors["Daring Fireball Department of Commerce"] = Classifier.SUPER_DISLIKE
        assertEquals(fields(oldRows), fields(classifier))
    }

    @Test
    fun test_capsules_back_to_neutral_remove_like_the_old_clear_button() {
        val classifier = classifier()
        val original = classifier()
        press(classifier.authors, original.authors, "John Gruber", tap(TapStyle.CYCLE))
        press(classifier.authors, original.authors, "John Gruber", tap(TapStyle.CYCLE))
        press(classifier.authors, original.authors, "Daring Fireball Department of Commerce", dislike)
        press(classifier.title, original.title, "[Sponsor]", superDislike)
        press(classifier.feeds, original.feeds, "1234", tap(TapStyle.CYCLE))
        press(classifier.feeds, original.feeds, "1234", tap(TapStyle.CYCLE))

        val oldRows = classifier()
        oldRows.authors["John Gruber"] = Classifier.CLEAR_LIKE
        oldRows.authors["Daring Fireball Department of Commerce"] = Classifier.CLEAR_DISLIKE
        oldRows.title["[Sponsor]"] = Classifier.CLEAR_SUPER_DISLIKE
        oldRows.feeds["1234"] = Classifier.CLEAR_LIKE
        assertEquals(fields(oldRows), fields(classifier))
    }

    @Test
    fun test_a_phrase_from_title_words_saves_like_the_old_title_selection() {
        val classifier = classifier()
        val original = classifier()
        val phrase = TrainerPhrase.words("[Sponsor] WorkOS: Build Your App").drop(1).take(1).fold("", TrainerPhrase::appendWord)
        assertEquals("WorkOS:", phrase)
        val typed = TrainerPhrase.appendWord("", "WorkOS")
        press(classifier.title, original.title, typed, superDislike)

        assertEquals(with("" to "super_dislike_title=WorkOS"), fields(classifier))
    }

    @Test
    fun test_disliking_the_publisher_capsule() {
        val classifier = classifier()
        val original = classifier()
        press(classifier.feeds, original.feeds, "1234", tap(TapStyle.CYCLE))

        assertEquals(with("like_feed=1234" to "dislike_feed=1234"), fields(classifier))
    }

    @Test
    fun test_an_untrained_capsule_turned_on_and_off_sends_nothing() {
        val classifier = classifier()
        val original = classifier()
        repeat(3) { press(classifier.tags, original.tags, "apple", tap(TapStyle.CYCLE)) }
        press(classifier.title, original.title, "WorkOS", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.title, original.title, "WorkOS", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.texts, original.texts, "Dropbox", superDislike)
        press(classifier.texts, original.texts, "Dropbox", superDislike)

        assertEquals(untouched.sorted(), fields(classifier))
    }

    @Test
    fun test_only_changed_title_text_and_url_regexes_are_sent() {
        val classifier = classifier()
        val original = classifier.copyRegexes()
        classifier.titleRegex["\\bWorkOS\\b"] = Classifier.DISLIKE
        press(classifier.textRegex, original.textRegex, "sponsor(ed)?", dislike)
        // Touched but back where it started, so it stays out like the untouched title regex.
        press(classifier.urlRegex, original.urlRegex, "/\\d{4}/", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.urlRegex, original.urlRegex, "/\\d{4}/", tap(TapStyle.TOGGLE_LIKE))

        classifier.recordRegexChanges(original)

        assertEquals(
            with(
                "" to "dislike_title_regex=%5CbWorkOS%5Cb",
                "" to "remove_dislike_text_regex=sponsor%28ed%29%3F",
            ),
            fields(classifier),
        )
    }

    @Test
    fun test_regex_changes_survive_the_queued_action_json() {
        val classifier = classifier()
        val original = classifier.copyRegexes()
        classifier.urlRegex["/sponsor/"] = Classifier.SUPER_DISLIKE
        classifier.recordRegexChanges(original)

        val restored = Gson().fromJson(Gson().toJson(classifier), Classifier::class.java)

        assertEquals(with("" to "super_dislike_url_regex=%2Fsponsor%2F"), fields(restored))
    }
}
