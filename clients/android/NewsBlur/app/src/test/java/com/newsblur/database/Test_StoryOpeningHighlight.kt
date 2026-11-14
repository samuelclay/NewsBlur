package com.newsblur.database

import android.animation.ValueAnimator
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.SystemClock
import android.view.View
import android.view.ViewConfiguration
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import io.mockk.*
import org.junit.Assert.*
import org.junit.Test

class Test_StoryOpeningHighlight {
    @Test
    fun test_tapped_row_holds_its_highlight_before_launching_reader() = withFixture { fixture ->
        every { fixture.listener.onStoryClicked(any(), "1:tapped") } answers {
            assertNotSame("Tap highlight must already be held when reader launch starts", fixture.original, fixture.background)
        }
        fixture.holder.onClick(fixture.row)
        verify(exactly = 1) { fixture.listener.onStoryClicked(any(), "1:tapped") }
        assertFalse(fixture.highlight().isFinished)
    }

    @Test
    fun test_reopening_during_return_fade_cancels_old_animation_and_holds_again() = withFixture { fixture ->
        val animation = mockk<ValueAnimator>(relaxed = true)
        val previous = ReturnedStoryHighlight(fixture.row, "1:tapped", { "1:tapped" }, 1, 2) { animation }
        previous.hold()
        previous.fade()
        setField(StoryViewAdapter::class.java, fixture.adapter, "returnHighlight", previous)
        setField(StoryViewAdapter::class.java, fixture.adapter, "pendingHighlightStoryHash", "1:tapped")
        setField(StoryViewAdapter::class.java, fixture.adapter, "pendingScrollStoryHash", "1:tapped")
        setField(StoryViewAdapter::class.java, fixture.adapter, "returnPresentationReady", true)

        fixture.holder.onClick(fixture.row)

        verify { animation.cancel() }
        assertTrue(previous.isFinished)
        assertNotSame(previous, fixture.highlight())
        assertFalse(fixture.highlight().isFinished)
        assertNull(field(fixture.adapter, "pendingHighlightStoryHash"))
        assertNull(field(fixture.adapter, "pendingScrollStoryHash"))
        assertEquals(false, field(fixture.adapter, "returnPresentationReady"))
        fixture.highlight().cancel()
        assertSame(fixture.original, fixture.background)
    }

    @Test
    fun test_invalid_story_does_not_highlight_or_launch() = withFixture { fixture ->
        fixture.story.storyHash = ""
        fixture.holder.onClick(fixture.row)
        assertSame(fixture.original, fixture.background)
        verify(exactly = 0) { fixture.listener.onStoryClicked(any(), any()) }
    }

    @Test
    fun test_debounced_tap_does_not_replace_the_current_highlight() = withFixture { fixture ->
        fixture.holder.onClick(fixture.row)
        val initial = fixture.highlight()
        fixture.holder.onClick(fixture.row)
        assertSame(initial, fixture.highlight())
        verify(exactly = 1) { fixture.listener.onStoryClicked(any(), any()) }
    }

    @Test
    fun test_failed_launch_restores_row_background() = withFixture { fixture ->
        every { fixture.listener.onStoryClicked(any(), any()) } throws IllegalStateException("Cannot launch reader")
        assertThrows(IllegalStateException::class.java) { fixture.holder.onClick(fixture.row) }
        assertSame(fixture.original, fixture.background)
    }

    @Test
    fun test_daily_briefing_without_story_list_return_lifecycle_does_not_leave_a_held_highlight() = withFixture { fixture ->
        setField(StoryViewAdapter::class.java, fixture.adapter, "fs", FeedSet.dailyBriefing())
        fixture.holder.onClick(fixture.row)
        verify(exactly = 1) { fixture.listener.onStoryClicked(any(), "1:tapped") }
        assertSame(fixture.original, fixture.background)
    }

    @Test
    fun test_direct_cluster_story_holds_highlight_before_reader_launch() = withFixture { fixture ->
        val clusterHolder = mockk<StoryViewAdapter.ClusterRowViewHolder>(relaxed = true)
        val cluster = Story.ClusterStory().apply { storyHash = "1:cluster"; feedId = "1" }
        setField(StoryViewAdapter::class.java, fixture.adapter, "feedUtils", mockk<FeedUtils>(relaxed = true))
        setField(StoryViewAdapter.ClusterRowViewHolder::class.java, clusterHolder, "this\$0", fixture.adapter)
        setField(StoryViewAdapter.ClusterRowViewHolder::class.java, clusterHolder, "clusterStory", cluster)
        setField(RecyclerView.ViewHolder::class.java, clusterHolder, "itemView", fixture.row)
        every { clusterHolder.clusterStory } returns cluster
        every { clusterHolder.onClick(fixture.row) } answers { callOriginal() }
        every { fixture.listener.onStoryClicked(any(), "1:cluster") } answers {
            assertNotSame(fixture.original, fixture.background)
        }
        clusterHolder.onClick(fixture.row)
        verify(exactly = 1) { fixture.listener.onStoryClicked(any(), "1:cluster") }
    }

    private fun withFixture(test: (Fixture) -> Unit) {
        mockkStatic(SystemClock::class, ViewConfiguration::class)
        mockkConstructor(ColorDrawable::class)
        try {
            every { SystemClock.elapsedRealtime() } returns 1000L
            every { ViewConfiguration.getDoubleTapTimeout() } returns 300
            test(Fixture())
        } finally {
            unmockkStatic(SystemClock::class, ViewConfiguration::class)
            unmockkConstructor(ColorDrawable::class)
        }
    }

    private class Fixture {
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        val holder = mockk<StoryViewAdapter.StoryViewHolder>(relaxed = true)
        val row = mockk<View>(relaxed = true)
        val original = mockk<Drawable>()
        var background: Drawable? = original
        val listener = mockk<StoryViewAdapter.OnStoryClickListener>(relaxed = true)
        val story = Story().apply { storyHash = "1:tapped"; feedId = "1" }

        init {
            every { row.background } answers { background }
            every { row.background = any() } answers { background = firstArg() }
            setField(StoryViewAdapter::class.java, adapter, "listener", listener)
            setField(StoryViewAdapter::class.java, adapter, "fs", FeedSet.singleFeed("1"))
            setField(StoryViewAdapter.StoryViewHolder::class.java, holder, "this\$0", adapter)
            setField(StoryViewAdapter.StoryViewHolder::class.java, holder, "story", story)
            setField(RecyclerView.ViewHolder::class.java, holder, "itemView", row)
            every { holder.story } returns story
            every { holder.onClick(row) } answers { callOriginal() }
            every { adapter["openHighlightedStory"](any<RecyclerView.ViewHolder>(), any<FeedSet>(), any<String>()) } answers { callOriginal() }
            every { adapter["holdReturnHighlight"](any<RecyclerView.ViewHolder>(), any<String>()) } answers { callOriginal() }
            every { adapter["cancelReturnHighlight"](any<RecyclerView.ViewHolder>()) } answers { callOriginal() }
            every { adapter["boundStoryHash"](any<RecyclerView.ViewHolder>()) } answers { callOriginal() }
            every { adapter["highlightColorForTheme"]() } returns 1
            every { adapter["defaultColorForTheme"]() } returns 2
        }

        fun highlight() = field(adapter, "returnHighlight") as ReturnedStoryHighlight
    }

    companion object {
        private fun setField(type: Class<*>, target: Any, name: String, value: Any) {
            type.getDeclaredField(name).apply { isAccessible = true }.set(target, value)
        }

        private fun field(adapter: StoryViewAdapter, name: String): Any? =
            StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.get(adapter)
    }
}
