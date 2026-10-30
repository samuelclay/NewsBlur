package com.newsblur.listen

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.ReadingAction
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Test_ListenStoryRead.kt checks that a story Listen played to the end is marked read through ListenStoryRead.kt,
 * including one queued in Up Next on the web or iOS that this device has no copy of.
 */
class Test_ListenStoryRead {
    private val context = mockk<Context>(relaxed = true)
    private val feedUtils = mockk<FeedUtils>(relaxed = true)
    private val dbHelper = mockk<BlurDatabaseHelper>(relaxed = true)
    private val syncServiceState = mockk<SyncServiceState>(relaxed = true)
    private val storyRead = ListenStoryRead(context, feedUtils, dbHelper, syncServiceState)

    @Before
    fun setUp() {
        // FeedUtils.triggerSync starts SyncService.kt, which needs a real Context.
        mockkObject(FeedUtils)
        every { FeedUtils.triggerSync(any()) } just runs
    }

    @After
    fun tearDown() = unmockkObject(FeedUtils)

    private fun listenStory(
        hash: String,
        story: Story?,
    ) = ListenStory(hash, "Story $hash", hash.substringBefore(':'), null, null, null, null, story)

    private fun localStory(hash: String) =
        Story().apply {
            storyHash = hash
            read = false
        }

    @Test
    fun test_a_story_queued_elsewhere_is_marked_read_by_hash() {
        every { dbHelper.getStoryByHash("42:a") } returns null
        val action = slot<ReadingAction>()

        storyRead.markFinished(listenStory("42:a", story = null))

        // The reading action queue sends it when online and keeps it until then (SyncService.kt).
        verify(exactly = 1) { dbHelper.enqueueAction(capture(action)) }
        val queued = action.captured
        assertTrue(queued is ReadingAction.MarkStoryRead)
        assertEquals("42:a", (queued as ReadingAction.MarkStoryRead).storyHash)
        // FeedSet.equals goes through the mocked FeedUtils, so the recounted feed is read off the captured set.
        val recount = slot<Set<FeedSet>>()
        verify { syncServiceState.addRecountCandidates(capture(recount)) }
        assertEquals(listOf("42"), recount.captured.map { it.singleFeed })
        verify { FeedUtils.triggerSync(context) }
        verify(exactly = 0) { feedUtils.markStoryAsRead(any(), any(), any()) }
    }

    @Test
    fun test_a_copy_that_arrived_after_the_story_was_queued_is_marked_read_locally() {
        val arrived = localStory("42:b")
        every { dbHelper.getStoryByHash("42:b") } returns arrived

        storyRead.markFinished(listenStory("42:b", story = null))

        verify { feedUtils.markStoryAsRead(arrived, context) }
        verify(exactly = 0) { dbHelper.enqueueAction(any()) }
    }

    @Test
    fun test_the_copy_listen_started_with_is_marked_read_locally() {
        val story = localStory("42:c")

        storyRead.markFinished(listenStory("42:c", story = story))

        verify { feedUtils.markStoryAsRead(story, context) }
        verify(exactly = 0) { dbHelper.getStoryByHash(any()) }
        verify(exactly = 0) { dbHelper.enqueueAction(any()) }
    }
}
