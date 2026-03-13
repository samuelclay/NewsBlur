package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.NewsBlurResponse
import io.mockk.every
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryApiImplReadTimeTest {
    private val networkClient = mockk<NetworkClient>()
    private val storyApi = StoryApiImpl(Gson(), networkClient)
    private val apiResponse = mockk<APIResponse>()

    init {
        every { apiResponse.getResponse(any(), NewsBlurResponse::class.java) } returns mockk(relaxed = true)
    }

    @Test
    fun markStoryAsReadIncludesQueuedReadTimes() =
        runTest {
            val urls = mutableListOf<String>()
            val values = mutableListOf<ValueMultimap>()
            coEvery { networkClient.post(capture(urls), capture(values)) } returns apiResponse

            storyApi.markStoryAsRead("story-hash", """{"story-hash":12}""")

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_MARK_STORIES_READ), urls.single())
            val body = values.single().asFormEncodedRequestBody().utf8()
            assertTrue(body.contains("story_hash=story-hash"))
            assertTrue(body.contains("read_times=%7B%22story-hash%22%3A12%7D"))
        }

    @Test
    fun submitReadTimesPostsWithoutStoryHash() =
        runTest {
            val values = mutableListOf<ValueMultimap>()
            coEvery { networkClient.post(any(), capture(values)) } returns apiResponse

            storyApi.submitReadTimes("""{"story-hash":12}""")

            val body = values.single().asFormEncodedRequestBody().utf8()
            assertTrue(body.contains("read_times=%7B%22story-hash%22%3A12%7D"))
            assertFalse(body.contains("story_hash="))
        }

    private fun okhttp3.RequestBody.utf8(): String =
        Buffer().also { writeTo(it) }.readUtf8()
}
