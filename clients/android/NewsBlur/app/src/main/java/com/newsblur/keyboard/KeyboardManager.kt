package com.newsblur.keyboard

import android.view.KeyEvent

class KeyboardManager {

    private var listener: KeyboardListener? = null

    fun addListener(listener: KeyboardListener) {
        this.listener = listener
    }

    fun removeListener() {
        this.listener = null
    }

    /**
     * @return Return <code>true</code> to prevent this event from being propagated
     * further, or <code>false</code> to indicate that you have not handled
     */
    fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean = when (keyCode) {
        KeyEvent.KEYCODE_E -> {
            handleKeycodeE(event)
        }
        KeyEvent.KEYCODE_A -> {
            handleKeycodeA(event)
        }
        KeyEvent.KEYCODE_DPAD_RIGHT -> {
            listener?.onKeyboardEvent(KeyboardEvent.SwitchViewRight)
            true
        }
        KeyEvent.KEYCODE_DPAD_LEFT -> {
            listener?.onKeyboardEvent(KeyboardEvent.SwitchViewLeft)
            true
        }
        else -> false
    }

    private fun handleKeycodeE(event: KeyEvent): Boolean = if (event.isAltPressed) {
        listener?.onKeyboardEvent(KeyboardEvent.OpenAllStories)
        true
    } else false

    private fun handleKeycodeA(event: KeyEvent): Boolean = if (event.isAltPressed) {
        listener?.onKeyboardEvent(KeyboardEvent.AddFeed)
        true
    } else false
}

interface KeyboardListener {

    fun onKeyboardEvent(event: KeyboardEvent)
}

sealed class KeyboardEvent {

    object OpenAllStories : KeyboardEvent()

    object AddFeed : KeyboardEvent()

    object SwitchViewRight : KeyboardEvent()

    object SwitchViewLeft : KeyboardEvent()
}