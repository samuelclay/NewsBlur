package com.newsblur.view

/**
 * When NewStoriesPill.kt steps aside for a reader scrolling away from it, and when it comes back.
 *
 * The first scroll away from the showing pill (down from a newest-first list's top pill, up from an
 * oldest-first list's bottom one) starts a [HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS] timer. When it runs out the
 * pill hides, whatever the reader did meanwhile, unless a tap or the stories running out got there first. The pill
 * also stays out of sight while ItemSetFragment.java's "N new stories" row is on screen.
 * Once hidden it returns after [RETURN_AFTER_IDLE_MILLIS] with no scrolling in either direction, counted from when
 * it hid or the last scroll after that, if stories are still waiting. A pill that returns starts over.
 */
class PillScrollAway(
    private val now: () -> Long,
) {
    var hiddenByScroll = false
        private set
    private var hideTimerStartedAt: Long? = null
    private var lastScrollAt = 0L
    private var hiddenAt = 0L

    /**
     * The list moved while the pill shows or is hidden by scrolling. Returns true when this movement started
     * the hide timer; NewStoriesPill.kt then checks back after [millisUntilHide].
     */
    fun onScroll(movedAway: Boolean): Boolean {
        val time = now()
        lastScrollAt = time
        if (hiddenByScroll || !movedAway || hideTimerStartedAt != null) return false
        hideTimerStartedAt = time
        return true
    }

    /** How long until the hide timer runs out; null when it isn't running. */
    fun millisUntilHide(): Long? =
        hideTimerStartedAt?.takeIf { !hiddenByScroll }?.let { maxOf(0L, it + HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS - now()) }

    /** The hide timer's check: returns true, and counts the pill as hidden, once its time is up. */
    fun hidesNow(): Boolean {
        if (millisUntilHide() != 0L) return false
        hiddenByScroll = true
        hideTimerStartedAt = null
        hiddenAt = now()
        return true
    }

    /** How long until a hidden pill may return, counted from when it hid or any scroll since; null while it shows. */
    fun millisUntilReturn(): Long? =
        if (hiddenByScroll) maxOf(0L, maxOf(lastScrollAt, hiddenAt) + RETURN_AFTER_IDLE_MILLIS - now()) else null

    /** Whether a pill hidden by scrolling comes back now, given whether stories are still waiting. */
    fun returnsNow(storiesWaiting: Boolean): Boolean {
        if (!hiddenByScroll || !storiesWaiting || millisUntilReturn() != 0L) return false
        reset()
        return true
    }

    /**
     * While stories wait, ItemSetFragment.java's list always carries an "N new stories" row at its edge, so they can
     * be added from the top of the list even after the floating pill stepped aside.
     */
    fun showsInlineRow(storiesWaiting: Boolean): Boolean = storiesWaiting

    /**
     * Whether the floating pill shows: stories wait, the scroll timer hasn't sent it away, and no part of the row is
     * on screen, so the two never double up.
     */
    fun pillShows(
        storiesWaiting: Boolean,
        rowOnScreen: Boolean,
    ): Boolean = storiesWaiting && !hiddenByScroll && !rowOnScreen

    /** A tap, another list, a reload, the stories running out, or a return start everything over. */
    fun reset() {
        hiddenByScroll = false
        hideTimerStartedAt = null
    }

    companion object {
        const val HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS = 5_000L
        const val RETURN_AFTER_IDLE_MILLIS = 180_000L

        // NewStoriesPill.kt's slide in and out from under the toolbar, with the arrival's easing.
        const val SLIDE_MILLIS = 300L
    }
}
