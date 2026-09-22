package com.newsblur.toolbar

import com.newsblur.util.StoryLoadingState
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.PrefConstants.ThemeValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryLoadingState {
    @Test fun test_empty_list_shows_initial_loading_until_response_arrives() {
        assertEquals(StoryLoadingState.INITIAL, StoryLoadingState.resolve(false, false, false, false, true))
        assertEquals(StoryLoadingState.INITIAL, StoryLoadingState.resolve(false, true, true, false, true))
    }

    @Test fun test_pagination_loads_at_the_end_of_existing_stories() {
        assertEquals(StoryLoadingState.NEXT_PAGE, StoryLoadingState.resolve(true, true, true, false, true))
        assertEquals(StoryLoadingState.NONE, StoryLoadingState.resolve(true, true, false, false, true))
    }

    @Test fun test_empty_and_finished_responses_stop_loading() {
        assertEquals(StoryLoadingState.NONE, StoryLoadingState.resolve(false, true, false, true, true))
        assertEquals(StoryLoadingState.NONE, StoryLoadingState.resolve(true, true, true, true, true))
    }

    @Test fun test_offline_lists_never_pulse() {
        assertEquals(StoryLoadingState.NONE, StoryLoadingState.resolve(false, false, true, false, false))
        assertEquals(StoryLoadingState.NONE, StoryLoadingState.resolve(true, true, true, false, false))
    }

    @Test fun test_all_themes_have_distinct_blue_pulse_endpoints() {
        for (theme in ThemeValue.entries) {
            val low = ReaderSheetPalette.loadingLowArgb(theme)
            val high = ReaderSheetPalette.loadingHighArgb(theme)
            assertNotEquals(low, high)
            assertEquals(255, high ushr 24)
            org.junit.Assert.assertTrue((high and 255) > ((high shr 16) and 255))
        }
    }
}
