package com.newsblur.preference

import android.content.SharedPreferences
import com.newsblur.util.MarkStoryReadBehavior
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Test

class MarkReadModePreferencesTest {
    private val values = mutableMapOf<String, Any>()
    private val editor = mockk<SharedPreferences.Editor>(relaxed = true).apply {
        every { putString(any(), any()) } answers { values[firstArg()] = secondArg<String>(); this@apply }
        every { putBoolean(any(), any()) } answers { values[firstArg()] = secondArg<Boolean>(); this@apply }
    }
    private val preferences = mockk<SharedPreferences> {
        every { getString(any(), any()) } answers { values[firstArg()] as? String ?: secondArg() }
        every { getBoolean(any(), any()) } answers { values[firstArg()] as? Boolean ?: secondArg() }
        every { edit() } returns editor
    }
    private val repo = PrefsRepo(preferences, mockk(relaxed = true))

    @Test fun existingSelectionOnlyDefaultIsPreserved() {
        assertEquals(MarkStoryReadBehavior.IMMEDIATELY, repo.getMarkStoryReadBehavior())
        assertFalse(repo.isMarkReadOnFeedScroll())
    }

    @Test fun legacyScrollChoiceBecomesCombinedScrollAndSelection() {
        values[PrefConstants.STORIES_MARK_READ_ON_SCROLL] = true
        assertEquals(MarkStoryReadBehavior.ON_SCROLL, repo.getMarkStoryReadBehavior())
        assertTrue(repo.isMarkReadOnFeedScroll())
    }

    @Test fun explicitLegacyDelayAndManualChoicesAreNotOverriddenByOldScrollFlag() {
        values[PrefConstants.STORIES_MARK_READ_ON_SCROLL] = true
        for (mode in listOf(MarkStoryReadBehavior.SECONDS_20, MarkStoryReadBehavior.SECONDS_45, MarkStoryReadBehavior.MANUALLY)) {
            values[PrefConstants.STORY_MARK_READ_BEHAVIOR] = mode.name
            assertEquals(mode, repo.getMarkStoryReadBehavior())
            assertFalse(repo.isMarkReadOnFeedScroll())
        }
    }

    @Test fun choosingAnyModeReplacesBothPreviousSettings() {
        for (previous in MarkStoryReadBehavior.entries) {
            for (next in MarkStoryReadBehavior.options()) {
                repo.setMarkStoryReadBehavior(previous)
                repo.setMarkStoryReadBehavior(next)
                assertEquals(next, repo.getMarkStoryReadBehavior())
                assertEquals(next == MarkStoryReadBehavior.ON_SCROLL, repo.isMarkReadOnFeedScroll())
                assertEquals(next == MarkStoryReadBehavior.ON_SCROLL, values[PrefConstants.STORIES_MARK_READ_ON_SCROLL])
            }
        }
    }

    @Test fun unknownSavedModesDoNotCrashPreferencesOrReader() {
        values[PrefConstants.STORY_MARK_READ_BEHAVIOR] = "obsolete"
        assertEquals(MarkStoryReadBehavior.IMMEDIATELY, repo.getMarkStoryReadBehavior())
    }
}
