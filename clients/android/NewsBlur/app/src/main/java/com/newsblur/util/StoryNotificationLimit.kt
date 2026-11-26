package com.newsblur.util

/**
 * StoryNotificationLimit.kt: NotificationUtils.java shows a handful of story notifications at most. The background
 * sync enforces that by walking its own list of stories; a pushed story arrives alone, so it has to make room among
 * the notifications already showing.
 */
object StoryNotificationLimit {
    data class Showing(
        val id: Int,
        val storyTime: Long,
        val storyHash: String,
    )

    /** The notifications to dismiss, oldest story first, so that one more fits under [limit]. */
    @JvmStatic
    fun toDismissForOneMore(
        showing: List<Showing>,
        limit: Int,
    ): List<Showing> = showing.sortedBy { it.storyTime }.take((showing.size - limit + 1).coerceAtLeast(0))
}
