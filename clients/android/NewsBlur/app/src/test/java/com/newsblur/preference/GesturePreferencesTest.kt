package com.newsblur.preference

import android.content.SharedPreferences
import com.newsblur.util.GestureAction
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Test

class GesturePreferencesTest {
    private val preferences =
        mockk<SharedPreferences> {
            every { getString(any(), any()) } answers { secondArg() }
            every { getBoolean(any(), any()) } answers { secondArg() }
        }
    private val repo = PrefsRepo(preferences, mockk(relaxed = true))

    @Test fun existingAndroidSwipeChoicesSurvive() {
        every { preferences.getString(PrefConstants.RTL_GESTURE_ACTION, any()) } returns GestureAction.GEST_ACTION_UNSAVE.name
        assertEquals(GestureAction.GEST_ACTION_UNSAVE, repo.getRightToLeftGestureAction())
        assertEquals(GestureAction.GEST_ACTION_BACK, repo.getLeftToRightGestureAction())
    }

    @Test fun unknownValuesFallBackWithoutCrashing() {
        every { preferences.getString(PrefConstants.LTR_GESTURE_ACTION, any()) } returns "obsolete"
        assertEquals(GestureAction.GEST_ACTION_BACK, repo.getLeftToRightGestureAction())
    }

    @Test fun swipeTogglesAreIndependentAndDoNotDisableLongPress() {
        every { preferences.getBoolean("enable_story_swipes", any()) } returns false
        assertFalse(repo.isStorySwipesEnabled())
        assertTrue(repo.isFeedSwipesEnabled())
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getStoryLongPressAction())
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getFeedLongPressAction())
    }

    @Test fun explicitStoryLongPressChoiceSurvivesDefaultChange() {
        every { preferences.getString("story_long_press", any()) } returns GestureAction.GEST_ACTION_ASK_AI.name
        assertEquals(GestureAction.GEST_ACTION_ASK_AI, repo.getStoryLongPressAction())
    }

    @Test fun defaultStoryLongPressRestoresOlderAndNewerReadMenu() {
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getStoryLongPressAction())
    }

    @Test fun explicitlySelectedShareStillOpensShare() {
        every { preferences.getString("story_long_press", any()) } returns GestureAction.GEST_ACTION_SHARE.name
        assertEquals(GestureAction.GEST_ACTION_SHARE, repo.getStoryLongPressAction())
    }

    @Test fun unknownStoryLongPressChoiceFallsBackToMenu() {
        every { preferences.getString("story_long_press", any()) } returns "obsolete"
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getStoryLongPressAction())
    }
    @Test fun defaultFeedLongPressOpensFullMenu() {
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getFeedLongPressAction())
    }

    @Test fun explicitlySelectedFeedReadRangeSurvivesDefaultChange() {
        every { preferences.getString("feed_long_press", any()) } returns GestureAction.GEST_ACTION_READ_RANGE.name
        assertEquals(GestureAction.GEST_ACTION_READ_RANGE, repo.getFeedLongPressAction())
    }

    @Test fun unknownFeedLongPressChoiceFallsBackToMenu() {
        every { preferences.getString("feed_long_press", any()) } returns "obsolete"
        assertEquals(GestureAction.GEST_ACTION_MENU, repo.getFeedLongPressAction())
    }

}
