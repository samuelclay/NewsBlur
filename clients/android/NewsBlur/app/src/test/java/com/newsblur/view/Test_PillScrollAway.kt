package com.newsblur.view

import com.newsblur.view.PillScrollAway.Companion.HIDE_AFTER_SCROLLING_AWAY_MILLIS
import com.newsblur.view.PillScrollAway.Companion.RETURN_AFTER_IDLE_MILLIS
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_PillScrollAway {
    private var clock = 1_000_000L
    private val scrollAway = PillScrollAway { clock }

    private fun scrollAwayFor(
        millis: Long,
        every: Long,
    ): Boolean {
        var hid = false
        val end = clock + millis
        while (clock <= end) {
            hid = scrollAway.onScroll(movedAway = true) || hid
            clock += every
        }
        return hid
    }

    // Five seconds of scrolling away hides the pill, but reading pauses between flicks must not add up to it.
    @Test
    fun test_onlyTimeSpentScrollingAwayCountsWithPausesCappedAtAQuarterSecond() {
        assertFalse("4s of steady scrolling", scrollAwayFor(4_000, every = 16))
        // Flicks a minute apart add 250ms each, not minutes: four more reach five seconds.
        clock += 60_000
        scrollAway.onScroll(movedAway = true)
        assertFalse(scrollAway.hiddenByScroll)
        repeat(3) {
            clock += 60_000
            scrollAway.onScroll(movedAway = true)
        }
        assertTrue(scrollAway.hiddenByScroll)
    }

    // Scrolling back toward the pill is the reader heading for it, so it never counts toward hiding it.
    @Test
    fun test_scrollingTowardThePillAddsNothing() {
        repeat(400) {
            scrollAway.onScroll(movedAway = true)
            clock += 16
            scrollAway.onScroll(movedAway = false)
            clock += 16
        }
        assertFalse(scrollAway.hiddenByScroll)
    }

    // A hidden pill returns only after three idle minutes, every scroll restarts the wait, and it needs stories.
    @Test
    fun test_hiddenPillReturnsAfterThreeIdleMinutesWithStoriesWaiting() {
        scrollAwayFor(HIDE_AFTER_SCROLLING_AWAY_MILLIS + 100, every = 16)
        assertTrue(scrollAway.hiddenByScroll)

        clock += RETURN_AFTER_IDLE_MILLIS - 1_000
        assertFalse(scrollAway.returnsNow(storiesWaiting = true))
        scrollAway.onScroll(movedAway = false)
        clock += RETURN_AFTER_IDLE_MILLIS - 1
        assertFalse("a scroll restarted the wait", scrollAway.returnsNow(storiesWaiting = true))
        assertEquals(1L, scrollAway.millisUntilReturn())

        clock += 1
        assertFalse("nothing waiting", scrollAway.returnsNow(storiesWaiting = false))
        assertTrue(scrollAway.returnsNow(storiesWaiting = true))
        assertFalse(scrollAway.hiddenByScroll)
        assertFalse("the count starts over once it's back", scrollAway.onScroll(movedAway = true))
    }
}
