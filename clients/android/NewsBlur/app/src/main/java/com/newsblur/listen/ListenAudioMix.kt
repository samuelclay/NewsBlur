package com.newsblur.listen

import android.content.SharedPreferences
import android.media.AudioManager
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.roundToInt

/** How Listen holds audio focus (ListenAudioMix.kt). */
enum class ListenFocusMode {
    /** ExoPlayer takes focus, so other apps pause: Listen's behavior when it doesn't play over other audio. */
    EXCLUSIVE,

    /** Listen asks to be heard over other apps, which lower their music while the voice plays. */
    DUCK_OTHERS,

    /** Listen plays without taking focus, so other apps keep their music at full volume. */
    NONE,
}

/** The Music section's settings in Listen's Now Playing sheet (ListenMusicSection.kt). */
data class ListenAudioMixSettings(
    val playsOverOtherAudio: Boolean = false,
    val lowersMusicWhileSpeaking: Boolean = true,
    val voiceVolume: Double = 1.0,
    val isMusicSectionCollapsed: Boolean = false,
) {
    /** ListenManager.kt applies music mixing to narration only, preserving normal podcast focus and volume. */
    fun forPlayback(isMedia: Boolean): ListenAudioMixSettings = if (isMedia) copy(playsOverOtherAudio = false) else this

    /** The balance only applies while Listen plays over other audio, where its slider is shown. */
    val effectiveVoiceVolume: Double
        get() = ListenAudioMixMath.effectiveVoiceVolume(playsOverOtherAudio, voiceVolume)

    val focusMode: ListenFocusMode
        get() = ListenAudioMixMath.focusMode(playsOverOtherAudio, lowersMusicWhileSpeaking)
}

/**
 * ListenAudioMix.kt's math for the Music / Voice balance, shared with iOS (ListenAudioMix.swift). The slider runs
 * from -1 (toward Music) to 1 (toward Voice) and each half is even in decibels: toward Music the voice drops to
 * -40 dB, toward Voice it's boosted up to +20 dB (ListenVoiceBoost.kt), since Listen can't turn another app's music
 * down.
 */
object ListenAudioMixMath {
    const val MIN_VOICE_VOLUME = 0.01
    const val MAX_VOICE_VOLUME = 10.0

    /** Near the middle the balance snaps to it, so the voice is easy to put back at 100%. */
    const val SNAP_DISTANCE = 0.06

    private val minimumDecibels = 20 * log10(MIN_VOICE_VOLUME)
    private val maximumDecibels = 20 * log10(MAX_VOICE_VOLUME)

    fun clampVoiceVolume(volume: Double): Double = if (volume.isFinite()) volume.coerceIn(MIN_VOICE_VOLUME, MAX_VOICE_VOLUME) else 1.0

    fun balanceForVoiceVolume(volume: Double): Double {
        val decibels = 20 * log10(clampVoiceVolume(volume))
        return if (decibels >= 0) decibels / maximumDecibels else -decibels / minimumDecibels
    }

    fun voiceVolumeForBalance(balance: Double): Double {
        val position = if (balance.isFinite()) balance.coerceIn(-1.0, 1.0) else 0.0
        val edgeDecibels = if (position >= 0) maximumDecibels else minimumDecibels
        return clampVoiceVolume(10.0.pow(abs(position) * edgeDecibels / 20))
    }

    fun snapped(balance: Double): Double = if (abs(balance) < SNAP_DISTANCE) 0.0 else balance

    fun effectiveVoiceVolume(
        playsOverOtherAudio: Boolean,
        voiceVolume: Double,
    ): Double = if (playsOverOtherAudio) clampVoiceVolume(voiceVolume) else 1.0

    /** ExoPlayer's volume stops at 1; the rest is ListenVoiceBoost.kt's job. */
    fun playerVolume(effectiveVoiceVolume: Double): Float = clampVoiceVolume(effectiveVoiceVolume).coerceAtMost(1.0).toFloat()

    /** The LoudnessEnhancer gain for a voice volume above 1, in millibels; 0 when there's nothing to boost. */
    fun boostMillibels(effectiveVoiceVolume: Double): Int {
        val volume = clampVoiceVolume(effectiveVoiceVolume)
        return if (volume > 1.0) (2000 * log10(volume)).roundToInt() else 0
    }

    /**
     * Whether an AudioManager mode means a call is ringing or under way, for ListenAudioFocus.kt's call watch. Call
     * screening (4) only exists from Android 11, so earlier versions never report it.
     */
    fun isCallMode(mode: Int): Boolean =
        mode == AudioManager.MODE_RINGTONE ||
            mode == AudioManager.MODE_IN_CALL ||
            mode == AudioManager.MODE_IN_COMMUNICATION ||
            mode == MODE_CALL_SCREENING

    private const val MODE_CALL_SCREENING = 4

    fun focusMode(
        playsOverOtherAudio: Boolean,
        lowersMusicWhileSpeaking: Boolean,
    ): ListenFocusMode =
        when {
            !playsOverOtherAudio -> ListenFocusMode.EXCLUSIVE
            lowersMusicWhileSpeaking -> ListenFocusMode.DUCK_OTHERS
            else -> ListenFocusMode.NONE
        }
}

/**
 * ListenAudioMix.kt keeps the Music section's settings. They depend on this device's audio, so they stay in this
 * device's SharedPreferences and never sync through ListenPreferences.kt.
 */
@Singleton
class ListenAudioMix
    @Inject
    constructor(
        private val prefs: SharedPreferences,
    ) {
        private val mutableSettings = MutableStateFlow(readSettings())
        val settings: StateFlow<ListenAudioMixSettings> = mutableSettings.asStateFlow()

        fun current(): ListenAudioMixSettings = mutableSettings.value

        fun setPlaysOverOtherAudio(value: Boolean) = save { putBoolean(KEY_PLAY_OVER_OTHER_AUDIO, value) }

        fun setLowersMusicWhileSpeaking(value: Boolean) = save { putBoolean(KEY_LOWER_MUSIC, value) }

        fun setVoiceVolume(value: Double) = save { putFloat(KEY_VOICE_VOLUME, ListenAudioMixMath.clampVoiceVolume(value).toFloat()) }

        fun setMusicSectionCollapsed(value: Boolean) = save { putBoolean(KEY_MUSIC_SECTION_COLLAPSED, value) }

        private fun save(change: SharedPreferences.Editor.() -> Unit) {
            prefs.edit(action = change)
            mutableSettings.value = readSettings()
        }

        private fun readSettings(): ListenAudioMixSettings =
            ListenAudioMixSettings(
                playsOverOtherAudio = prefs.getBoolean(KEY_PLAY_OVER_OTHER_AUDIO, false),
                lowersMusicWhileSpeaking = prefs.getBoolean(KEY_LOWER_MUSIC, true),
                voiceVolume = ListenAudioMixMath.clampVoiceVolume(prefs.getFloat(KEY_VOICE_VOLUME, 1f).toDouble()),
                isMusicSectionCollapsed = prefs.getBoolean(KEY_MUSIC_SECTION_COLLAPSED, false),
            )

        companion object {
            // ListenAudioMix.kt's keys match iOS's ListenAudioMix.swift and stay out of ListenPrefKeys, which syncs.
            const val KEY_PLAY_OVER_OTHER_AUDIO = "listen_play_over_other_audio"
            const val KEY_LOWER_MUSIC = "listen_lower_music_while_speaking"
            const val KEY_VOICE_VOLUME = "listen_voice_volume"
            const val KEY_MUSIC_SECTION_COLLAPSED = "listen_music_section_collapsed"
        }
    }
