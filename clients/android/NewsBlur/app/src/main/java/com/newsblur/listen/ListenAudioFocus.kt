package com.newsblur.listen

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi

/**
 * ListenAudioFocus.kt handles audio focus while Listen plays over other audio (ListenAudioMix.kt), where ExoPlayer
 * doesn't take focus because that would pause the other app's music.
 *
 * With "Lower music while voice speaks" on, Listen holds AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK while the voice plays,
 * so the other app lowers its music, and gives it back when Listen pauses or finishes so the music comes back up.
 * Another app starting its own music doesn't pause Listen; a phone call or alarm does, and Listen picks up again
 * when it ends.
 *
 * With lowering off, Listen holds no focus at all, so it watches for calls instead (Android 12 and later).
 *
 * [onPause] and [onResume] are ListenManager.kt's own pause and play.
 */
class ListenAudioFocus(
    context: Context,
    private val onPause: () -> Unit,
    private val onResume: () -> Unit,
) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var request: AudioFocusRequest? = null
    private var pausedByFocusLoss = false
    private var pausedForCall = false
    private var callWatcher: Any? = null
    private var abandonScheduled = false
    private val abandonLater = Runnable { abandon() }

    /**
     * Called with every Listen state change: [mode] from ListenAudioMix.kt, and whether the voice is [speaking]
     * (playing or about to). [abandonDelayMs] keeps focus a moment after a story finishes, so the music doesn't come
     * up and go back down when auto-continue starts the next one.
     */
    fun update(
        mode: ListenFocusMode,
        speaking: Boolean,
        abandonDelayMs: Long,
    ) {
        if (speaking) {
            pausedByFocusLoss = false
            pausedForCall = false
        }
        if (mode == ListenFocusMode.DUCK_OTHERS && (speaking || pausedByFocusLoss)) {
            cancelAbandon()
            if (request == null) requestFocus()
        } else if (request != null) {
            if (mode == ListenFocusMode.DUCK_OTHERS && abandonDelayMs > 0L) {
                if (!abandonScheduled) {
                    abandonScheduled = true
                    handler.postDelayed(abandonLater, abandonDelayMs)
                }
            } else {
                abandon()
            }
        }
        if (mode != ListenFocusMode.DUCK_OTHERS) pausedByFocusLoss = false
        val watchesCalls = mode == ListenFocusMode.NONE && (speaking || pausedForCall)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (watchesCalls) watchCalls() else stopWatchingCalls()
        }
        if (mode != ListenFocusMode.NONE) pausedForCall = false
    }

    private fun requestFocus() {
        val focusRequest =
            AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes
                        .Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                ).setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener(::onFocusChange, handler)
                .build()
        if (audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            request = focusRequest
        } else {
            // ListenAudioFocus.kt: focus is refused during a call, and the voice shouldn't play over one.
            onPause()
        }
    }

    private fun abandon() {
        cancelAbandon()
        request?.let { audioManager.abandonAudioFocusRequest(it) }
        request = null
    }

    private fun cancelAbandon() {
        handler.removeCallbacks(abandonLater)
        abandonScheduled = false
    }

    private fun onFocusChange(change: Int) {
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // A call, an alarm or the assistant: pause, keep the request, and resume when focus comes back.
                pausedByFocusLoss = true
                onPause()
            }
            AudioManager.AUDIOFOCUS_GAIN ->
                if (pausedByFocusLoss) {
                    pausedByFocusLoss = false
                    onResume()
                }
            // Another app started its own music: Listen keeps reading over it and asks again on its next play.
            AudioManager.AUDIOFOCUS_LOSS -> request = null
            // A notification sound: Android lowers the voice for it on its own.
            else -> Unit
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun watchCalls() {
        if (callWatcher != null) return
        val listener = AudioManager.OnModeChangedListener(::onModeChanged)
        audioManager.addOnModeChangedListener({ command -> handler.post(command) }, listener)
        callWatcher = listener
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun stopWatchingCalls() {
        val listener = callWatcher as? AudioManager.OnModeChangedListener ?: return
        audioManager.removeOnModeChangedListener(listener)
        callWatcher = null
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun onModeChanged(mode: Int) {
        val inCall =
            mode == AudioManager.MODE_IN_CALL ||
                mode == AudioManager.MODE_IN_COMMUNICATION ||
                mode == AudioManager.MODE_RINGTONE ||
                mode == AudioManager.MODE_CALL_SCREENING
        if (inCall && !pausedForCall) {
            pausedForCall = true
            onPause()
        } else if (!inCall && pausedForCall) {
            pausedForCall = false
            onResume()
        }
    }
}
