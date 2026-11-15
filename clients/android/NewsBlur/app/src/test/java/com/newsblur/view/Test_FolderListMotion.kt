package com.newsblur.view

import android.animation.ValueAnimator
import android.graphics.Canvas
import android.view.View
import com.newsblur.util.ViewUtils
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.lang.reflect.InvocationTargetException

class Test_FolderListMotion {
    @Before fun setup() {
        mockkStatic(ReaderMotion::class, ValueAnimator::class, ViewUtils::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
    }

    @After fun cleanup() = unmockkAll()

    // Test_FolderListMotion.kt protects presentation at the first drawn frame: consuming IDs during
    // detached measurement would omit the folders that layout prepared before their feed rows.
    @Test fun test_startup_draw_retries_unpresented_rows_and_orders_top_level_folders_and_feeds() {
        val fixture = fixture()
        var ready = false
        val starts = mutableListOf<Pair<View, Long>>()
        every { ReaderMotion.enter(any(), any(), any()) } answers {
            if (ready) starts.add(firstArg<View>() to secondArg())
            ready
        }
        fixture.draw()
        assertTrue(starts.isEmpty())
        ready = true
        fixture.draw()
        assertEquals(fixture.rows, starts.map { it.first })
        assertTrue("Every lower row must begin later, including rows beyond the fifth", starts.zipWithNext().all { (a, b) -> a.second < b.second })
        assertTrue(starts.last().second <= 175)
        starts.clear()
        fixture.draw()
        assertTrue("Sync redraws must not replay already visible row identities", starts.isEmpty())
    }

    @Test fun test_reduced_motion_and_power_save_do_not_defer_a_surprise_entrance() {
        for (powerSave in listOf(false, true)) {
            val fixture = fixture()
            every { ValueAnimator.areAnimatorsEnabled() } returns powerSave
            every { ViewUtils.isPowerSaveMode(any()) } returns powerSave
            fixture.draw()
            every { ValueAnimator.areAnimatorsEnabled() } returns true
            every { ViewUtils.isPowerSaveMode(any()) } returns false
            fixture.draw()
            verify(exactly = 0) { ReaderMotion.enter(any(), any(), any()) }
        }
    }

    @Test fun test_filter_change_presents_matching_rows_again_without_delaying_the_data_change() {
        val fixture = fixture()
        val starts = mutableListOf<View>()
        every { ReaderMotion.enter(any(), any(), any()) } answers { starts.add(firstArg()); true }
        every { fixture.list.animateFilterChange(any()) } answers { callOriginal() }
        fixture.draw()
        starts.clear()
        var changed = false

        fixture.list.animateFilterChange { changed = true }

        assertTrue("The selected filter must take effect before animation finishes", changed)
        fixture.draw()
        assertEquals("Switching filters also animates folders whose identity did not change", fixture.rows, starts)
        starts.clear()
        fixture.draw()
        assertTrue("The resulting sync redraw must not restart the filter animation", starts.isEmpty())
    }

    @Test fun test_rows_visible_behind_floating_toolbar_padding_join_the_cascade() {
        val fixture = fixture()
        every { fixture.list.clipToPadding } returns false
        every { fixture.list.paddingBottom } returns 200
        val starts = mutableListOf<View>()
        every { ReaderMotion.enter(any(), any(), any()) } answers { starts.add(firstArg()); true }
        fixture.draw()
        assertEquals("Main.java draws through its toolbar padding; visible bottom rows must not pop in ahead of the cascade", fixture.rows, starts)
    }

    private fun fixture(): Fixture {
        val list = mockk<AnimatedFolderListView>(relaxed = true)
        val rows = List(12) { index -> mockk<View>(relaxed = true).also {
            every { it.top } returns index * 40
            every { it.bottom } returns (index + 1) * 40
            every { it.height } returns 40
            every { it.visibility } returns View.VISIBLE
        } }
        every { list.childCount } returns rows.size
        every { list.getChildAt(any()) } answers { rows[firstArg()] }
        every { list.getItemIdAtPosition(any()) } answers { firstArg<Int>().toLong() + 100 }
        every { list.height } returns 600
        every { list.width } returns 320
        every { list.isAttachedToWindow } returns true
        every { list.isShown } returns true
        every { list.windowVisibility } returns View.VISIBLE
        every { list["dispatchDraw"](any<Canvas>()) } answers { callOriginal() }
        every { list["presentVisibleRows"]() } answers { callOriginal() }
        for ((name, value) in mapOf("seenRows" to mutableSetOf<Long>(), "movingViews" to emptyList<Any>(), "leavingRows" to emptyList<Any>())) {
            AnimatedFolderListView::class.java.getDeclaredField(name).apply { isAccessible = true }.set(list, value)
        }
        return Fixture(list, rows)
    }

    private data class Fixture(val list: AnimatedFolderListView, val rows: List<View>) {
        fun draw() {
            try {
                AnimatedFolderListView::class.java.getDeclaredMethod("dispatchDraw", Canvas::class.java)
                    .apply { isAccessible = true }.invoke(list, mockk<Canvas>(relaxed = true))
            } catch (exception: InvocationTargetException) {
                if (exception.cause?.message?.startsWith("Method dispatchDraw in android.widget.ExpandableListView not mocked.") != true) throw exception
            }
        }
    }
}
