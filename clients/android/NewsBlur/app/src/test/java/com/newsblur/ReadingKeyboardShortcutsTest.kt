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

class ReadingKeyboardShortcutsTest {

    private val manager = KeyboardManager()

    @After
    fun afterTest() {
        manager.removeListener()
    }

    @Test
    fun previousStoryTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_J, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.PreviousStory) }
    }

    @Test
    fun previousStoryArrowTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_DPAD_DOWN, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.PreviousStory) }
    }

    @Test
    fun nextStoryTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_K, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.NextStory) }
    }

    @Test
    fun nextStoryArrowTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_DPAD_UP, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.NextStory) }
    }

    @Test
    fun toggleTextViewTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns true

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_ENTER, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.ToggleTextView) }
    }

    @Test
    fun noToggleTextViewTest() {
        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns false

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_ENTER, keyEvent)
        Assert.assertFalse(handled)
    }

    @Test
    fun pageDownTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns false

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_SPACE, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.PageDown) }
    }

    @Test
    fun pageUpTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns true

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_SPACE, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.PageUp) }
    }

    @Test
    fun nextUnreadStoryTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_N, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.NextUnreadStory) }
    }

    @Test
    fun toggleReadUnreadUTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_U, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.ToggleReadUnread) }
    }

    @Test
    fun toggleReadUnreadMTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_M, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.ToggleReadUnread) }
    }

    @Test
    fun saveUnsaveStoryTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns false

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_S, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.SaveUnsaveStory) }
    }

    @Test
    fun shareStoryTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val keyEvent = mockk<KeyEvent>()
        every { keyEvent.isShiftPressed } returns true

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_S, keyEvent)
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.ShareStory) }
    }

    @Test
    fun openInBrowserOTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_O, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.OpenInBrowser) }
    }

    @Test
    fun openInBrowserVTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_V, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.OpenInBrowser) }
    }

    @Test
    fun scrollToCommentsTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_C, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.ScrollToComments) }
    }

    @Test
    fun openStoryTrainerTest() {
        val listener = mockk<KeyboardListener>()
        every { listener.onKeyboardEvent(any()) } returns Unit
        manager.addListener(listener)

        val handled = manager.onKeyUp(KeyEvent.KEYCODE_T, mockk())
        Assert.assertTrue(handled)
        verify { listener.onKeyboardEvent(KeyboardEvent.OpenStoryTrainer) }
    }
}