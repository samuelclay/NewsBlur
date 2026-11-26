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

    /**
     * The stories to dismiss, oldest first, so that [showing] and the [incoming] story fit under [limit]. The
     * incoming story is a candidate too: an old story must not take the place of a newer one, which is the same
     * newest-first rule NotificationUtils.java applies in the background sync.
     */
    @JvmStatic
    fun toDismiss(
        showing: List<Showing>,
        incoming: Showing,
        limit: Int,
    ): List<Showing> = (showing + incoming).sortedBy { it.storyTime }.take((showing.size + 1 - limit).coerceAtLeast(0))
}
