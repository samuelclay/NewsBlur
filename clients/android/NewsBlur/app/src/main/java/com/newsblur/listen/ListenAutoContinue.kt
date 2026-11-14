package com.newsblur.listen

import com.newsblur.domain.Story

/**
 * ListenAutoContinue.kt picks the stories Listen goes on to when one finishes, from the list it was started in
 * (ListenManager.kt's continueAfter). A feed or folder continues with the unread stories after the current one.
 * Saved Stories and Read Stories hold nothing but read stories, so they follow the list's own order instead, as
 * sorted on screen (Reading.kt's listenFollowsListOrder). Neither ever wraps around to the stories before the
 * current one.
 */
object ListenAutoContinue {
    /**
     * The next [limit] stories after the current one, in list order. A story played from Up Next may not be in
     * the list, so the list continues after [continueFromHash], the last story that was. Read states and Up Next
     * are asked for lazily, only for the stories considered, since [isRead] reads the database.
     */
    fun candidatesAfter(
        stories: List<Story>,
        currentHash: String,
        continueFromHash: String?,
        followsListOrder: Boolean,
        limit: Int,
        isRead: (Story) -> Boolean,
        isQueued: (String) -> Boolean,
    ): List<Story> {
        val anchor = currentHash.takeIf { hash -> stories.any { it.storyHash == hash } } ?: continueFromHash
        val index = stories.indexOfFirst { it.storyHash == anchor }
        if (index < 0) return emptyList()
        return stories
            .asSequence()
            .drop(index + 1)
            .filter { candidate ->
                candidate.storyHash != currentHash &&
                    (followsListOrder || !isRead(candidate)) &&
                    // Stories already in Up Next play from there, so they aren't listed twice.
                    !isQueued(candidate.storyHash)
            }.take(limit)
            .toList()
    }
}
