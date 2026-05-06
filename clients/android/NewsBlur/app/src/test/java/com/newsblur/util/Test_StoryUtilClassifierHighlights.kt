package com.newsblur.util

import android.content.res.Configuration
import com.google.gson.JsonParser
import com.newsblur.domain.Classifier
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_StoryUtilClassifierHighlights {
    @Test
    fun test_build_minimal_html_does_not_inject_tag_only_classifiers_into_story_text() =
        runTest {
            val classifier =
                Classifier().apply {
                    tags["evolution"] = Classifier.LIKE
                }

            val html =
                StoryUtil.buildMinimalHtml(
                    storyHtml = "<p>evolution</p>",
                    fontCss = "",
                    themeValue = PrefConstants.ThemeValue.LIGHT,
                    nightMask = Configuration.UI_MODE_NIGHT_NO,
                    enableHighlights = false,
                    classifier = classifier,
                )

            assertFalse(html.contains("NB_applyClassifiers("))
        }

    @Test
    fun test_build_minimal_html_does_not_inject_non_text_classifiers_into_story_text() =
        runTest {
            val classifier =
                Classifier().apply {
                    authors["Sam"] = Classifier.LIKE
                    title["evolution"] = Classifier.LIKE
                    titleRegex["evo.*"] = Classifier.LIKE
                    urls["https://example.com"] = Classifier.DISLIKE
                    urlRegex["example\\.com"] = Classifier.DISLIKE
                }

            val html =
                StoryUtil.buildMinimalHtml(
                    storyHtml = "<p>evolution</p>",
                    fontCss = "",
                    themeValue = PrefConstants.ThemeValue.LIGHT,
                    nightMask = Configuration.UI_MODE_NIGHT_NO,
                    enableHighlights = false,
                    classifier = classifier,
                )

            assertFalse(html.contains("NB_applyClassifiers("))
        }

    @Test
    fun test_classifier_payload_only_includes_text_classifiers_for_story_text() {
        val classifier =
            Classifier().apply {
                authors["Sam"] = Classifier.LIKE
                tags["evolution"] = Classifier.LIKE
                title["evolution"] = Classifier.LIKE
                titleRegex["evo.*"] = Classifier.LIKE
                texts["axis"] = Classifier.DISLIKE
                urls["https://example.com"] = Classifier.DISLIKE
                urlRegex["example\\.com"] = Classifier.DISLIKE
            }

        val payload = JsonParser.parseString(StoryUtil.classifierToJson(classifier)).asJsonObject

        assertFalse(payload.has("authors"))
        assertFalse(payload.has("tags"))
        assertFalse(payload.has("titles"))
        assertFalse(payload.has("title_regex"))
        assertFalse(payload.has("urls"))
        assertFalse(payload.has("url_regex"))
        assertTrue(payload.getAsJsonObject("texts").get("axis").asInt == Classifier.DISLIKE)
    }
}
