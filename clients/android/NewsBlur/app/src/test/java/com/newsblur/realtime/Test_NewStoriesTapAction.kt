package com.newsblur.realtime

import com.newsblur.realtime.RealtimeUpdates.NewStories
import com.newsblur.realtime.RealtimeUpdates.NewStories.Placement
import com.newsblur.realtime.RealtimeUpdates.NewStories.TapAction
import com.newsblur.util.FeedSet
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_NewStoriesTapAction {
    private val feed = FeedSet.singleFeed("1")

    // The pill and the row standing in for it share one tap (NewStoriesPill.tap): up to the cap the fetched stories
    // are added; past it, or with stories only counted, the list reloads its newest page and fills the gap.
    @Test
    fun test_tapAddsFetchedStoriesUpToTheCapAndFillsTheGapPastIt() {
        val fetched = (1..RealtimeUpdates.NEW_STORIES_CAP).map { "1:story$it" }
        assertEquals(
            TapAction.Insert(fetched, Placement.TOP),
            NewStories(feed, fetched, Placement.TOP).tapAction,
        )
        assertEquals(
            TapAction.FillGap(Placement.BOTTOM),
            NewStories(feed, fetched + "1:one-more", Placement.BOTTOM).tapAction,
        )
        assertEquals(
            TapAction.FillGap(Placement.TOP),
            NewStories(feed, listOf("1:fetched"), Placement.TOP, unfetchedCount = 1).tapAction,
        )
        assertEquals(TapAction.None, NewStories.NONE.tapAction)
    }
}
