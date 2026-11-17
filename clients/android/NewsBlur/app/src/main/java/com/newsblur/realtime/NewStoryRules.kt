package com.newsblur.realtime

import com.newsblur.util.FeedSet
import com.newsblur.util.StoryOrder

/** Which open story lists RealtimeUpdates.kt offers new stories to, and where NewStoriesPill.kt shows them. */
internal object NewStoryRules {
    /**
     * A story from [feedId] belongs in the open list when that list is the feed itself, a folder holding
     * it, or All Site Stories. Saved, read, search, social, briefing, trending, infrequent and widget
     * lists don't take realtime stories, like the web's dashboard rivers (dashboard_river_view.js).
     */
    fun listAccepts(
        fs: FeedSet,
        feedId: String,
        subscribedFeedIds: Set<String>,
    ): Boolean =
        when {
            fs.searchQuery != null || fs.isFilterSaved || fs.isForWidget -> false
            fs.singleFeed != null -> fs.singleFeed == feedId
            fs.multipleFeeds != null -> fs.multipleFeeds.contains(feedId)
            fs.isAllNormal -> feedId in subscribedFeedIds
            else -> false
        }

    /**
     * Newest-first lists show the pill at the top. Oldest-first lists only show it once their last page
     * has loaded: until then pagination brings the new stories in at the end on its own.
     */
    fun placement(
        order: StoryOrder,
        lastPageLoaded: Boolean,
    ): RealtimeUpdates.NewStories.Placement? =
        when (order) {
            StoryOrder.NEWEST -> RealtimeUpdates.NewStories.Placement.TOP
            StoryOrder.OLDEST -> if (lastPageLoaded) RealtimeUpdates.NewStories.Placement.BOTTOM else null
        }
}
