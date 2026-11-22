package com.newsblur.realtime

/**
 * Coalesces realtime count refreshes into one /reader/feed_unread_count request (RealtimeUpdates.kt).
 * Each API id keeps its earliest due time; a flush takes every id due within [windowMillis] of now,
 * so a burst of feed:update jitters lands in one request instead of one per feed.
 */
class UnreadCountBatcher(
    private val windowMillis: Long = 1_000L,
) {
    private val dueAt = LinkedHashMap<String, Long>()

    @Synchronized
    fun add(
        apiIds: Collection<String>,
        due: Long,
    ) {
        for (id in apiIds) {
            val current = dueAt[id]
            if (current == null || due < current) dueAt[id] = due
        }
    }

    @Synchronized
    fun nextDueAt(): Long? = dueAt.values.minOrNull()

    @Synchronized
    fun takeDue(now: Long): Set<String> {
        val cutoff = now + windowMillis
        val taken = dueAt.filterValues { it <= cutoff }.keys.toSet()
        taken.forEach(dueAt::remove)
        return taken
    }

    @Synchronized
    fun clear() = dueAt.clear()
}
