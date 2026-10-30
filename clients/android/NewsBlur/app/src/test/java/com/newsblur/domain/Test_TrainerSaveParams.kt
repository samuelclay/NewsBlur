package com.newsblur.domain

import com.google.gson.Gson
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Test

// Test_TrainerSaveParams.kt pins the /classifier/save form that the story and site trainers send
// for each choice the old row-based trainer offered (util/UIUtils.java setupIntelDialogRow's like,
// dislike, super dislike and clear buttons, and the story title selection), so the redesigned
// trainers keep sending exactly the same parameters for the same choices.
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
}
