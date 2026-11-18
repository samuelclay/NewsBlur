package com.newsblur.listen

import com.newsblur.preference.ListenRotationVoice
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_ListenVoiceRotation {
    // Test_ListenVoiceRotation.kt: manifest retries must not advance a story, languages rotate independently,
    // and a fallback consumes the requested voice's turn. Advancing on every request would break this.
    @Test
    fun test_story_rotation_retry_fallback_wrap_and_session_reset() {
        val rotations =
            mapOf(
                "en" to listOf(ListenRotationVoice("a", "A"), ListenRotationVoice("b", "B")),
                "fr" to listOf(ListenRotationVoice("c", "C"), ListenRotationVoice("d", "D")),
            )
        val session = ListenVoiceRotationSession()
        session.beginStory("one", rotations)
        session.record("en", "fallback")
        session.beginStory("one", rotations)
        assertEquals("a", session.choices["en"])
        session.beginStory("two", rotations)
        assertEquals(mapOf("en" to "b", "fr" to "c"), session.choices)
        session.record("en", "b")
        session.beginStory("three", rotations)
        assertEquals("a", session.choices["en"])
        session.reset()
        session.beginStory("four", rotations)
        assertEquals("a", session.choices["en"])
    }

    // Test_ListenVoiceRotation.kt: editing the list affects the next story while the current narrator stays fixed.
    @Test
    fun test_editing_rotation_and_using_one_voice() {
        val session = ListenVoiceRotationSession()
        val voices = listOf(ListenRotationVoice("a", "A"), ListenRotationVoice("b", "B"), ListenRotationVoice("c", "C"))
        session.beginStory("one", mapOf("en" to voices))
        session.record("en", "a")
        session.beginStory("one", mapOf("en" to voices.drop(1)))
        assertEquals("a", session.choices["en"])
        session.beginStory("two", mapOf("en" to voices.drop(1)))
        assertEquals("b", session.choices["en"])
        session.useVoice("c", "en")
        session.beginStory("three", mapOf("en" to voices))
        assertEquals("a", session.choices["en"])
    }
}
