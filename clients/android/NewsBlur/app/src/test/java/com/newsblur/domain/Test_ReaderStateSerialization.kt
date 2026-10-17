package com.newsblur.domain

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

class Test_ReaderStateSerialization {
    @Test
    fun test_api_classifier_survives_fragment_state_serialization() {
        val classifier = Gson().fromJson(
            """{
              "authors":{"Writer":1},"author_regex":{"Writer.*":-1},
              "titles":{"Title":1},"title_regex":{"Title.*":-1},
              "tags":{"Tag":1},"feeds":{"42":1},
              "texts":{"Text":1},"text_regex":{"Text.*":-1},
              "urls":{"https://example.com":1},"url_regex":{"example.*":-1}
            }""",
            Classifier::class.java,
        )

        val restored = roundTrip(classifier)

        assertEquals(classifier.authors, restored.authors)
        assertEquals(classifier.authorRegex, restored.authorRegex)
        assertEquals(classifier.title, restored.title)
        assertEquals(classifier.titleRegex, restored.titleRegex)
        assertEquals(classifier.tags, restored.tags)
        assertEquals(classifier.feeds, restored.feeds)
        assertEquals(classifier.texts, restored.texts)
        assertEquals(classifier.textRegex, restored.textRegex)
        assertEquals(classifier.urls, restored.urls)
        assertEquals(classifier.urlRegex, restored.urlRegex)
    }

    @Test
    fun test_story_with_comment_replies_survives_dialog_state_serialization() {
        val story = Gson().fromJson(
            """{
              "story_hash":"42:story",
              "public_comments":[{"id":"comment","replies":[
                {"reply_id":"reply","comments":"Reply text","user_id":"7"}
              ]}]
            }""",
            Story::class.java,
        )

        val restored = roundTrip(story)

        assertEquals("42:story", restored.storyHash)
        assertEquals("comment", restored.publicComments.single().id)
        assertEquals("reply", restored.publicComments.single().replies.single().id)
        assertEquals("Reply text", restored.publicComments.single().replies.single().text)
        assertEquals("7", restored.publicComments.single().replies.single().userId)
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> roundTrip(value: T): T {
        val bytes = ByteArrayOutputStream().use { output ->
            ObjectOutputStream(output).use { it.writeObject(value) }
            output.toByteArray()
        }
        return ObjectInputStream(ByteArrayInputStream(bytes)).use { it.readObject() as T }
    }
}
