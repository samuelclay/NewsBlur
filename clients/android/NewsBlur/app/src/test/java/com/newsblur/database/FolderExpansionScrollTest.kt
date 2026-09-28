package com.newsblur.database

import android.widget.ExpandableListView
import android.widget.ImageView
import com.newsblur.view.AnimatedFolderListView
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.Test
import java.lang.ref.WeakReference

class FolderExpansionScrollTest {
    @Test
    fun expandingFolderDoesNotStartAnIndependentScrollAnimation() {
        // FolderListAdapter.java must keep the tapped heading anchored while its rows move.
        val list = mockk<ExpandableListView>(relaxed = true)
        val indicator = mockk<ImageView>(relaxed = true)
        val adapter = mockk<FolderListAdapter>(relaxed = true)
        every { adapter["toggleGroup"](indicator, 3) } answers { callOriginal() }
        adapter.listBackref = WeakReference(list)
        FolderListAdapter::class.java
            .getDeclaredMethod("toggleGroup", ImageView::class.java, Int::class.javaPrimitiveType)
            .apply { isAccessible = true }
            .invoke(adapter, indicator, 3)

        verify(exactly = 1) { list.expandGroup(3, false) }
        verify(exactly = 0) { list.expandGroup(3, true) }
    }

    @Test
    fun groupStateChangesInsideTheAnimationCaptureForBothDirections() {
        for (expanded in listOf(false, true)) {
            val list = mockk<AnimatedFolderListView>(relaxed = true)
            every { list.isGroupExpanded(3) } returns expanded
            val change = slot<Runnable>()
            every { list.animateGroupChange(3, !expanded, capture(change)) } returns Unit
            val indicator = mockk<ImageView>(relaxed = true)
            val adapter = mockk<FolderListAdapter>(relaxed = true)
            every { adapter["toggleGroup"](indicator, 3) } answers { callOriginal() }
            adapter.listBackref = WeakReference(list)

            FolderListAdapter::class.java
                .getDeclaredMethod("toggleGroup", ImageView::class.java, Int::class.javaPrimitiveType)
                .apply { isAccessible = true }
                .invoke(adapter, indicator, 3)

            verify(exactly = 0) { list.expandGroup(any(), any()) }
            verify(exactly = 0) { list.collapseGroup(any()) }
            change.captured.run()
            if (expanded) {
                verify(exactly = 1) { list.collapseGroup(3) }
            } else {
                verify(exactly = 1) { list.expandGroup(3, false) }
            }
        }
    }
}
