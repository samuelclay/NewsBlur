package com.newsblur.realtime

/**
 * Where ItemSetFragment.java's gap row goes while a gap stream (SyncServiceState.restartPagingKeepingStories)
 * fills in a list. Pages merge into the reading session by date, so the stream's insertion cursor is the
 * latest page's last story that the list shows: stories above it are covered, stories below it are the ones
 * listed before the stream that it hasn't reached yet.
 */
object GapStreamCursor {
    sealed interface Gap {
        /** No page yet, or none of the latest page is listed. */
        data object None : Gap

        /** The stream reached the last story listed: paging carries on at the end as usual. */
        data object Closed : Gap

        /** The gap row sits after this story. */
        data class After(
            val storyHash: String,
        ) : Gap
    }

    fun gap(
        latestPage: List<String>,
        listed: List<String>,
        pinned: Set<String>,
    ): Gap {
        // GapStreamCursor.kt measures the end without the pill's pinned stories, which sit at the list's edge.
        val lastListed = listed.indexOfLast { it !in pinned }
        val positions = HashMap<String, Int>(listed.size)
        listed.forEachIndexed { index, hash -> positions[hash] = index }
        for (hash in latestPage.asReversed()) {
            if (hash in pinned) continue
            val position = positions[hash] ?: continue
            return if (position >= lastListed) Gap.Closed else Gap.After(hash)
        }
        return Gap.None
    }
}
