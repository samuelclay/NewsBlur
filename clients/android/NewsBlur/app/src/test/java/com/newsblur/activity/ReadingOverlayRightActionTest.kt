package com.newsblur.activity

import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingOverlayRightActionTest {
    @Test
    fun nextUnreadKeepsTraversalInReader() {
        assertEquals(
            OverlayRightAction.NEXT_UNREAD,
            resolveOverlayRightAction(unreadCount = 3, isTaskRoot = false, hasReadingLaunchParent = true),
        )
    }

    @Test
    fun doneAnimatesToFeedListWhenStoryListParentExists() {
        assertEquals(
            OverlayRightAction.ANIMATE_TO_FEED_LIST,
            resolveOverlayRightAction(unreadCount = 0, isTaskRoot = false, hasReadingLaunchParent = true),
        )
    }

    @Test
    fun doneReturnsToMainWhenReaderIsTaskRoot() {
        assertEquals(
            OverlayRightAction.RETURN_TO_MAIN,
            resolveOverlayRightAction(unreadCount = 0, isTaskRoot = true, hasReadingLaunchParent = false),
        )
    }

    @Test
    fun doneFallsBackToReaderFinishWithoutTaskRootOrStoryListParent() {
        assertEquals(
            OverlayRightAction.FINISH_READING,
            resolveOverlayRightAction(unreadCount = 0, isTaskRoot = false, hasReadingLaunchParent = false),
        )
    }
}
