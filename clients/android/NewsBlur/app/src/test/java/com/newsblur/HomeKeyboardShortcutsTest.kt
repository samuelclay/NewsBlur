package com.newsblur

import android.view.KeyEvent
import com.newsblur.keyboard.KeyboardEvent
import com.newsblur.keyboard.KeyboardListener
import com.newsblur.keyboard.KeyboardManager
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert
import org.junit.Test

class HomeKeyboardShortcutsTest {

    private val manager = KeyboardManager()

    @After
    fun afterTest() {
        manager.removeListener()
    }

    @Test
    fun openAllStoriesTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isAltPressed } returns true

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_E, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.OpenAllStories) }
    }

    @Test
    fun notOpenAllStoriesTest() {
        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isAltPressed } returns false

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_E, keyEvent)
        Assert.assertFalse(handled)
    }

    @Test
    fun addSiteTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isAltPressed } returns true

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_A, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.AddFeed) }
    }

    @Test
    fun notAddSiteTest() {
        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isAltPressed } returns false

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_A, keyEvent)
        Assert.assertFalse(handled)
    }

    @Test
    fun switchViewLeftTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_DPAD_LEFT, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.SwitchViewLeft) }
    }

    @Test
    fun switchViewRightTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_DPAD_RIGHT, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.SwitchViewRight) }
    }
}