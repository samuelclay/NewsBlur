package com.newsblur.util

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.network.FolderApi
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceState
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FeedUtilsImmediateReadSyncTest {
    private val dbHelper = mockk<BlurDatabaseHelper>(relaxed = true)
    private val folderApi = mockk<FolderApi>(relaxed = true)
    private val prefsRepo = mockk<PrefsRepo>(relaxed = true)
    private val syncServiceState = mockk<SyncServiceState>(relaxed = true)
    private val tryFeedStore = mockk<TryFeedStore>(relaxed = true)
    private val storyApi = mockk<StoryApi>()
    private val context = mockk<Context>(relaxed = true)

    private val feedUtils =
        FeedUtils(
            dbHelper = dbHelper,
            folderApi = folderApi,
            prefsRepo = prefsRepo,
            syncServiceState = syncServiceState,
            tryFeedStore = tryFeedStore,
            storyApi = storyApi,
        )

    @Test
    fun syncStoryAsReadNowPostsImmediatelyWithoutQueueingOnSuccess() =
        runTest {
            val story = unreadStory()
            every { dbHelper.setStoryReadState(story, true) } returns emptySet()
            every { syncServiceState.addRecountCandidates(any()) } just runs
            coEvery { storyApi.markStoryAsRead(story.storyHash, """{"story-hash":12}""") } returns NewsBlurResponse()

            feedUtils.syncStoryAsReadNow(story, context, """{"story-hash":12}""")

            coVerify { storyApi.markStoryAsRead("story-hash", """{"story-hash":12}""") }
            verify(exactly = 0) { dbHelper.enqueueAction(any()) }
        }

    @Test
    fun syncStoryAsReadNowQueuesFallbackWhenImmediatePostFails() =
        runTest {
            val story = unreadStory()
            val protocolError = NewsBlurResponse().apply { isProtocolError = true }
            val queuedAction = slot<ReadingAction>()
            every { dbHelper.setStoryReadState(story, true) } returns emptySet()
            every { syncServiceState.addRecountCandidates(any()) } just runs
            coEvery { storyApi.markStoryAsRead(story.storyHash, null) } returns protocolError

            feedUtils.syncStoryAsReadNow(story, context)

            verify { dbHelper.enqueueAction(capture(queuedAction)) }
            val action = queuedAction.captured
            assertTrue(action is ReadingAction.MarkStoryRead)
            action as ReadingAction.MarkStoryRead
            assertEquals("story-hash", action.storyHash)
            assertNull(action.readTimesJson)
        }

    @Test
    fun submitReadTimesNowQueuesFallbackWhenImmediateFlushFails() =
        runTest {
            val protocolError = NewsBlurResponse().apply { isProtocolError = true }
            val queuedAction = slot<ReadingAction>()
            coEvery { storyApi.submitReadTimes("""{"story-hash":12}""") } returns protocolError

            feedUtils.submitReadTimesNow(context, """{"story-hash":12}""")

            verify { dbHelper.enqueueAction(capture(queuedAction)) }
            val action = queuedAction.captured
            assertTrue(action is ReadingAction.ReportStoryReadTimes)
            action as ReadingAction.ReportStoryReadTimes
            assertEquals("""{"story-hash":12}""", action.readTimesJson)
        }

    private fun unreadStory() =
        Story().apply {
            storyHash = "story-hash"
            read = false
        }
}
