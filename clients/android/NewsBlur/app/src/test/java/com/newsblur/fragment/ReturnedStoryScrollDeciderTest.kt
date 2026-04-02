package com.newsblur.fragment

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReturnedStoryScrollDeciderTest {
    @Test
    fun visibleReturnedStoryDoesNotScroll() {
        assertFalse(ReturnedStoryScrollDecider.shouldScrollToReturnedStory(8, 4, 10))
    }

    @Test
    fun offscreenReturnedStoryScrolls() {
        assertTrue(ReturnedStoryScrollDecider.shouldScrollToReturnedStory(12, 4, 10))
    }

    @Test
    fun missingReturnedStoryDoesNotScroll() {
        assertFalse(ReturnedStoryScrollDecider.shouldScrollToReturnedStory(-1, 4, 10))
    }
}
