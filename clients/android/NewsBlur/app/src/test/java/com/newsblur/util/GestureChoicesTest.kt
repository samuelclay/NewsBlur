package com.newsblur.util

import org.junit.Assert.assertTrue
import org.junit.Test

class GestureChoicesTest {
    @Test fun longPressOffersSavingAndUnsavingTheSelectedStory() {
        assertTrue("Long press should offer the same save/unsave toggle as story swipes",
            GestureChoices.storyLongPress.contains(GestureAction.GEST_ACTION_TOGGLE_SAVE))
    }

    @Test fun existingLongPressSelectionsRemainAvailable() {
        assertTrue(GestureChoices.storyLongPress.containsAll(listOf(
            GestureAction.GEST_ACTION_SAVE,
            GestureAction.GEST_ACTION_SHARE,
            GestureAction.GEST_ACTION_MENU,
        )))
    }
}
