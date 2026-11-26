package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.network.domain.UnreadStoryHashesResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_StoryApiUnreadHashFeeds {
    @Test
    fun test_filtered_unread_hash_request_repeats_feed_id_for_each_feed() =
        runTest {
            val networkClient = mockk<NetworkClient>()
            val apiResponse = mockk<APIResponse>()
            val values = mutableListOf<ValueMultimap>()
            every { apiResponse.getResponse(any(), UnreadStoryHashesResponse::class.java) } returns UnreadStoryHashesResponse()
            coEvery { networkClient.get(APIConstants.buildUrl(APIConstants.PATH_UNREAD_HASHES), capture(values)) } returns apiResponse

            StoryApiImpl(Gson(), networkClient).getUnreadStoryHashes(listOf("11", "22"))

            // apps/reader/views.py unread_story_hashes reads the feeds with request.GET.getlist("feed_id").
            val parameters = Buffer().also { values.single().asFormEncodedRequestBody().writeTo(it) }.readUtf8().split("&")
            assertEquals(listOf("feed_id=11", "feed_id=22", "include_timestamps=1"), parameters.sorted())
        }

    @Test
    fun test_cancellable_lookups_use_the_request_a_timeout_can_abort() =
        runTest {
            val networkClient = mockk<NetworkClient>()
            val apiResponse = mockk<APIResponse>()
            every { apiResponse.getResponse(any(), UnreadStoryHashesResponse::class.java) } returns UnreadStoryHashesResponse()
            every { apiResponse.getResponse(any(), StoriesResponse::class.java) } returns StoriesResponse()
            // NetworkClientImpl.kt's plain get retries with blocking sleeps that no coroutine timeout interrupts.
            coEvery { networkClient.getCancellable(any(), any()) } returns apiResponse
            val storyApi = StoryApiImpl(Gson(), networkClient)

            storyApi.getUnreadStoryHashes(listOf("11"), cancellable = true)
            storyApi.getStoriesByHash(listOf("11:abc"), cancellable = true)

            coVerify(exactly = 1) { networkClient.getCancellable(APIConstants.buildUrl(APIConstants.PATH_UNREAD_HASHES), any()) }
            coVerify(exactly = 1) { networkClient.getCancellable(APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES), any()) }
        }
}
