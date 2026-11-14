package com.newsblur.view

import com.newsblur.util.GestureAction
import com.newsblur.util.GestureSwipeAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GestureSwipeActionTest {
    @Test fun readToggleOffersTheDestinationState() {
        val unread = GestureSwipeAction.resolve(GestureAction.GEST_ACTION_TOGGLE_READ, isRead = false)!!
        val read = GestureSwipeAction.resolve(GestureAction.GEST_ACTION_TOGGLE_READ, isRead = true)!!
        assertEquals(GestureAction.GEST_ACTION_MARKREAD, unread.action)
        assertEquals(GestureAction.GEST_ACTION_MARKUNREAD, read.action)
        assertNotEquals(unread.iconRes, read.iconRes)
    }

    @Test fun saveToggleOffersTheDestinationState() {
        val unsaved = GestureSwipeAction.resolve(GestureAction.GEST_ACTION_TOGGLE_SAVE, isSaved = false)!!
        val saved = GestureSwipeAction.resolve(GestureAction.GEST_ACTION_TOGGLE_SAVE, isSaved = true)!!
        assertEquals(GestureAction.GEST_ACTION_SAVE, unsaved.action)
        assertEquals(GestureAction.GEST_ACTION_UNSAVE, saved.action)
        assertNotEquals(unsaved.iconRes, saved.iconRes)
    }

    @Test fun explicitActionsDoNotInvertWithStoryState() {
        listOf(
            GestureAction.GEST_ACTION_MARKREAD,
            GestureAction.GEST_ACTION_MARKUNREAD,
            GestureAction.GEST_ACTION_SAVE,
            GestureAction.GEST_ACTION_UNSAVE,
        ).forEach { action ->
            assertEquals(action, GestureSwipeAction.resolve(action, isRead = true, isSaved = true)!!.action)
            assertEquals(action, GestureSwipeAction.resolve(action, isRead = false, isSaved = false)!!.action)
        }
    }

    @Test fun everyEnabledActionHasAnIconAndConcreteAction() {
        GestureAction.values().filter { it != GestureAction.GEST_ACTION_NONE }.forEach { action ->
            val presentation = GestureSwipeAction.resolve(action)!!
            assertNotEquals("Missing icon for $action", 0, presentation.iconRes)
            assertNotEquals(GestureAction.GEST_ACTION_TOGGLE_READ, presentation.action)
            assertNotEquals(GestureAction.GEST_ACTION_TOGGLE_SAVE, presentation.action)
        }
    }

    @Test fun disabledGestureDoesNotRevealAnAction() {
        assertNull(GestureSwipeAction.resolve(GestureAction.GEST_ACTION_NONE))
    }
}
