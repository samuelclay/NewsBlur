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
 * Another app starting its own music doesn't pause Listen, and Listen doesn't take focus back from it until the
 * voice next starts from a pause; a phone call or alarm pauses Listen, and it picks up again when the call ends.
 *
 * With lowering off, Listen holds no focus at all, so it watches the audio mode for calls instead.
 *
 * [onPause] and [onResume] are ListenManager.kt's own pause and play. The Android calls go through
 * [ListenFocusSystem], so these rules are tested without a device (Test_ListenAudioFocus.kt).
 */
class ListenAudioFocus(
    private val system: ListenFocusSystem,
    private val onPause: () -> Unit,
    private val onResume: () -> Unit,
) {
    constructor(context: Context, onPause: () -> Unit, onResume: () -> Unit) :
        this(AndroidListenFocusSystem(context), onPause, onResume)

    private var holdsFocus = false
    private var pausedByFocusLoss = false
    private var pausedForCall = false
    private var watchesCalls = false

    /** Another app took focus for good; Listen waits for its own next play before asking again. */
    private var lostFocusToOtherApp = false
    private var wasSpeaking = false
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
            // ListenAudioFocus.kt: only a new play, not the 200 ms state ticks while speaking, asks for focus again.
            if (!wasSpeaking) lostFocusToOtherApp = false
        }
        wasSpeaking = speaking
        if (mode == ListenFocusMode.DUCK_OTHERS && (speaking || pausedByFocusLoss)) {
            cancelAbandon()
            if (!holdsFocus && !lostFocusToOtherApp) requestFocus()
        } else if (holdsFocus) {
            if (mode == ListenFocusMode.DUCK_OTHERS && abandonDelayMs > 0L) {
                if (!abandonScheduled) {
                    abandonScheduled = true
                    system.postDelayed(abandonDelayMs, abandonLater)
                }
            } else {
                abandon()
            }
        }
        if (mode != ListenFocusMode.DUCK_OTHERS) pausedByFocusLoss = false
        if (mode == ListenFocusMode.NONE && (speaking || pausedForCall)) watchCalls() else stopWatchingCalls()
        if (mode != ListenFocusMode.NONE) pausedForCall = false
    }

    /** Listen closed: forget any interruption, stop watching for calls and give focus back right away. */
    fun release() {
        pausedByFocusLoss = false
        pausedForCall = false
        lostFocusToOtherApp = false
        wasSpeaking = false
        stopWatchingCalls()
        abandon()
    }

    private fun requestFocus() {
        if (system.requestFocus(::onFocusChange)) {
            holdsFocus = true
        } else {
            // ListenAudioFocus.kt: focus is refused during a call, and the voice shouldn't play over one.
            onPause()
        }
    }

    private fun abandon() {
        cancelAbandon()
        if (holdsFocus) system.abandonFocus()
        holdsFocus = false
    }

    private fun cancelAbandon() {
        system.removeCallbacks(abandonLater)
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
            AudioManager.AUDIOFOCUS_LOSS -> {
                holdsFocus = false
                lostFocusToOtherApp = true
            }
            // A notification sound: Android lowers the voice for it on its own.
            else -> Unit
        }
    }

    private fun watchCalls() {
        if (watchesCalls) return
        watchesCalls = true
        system.watchMode(::onModeChanged)
    }

    private fun stopWatchingCalls() {
        if (!watchesCalls) return
        watchesCalls = false
        system.stopWatchingMode()
    }

    private fun onModeChanged(mode: Int) {
        val inCall = ListenAudioMixMath.isCallMode(mode)
        if (inCall && !pausedForCall) {
            pausedForCall = true
            onPause()
        } else if (!inCall && pausedForCall) {
            pausedForCall = false
            onResume()
        }
    }
}

/** The Android calls ListenAudioFocus.kt makes, behind an interface so its rules can be tested without a device. */
interface ListenFocusSystem {
    /** Asks for AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK and says whether it was granted; [onChange] gets focus changes. */
    fun requestFocus(onChange: (Int) -> Unit): Boolean

    fun abandonFocus()

    /** Calls [onMode] with the audio mode whenever it changes, until [stopWatchingMode]. */
    fun watchMode(onMode: (Int) -> Unit)

    fun stopWatchingMode()

    fun postDelayed(
        delayMs: Long,
        action: Runnable,
    )

    fun removeCallbacks(action: Runnable)
}

/**
 * ListenAudioFocus.kt's [ListenFocusSystem] on a device. The audio mode has a change listener from Android 12;
 * before that it's checked twice a second while Listen watches for calls.
 */
private class AndroidListenFocusSystem(
    context: Context,
) : ListenFocusSystem {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var request: AudioFocusRequest? = null
    private var modeListener: Any? = null
    private var pollMode: Runnable? = null

    override fun requestFocus(onChange: (Int) -> Unit): Boolean {
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
                .setOnAudioFocusChangeListener({ change -> onChange(change) }, handler)
                .build()
        val granted = audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        request = if (granted) focusRequest else null
        return granted
    }

    override fun abandonFocus() {
        request?.let { audioManager.abandonAudioFocusRequest(it) }
        request = null
    }

    override fun watchMode(onMode: (Int) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            watchModeChanges(onMode)
            return
        }
        val poll =
            object : Runnable {
                override fun run() {
                    onMode(audioManager.mode)
                    handler.postDelayed(this, MODE_POLL_MS)
                }
            }
        pollMode = poll
        handler.post(poll)
    }

    override fun stopWatchingMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) stopWatchingModeChanges()
        pollMode?.let(handler::removeCallbacks)
        pollMode = null
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun watchModeChanges(onMode: (Int) -> Unit) {
        val listener = AudioManager.OnModeChangedListener { mode -> onMode(mode) }
        audioManager.addOnModeChangedListener({ command -> handler.post(command) }, listener)
        modeListener = listener
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun stopWatchingModeChanges() {
        val listener = modeListener as? AudioManager.OnModeChangedListener ?: return
        audioManager.removeOnModeChangedListener(listener)
        modeListener = null
    }

    override fun postDelayed(
        delayMs: Long,
        action: Runnable,
    ) {
        handler.postDelayed(action, delayMs)
    }

    override fun removeCallbacks(action: Runnable) {
        handler.removeCallbacks(action)
    }

    private companion object {
        const val MODE_POLL_MS = 500L
    }
}
