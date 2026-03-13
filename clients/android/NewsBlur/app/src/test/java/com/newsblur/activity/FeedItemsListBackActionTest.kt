package com.newsblur.activity

import org.junit.Assert.assertEquals
import org.junit.Test

class FeedItemsListBackActionTest {
    @Test
    fun swipeBackBypassesReviewInterceptionWhenReviewInfoIsAvailable() {
        assertEquals(
            FeedItemsBackAction.FINISH_STORY_LIST,
            resolveFeedItemsBackAction(hasReviewInfo = true, isGestureNavigation = true),
        )
    }

    @Test
    fun buttonBackLaunchesReviewWhenReviewInfoIsAvailable() {
        assertEquals(
            FeedItemsBackAction.LAUNCH_REVIEW,
            resolveFeedItemsBackAction(hasReviewInfo = true, isGestureNavigation = false),
        )
    }

    @Test
    fun backFinishesNormallyWhenNoReviewInfoIsAvailable() {
        assertEquals(
            FeedItemsBackAction.FINISH_STORY_LIST,
            resolveFeedItemsBackAction(hasReviewInfo = false, isGestureNavigation = false),
        )
    }
}
