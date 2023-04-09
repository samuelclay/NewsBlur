package com.newsblur.keyboard

interface KeyboardListener {

    fun onKeyboardEvent(event: KeyboardEvent)
}

sealed class KeyboardEvent {

    /**
     * Keyboard events for Home
     */
    object OpenAllStories : KeyboardEvent()
    object AddFeed : KeyboardEvent()
    object SwitchViewRight : KeyboardEvent()
    object SwitchViewLeft : KeyboardEvent()

    /**
     * Keyboard events for Reading
     */
    object NextStory : KeyboardEvent()
    object PreviousStory : KeyboardEvent()
    object ToggleTextView : KeyboardEvent()
    object NextUnreadStory : KeyboardEvent()
    object ToggleReadUnread : KeyboardEvent()
    object SaveUnsaveStory : KeyboardEvent()
    object OpenInBrowser : KeyboardEvent()
    object ShareStory : KeyboardEvent()
    object ScrollToComments : KeyboardEvent()
    object OpenStoryTrainer : KeyboardEvent()
    object PageDown: KeyboardEvent()
    object PageUp: KeyboardEvent()

   object Tutorial: KeyboardEvent()
}
