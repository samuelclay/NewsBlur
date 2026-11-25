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
     * What a tap past the cap shows: the [count] newest-dated stories of everything waiting (the oldest-dated, for an
     * oldest-first list), in the list's order, as if the list loaded right then. [waiting] maps each story to its
     * date in seconds, so a story announced again is still one story.
     */
    fun pickForTap(
        waiting: Map<String, Long>,
        count: Int,
        newestFirst: Boolean,
    ): List<String> {
        val byDate = compareBy<Map.Entry<String, Long>> { it.value }.thenBy { it.key }
        return waiting.entries.sortedWith(if (newestFirst) byDate.reversed() else byDate).take(count).map { it.key }
    }

    /**
     * Whether a story dated [seconds] belongs among the [cap] stories RealtimeUpdates.kt keeps loaded for the tap: always
     * while there's room, and past it only when it's newer than the oldest of the [held] dates (older than the newest,
     * for an oldest-first list). A same-dated story is only counted, so arrivals never displace each other back and forth.
     */
    fun belongsAmongLoaded(
        seconds: Long,
        held: Collection<Long>,
        cap: Int,
        newestFirst: Boolean,
    ): Boolean {
        if (held.size < cap) return true
        val edge = (if (newestFirst) held.sortedDescending() else held.sorted())[cap - 1]
        return if (newestFirst) seconds > edge else seconds < edge
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
