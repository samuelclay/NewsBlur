package com.newsblur.domain

import com.google.gson.Gson
import com.newsblur.fragment.TrainerPhrase
import com.newsblur.fragment.TrainerScores
import com.newsblur.fragment.TrainerScores.TapStyle
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Test

// Test_TrainerSaveParams.kt pins the feed-scoped /classifier/save fields the story and site
// trainers send for each choice the old row-based trainer offered (util/UIUtils.java
// setupIntelDialogRow's like, dislike, super dislike and clear buttons, and the story title
// selection), then makes the same choices with the redesigned trainer's capsules
// (fragment/TrainerScores.kt) and expects exactly the same fields. Classifiers the reader didn't
// change are no longer sent again (Classifier.recordChanges).
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

    /** Records what changed since [original] and returns the feed save's fields. */
    private fun saved(
        classifier: Classifier,
        original: Classifier,
    ): List<String> {
        classifier.recordChanges(original)
        return fieldsOf(classifier)
    }

    @Test
    fun test_an_untouched_trainer_sends_nothing() {
        val classifier = classifier()

        assertEquals(emptyList<String>(), saved(classifier, classifier.snapshot()))
    }

    @Test
    fun test_liking_disliking_and_super_disliking_rows() {
        val classifier = classifier()
        val original = classifier.snapshot()
        // Old trainer: the like button on a new tag, dislike on an author, super dislike on another.
        classifier.tags["apple"] = Classifier.LIKE
        classifier.authors["John Gruber"] = Classifier.DISLIKE
        classifier.authors["Daring Fireball Department of Commerce"] = Classifier.SUPER_DISLIKE

        assertEquals(
            listOf(
                "dislike_author=John+Gruber",
                "like_tag=apple",
                "super_dislike_author=Daring+Fireball+Department+of+Commerce",
            ),
            saved(classifier, original),
        )
    }

    @Test
    fun test_clearing_rows_removes_the_opinion_they_had() {
        val classifier = classifier()
        val original = classifier.snapshot()
        // Old trainer: the clear button turns each opinion into its matching removal.
        classifier.authors["John Gruber"] = Classifier.CLEAR_LIKE
        classifier.authors["Daring Fireball Department of Commerce"] = Classifier.CLEAR_DISLIKE
        classifier.title["[Sponsor]"] = Classifier.CLEAR_SUPER_DISLIKE
        classifier.feeds["1234"] = Classifier.CLEAR_LIKE

        assertEquals(
            listOf(
                "remove_dislike_author=Daring+Fireball+Department+of+Commerce",
                "remove_like_author=John+Gruber",
                "remove_like_feed=1234",
                "remove_super_dislike_title=%5BSponsor%5D",
            ),
            saved(classifier, original),
        )
    }

    @Test
    fun test_training_a_selected_title_phrase() {
        val classifier = classifier()
        val original = classifier.snapshot()
        // Old story trainer: a selected title phrase saves with the chosen opinion.
        classifier.title["WorkOS"] = Classifier.SUPER_DISLIKE

        assertEquals(listOf("super_dislike_title=WorkOS"), saved(classifier, original))
    }

    @Test
    fun test_disliking_the_publisher() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.feeds["1234"] = Classifier.DISLIKE

        assertEquals(listOf("dislike_feed=1234"), saved(classifier, original))
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
        val original = classifier.snapshot()
        press(classifier.tags, original.tags, "apple", tap(TapStyle.CYCLE))
        // A liked author's capsule cycles on to a dislike, the same as the old dislike button.
        press(classifier.authors, original.authors, "John Gruber", tap(TapStyle.CYCLE))
        press(classifier.authors, original.authors, "Daring Fireball Department of Commerce", superDislike)

        val oldRows = classifier()
        oldRows.tags["apple"] = Classifier.LIKE
        oldRows.authors["John Gruber"] = Classifier.DISLIKE
        oldRows.authors["Daring Fireball Department of Commerce"] = Classifier.SUPER_DISLIKE
        assertEquals(saved(oldRows, classifier()), saved(classifier, original))
    }

    @Test
    fun test_capsules_back_to_neutral_remove_like_the_old_clear_button() {
        val classifier = classifier()
        val original = classifier.snapshot()
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
        assertEquals(saved(oldRows, classifier()), saved(classifier, original))
    }

    @Test
    fun test_a_phrase_from_title_words_saves_like_the_old_title_selection() {
        val classifier = classifier()
        val original = classifier.snapshot()
        val words = TrainerPhrase.words("[Sponsor] WorkOS: Build Your App")
        val phrase = TrainerPhrase.appendWord("", words[1])
        assertEquals("WorkOS:", phrase)
        val typed = TrainerPhrase.appendWord("", "WorkOS")
        press(classifier.title, original.title, typed, superDislike)

        assertEquals(listOf("super_dislike_title=WorkOS"), saved(classifier, original))
    }

    @Test
    fun test_disliking_the_publisher_capsule() {
        val classifier = classifier()
        val original = classifier.snapshot()
        press(classifier.feeds, original.feeds, "1234", tap(TapStyle.CYCLE))

        assertEquals(listOf("dislike_feed=1234"), saved(classifier, original))
    }

    @Test
    fun test_an_untrained_capsule_turned_on_and_off_sends_nothing() {
        val classifier = classifier()
        val original = classifier.snapshot()
        repeat(3) { press(classifier.tags, original.tags, "apple", tap(TapStyle.CYCLE)) }
        press(classifier.title, original.title, "WorkOS", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.title, original.title, "WorkOS", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.texts, original.texts, "Dropbox", superDislike)
        press(classifier.texts, original.texts, "Dropbox", superDislike)

        assertEquals(emptyList<String>(), saved(classifier, original))
    }

    @Test
    fun test_only_changed_regexes_are_sent() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.titleRegex["\\bWorkOS\\b"] = Classifier.DISLIKE
        press(classifier.textRegex, original.textRegex, "sponsor(ed)?", dislike)
        // Touched but back where it started, so it stays out like the untouched title regex.
        press(classifier.urlRegex, original.urlRegex, "/\\d{4}/", tap(TapStyle.TOGGLE_LIKE))
        press(classifier.urlRegex, original.urlRegex, "/\\d{4}/", tap(TapStyle.TOGGLE_LIKE))
        classifier.authorRegex["^Sponsor"] = Classifier.CLEAR_DISLIKE

        assertEquals(
            listOf(
                "dislike_title_regex=%5CbWorkOS%5Cb",
                "remove_dislike_author_regex=%5ESponsor",
                "remove_dislike_text_regex=sponsor%28ed%29%3F",
            ),
            saved(classifier, original),
        )
    }

    @Test
    fun test_changes_survive_the_queued_action_json() {
        val classifier = classifier()
        val original = classifier.snapshot()
        classifier.urlRegex["/sponsor/"] = Classifier.SUPER_DISLIKE
        classifier.recordChanges(original)

        val restored = Gson().fromJson(Gson().toJson(classifier), Classifier::class.java)

        assertEquals(classifier.changes, restored.changes)
        assertEquals(listOf("super_dislike_url_regex=%2Fsponsor%2F"), fieldsOf(restored))
    }

    @Test
    fun test_prompt_capsules_save_like_the_old_focus_hide_and_remove_buttons() {
        val payload = """{"prompts": {"Non-apple related news": 1, "Sports": -1, "Crypto": 1}}"""
        val prompts = Gson().fromJson(payload, Classifier::class.java)
        val original = prompts.snapshot()
        // fragment/AiClassifierSections.kt: tapping a focus prompt hides it, tapping a hidden one removes it.
        press(prompts.prompts, original.prompts, "Non-apple related news", tap(TapStyle.CYCLE))
        press(prompts.prompts, original.prompts, "Sports", tap(TapStyle.CYCLE))
        press(prompts.prompts, original.prompts, "Crypto", tap(TapStyle.CYCLE))
        press(prompts.prompts, original.prompts, "Crypto", tap(TapStyle.CYCLE))

        val oldButtons = Gson().fromJson(payload, Classifier::class.java)
        oldButtons.prompts["Non-apple related news"] = Classifier.DISLIKE
        oldButtons.prompts["Sports"] = Classifier.CLEAR_DISLIKE
        oldButtons.prompts["Crypto"] = Classifier.CLEAR_LIKE
        assertEquals(saved(oldButtons, Gson().fromJson(payload, Classifier::class.java)), saved(prompts, original))
        assertEquals(
            listOf("dislike_prompt=Non-apple+related+news", "remove_dislike_prompt=Sports", "remove_like_prompt=Crypto"),
            fieldsOf(prompts),
        )
    }

    /** The feed save's fields for changes already recorded, sorted, since ValueMultimap.java keeps no order. */
    private fun fieldsOf(classifier: Classifier): List<String> =
        Buffer()
            .also { classifier.getAPITuples().asFormEncodedRequestBody().writeTo(it) }
            .readUtf8()
            .split("&")
            .filter { it.isNotEmpty() }
            .sorted()
}
