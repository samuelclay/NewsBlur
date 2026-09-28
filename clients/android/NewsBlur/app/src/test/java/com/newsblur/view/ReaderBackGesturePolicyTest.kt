package com.newsblur.view

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReaderBackGesturePolicyTest {
    @Test
    fun threeButtonNavigationKeepsTheAppEdgeSwipeOnAndroid15() {
        assertFalse(readerUsesSystemBackGesture(35, false))
    }

    @Test
    fun modernGestureNavigationUsesTheSystemBackGesture() {
        assertTrue(readerUsesSystemBackGesture(35, true))
        assertFalse(readerUsesSystemBackGesture(33, true))
    }
}
