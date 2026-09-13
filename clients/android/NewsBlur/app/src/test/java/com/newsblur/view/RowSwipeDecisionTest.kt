package com.newsblur.view

import org.junit.Assert.*
import org.junit.Test

class RowSwipeDecisionTest {
    @Test fun verticalScrollCannotBecomeAReadSwipeLater() {
        val gesture = RowSwipeDecision(8f).apply { begin() }
        assertFalse(gesture.move(2f, 25f, true))
        assertFalse(gesture.move(150f, 30f, true))
        assertFalse(gesture.finish(150f, 400, true))
    }
    @Test fun canceledSwipeNeverActsEvenAfterCrossingThreshold() {
        val gesture = RowSwipeDecision(8f).apply { begin() }
        assertTrue(gesture.move(140f, 2f, true))
        gesture.cancel()
        assertFalse(gesture.finish(140f, 400, true))
    }
    @Test fun draggingBackBelowThresholdCancels() {
        val gesture = RowSwipeDecision(8f).apply { begin() }
        assertTrue(gesture.move(-200f, 0f, true))
        assertTrue(gesture.move(-20f, 0f, true))
        assertFalse(gesture.finish(-20f, 400, true))
    }
    @Test fun commitsBothDirectionsOnceAtTwentyPercent() {
        for (offset in listOf(-80f, 80f)) {
            val gesture = RowSwipeDecision(8f).apply { begin() }
            assertTrue(gesture.move(offset, 0f, true))
            assertTrue(gesture.finish(offset, 400, true))
            assertFalse(gesture.finish(offset, 400, true))
        }
    }
    @Test fun disabledDirectionNeverClaimsTouchOrCommits() {
        val gesture = RowSwipeDecision(8f).apply { begin() }
        assertFalse(gesture.move(100f, 0f, false))
        assertFalse(gesture.finish(100f, 400, false))
    }
    @Test fun newTouchRecoversAfterCancellation() {
        val gesture = RowSwipeDecision(8f).apply { begin(); cancel(); begin() }
        assertTrue(gesture.move(-100f, 0f, true))
        assertTrue(gesture.finish(-100f, 400, true))
    }
    @Test fun diagonalDriftAndZeroSizedRowsDoNotCommit() {
        val gesture = RowSwipeDecision(8f).apply { begin() }
        assertFalse(gesture.move(9f, 8f, true))
        assertFalse(gesture.finish(90f, 0, true))
    }
}
