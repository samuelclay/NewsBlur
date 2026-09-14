package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.domain.Feed
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.StoriesResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ReaderTargetLoaderTest {
    private val api = mockk<StoryApi>()
    private val database = mockk<BlurDatabaseHelper>(relaxed = true)
    private val hash = "9959362:8b82ea"

    @Test fun oldChildLoadsByExactHashWithoutFeedPaginationAndKeepsNormalizedReadState() = runTest {
        val child = Story().apply { storyHash = hash; feedId = "9959362" }
        val response = StoriesResponse().apply {
            stories = arrayOf(child)
            readStatusAuthoritative = false
        }
        coEvery { api.getStoriesByHash(listOf(hash)) } returns response
        every { database.getFeed("9959362") } returns Feed().apply { title = "Google News"; faviconUrl = "https://example.com/icon.png" }
        every { database.insertStories(response, StateFilter.ALL, false) } answers {
            assertFalse(response.readStatusAuthoritative)
            child.read = true // ReaderTargetLoaderTest models the existing DB read-state merge.
        }

        val result = ReaderTargetLoader(api, database).load(hash)

        assertSame(child, result)
        assertTrue(result!!.read)
        assertEquals("Google News", result.extern_feedTitle)
        assertEquals("https://example.com/icon.png", result.extern_faviconUrl)
        coVerify(exactly = 1) { api.getStoriesByHash(listOf(hash)) }
        coVerify(exactly = 0) { api.getStories(any(), any(), any(), any(), any()) }
        verify(exactly = 1) { database.insertStories(response, StateFilter.ALL, false) }
    }

    @Test fun unavailableChildIsTerminalWithoutStoringUnrelatedResults() = runTest {
        coEvery { api.getStoriesByHash(listOf(hash)) } returns StoriesResponse().apply {
            stories = arrayOf(Story().apply { storyHash = "9959362:other" })
        }
        assertNull(ReaderTargetLoader(api, database).load(hash))
        verify(exactly = 0) { database.insertStories(any(), any(), any()) }
    }

    @Test fun networkFailureAndTimeoutAreTerminal() = runTest {
        coEvery { api.getStoriesByHash(listOf(hash)) } throws IllegalStateException("offline")
        assertNull(ReaderTargetLoader(api, database).load(hash))
        coEvery { api.getStoriesByHash(listOf(hash)) } coAnswers { delay(60_000); null }
        assertNull(ReaderTargetLoader(api, database).load(hash))
        assertTrue(testScheduler.currentTime < 60_000)
    }

    @Test fun leavingReaderCancelsTheRequest() = runTest {
        coEvery { api.getStoriesByHash(listOf(hash)) } throws CancellationException("reader closed")
        try {
            ReaderTargetLoader(api, database).load(hash)
            fail("Cancellation must reach the reader lifecycle")
        } catch (_: CancellationException) {
        }
    }

    @Test fun lateResponseAfterCancellationCannotBeStored() = runTest {
        coEvery { api.getStoriesByHash(listOf(hash)) } coAnswers {
            currentCoroutineContext().cancel()
            StoriesResponse().apply { stories = arrayOf(Story().apply { storyHash = hash }) }
        }
        val request = launch { ReaderTargetLoader(api, database).load(hash) }
        request.join()
        assertTrue(request.isCancelled)
        verify(exactly = 0) { database.insertStories(any(), any(), any()) }
    }
}
