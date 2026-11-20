package com.newsblur.listen

import com.newsblur.preference.ListenRotationVoice

/** ListenVoiceRotationSession.kt keeps the cursor local, while ListenPreferences.kt syncs only the lists. */
class ListenVoiceRotationSession {
    private val lastVoices = mutableMapOf<String, String>()
    private var storyHash: String? = null
    var choices: Map<String, String> = emptyMap()
        private set

    fun beginStory(
        hash: String,
        rotations: Map<String, List<ListenRotationVoice>>,
    ) {
        if (storyHash == hash) return
        storyHash = hash
        choices =
            rotations.filterValues { it.isNotEmpty() }.mapValues { (language, voices) ->
                val previous = voices.indexOfFirst { it.voiceId == lastVoices[language] }
                voices[(previous + 1) % voices.size].voiceId
            }
    }

    fun record(
        language: String?,
        resolvedVoice: String?,
    ) {
        if (language == null) return
        val voice = choices[language] ?: resolvedVoice ?: return
        choices = choices + (language to voice)
        lastVoices[language] = voice
    }

    fun useVoice(
        id: String,
        language: String,
    ) {
        choices = choices + (language to id)
        lastVoices[language] = id
    }

    fun reset() {
        lastVoices.clear()
        choices = emptyMap()
        storyHash = null
    }
}
