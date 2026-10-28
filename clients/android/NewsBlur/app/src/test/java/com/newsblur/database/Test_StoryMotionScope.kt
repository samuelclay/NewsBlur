package com.newsblur.database

import android.animation.ValueAnimator
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import com.newsblur.util.ViewUtils
import com.newsblur.view.ReaderMotion
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class Test_StoryMotionScope {
    @Before fun setUp() {
        mockkStatic(ReaderMotion::class, ValueAnimator::class, ViewUtils::class)
        mockkConstructor(Rect::class)
        every { ValueAnimator.areAnimatorsEnabled() } returns true
        every { ViewUtils.isPowerSaveMode(any()) } returns false
        every { ReaderMotion.enter(any(), any(), any()) } returns true
    }

    @After fun tearDown() = unmockkAll()

    private fun adapter(seen: MutableSet<String>): StoryViewAdapter {
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        fun field(name: String, value: Any) {
            StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
        }
        field("motionSeen", seen)
        field("motionRect", Rect())
        field("diffFeedSet", FeedSet.singleFeed("1"))
        every { adapter.updateFeedSet(any()) } answers { callOriginal() }
        every { adapter.onAttachedToRecyclerView(any()) } answers { callOriginal() }
        return adapter
    }

    @Test fun test_opening_a_folder_replays_entrances_for_stories_seen_in_another_feed() {
        val seen = mutableSetOf("1:shared-story")
        // Test_StoryMotionScope.kt models the tablet reusing its adapter when opening a folder.
        adapter(seen).updateFeedSet(FeedSet.allFeeds())
        assertTrue("A new feed/folder must get its own first-visible cascade", seen.isEmpty())
    }

    @Test fun test_same_feed_refresh_does_not_replay_seen_stories() {
        val seen = mutableSetOf("1:shared-story")
        adapter(seen).updateFeedSet(FeedSet.singleFeed("1"))
        assertEquals(setOf("1:shared-story"), seen)
    }

    @Test fun test_previous_feed_rows_do_not_consume_the_new_scope_before_its_commit() {
        val seen = mutableSetOf<String>()
        val adapter = adapter(seen)
        val preDraw = attach(adapter, listOf(row()))
        adapter.updateFeedSet(FeedSet.allFeeds())
        preDraw.onPreDraw()
        assertTrue(seen.isEmpty())
        verify(exactly = 0) { ReaderMotion.enter(any(), any(), any()) }
    }

    @Test fun test_an_entrance_that_cannot_start_remains_pending() {
        val seen = mutableSetOf<String>()
        val preDraw = attach(adapter(seen), listOf(row()))
        every { ReaderMotion.enter(any(), any(), any()) } returns false
        preDraw.onPreDraw()
        assertTrue(seen.isEmpty())
        every { ReaderMotion.enter(any(), any(), any()) } returns true
        preDraw.onPreDraw()
        assertEquals(setOf("1:row0"), seen)
    }

    private fun row(): View = mockk<View>(relaxed = true).also {
        every { it.isAttachedToWindow } returns true
        every { it.isShown } returns true
        every { it.windowVisibility } returns View.VISIBLE
        every { it.visibility } returns View.VISIBLE
        every { it.alpha } returns 1f
        every { it.parent } returns null
    }

    private fun attach(adapter: StoryViewAdapter, rows: List<View>): ViewTreeObserver.OnPreDrawListener {
        val rv = mockk<RecyclerView>(relaxed = true)
        val observer = mockk<ViewTreeObserver>(relaxed = true)
        val preDraw = slot<ViewTreeObserver.OnPreDrawListener>()
        every { rv.viewTreeObserver } returns observer
        every { rv.childCount } returns rows.size
        every { observer.addOnPreDrawListener(capture(preDraw)) } just Runs
        rows.forEachIndexed { index, row ->
            val holder = mockk<StoryViewAdapter.StoryViewHolder>(relaxed = true)
            every { rv.getChildAt(index) } returns row
            every { rv.getChildViewHolder(row) } returns holder
            every { holder.story } returns Story().apply { storyHash = "1:row$index" }
            every { row.getGlobalVisibleRect(any()) } answers {
                firstArg<Rect>().apply { top = (rows.size - index - 1) * 40; left = 0; right = 300; bottom = top + 40 }
                true
            }
        }
        adapter.onAttachedToRecyclerView(rv)
        return preDraw.captured
    }

    @Test fun test_recycler_child_order_does_not_scramble_the_screen_order_or_merge_late_delays() {
        val rows = List(8) { row() }
        val calls = mutableListOf<Pair<View, Long>>()
        every { ReaderMotion.enter(any(), any(), any()) } answers { calls.add(firstArg<View>() to secondArg<Long>()); true }
        attach(adapter(mutableSetOf()), rows).onPreDraw()
        assertEquals(rows.reversed(), calls.map { it.first })
        assertTrue(calls.zipWithNext().all { (a, b) -> a.second < b.second })
        assertTrue(calls.all { it.second <= 175 })
    }

    @Test fun test_hidden_detached_transparent_and_disabled_rows_keep_their_first_entrance() {
        for (state in listOf("hidden", "detached", "transparent", "ancestor", "window", "disabled", "power-save")) {
            val seen = mutableSetOf<String>()
            val row = row()
            val ancestor = mockk<ViewGroup>(relaxed = true)
            every { ancestor.visibility } returns View.VISIBLE
            every { ancestor.alpha } returns 1f
            every { ancestor.parent } returns null
            when (state) {
                "hidden" -> every { row.isShown } returns false
                "detached" -> every { row.isAttachedToWindow } returns false
                "transparent" -> every { row.alpha } returns 0f
                "ancestor" -> { every { row.parent } returns ancestor; every { ancestor.alpha } returns 0f }
                "window" -> every { row.windowVisibility } returns View.INVISIBLE
                "disabled" -> every { ValueAnimator.areAnimatorsEnabled() } returns false
                "power-save" -> every { ViewUtils.isPowerSaveMode(any()) } returns true
            }
            val preDraw = attach(adapter(seen), listOf(row))
            preDraw.onPreDraw()
            assertTrue("$state rows must keep their entrance pending", seen.isEmpty())
            every { row.isShown } returns true
            every { row.isAttachedToWindow } returns true
            every { row.alpha } returns 1f
            every { row.windowVisibility } returns View.VISIBLE
            every { ancestor.alpha } returns 1f
            every { ValueAnimator.areAnimatorsEnabled() } returns true
            every { ViewUtils.isPowerSaveMode(any()) } returns false
            preDraw.onPreDraw()
            assertEquals(setOf("1:row0"), seen)
        }
    }
}
