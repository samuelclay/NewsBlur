package com.newsblur.realtime

import com.newsblur.realtime.GapStreamCursor.Gap
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_GapStreamCursor {
    private val listed = listOf("new1", "new2", "new3", "old1", "old2", "old3")

    // The newest page slid in above the stories listed before: the gap row belongs between the two blocks,
    // after the page's last story, so the reader can see where stories are still missing.
    @Test
    fun test_gapSitsAfterTheLatestPagesLastListedStory() {
        assertEquals(Gap.After("new3"), GapStreamCursor.gap(listOf("new1", "new2", "new3"), listed, emptySet()))
    }

    // A page's last stories can be hidden by the list's filter; the cursor is the last one the list shows,
    // never a story that isn't there.
    @Test
    fun test_storiesTheListDoesNotShowDoNotMoveTheCursor() {
        assertEquals(Gap.After("new2"), GapStreamCursor.gap(listOf("new1", "new2", "hidden"), listed, emptySet()))
        assertEquals(Gap.None, GapStreamCursor.gap(listOf("hidden"), listed, emptySet()))
    }

    // Pages that only cover stories listed before advance the cursor through them; when it reaches the last
    // listed story the gap is closed and the usual paging appends at the end.
    @Test
    fun test_gapClosesOnlyWhenTheStreamReachesTheLastListedStory() {
        assertEquals(Gap.After("old2"), GapStreamCursor.gap(listOf("old1", "old2"), listed, emptySet()))
        assertEquals(Gap.Closed, GapStreamCursor.gap(listOf("old2", "old3"), listed, emptySet()))
    }

    // A page the list's filter hides entirely (Focus, or stories the reader's classifiers hide) lists nothing; the gap
    // row must stay where it was so it can still ask for the page after it.
    @Test
    fun test_aPageTheFilterHidesEntirelyKeepsTheGapWhereItWas() {
        assertEquals(Gap.After("new3"), GapStreamCursor.gap(listOf("hidden1", "hidden2"), listed, emptySet(), previousAnchor = "new3"))
        assertEquals(Gap.None, GapStreamCursor.gap(listOf("hidden1"), listed, emptySet()))
    }

    // An oldest-first list keeps the pill's pinned stories at its end; they mustn't hold the gap open, or count
    // as the stream's cursor.
    @Test
    fun test_pinnedStoriesAtTheEndAreNotTheEndOfTheList() {
        val oldestFirst = listOf("old1", "old2", "old3", "pinned")
        assertEquals(Gap.Closed, GapStreamCursor.gap(listOf("old3"), oldestFirst, setOf("pinned")))
        assertEquals(Gap.After("old2"), GapStreamCursor.gap(listOf("old2", "pinned"), oldestFirst, setOf("pinned")))
    }
}
