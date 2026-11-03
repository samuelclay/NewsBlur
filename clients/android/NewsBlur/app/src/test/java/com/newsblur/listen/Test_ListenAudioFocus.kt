package com.newsblur.listen

import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Test_ListenAudioFocus.kt drives ListenAudioFocus.kt's rules for playing over other audio through a fake
 * [ListenFocusSystem]: when Listen asks for focus, gives it back, and pauses or resumes for calls.
 */
class Test_ListenAudioFocus {
    private class FakeFocusSystem : ListenFocusSystem {
        var holdsFocus = false
        var requests = 0
        var focusChange: ((Int) -> Unit)? = null
        var modeWatcher: ((Int) -> Unit)? = null
        val delayed = mutableListOf<Runnable>()

        override fun requestFocus(onChange: (Int) -> Unit): Boolean {
            requests += 1
            focusChange = onChange
            holdsFocus = true
            return true
        }

        override fun abandonFocus() {
            holdsFocus = false
        }

        override fun watchMode(onMode: (Int) -> Unit) {
            modeWatcher = onMode
        }

        override fun stopWatchingMode() {
            modeWatcher = null
        }

        override fun postDelayed(
            delayMs: Long,
            action: Runnable,
        ) {
            delayed += action
        }

        override fun removeCallbacks(action: Runnable) {
            delayed -= action
        }
    }

    private val system = FakeFocusSystem()
    private var pauses = 0
    private var resumes = 0
    private val focus = ListenAudioFocus(system, onPause = { pauses += 1 }, onResume = { resumes += 1 })

    private fun publish(
        mode: ListenFocusMode,
        speaking: Boolean,
    ) = focus.update(mode, speaking, abandonDelayMs = 0L)

    @Test
    fun test_another_apps_music_keeps_focus_until_listen_plays_again() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertEquals(1, system.requests)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS)
        // Test_ListenAudioFocus.kt: ListenManager.kt publishes every 200 ms while the voice plays.
        repeat(5) { publish(ListenFocusMode.DUCK_OTHERS, speaking = true) }
        assertEquals("A podcast app that took focus shouldn't be ducked again right away", 1, system.requests)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertEquals("Playing again after a pause asks for focus again", 2, system.requests)
    }

    @Test
    fun test_pausing_gives_focus_back_so_the_music_comes_up() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertTrue(system.holdsFocus)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        assertFalse(system.holdsFocus)
    }

    @Test
    fun test_closing_during_an_interruption_gives_focus_back_and_never_resumes() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT)
        assertEquals(1, pauses)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        assertTrue("The interrupted story keeps focus so it can resume", system.holdsFocus)
        focus.release()
        assertFalse(system.holdsFocus)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_GAIN)
        assertEquals("A closed story doesn't come back when the call ends", 0, resumes)
    }

    @Test
    fun test_without_lowering_a_call_pauses_and_its_end_resumes() {
        publish(ListenFocusMode.NONE, speaking = true)
        assertEquals("Without lowering, Listen takes no focus", 0, system.requests)
        val watcher = system.modeWatcher
        assertNotNull(watcher)
        watcher?.invoke(AudioManager.MODE_RINGTONE)
        assertEquals(1, pauses)
        publish(ListenFocusMode.NONE, speaking = false)
        assertNotNull("The paused story keeps watching for the call to end", system.modeWatcher)
        watcher?.invoke(AudioManager.MODE_NORMAL)
        assertEquals(1, resumes)
    }

    @Test
    fun test_closing_stops_watching_for_calls() {
        publish(ListenFocusMode.NONE, speaking = true)
        system.modeWatcher?.invoke(AudioManager.MODE_IN_CALL)
        focus.release()
        assertNull(system.modeWatcher)
    }
}
