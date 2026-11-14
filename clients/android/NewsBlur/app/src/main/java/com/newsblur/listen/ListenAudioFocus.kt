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
 * voice next starts from a pause (not when auto-continue moves to the next story or Listen picks up after a call);
 * a phone call or alarm pauses Listen, and it picks up again when the call ends.
 *
 * Whenever Listen plays without focus, with lowering off or after another app took focus, it gets no interruption
 * callbacks, so it watches the audio mode for calls instead.
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

    /** The voice stopped because a story ended, so starting again may be auto-continue rather than a new play. */
    private var stoppedAtStoryEnd = false

    /** Set while Listen picks up after the call that paused it, which isn't a new play. */
    private var resumedAfterCall = false
    private val forgetStoryEnd = Runnable { stoppedAtStoryEnd = false }
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
            val resumingAfterCall = resumedAfterCall
            resumedAfterCall = false
            pausedByFocusLoss = false
            pausedForCall = false
            // ListenAudioFocus.kt: only a new play asks for focus again, not the 200 ms state ticks while speaking,
            // auto-continue starting the next story, or picking up after a call.
            if (!wasSpeaking && !stoppedAtStoryEnd && !resumingAfterCall) lostFocusToOtherApp = false
            stoppedAtStoryEnd = false
            system.removeCallbacks(forgetStoryEnd)
        } else if (wasSpeaking) {
            // A story ended (ListenManager.kt keeps focus a moment for auto-continue): once that moment passes
            // without a next story, playing again is a new play.
            stoppedAtStoryEnd = abandonDelayMs > 0L
            if (stoppedAtStoryEnd) system.postDelayed(abandonDelayMs, forgetStoryEnd)
        }
        wasSpeaking = speaking
        if (mode == ListenFocusMode.DUCK_OTHERS && (speaking || pausedByFocusLoss)) {
            cancelAbandon()
            if (!holdsFocus && !lostFocusToOtherApp && !requestFocus()) return
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
        val playsWithoutFocus = mode == ListenFocusMode.NONE || (mode == ListenFocusMode.DUCK_OTHERS && !holdsFocus)
        if (playsWithoutFocus && (speaking || pausedForCall)) watchCalls() else stopWatchingCalls()
        // ExoPlayer handles calls itself when Listen doesn't play over other audio.
        if (mode == ListenFocusMode.EXCLUSIVE) pausedForCall = false
    }

    /** Listen closed: forget any interruption, stop watching for calls and give focus back right away. */
    fun release() {
        pausedByFocusLoss = false
        pausedForCall = false
        lostFocusToOtherApp = false
        wasSpeaking = false
        stoppedAtStoryEnd = false
        resumedAfterCall = false
        system.removeCallbacks(forgetStoryEnd)
        stopWatchingCalls()
        abandon()
    }

    private fun requestFocus(): Boolean {
        if (system.requestFocus(::onFocusChange)) {
            holdsFocus = true
        } else {
            // ListenAudioFocus.kt: focus is refused during a call, and the voice shouldn't play over one.
            onPause()
        }
        return holdsFocus
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
            // ListenAudioFocus.kt: ListenManager.kt publishes inside onResume, so the flag covers only that resume
            // and can't linger to a later, deliberate play when the resume doesn't get the voice speaking.
            resumedAfterCall = true
            onResume()
            resumedAfterCall = false
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
internal class AndroidListenFocusSystem(
    context: Context,
    private val handler: Handler = Handler(Looper.getMainLooper()),
) : ListenFocusSystem {
    private val audioManager = context.getSystemService(AudioManager::class.java)
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
    internal fun watchModeChanges(onMode: (Int) -> Unit) {
        val listener = AudioManager.OnModeChangedListener { mode -> onMode(mode) }
        audioManager.addOnModeChangedListener({ command -> handler.post(command) }, listener)
        modeListener = listener
        onMode(audioManager.mode)
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
