package com.newsblur.network

import com.google.gson.GsonBuilder
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.serialization.BooleanTypeAdapter
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryApiReadAuthorityTest {
    private val gson = GsonBuilder()
        .registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
        .create()

    @Test fun regularStoryResponsesKeepAuthoritativeUnreadState() {
        val response = gson.fromJson("""{"stories":[{"read_status":0}]}""", StoriesResponse::class.java)
        assertTrue(response.readStatusAuthoritative)
        assertFalse(response.stories.single().read)
    }

    @Test fun hashLookupMarksReadStateAsUnavailable() = runTest {
        val client = mockk<NetworkClient>()
        val apiResponse = mockk<APIResponse>()
        val response = gson.fromJson("""{"stories":[{"read_status":0}]}""", StoriesResponse::class.java)
        coEvery { client.get(APIConstants.buildUrl(APIConstants.PATH_RIVER_STORIES), any<ValueMultimap>()) } returns apiResponse
        every { apiResponse.getResponse(any(), StoriesResponse::class.java) } returns response

        val result = StoryApiImpl(gson, client).getStoriesByHash(listOf("542993:48c9aa"))!!

        assertFalse(result.readStatusAuthoritative)
        assertFalse(result.stories.single().read)
    }

    @Test fun authorityIsLocalTransportMetadata() {
        val response = gson.fromJson("""{"readStatusAuthoritative":false}""", StoriesResponse::class.java)
        assertTrue(response.readStatusAuthoritative)
        assertFalse(gson.toJsonTree(response).asJsonObject.has("readStatusAuthoritative"))
    }
}
