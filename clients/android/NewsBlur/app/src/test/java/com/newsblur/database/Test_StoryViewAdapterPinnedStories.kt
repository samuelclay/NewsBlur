package com.newsblur.database

import com.newsblur.domain.Story
import com.newsblur.util.StoryOrder
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_StoryViewAdapterPinnedStories {
    // NewStoriesPill.kt pins a story published days ago to the top of a newest-first list. After the reader comes
    // back to the list, StoryViewAdapter.kt holds back stories newer than the ones on screen; measuring "on screen"
    // with the pinned story would hold back every following page dated after it too.
    @Test
    fun test_aStoryPinnedToTheTopDoesNotHoldBackLaterPagesAfterAResume() {
        val pinned = story("1:sunday", 1_000)
        val listed = listOf(pinned, story("1:a", 5_000), story("1:b", 4_000), story("1:c", 3_000))
        val adapter = adapter(listed, StoryOrder.NEWEST)
        val nextPage = story("1:next-page", 2_500)
        val heldBack = story("1:arrived-while-away", 4_500)

        val shown = skipBackfill(adapter, listed + nextPage + heldBack, setOf(pinned.storyHash))

        assertEquals(listed.map { it.storyHash } + nextPage.storyHash, shown.map { it.storyHash })
    }

    private fun story(
        hash: String,
        timestamp: Long,
    ) = Story().apply {
        storyHash = hash
        feedId = "1"
        this.timestamp = timestamp
    }

    private fun adapter(
        listed: List<Story>,
        order: StoryOrder,
    ): StoryViewAdapter {
        val adapter = mockk<StoryViewAdapter>(relaxed = true)
        fun field(
            name: String,
            value: Any,
        ) {
            StoryViewAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
        }
        field("stories", listed.toMutableList())
        field("storyOrder", order)
        every { adapter["applySkipBackfill"](any<List<Story>>(), any<Boolean>(), any<Set<String>>()) } answers { callOriginal() }
        return adapter
    }

    @Suppress("UNCHECKED_CAST")
    private fun skipBackfill(
        adapter: StoryViewAdapter,
        incoming: List<Story>,
        pinned: Set<String>,
    ): List<Story> =
        StoryViewAdapter::class.java
            .getDeclaredMethod("applySkipBackfill", List::class.java, Boolean::class.javaPrimitiveType, Set::class.java)
            .apply { isAccessible = true }
            .invoke(adapter, incoming, true, pinned) as List<Story>
}
