package com.newsblur.listen

import com.newsblur.domain.Story
import org.junit.Assert.assertEquals
import org.junit.Test

/** Test_ListenAutoContinue.kt checks which story ListenAutoContinue.kt plays next from the list Listen started in. */
class Test_ListenAutoContinue {
    private fun story(
        hash: String,
        read: Boolean,
    ) = Story().apply {
        storyHash = hash
        feedId = "1"
        this.read = read
    }

    private fun next(
        stories: List<Story>,
        current: String,
        followsListOrder: Boolean,
        continueFrom: String? = null,
        queued: Set<String> = emptySet(),
        limit: Int = 10,
    ) = ListenAutoContinue
        .candidatesAfter(
            stories = stories,
            currentHash = current,
            continueFromHash = continueFrom,
            followsListOrder = followsListOrder,
            limit = limit,
            isRead = { it.read },
            isQueued = { it in queued },
        ).map { it.storyHash }

    @Test
    fun test_a_saved_list_of_read_stories_continues_in_list_order() {
        // Saved Stories sorted oldest first, everything already read: playback moves down the list as sorted.
        val saved = listOf(story("s:1", true), story("s:2", true), story("s:3", true), story("s:4", true))
        assertEquals(listOf("s:3", "s:4"), next(saved, current = "s:2", followsListOrder = true))
    }

    @Test
    fun test_a_feed_skips_read_stories() {
        val feed = listOf(story("f:1", true), story("f:2", false), story("f:3", true), story("f:4", false), story("f:5", false))
        assertEquals(listOf("f:4", "f:5"), next(feed, current = "f:2", followsListOrder = false))
        // The same list read to the end has nothing to continue to.
        assertEquals(emptyList<String>(), next(feed.map { story(it.storyHash, true) }, current = "f:2", followsListOrder = false))
    }

    @Test
    fun test_never_wraps_around_to_earlier_stories() {
        val feed = listOf(story("f:1", false), story("f:2", false), story("f:3", false))
        assertEquals(emptyList<String>(), next(feed, current = "f:3", followsListOrder = false))
        assertEquals(emptyList<String>(), next(feed, current = "f:3", followsListOrder = true))
    }

    @Test
    fun test_a_story_from_up_next_continues_after_the_last_list_story() {
        val feed = listOf(story("f:1", false), story("f:2", false), story("f:3", false))
        assertEquals(listOf("f:3"), next(feed, current = "elsewhere:9", followsListOrder = false, continueFrom = "f:2"))
        assertEquals(emptyList<String>(), next(feed, current = "elsewhere:9", followsListOrder = false, continueFrom = null))
    }

    @Test
    fun test_queued_stories_and_the_limit_apply_to_both_orders() {
        val saved = (1..6).map { story("s:$it", true) }
        assertEquals(listOf("s:2", "s:4"), next(saved, current = "s:1", followsListOrder = true, queued = setOf("s:3"), limit = 2))
        val feed = (1..6).map { story("f:$it", false) }
        assertEquals(listOf("f:2", "f:4"), next(feed, current = "f:1", followsListOrder = false, queued = setOf("f:3"), limit = 2))
    }
}
