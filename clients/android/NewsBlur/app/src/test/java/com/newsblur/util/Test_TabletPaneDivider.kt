package com.newsblur.util

import android.app.Activity
import android.view.MotionEvent
import android.view.View
import android.view.ViewParent
import android.widget.FrameLayout
import androidx.window.embedding.SplitAttributes
import androidx.window.embedding.SplitInfo
import androidx.window.embedding.ActivityStack
import androidx.window.WindowSdkExtensions
import com.newsblur.NbApplication
import com.newsblur.R
import com.newsblur.activity.FeedListDrawer
import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.Before
import org.junit.After

class Test_TabletPaneDivider {
    @Before
    fun useLiveResizeByDefault() {
        mockkObject(WindowSdkExtensions.Companion)
        every { WindowSdkExtensions.getInstance().extensionVersion } returns 7
    }

    @After
    fun restoreWindowExtensions() {
        unmockkObject(WindowSdkExtensions.Companion)
    }

    @Test
    fun test_old_embedding_previews_without_resizing_until_exact_release() = withLegacyGuide { divider, guide ->
        divider.onTouchEvent(touch(MotionEvent.ACTION_DOWN, 500f))
        divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 520f))
        every { divider["applyPendingResize"]() } answers { callOriginal() }
        TabletPaneDivider::class.java.getDeclaredMethod("applyPendingResize").apply { isAccessible = true }.invoke(divider)

        verify(exactly = 0) { StorySplitView.resizePane(any(), any(), any(), any()) }
        verify { guide.move(match { kotlin.math.abs(it - 420f) < 0.01f }) }
        divider.onTouchEvent(touch(MotionEvent.ACTION_UP, 550f))
        verify(exactly = 1) { StorySplitView.resizePane(any(), false, match { kotlin.math.abs(it - 0.45f) < 0.0001f }, true) }
        verify(exactly = 1) { guide.dismiss() }
    }

    @Test
    fun test_rtl_preview_moves_with_the_finger_and_cancellation_discards_it() = withLegacyGuide { divider, guide ->
        field("rightEdge").setBoolean(divider, false)
        divider.onTouchEvent(touch(MotionEvent.ACTION_DOWN, 500f))
        divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 550f))
        verify { guide.move(match { kotlin.math.abs(it - 650f) < 0.01f }) }
        divider.onTouchEvent(touch(MotionEvent.ACTION_CANCEL, 550f))
        verify(exactly = 0) { StorySplitView.resizePane(any(), any(), any(), any()) }
        verify(exactly = 1) { guide.dismiss() }
    }

    @Test
    fun test_hiding_or_detaching_removes_the_preview_without_applying_it() {
        for (detach in listOf(false, true)) withLegacyGuide { divider, guide ->
            divider.onTouchEvent(touch(MotionEvent.ACTION_DOWN, 500f))
            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 520f))
            if (detach) {
                every { divider["onDetachedFromWindow"]() } answers { callOriginal() }
                try {
                    TabletPaneDivider::class.java.getDeclaredMethod("onDetachedFromWindow").apply { isAccessible = true }.invoke(divider)
                } catch (error: java.lang.reflect.InvocationTargetException) {
                    // The JVM's View stub throws at super.onDetachedFromWindow, after our cleanup.
                    assertTrue(error.cause?.message?.contains("Method onDetachedFromWindow in android.view.View not mocked") == true)
                }
            } else {
                every { divider.update(any()) } answers { callOriginal() }
                divider.update(emptyList())
            }
            verify(exactly = 0) { StorySplitView.resizePane(any(), any(), any(), any()) }
            verify(exactly = 1) { guide.dismiss() }
        }
    }

    private fun withLegacyGuide(block: (TabletPaneDivider, TabletPaneResizeGuide) -> Unit) {
        mockkObject(StorySplitView, WindowSdkExtensions.Companion, TabletPaneResizeGuide.Companion)
        try {
            val divider = dragFixture()
            val guide = mockk<TabletPaneResizeGuide>(relaxed = true)
            every { WindowSdkExtensions.getInstance().extensionVersion } returns 3
            every { TabletPaneResizeGuide.show(any(), any(), any(), any(), any(), any()) } returns guide
            every { StorySplitView.resizePane(any(), any(), any(), any()) } returns Unit
            every { divider["prepareDrag"]() } returns Unit
            block(divider, guide)
        } finally {
            unmockkObject(StorySplitView, WindowSdkExtensions.Companion, TabletPaneResizeGuide.Companion)
        }
    }

    @Test
    fun test_continuous_moves_do_not_postpone_the_already_scheduled_frame() {
        mockkObject(StorySplitView)
        try {
            val divider = dragFixture()
            var frame = 0
            val pending = mutableMapOf<Runnable, Int>()
            val renderedRatios = mutableListOf<Float>()
            every { StorySplitView.resizePane(any(), any(), any(), any()) } answers {
                renderedRatios.add(thirdArg())
            }
            every { divider["applyPendingResize"]() } answers { callOriginal() }
            val applyPending = TabletPaneDivider::class.java.getDeclaredMethod("applyPendingResize").apply { isAccessible = true }
            val render = Runnable {
                applyPending.invoke(divider)
            }
            field("frameUpdate").set(divider, render)
            every { divider.postOnAnimation(any()) } answers {
                pending[firstArg()] = frame + 1
            }
            every { divider.removeCallbacks(any()) } answers { pending.remove(firstArg()) != null }

            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 510f))
            // Choreographer dispatches the next input batch before animation callbacks in that frame.
            frame = 1
            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 520f))
            pending.filterValues { it <= frame }.keys.toList().forEach { callback ->
                pending.remove(callback)
                callback.run()
            }

            assertEquals("Continuous input starved the resize frame", 1, renderedRatios.size)
            assertEquals(0.42f, renderedRatios.single(), 0.0001f)
            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 530f))
            frame = 2
            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 540f))
            pending.filterValues { it <= frame }.keys.toList().forEach { callback ->
                pending.remove(callback)
                callback.run()
            }
            assertEquals("Resizing stopped after its first frame", 2, renderedRatios.size)
            assertEquals(0.44f, renderedRatios.last(), 0.0001f)
        } finally {
            unmockkObject(StorySplitView)
        }
    }

    @Test
    fun test_release_uses_its_final_coordinate_and_cancels_the_older_frame() {
        mockkObject(StorySplitView)
        try {
            val divider = dragFixture()
            val activity = field("activity").get(divider) as Activity
            val render = Runnable {}
            field("frameUpdate").set(divider, render)
            every { StorySplitView.resizePane(any(), any(), any(), any()) } returns Unit

            divider.onTouchEvent(touch(MotionEvent.ACTION_MOVE, 520f))
            divider.onTouchEvent(touch(MotionEvent.ACTION_UP, 550f))

            // TabletPaneDivider.kt must not stop at the preceding MOVE's position when lifting.
            verify(exactly = 1) { StorySplitView.resizePane(activity, false, match { kotlin.math.abs(it - 0.45f) < 0.0001f }, true) }
            verify { divider.removeCallbacks(render) }
        } finally {
            unmockkObject(StorySplitView)
        }
    }

    private fun dragFixture(): TabletPaneDivider {
        val divider = mockk<TabletPaneDivider>(relaxed = true)
        val activity = mockk<ItemsList>(relaxed = true)
        for ((name, value) in mapOf(
            "activity" to activity, "density" to 1f, "startRatio" to 0.4f,
            "parentWidth" to 1000f, "startX" to 500f, "ratio" to 0.4f,
            "dragging" to true, "rightEdge" to true
        )) field(name).set(divider, value)
        every { divider.onTouchEvent(any()) } answers { callOriginal() }
        return divider
    }

    private fun field(name: String) =
        TabletPaneDivider::class.java.getDeclaredField(name).apply { isAccessible = true }

    private fun touch(action: Int, screenX: Float): MotionEvent = mockk {
        every { actionMasked } returns action
        every { rawX } returns screenX
    }

    @Test
    fun test_drag_follows_actual_split_direction_when_view_locale_disagrees() {
        mockkObject(Reading.Companion, FeedListDrawer.Companion)
        try {
            for (feeds in listOf(false, true)) {
                for (primaryOnRight in listOf(false, true)) {
                    val drawer = if (feeds) mockk<FeedListDrawer>(relaxed = true) else null
                    val activity: Activity = drawer ?: mockk<ItemsList>(relaxed = true)
                    val app = mockk<NbApplication>(relaxed = true)
                    every { activity.applicationContext } returns app
                    val divider = mockk<TabletPaneDivider>(relaxed = true)
                    every { Reading.peekReader(any()) } returns null
                    every { FeedListDrawer.peek(any()) } returns drawer
                    val primary = ActivityStack(if (feeds) emptyList() else listOf(activity), false)
                    val secondary = ActivityStack(listOfNotNull(drawer), false)
                    val attributes = SplitAttributes.Builder()
                        .setLayoutDirection(if (primaryOnRight) SplitAttributes.LayoutDirection.RIGHT_TO_LEFT else SplitAttributes.LayoutDirection.LEFT_TO_RIGHT)
                        .setSplitType(SplitAttributes.SplitType.ratio(0.4f)).build()
                    val split = SplitInfo(primary, secondary, attributes)
                    every { divider.layoutParams } returns mockk<FrameLayout.LayoutParams>(relaxed = true)
                    every { divider.layoutDirection } returns if (primaryOnRight) View.LAYOUT_DIRECTION_LTR else View.LAYOUT_DIRECTION_RTL
                    every { divider.update(any()) } answers { callOriginal() }
                    every { divider.onTouchEvent(any()) } answers { callOriginal() }
                    for ((name, value) in mapOf("activity" to activity, "density" to 1f, "startRatio" to 0.4f, "parentWidth" to 1000f, "startX" to 500f, "dragging" to true)) {
                        TabletPaneDivider::class.java.getDeclaredField(name).apply { isAccessible = true; set(divider, value) }
                    }
                    divider.update(listOf(split))
                    val event = mockk<MotionEvent> {
                        every { actionMasked } returns MotionEvent.ACTION_MOVE
                        every { rawX } returns 600f
                    }
                    divider.onTouchEvent(event)

                    // TabletPaneDivider.kt must resize the pane under the finger during a locale transition.
                    val resizedPaneOnRight = if (feeds) !primaryOnRight else primaryOnRight
                    val expectedRatio = if (resizedPaneOnRight) 0.3f else 0.5f
                    val ratio = TabletPaneDivider::class.java.getDeclaredField("ratio").apply { isAccessible = true }.getFloat(divider)
                    assertEquals("feeds=$feeds, primaryOnRight=$primaryOnRight", expectedRatio, ratio, 0.0001f)
                }
            }
        } finally {
            unmockkObject(Reading.Companion, FeedListDrawer.Companion)
        }
    }

    @Test
    fun test_drag_starts_anywhere_along_the_list_boundary() {
        val divider = mockk<TabletPaneDivider>(relaxed = true)
        field("activity").set(divider, mockk<ItemsList>(relaxed = true))
        val parent = mockk<ViewParent>(relaxed = true)
        every { divider.parent } returns parent
        every { divider.height } returns 1200
        every { divider["prepareDrag"]() } returns Unit
        every { divider.onTouchEvent(any()) } answers { callOriginal() }
        TabletPaneDivider::class.java.getDeclaredField("density").apply { isAccessible = true; setFloat(divider, 1f) }
        val event = mockk<MotionEvent> {
            every { actionMasked } returns MotionEvent.ACTION_DOWN
            every { y } returns 100f
            every { rawX } returns 500f
        }

        // TabletPaneDivider.kt exposes the whole border, not only its small center indicator.
        assertTrue("A drag near the top of the border was rejected", divider.onTouchEvent(event))
        verify(exactly = 1) { parent.requestDisallowInterceptTouchEvent(true) }
    }

    @Test
    fun test_wider_strip_leaves_toolbar_buttons_clickable() {
        val divider = dragFixture()
        val activity = field("activity").get(divider) as Activity
        val toolbar = mockk<View>(relaxed = true)
        every { activity.findViewById<View>(R.id.toolbar) } returns toolbar
        every { toolbar.isShown } returns true
        every { toolbar.width } returns 1000
        every { toolbar.height } returns 80
        every { toolbar.getLocationOnScreen(any()) } answers {
            firstArg<IntArray>()[0] = 0
            firstArg<IntArray>()[1] = 40
        }
        val event = touch(MotionEvent.ACTION_DOWN, 980f)
        every { event.rawY } returns 75f

        org.junit.Assert.assertFalse(divider.onTouchEvent(event))
    }

    @Test
    fun test_only_the_owner_list_pane_shows_the_divider() {
        mockkObject(Reading.Companion, FeedListDrawer.Companion)
        try {
            val titles = mockk<ItemsList>(relaxed = true)
            for (feeds in listOf(false, true)) {
                val reader = if (feeds) null else mockk<Reading>(relaxed = true)
                val drawer = if (feeds) mockk<FeedListDrawer>(relaxed = true) else null
                val secondary: Activity = drawer ?: reader!!
                val owner: Activity = drawer ?: titles
                every { Reading.peekReader(any()) } returns reader
                every { FeedListDrawer.peek(any()) } returns drawer
                val split = SplitInfo(
                    ActivityStack(listOf(titles), false),
                    ActivityStack(listOf(secondary), false),
                    SplitAttributes.Builder().setSplitType(SplitAttributes.SplitType.ratio(0.4f)).build()
                )
                for (activity in listOf(titles, secondary)) {
                    val divider = mockk<TabletPaneDivider>(relaxed = true)
                    every { divider.layoutParams } returns mockk<FrameLayout.LayoutParams>(relaxed = true)
                    every { divider.update(any()) } answers { callOriginal() }
                    TabletPaneDivider::class.java.getDeclaredField("activity").apply { isAccessible = true; set(divider, activity) }

                    divider.update(listOf(split))

                    val expected = if (activity === owner) View.VISIBLE else View.GONE
                    verify { divider.visibility = expected }
                }
            }
        } finally {
            unmockkObject(Reading.Companion, FeedListDrawer.Companion)
        }
    }

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
