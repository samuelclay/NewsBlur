package com.newsblur.activity

import com.newsblur.util.FeedSet
import com.newsblur.util.Session
import com.newsblur.util.SessionDataSource
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.Test

class Test_ItemsListMarkReadNavigation {
    @Test
    fun test_mark_read_with_tablet_feed_pane_open_keeps_app_foreground() {
        mockkObject(FeedListDrawer.Companion)
        try {
            val activity = mockk<ItemsList>(relaxed = true)
            val drawer = mockk<FeedListDrawer>(relaxed = true)
            every { activity.taskId } returns 123
            every { activity.slidesOverFeedDrawer() } returns true
            every { FeedListDrawer.peek(123) } returns drawer
            every { FeedListDrawer.open(activity) } returns Unit
            every { activity.onReadingActionCompleted() } answers { callOriginal() }
            every { activity.backToFeedList() } answers { callOriginal() }

            // ItemsList.java receives the same completion from the toolbar and menu actions.
            activity.onReadingActionCompleted()

            verify(exactly = 1) { FeedListDrawer.open(activity) }
            verify(exactly = 0) { activity.moveTaskToBack(any()) }
            verify(exactly = 0) { activity.finish() }
        } finally {
            unmockkObject(FeedListDrawer.Companion)
        }
    }

    @Test
    fun test_mark_read_after_last_session_opens_closed_tablet_feed_pane() {
        mockkObject(FeedListDrawer.Companion)
        try {
            val activity = mockk<ItemsList>(relaxed = true)
            val sessions = mockk<SessionDataSource>()
            every { sessions.getNextSession() } returns null
            setSessions(activity, sessions)
            every { activity.slidesOverFeedDrawer() } returns true
            every { FeedListDrawer.open(activity) } returns Unit
            every { activity.onReadingActionCompleted() } answers { callOriginal() }

            activity.onReadingActionCompleted()

            verify(exactly = 1) { FeedListDrawer.open(activity) }
            verify(exactly = 0) { activity.moveTaskToBack(any()) }
            verify(exactly = 0) { activity.finish() }
        } finally {
            unmockkObject(FeedListDrawer.Companion)
        }
    }

    @Test
    fun test_mark_read_on_phone_returns_to_the_feed_list() {
        val activity = mockk<ItemsList>(relaxed = true)
        every { activity.slidesOverFeedDrawer() } returns false
        every { activity.onReadingActionCompleted() } answers { callOriginal() }

        activity.onReadingActionCompleted()

        verify(exactly = 1) { activity.finish() }
        verify(exactly = 0) { activity.moveTaskToBack(any()) }
    }

    @Test
    fun test_mark_read_with_next_session_continues_reading() {
        val activity = mockk<ItemsList>(relaxed = true)
        val next = Session(FeedSet.singleFeed("2"))
        val sessions = mockk<SessionDataSource>()
        every { sessions.getNextSession() } returns next
        setSessions(activity, sessions)
        every { activity.onReadingActionCompleted() } answers { callOriginal() }

        activity.onReadingActionCompleted()

        verify(exactly = 1) { activity["applyNextSession"](next) }
        verify(exactly = 0) { activity.finish() }
        verify(exactly = 0) { activity.moveTaskToBack(any()) }
    }

    @Test
    fun test_explicit_back_with_tablet_feed_pane_open_still_leaves_app() {
        mockkObject(FeedListDrawer.Companion)
        try {
            val activity = mockk<ItemsList>(relaxed = true)
            every { activity.slidesOverFeedDrawer() } returns true
            every { FeedListDrawer.peek(activity.taskId) } returns mockk(relaxed = true)
            every { activity.backToFeedList() } answers { callOriginal() }

            activity.backToFeedList()

            verify(exactly = 1) { activity.moveTaskToBack(true) }
            verify(exactly = 0) { activity.finish() }
        } finally {
            unmockkObject(FeedListDrawer.Companion)
        }
    }

    private fun setSessions(activity: ItemsList, sessions: SessionDataSource) {
        // ItemsList.java normally receives this session source from its launch intent.
        ItemsList::class.java.getDeclaredField("sessionDataSource").apply {
            isAccessible = true
            set(activity, sessions)
        }
    }
}
