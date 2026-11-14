package com.newsblur.fragment

import com.newsblur.domain.Story
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

// Test_TrainerStoryText.kt: the story trainer's Story Text section lists the saved text phrases the
// story matches. Stories from the list and the reader carry no text (Story.fromCursor,
// Story.copyForBundle), so StoryIntelTrainerFragment.java reads it through
// TrainerPhrase.withStoryContent before IntelTrainerSections.kt lists the phrases.
class Test_TrainerStoryText {
    private val saved = listOf("My thanks to", "WWDC")

    private fun listedStory(): Story =
        Story().apply {
            storyHash = "6:sponsor"
            feedId = "6"
            title = "[Sponsor] Example App"
        }

    @Test
    fun test_a_listed_story_without_its_text_matches_no_text_phrase() {
        assertEquals(emptyList<String>(), TrainerPhrase.storyPhrases(TrainerPhraseKind.TEXT, saved, listedStory()))
    }

    @Test
    fun test_a_saved_text_phrase_the_story_text_contains_is_listed() {
        val story = listedStory()
        val loaded =
            TrainerPhrase.withStoryContent(story) { hash ->
                if (hash == "6:sponsor") "<p>My thanks to Example App for sponsoring the site this week.</p>" else null
            }

        assertEquals(listOf("My thanks to"), TrainerPhrase.storyPhrases(TrainerPhraseKind.TEXT, saved, loaded))
        assertEquals("[Sponsor] Example App", loaded.title)
        assertNull("The fragment arguments' story stays without its text", story.content)
    }

    @Test
    fun test_a_story_that_has_its_text_is_used_as_is() {
        val story = listedStory().apply { content = "WWDC is next week." }

        val loaded = TrainerPhrase.withStoryContent(story) { throw AssertionError("Read the text again") }

        assertSame(story, loaded)
        assertEquals(listOf("WWDC"), TrainerPhrase.storyPhrases(TrainerPhraseKind.TEXT, saved, loaded))
    }
}
