package com.newsblur.util

import com.google.gson.Gson
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.FeedApi
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncServiceState
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertTrue
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingActionClusterReadTest {
    @Test
    fun bulkReadKeepsOriginalTimeForInitialApplyAndFollowupReplay() {
        val db = mockk<BlurDatabaseHelper>(relaxed = true)
        val action = ReadingAction.MarkFeedRead(FeedSet.singleFeed("2"), olderThan = 500, time = 100)
        val restored = ReadingAction.fromJson(ReadingAction.toJson(action))

        action.doLocal(db, mockk(relaxed = true), false)
        restored.doLocal(db, mockk(relaxed = true), true)

        verify(exactly = 2) { db.markStoriesRead(action.feedSet, 500, null, 100) }
    }

    @Test
    fun queuedSuccessAppliesAuthoritativeChildrenAndRetainsThemForFollowupReplay() = runTest {
        val db = mockk<BlurDatabaseHelper>(relaxed = true)
        val api = mockk<StoryApi>()
        coEvery { api.markStoryAsRead("1:parent", null) } returns NewsBlurResponse().apply {
            storyHashes = arrayOf("1:parent", "2:child")
        }
        val action = ReadingAction.MarkStoryRead("1:parent")
        action.doRemote(mockk(relaxed = true), mockk(), api, db, StateFilter.ALL)
        verify { db.applyStoryReadHashes(listOf("1:parent", "2:child"), true, true, action.time) }
        action.doLocal(db, mockk(relaxed = true), true)
        verify { db.applyStoryReadHashes(match { it.containsAll(listOf("1:parent", "2:child")) }, true, false, action.time) }
    }

    @Test
    fun failedQueuedResponseNeverAppliesServerHashesAndRetryPreservesOptimisticChildren() = runTest {
        val db = mockk<BlurDatabaseHelper>(relaxed = true)
        val api = mockk<StoryApi>()
        coEvery { api.markStoryAsRead("1:parent", null) } returns NewsBlurResponse().apply {
            isProtocolError = true
            storyHashes = arrayOf("4:unconfirmed")
        }
        val original = ReadingAction.MarkStoryRead("1:parent", relatedStoryHashes = listOf("2:child"))
        val action = ReadingAction.fromJson(ReadingAction.toJson(original)) as ReadingAction.MarkStoryRead
        val result = action.doRemote(mockk(relaxed = true), mockk(), api, db, StateFilter.ALL)
        assertTrue(result!!.isProtocolError)
        assertEquals(listOf("2:child"), action.relatedStoryHashes)
        verify(exactly = 0) { db.applyStoryReadHashes(any(), any(), any()) }
        verify(exactly = 0) { db.applyStoryReadHashes(any(), any(), any(), any()) }
    }
    @Test
    fun queuedExpandedReadPublishesStoryAndFeedMetadataChanges() = runTest {
        val storyApi = mockk<StoryApi>()
        val response = Gson().fromJson(
            """{"code":1,"story_hashes":["1:parent","2:match"]}""",
            NewsBlurResponse::class.java,
        )
        coEvery { storyApi.markStoryAsRead("1:parent", null) } returns response

        val result = ReadingAction.MarkStoryRead("1:parent").doRemote(
            mockk<SyncServiceState>(relaxed = true),
            mockk<FeedApi>(),
            storyApi,
            mockk<BlurDatabaseHelper>(relaxed = true),
            StateFilter.ALL,
        )

        assertEquals(UPDATE_STORY or UPDATE_METADATA, result!!.impactCode)
    }
}
