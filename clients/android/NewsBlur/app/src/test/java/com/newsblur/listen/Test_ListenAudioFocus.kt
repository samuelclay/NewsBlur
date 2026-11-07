package com.newsblur.listen

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import io.mockk.every
import io.mockk.mockk
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
        var grantsFocus = true
        var holdsFocus = false
        var requests = 0
        var focusChange: ((Int) -> Unit)? = null
        var modeWatcher: ((Int) -> Unit)? = null
        val delayed = mutableListOf<Runnable>()

        override fun requestFocus(onChange: (Int) -> Unit): Boolean {
            requests += 1
            focusChange = onChange
            holdsFocus = grantsFocus
            return grantsFocus
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

        /** Lets every pending delay run, as if its time passed. */
        fun runDelayed() {
            val due = delayed.toList()
            delayed.clear()
            due.forEach(Runnable::run)
        }
    }

    private val system = FakeFocusSystem()
    private var pauses = 0
    private var resumes = 0

    /** Like ListenManager.kt, a resume that works publishes the voice speaking before onResume returns. */
    private var resumeMode: ListenFocusMode? = null
    private val focus: ListenAudioFocus =
        ListenAudioFocus(
            system,
            onPause = { pauses += 1 },
            onResume = {
                resumes += 1
                resumeMode?.let { publish(it, speaking = true) }
            },
        )

    private fun publish(
        mode: ListenFocusMode,
        speaking: Boolean,
    ): Unit = focus.update(mode, speaking, abandonDelayMs = 0L)

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
    fun test_auto_continue_doesnt_take_focus_back_from_another_app() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS)
        // Test_ListenAudioFocus.kt: ListenManager.kt ends a story with a moment's grace, then starts the next one.
        focus.update(ListenFocusMode.DUCK_OTHERS, speaking = false, abandonDelayMs = 2000L)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertEquals("The next story shouldn't lower the podcast again", 1, system.requests)
    }

    @Test
    fun test_playing_again_after_the_list_ends_is_a_new_play() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS)
        focus.update(ListenFocusMode.DUCK_OTHERS, speaking = false, abandonDelayMs = 2000L)
        system.runDelayed()
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertEquals(2, system.requests)
    }

    @Test
    fun test_a_call_still_pauses_listen_after_another_app_took_focus() {
        resumeMode = ListenFocusMode.DUCK_OTHERS
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        val watcher = system.modeWatcher
        assertNotNull("Without focus there are no interruption callbacks, so Listen watches for calls", watcher)
        watcher?.invoke(AudioManager.MODE_IN_COMMUNICATION)
        assertEquals(1, pauses)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        assertNotNull("The paused story keeps watching for the call to end", system.modeWatcher)
        watcher?.invoke(AudioManager.MODE_NORMAL)
        assertEquals(1, resumes)
        assertEquals("Picking up after the call leaves the other app's music up", 1, system.requests)
    }

    @Test
    fun test_a_resume_after_a_call_that_doesnt_play_leaves_the_next_play_new() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.focusChange?.invoke(AudioManager.AUDIOFOCUS_LOSS)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        system.modeWatcher?.invoke(AudioManager.MODE_IN_CALL)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        // Test_ListenAudioFocus.kt: the story failed during the call, so resuming doesn't get the voice speaking.
        system.modeWatcher?.invoke(AudioManager.MODE_NORMAL)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = false)
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertEquals("A deliberate play later asks for focus again", 2, system.requests)
    }

    @Test
    fun test_holding_focus_leaves_calls_to_the_focus_callbacks() {
        publish(ListenFocusMode.DUCK_OTHERS, speaking = true)
        assertNull(system.modeWatcher)
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

    @Test
    fun test_refused_focus_does_not_restart_call_watching_after_reentrant_pause() {
        system.grantsFocus = false
        lateinit var reentrant: ListenAudioFocus
        reentrant =
            ListenAudioFocus(
                system,
                onPause = { reentrant.update(ListenFocusMode.DUCK_OTHERS, false, 0L) },
                onResume = { resumes += 1 },
            )
        reentrant.update(ListenFocusMode.DUCK_OTHERS, true, 0L)
        assertNull("A refused play stays paused without a call-end resume", system.modeWatcher)
        assertEquals(0, resumes)
    }

    @Test
    fun test_android_mode_listener_delivers_an_already_active_call() {
        // Test_ListenAudioFocus.kt exercises the Android 12+ adapter, whose listener only reports later changes.
        val context = mockk<Context>()
        val manager = mockk<AudioManager>(relaxed = true)
        val handler = mockk<Handler>(relaxed = true)
        every { context.getSystemService(AudioManager::class.java) } returns manager
        every { manager.mode } returns AudioManager.MODE_IN_COMMUNICATION
        val adapter = AndroidListenFocusSystem(context, handler)
        val modes = mutableListOf<Int>()
        adapter.watchModeChanges { modes += it }
        assertEquals(listOf(AudioManager.MODE_IN_COMMUNICATION), modes)
    }
}
