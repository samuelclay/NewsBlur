package com.newsblur.util

import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class CursorFiltersTargetStoryTest {
    @Test
    fun feed_set_filter_overrides_are_used_for_target_story_navigation() {
        val prefsRepo = mockk<PrefsRepo>()
        every { prefsRepo.getStateFilter() } returns StateFilter.BEST
        every { prefsRepo.getReadFilter(any()) } returns ReadFilter.UNREAD
        every { prefsRepo.getStoryOrder(any()) } returns StoryOrder.NEWEST

        val feedSet =
            FeedSet.singleFeed("42").apply {
                stateFilterOverride = StateFilter.ALL
                readFilterOverride = ReadFilter.ALL
            }

        val cursorFilters = CursorFilters(prefsRepo, feedSet)

        assertEquals(StateFilter.ALL, cursorFilters.stateFilter)
        assertEquals(ReadFilter.ALL, cursorFilters.readFilter)
        assertEquals(StoryOrder.NEWEST, cursorFilters.storyOrder)
    }
}
