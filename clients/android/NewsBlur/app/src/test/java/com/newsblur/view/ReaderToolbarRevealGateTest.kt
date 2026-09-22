package com.newsblur.view

import org.junit.Assert.assertEquals
import org.junit.Test

class ReaderToolbarRevealGateTest {
    @Test fun reverseDragMustCross30Pixels() {
        val gate = ReaderToolbarRevealGate(30)
        assertEquals(0, gate.filter(-15, true, true, false))
        assertEquals(0, gate.filter(0, true, true, false))
        assertEquals(0, gate.filter(-15, true, true, false))
        assertEquals(-6, gate.filter(-6, true, true, false))
    }

    @Test fun forwardScrollAndNewDragResetThreshold() {
        val gate = ReaderToolbarRevealGate(30)
        gate.filter(-20, true, true, false)
        assertEquals(3, gate.filter(3, true, true, false))
        assertEquals(0, gate.filter(-20, true, true, false))
        gate.reset()
        assertEquals(0, gate.filter(-20, true, true, false))
    }

    @Test fun flingCannotRevealButTopAndVisibleToolbarRespondImmediately() {
        val gate = ReaderToolbarRevealGate(30)
        assertEquals(0, gate.filter(-100, false, true, false))
        assertEquals(-10, gate.filter(-10, true, false, false))
        assertEquals(-10, gate.filter(-10, false, true, true))
    }
}
