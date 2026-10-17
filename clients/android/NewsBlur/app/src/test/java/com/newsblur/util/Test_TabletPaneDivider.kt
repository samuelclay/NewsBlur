package com.newsblur.util

import android.view.ViewParent
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class Test_TabletPaneDivider {
    @Test
    fun test_hiding_a_dragging_divider_cancels_the_pending_pane_resize() {
        val divider = mockk<TabletPaneDivider>(relaxed = true)
        val parent = mockk<ViewParent>(relaxed = true)
        val pendingResize = Runnable {}
        TabletPaneDivider::class.java.getDeclaredField("frameUpdate").apply {
            isAccessible = true
            set(divider, pendingResize)
        }
        TabletPaneDivider::class.java.getDeclaredField("dragging").apply {
            isAccessible = true
            setBoolean(divider, true)
        }
        every { divider.parent } returns parent
        every { divider.update(any()) } answers { callOriginal() }

        // TabletPaneDivider.kt must not resize a previous pair after fullscreen removes its split.
        divider.update(emptyList())

        verify(exactly = 1) { divider.removeCallbacks(pendingResize) }
        verify(exactly = 1) { parent.requestDisallowInterceptTouchEvent(false) }
    }
}
