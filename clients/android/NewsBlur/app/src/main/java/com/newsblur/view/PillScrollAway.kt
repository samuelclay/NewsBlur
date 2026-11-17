package com.newsblur.view

/**
 * When NewStoriesPill.kt steps aside for a reader scrolling away from it, and when it comes back.
 *
 * Time spent scrolling away (down from a newest-first list's top pill, up from an oldest-first list's bottom
 * one) adds up while the pill shows; each pause between scroll movements counts for at most
 * [SCROLL_GAP_CAP_MILLIS], and scrolling toward the pill adds nothing. At [HIDE_AFTER_SCROLLING_AWAY_MILLIS]
 * the pill hides. Once hidden it returns after [RETURN_AFTER_IDLE_MILLIS] with no scrolling in either
 * direction, if stories are still waiting; every scroll restarts that wait.
 */
class PillScrollAway(
    private val now: () -> Long,
) {
    var hiddenByScroll = false
        private set
    private var awayMillis = 0L
    private var lastAwayAt: Long? = null
    private var lastScrollAt = 0L

    /**
     * The list moved while the pill shows or is hidden by scrolling. Returns true when this movement hides
     * the pill.
     */
    fun onScroll(movedAway: Boolean): Boolean {
        val time = now()
        lastScrollAt = time
        if (hiddenByScroll) return false
        if (!movedAway) {
            // PillScrollAway.kt only adds the time between consecutive movements away from the pill.
            lastAwayAt = null
            return false
        }
        lastAwayAt?.let { awayMillis += minOf(time - it, SCROLL_GAP_CAP_MILLIS) }
        lastAwayAt = time
        if (awayMillis < HIDE_AFTER_SCROLLING_AWAY_MILLIS) return false
        hiddenByScroll = true
        return true
    }

    /** How long until a hidden pill may return, counted from the last scroll; null while it shows. */
    fun millisUntilReturn(): Long? =
        if (hiddenByScroll) maxOf(0L, lastScrollAt + RETURN_AFTER_IDLE_MILLIS - now()) else null

    /** Whether a pill hidden by scrolling comes back now, given whether stories are still waiting. */
    fun returnsNow(storiesWaiting: Boolean): Boolean {
        if (!hiddenByScroll || !storiesWaiting || millisUntilReturn() != 0L) return false
        reset()
        return true
    }

    /** A tap, another list, a reload, or the stories running out start the accounting over. */
    fun reset() {
        hiddenByScroll = false
        awayMillis = 0L
        lastAwayAt = null
    }

    companion object {
        const val HIDE_AFTER_SCROLLING_AWAY_MILLIS = 5_000L
        const val RETURN_AFTER_IDLE_MILLIS = 180_000L
        const val SCROLL_GAP_CAP_MILLIS = 250L

        // NewStoriesPill.kt's slide in and out from under the toolbar, with the arrival's easing.
        const val SLIDE_MILLIS = 300L
    }
}
