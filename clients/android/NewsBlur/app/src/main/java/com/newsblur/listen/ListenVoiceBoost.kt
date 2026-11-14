package com.newsblur.listen

import android.media.audiofx.LoudnessEnhancer
import com.newsblur.util.Log

/**
 * ListenVoiceBoost.kt makes Listen's voice louder than 100% when the Music / Voice balance (ListenMusicSection.kt)
 * leans toward the voice. ExoPlayer's volume stops at 1 and Listen can't turn another app's music down, so a
 * LoudnessEnhancer on ExoPlayer's audio session raises the voice, limiting its peaks so it doesn't clip. The effect
 * only exists while there's a boost, and follows ExoPlayer to a new audio session.
 */
class ListenVoiceBoost {
    private var enhancer: LoudnessEnhancer? = null
    private var audioSessionId = NO_SESSION
    private var gainMillibels = 0

    /** ExoPlayer's audio session, from when it's built and whenever it changes. */
    fun attach(sessionId: Int) {
        if (sessionId == audioSessionId) return
        releaseEffect()
        audioSessionId = sessionId
        apply()
    }

    /** The boost in millibels from ListenAudioMixMath.boostMillibels; 0 turns the effect off. */
    fun setGain(millibels: Int) {
        if (millibels == gainMillibels && (millibels == 0 || enhancer != null)) return
        gainMillibels = millibels
        apply()
    }

    /** ListenManager.kt releases ExoPlayer, and its audio session with it. */
    fun release() {
        releaseEffect()
        audioSessionId = NO_SESSION
    }

    private fun apply() {
        if (gainMillibels <= 0) {
            enhancer?.enabled = false
            return
        }
        val effect = enhancer ?: create() ?: return
        try {
            effect.setTargetGain(gainMillibels)
            effect.enabled = true
        } catch (e: RuntimeException) {
            Log.w(this.javaClass.name, "Listen couldn't set the voice boost: ${e.message}")
        }
    }

    private fun create(): LoudnessEnhancer? {
        if (audioSessionId == NO_SESSION) return null
        return try {
            LoudnessEnhancer(audioSessionId).also { enhancer = it }
        } catch (e: RuntimeException) {
            // ListenVoiceBoost.kt: some devices don't offer the effect, and the voice simply stays at 100%.
            Log.w(this.javaClass.name, "Listen couldn't create the voice boost: ${e.message}")
            null
        }
    }

    private fun releaseEffect() {
        enhancer?.release()
        enhancer = null
    }

    private companion object {
        // C.AUDIO_SESSION_ID_UNSET in Media3; ExoPlayer generates a real session ID when it's built.
        const val NO_SESSION = 0
    }
}
