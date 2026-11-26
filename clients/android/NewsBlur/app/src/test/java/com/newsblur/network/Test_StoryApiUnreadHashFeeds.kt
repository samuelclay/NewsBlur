package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.UnreadStoryHashesResponse
import io.mockk.coEvery
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
}
