package com.newsblur.view

import com.newsblur.view.PillScrollAway.Companion.HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS
import com.newsblur.view.PillScrollAway.Companion.RETURN_AFTER_IDLE_MILLIS
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_PillScrollAway {
    private var clock = 1_000_000L
    private val scrollAway = PillScrollAway { clock }

    // Sam: the first scroll away starts five seconds; untapped by then, the pill goes, whatever the reader did in
    // between. Later scrolling, stopping, or scrolling back must not restart or cancel that timer.
    @Test
    fun test_firstScrollAwayHidesThePillFiveSecondsLaterWhateverHappensMeanwhile() {
        assertTrue("the first scroll away starts the timer", scrollAway.onScroll(movedAway = true))
        assertEquals(HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS, scrollAway.millisUntilHide())

        clock += 1_000
        assertFalse("later scrolls don't restart it", scrollAway.onScroll(movedAway = true))
        clock += 1_000
        scrollAway.onScroll(movedAway = false)
        clock += HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS - 2_001
        assertFalse(scrollAway.hidesNow())

        clock += 1
        assertTrue(scrollAway.hidesNow())
        assertTrue(scrollAway.hiddenByScroll)
    }

    // Scrolling toward the pill is the reader heading for it, and a tap means they used it: neither hides it.
    @Test
    fun test_scrollingTowardThePillOrTappingItLeavesItShowing() {
        scrollAway.onScroll(movedAway = false)
        assertNull(scrollAway.millisUntilHide())

        scrollAway.onScroll(movedAway = true)
        scrollAway.reset()
        clock += HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS
        assertFalse(scrollAway.hidesNow())
        assertFalse(scrollAway.hiddenByScroll)
    }

    // A hidden pill returns only after three idle minutes, every scroll restarts the wait, it needs stories, and
    // once back the next scroll away starts a fresh five seconds.
    @Test
    fun test_hiddenPillReturnsAfterThreeIdleMinutesAndStartsOver() {
        scrollAway.onScroll(movedAway = true)
        clock += HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS
        assertTrue(scrollAway.hidesNow())

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
        assertTrue("a fresh timer once it's back", scrollAway.onScroll(movedAway = true))
        assertEquals(HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS, scrollAway.millisUntilHide())
    }

    // Sam expects a "New stories" button at the top of the list whenever stories wait, whether the floating pill is
    // showing or the scroll timer sent it away.
    @Test
    fun test_inlineRowShowsWheneverStoriesWait() {
        assertTrue("pill showing", scrollAway.showsInlineRow(storiesWaiting = true))

        scrollAway.onScroll(movedAway = true)
        clock += HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS
        scrollAway.hidesNow()
        assertTrue("pill hidden by the timer", scrollAway.showsInlineRow(storiesWaiting = true))
        assertFalse("nothing waiting", scrollAway.showsInlineRow(storiesWaiting = false))
    }

    // The pill and the row must never double up: the pill shows only while no part of the row is on screen, and a
    // pill sent away by the timer stays away even when the row scrolls off.
    @Test
    fun test_pillStaysHiddenWhileTheRowIsOnScreen() {
        assertFalse(scrollAway.pillShows(storiesWaiting = true, rowOnScreen = true))
        assertTrue(scrollAway.pillShows(storiesWaiting = true, rowOnScreen = false))
        assertFalse("nothing waiting", scrollAway.pillShows(storiesWaiting = false, rowOnScreen = false))

        scrollAway.onScroll(movedAway = true)
        clock += HIDE_AFTER_FIRST_SCROLL_AWAY_MILLIS
        scrollAway.hidesNow()
        assertFalse("sent away by the timer", scrollAway.pillShows(storiesWaiting = true, rowOnScreen = false))

        clock += RETURN_AFTER_IDLE_MILLIS
        scrollAway.returnsNow(storiesWaiting = true)
        assertTrue("back after the idle wait", scrollAway.pillShows(storiesWaiting = true, rowOnScreen = false))
        assertFalse("still makes way for the row", scrollAway.pillShows(storiesWaiting = true, rowOnScreen = true))
    }
}
