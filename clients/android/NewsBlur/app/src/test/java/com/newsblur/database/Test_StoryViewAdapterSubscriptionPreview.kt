package com.newsblur.database

import android.os.SystemClock
import android.view.View
import androidx.recyclerview.widget.ListUpdateCallback
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import com.newsblur.util.StoryListStyle
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryViewAdapterSubscriptionPreview {
    @Before fun setUp() {
        mockkStatic(SystemClock::class, android.util.Log::class)
        every { SystemClock.elapsedRealtime() } returns 0L
        every { android.util.Log.d(any(), any()) } returns 0
    }

    @After fun tearDown() {
        unmockkStatic(SystemClock::class, android.util.Log::class)
    }

    @Test
    fun test_free_folder_first_page_notifies_only_the_three_visible_stories() {
        val fixture = Fixture(FeedSet.folder("Folder", setOf("1", "2")))
        fixture.load((1..12).map(::story))
        assertEquals(4, fixture.adapter.itemCount)
        assertEquals(12, fixture.adapter.rawStoryCount)
        fixture.assertNotificationsMatchVisibleRows()
    }

    @Test
    fun test_free_all_stories_paging_does_not_insert_hidden_rows() {
        val fixture = Fixture(FeedSet.allFeeds())
        fixture.load((1..3).map(::story))
        fixture.assertNotificationsMatchVisibleRows()
        fixture.load((1..12).map(::story))
        fixture.assertNotificationsMatchVisibleRows()
        assertEquals(4, fixture.adapter.itemCount)
    }

    @Test
    fun test_free_folder_refresh_replaces_preview_without_removing_hidden_rows() {
        val fixture = Fixture(FeedSet.folder("Folder", setOf("1", "2")))
        fixture.load((1..12).map(::story))
        fixture.load((10..14).map(::story))
        fixture.assertNotificationsMatchVisibleRows()
        fixture.load(emptyList())
        fixture.assertNotificationsMatchVisibleRows()
        assertEquals(1, fixture.adapter.itemCount)
    }

    @Test
    fun test_premium_folder_and_free_single_feed_keep_the_full_page() {
        for (fixture in listOf(Fixture(FeedSet.allFeeds(), subscribed = true), Fixture(FeedSet.singleFeed("1")))) {
            fixture.load((1..12).map(::story))
            fixture.assertNotificationsMatchVisibleRows()
            assertEquals(13, fixture.adapter.itemCount)
        }
    }

    @Test
    fun test_subscription_refresh_keeps_count_stable_until_the_new_rows_are_committed() {
        val fixture = Fixture(FeedSet.allFeeds())
        fixture.load((1..12).map(::story))
        fixture.setSubscribed(true)
        assertEquals("Account refresh must not silently change RecyclerView row count", 4, fixture.adapter.itemCount)
        fixture.load((1..12).map(::story))
        fixture.assertNotificationsMatchVisibleRows()
        assertEquals(13, fixture.adapter.itemCount)
    }

    @Test
    fun test_preview_keeps_related_rows_of_the_third_visible_story() {
        val fixture = Fixture(FeedSet.allFeeds())
        fixture.showRelatedStories()
        fixture.load(
            (1..12).map { number ->
                story(number).apply {
                    clusterStories =
                        arrayOf(
                            Story.ClusterStory().apply {
                                storyHash = "2:$number"
                                feedId = "2"
                                title = "Related $number"
                            },
                        )
                }
            },
        )
        assertEquals(7, fixture.adapter.itemCount)
        fixture.assertNotificationsMatchVisibleRows()
    }

    private class Fixture(
        feedSet: FeedSet,
        subscribed: Boolean = false,
    ) {
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        private val prefs = mockk<PrefsRepo>(relaxed = true)
        private val grid = mockk<RecyclerView>(relaxed = true)
        private var notifiedItemCount = 1

        init {
            every { prefs.hasSubscription() } returns subscribed
            for ((name, value) in mapOf(
                "fs" to feedSet,
                "prefsRepo" to prefs,
                "listStyle" to StoryListStyle.LIST,
                "stories" to mutableListOf<Story>(),
                "displayItems" to mutableListOf<StoryViewAdapter.DisplayItem>(),
                "storyDisplayPositions" to mutableListOf<Int>(),
                "footerViews" to mutableListOf(mockk<View>(relaxed = true)),
                "clusterThumbnailUrls" to mutableMapOf<String, String?>(),
            )) {
                StoryViewAdapter::class.java
                    .getDeclaredField(name)
                    .apply { isAccessible = true }
                    .set(adapter, value)
            }
            every { adapter.itemCount } answers { callOriginal() }
            every { adapter.storyCount } answers { callOriginal() }
            every { adapter.rawStoryCount } answers { callOriginal() }
            every { adapter["visibleDisplayItemCount"]() } answers { callOriginal() }
            every { adapter["buildDisplayItems"](any<List<Story>>()) } answers { callOriginal() }
            every { adapter["calculateStoryDiff"](any<StoryViewAdapter.StorySubmission>()) } answers { callOriginal() }
            every { adapter["commitStoryDiff"](any<StoryViewAdapter.StoryDifference>()) } answers { callOriginal() }
            every { adapter["applySkipBackfill"](any<List<Story>>(), false) } answers { firstArg<List<Story>>() }
            every { grid.adapter } returns adapter
        }

        fun setSubscribed(subscribed: Boolean) {
            every { prefs.hasSubscription() } returns subscribed
        }

        fun showRelatedStories() {
            every { prefs.getBoolean(any(), any()) } returns true
            every { adapter["subscribedFeedIds"]() } returns setOf("1", "2")
        }

        fun load(stories: List<Story>) {
            val submission = StoryViewAdapter.StorySubmission(stories, 1, grid, false, 0, null)
            val calculate =
                StoryViewAdapter::class.java.getDeclaredMethod("calculateStoryDiff", StoryViewAdapter.StorySubmission::class.java).apply {
                    isAccessible =
                        true
                }
            val difference = calculate.invoke(adapter, submission) as StoryViewAdapter.StoryDifference
            difference.diff.dispatchUpdatesTo(
                object : ListUpdateCallback {
                    override fun onInserted(
                        position: Int,
                        count: Int,
                    ) {
                        notifiedItemCount += count
                    }

                    override fun onRemoved(
                        position: Int,
                        count: Int,
                    ) {
                        notifiedItemCount -= count
                    }

                    override fun onMoved(
                        fromPosition: Int,
                        toPosition: Int,
                    ) = Unit

                    override fun onChanged(
                        position: Int,
                        count: Int,
                        payload: Any?,
                    ) = Unit
                },
            )
            StoryViewAdapter::class.java
                .getDeclaredMethod("commitStoryDiff", StoryViewAdapter.StoryDifference::class.java)
                .apply {
                    isAccessible =
                        true
                }.invoke(adapter, difference)
        }

        fun assertNotificationsMatchVisibleRows() {
            assertEquals(
                "RecyclerView must receive exactly the row count exposed by StoryViewAdapter.kt",
                adapter.itemCount,
                notifiedItemCount,
            )
        }
    }

    companion object {
        private fun story(number: Int) =
            Story().apply {
                storyHash = "1:$number"
                feedId = "1"
                title = "Story $number"
                sharedUserIds = emptyArray()
            }
    }
}
