package com.newsblur.util

import android.content.Context
import android.view.View
import android.view.ViewTreeObserver
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.newsblur.R
import com.newsblur.util.EdgeToEdgeUtil.applyReaderBottomInsetTo
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_ReaderBottomInset {
    @Test
    fun test_final_comment_scrolls_above_floating_reader_controls() {
        mockkStatic(ViewCompat::class, UIUtils::class)
        try {
            val context = mockk<Context>()
            val viewport = mockk<View>(relaxed = true)
            val root = mockk<View>(relaxed = true)
            val overlay = mockk<View>(relaxed = true)
            val comments = mockk<View>(relaxed = true)
            val insets = mockk<WindowInsetsCompat>()
            val observer = mockk<ViewTreeObserver>(relaxed = true)
            val listener = slot<ViewTreeObserver.OnGlobalLayoutListener>()
            val preDraw = slot<ViewTreeObserver.OnPreDrawListener>()
            every { viewport.isAttachedToWindow } returns true
            every { viewport.viewTreeObserver } returns observer
            every { observer.isAlive } returns true
            every { observer.addOnGlobalLayoutListener(capture(listener)) } just Runs
            every { observer.addOnPreDrawListener(capture(preDraw)) } just Runs
            every { viewport.context } returns context
            every { viewport.rootView } returns root
            every { root.findViewById<View>(R.id.content_bottom_overlay) } returns overlay
            every { ViewCompat.getRootWindowInsets(viewport) } returns insets
            every { insets.getInsets(WindowInsetsCompat.Type.navigationBars()) } returns Insets.of(0, 0, 0, 24)
            every { UIUtils.dp2px(context, 8) } returns 8
            every { viewport.height } returns 800
            every { viewport.isLaidOut } returns true
            every { overlay.isLaidOut } returns true
            every { viewport.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = 24 }
            every { overlay.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = 744 }

            val clearListener = viewport.applyReaderBottomInsetTo(comments)

            // Test_ReaderBottomInset.kt: 24px navigation alone leaves the last comment under the capsules.
            verify { comments.setPadding(0, 0, 0, 88) }

            // Test_ReaderBottomInset.kt: switching to gesture navigation or resizing must recompute the clearance.
            every { insets.getInsets(WindowInsetsCompat.Type.navigationBars()) } returns Insets.NONE
            every { overlay.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = 768 }
            if (listener.isCaptured) listener.captured.onGlobalLayout() else preDraw.captured.onPreDraw()
            verify { comments.setPadding(0, 0, 0, 64) }

            // Test_ReaderBottomInset.kt: AppBarLayout reveals the toolbar with offsetTopAndBottom,
            // moving the viewport without another layout. The next frame must still clear the capsules.
            every { viewport.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = 80 }
            if (preDraw.isCaptured) preDraw.captured.onPreDraw()
            verify { comments.setPadding(0, 0, 0, 120) }

            // Test_ReaderBottomInset.kt: FragmentStateManager detaches the view before onDestroyView,
            // so cleanup must remove the callback from the original window observer, not the new floating one.
            val detachedObserver = mockk<ViewTreeObserver>(relaxed = true)
            every { detachedObserver.isAlive } returns true
            every { viewport.viewTreeObserver } returns detachedObserver
            clearListener.run()
            if (listener.isCaptured) {
                verify { observer.removeOnGlobalLayoutListener(listener.captured) }
            } else {
                verify { observer.removeOnPreDrawListener(preDraw.captured) }
            }
            verify(exactly = 0) { detachedObserver.removeOnGlobalLayoutListener(any()) }
            verify(exactly = 0) { detachedObserver.removeOnPreDrawListener(any()) }
        } finally {
            unmockkStatic(ViewCompat::class, UIUtils::class)
        }
    }
}
