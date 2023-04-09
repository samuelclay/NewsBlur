package com.newsblur.keyboard

import android.content.Context
import android.content.res.Configuration
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
        /**
         * Home events
         */
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
        /**
         * Story events
         */
        KeyEvent.KEYCODE_J,
        KeyEvent.KEYCODE_DPAD_DOWN -> {
            listener?.onKeyboardEvent(KeyboardEvent.PreviousStory)
            true
        }
        KeyEvent.KEYCODE_K,
        KeyEvent.KEYCODE_DPAD_UP -> {
            listener?.onKeyboardEvent(KeyboardEvent.NextStory)
            true
        }
        KeyEvent.KEYCODE_N -> {
            listener?.onKeyboardEvent(KeyboardEvent.NextUnreadStory)
            true
        }
        KeyEvent.KEYCODE_U, KeyEvent.KEYCODE_M -> {
            listener?.onKeyboardEvent(KeyboardEvent.ToggleReadUnread)
            true
        }
        KeyEvent.KEYCODE_S -> {
            if (event.isShiftPressed) listener?.onKeyboardEvent(KeyboardEvent.ShareStory)
            else listener?.onKeyboardEvent(KeyboardEvent.SaveUnsaveStory)
            true
        }
        KeyEvent.KEYCODE_O, KeyEvent.KEYCODE_V -> {
            listener?.onKeyboardEvent(KeyboardEvent.OpenInBrowser)
            true
        }
        KeyEvent.KEYCODE_C -> {
            listener?.onKeyboardEvent(KeyboardEvent.ScrollToComments)
            true
        }
        KeyEvent.KEYCODE_T -> {
            listener?.onKeyboardEvent(KeyboardEvent.OpenStoryTrainer)
            true
        }
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER -> {
            if (event.isShiftPressed) {
                listener?.onKeyboardEvent(KeyboardEvent.ToggleTextView)
                true
            } else false
        }
        KeyEvent.KEYCODE_SPACE -> {
            if (event.isShiftPressed) listener?.onKeyboardEvent(KeyboardEvent.PageUp)
            else listener?.onKeyboardEvent(KeyboardEvent.PageDown)
            true
        }
        KeyEvent.KEYCODE_ALT_RIGHT,
        KeyEvent.KEYCODE_ALT_LEFT -> {
            listener?.onKeyboardEvent(KeyboardEvent.Tutorial)
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

    fun isKnownKeyCode(keyCode: Int): Boolean =
            isShortcutKeyCode(keyCode) && isSpecialKeyCode(keyCode)

    private fun isSpecialKeyCode(keyCode: Int) = when (keyCode) {
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER,
        KeyEvent.KEYCODE_SPACE,
        -> true
        else -> false
    }

    private fun isShortcutKeyCode(keyCode: Int) = when (keyCode) {
        KeyEvent.KEYCODE_E,
        KeyEvent.KEYCODE_A,
        KeyEvent.KEYCODE_J,
        KeyEvent.KEYCODE_K,
        KeyEvent.KEYCODE_N,
        KeyEvent.KEYCODE_U,
        KeyEvent.KEYCODE_M,
        KeyEvent.KEYCODE_S,
        KeyEvent.KEYCODE_O,
        KeyEvent.KEYCODE_V,
        KeyEvent.KEYCODE_C,
        KeyEvent.KEYCODE_T,
        -> true
        else -> false
    }

    companion object {

        @JvmStatic
        fun hasHardwareKeyboard(context: Context) =
                context.resources.configuration.keyboard == Configuration.KEYBOARD_QWERTY
    }
}