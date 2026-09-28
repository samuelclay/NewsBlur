package com.newsblur.addsite

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.APIResponse
import com.newsblur.network.FeedApiImpl
import com.newsblur.network.NetworkClient
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okhttp3.FormBody
import org.junit.Assert.assertEquals
import org.junit.Test

class AddSiteSearchApiTest {
    @Test fun searchRequestsFullFeedDataAndParsesFreshness() =
        runTest {
            val network = mockk<NetworkClient>()
            val response = mockk<APIResponse>()
            val requests = mutableListOf<ValueMultimap>()
            every { response.isError } returns false
            every { response.responseBody } returns
                """[{"id":1,"feed_title":"kottke.org","feed_address":"https://feeds.kottke.org/main","num_subscribers":15430,"last_story_seconds_ago":172800}]"""
            coEvery { network.get(any(), capture(requests)) } returns response
            val result = FeedApiImpl(Gson(), network).searchForFeed("kottke")!!.single()
            val body = requests.single().asFormEncodedRequestBody() as FormBody
            val values = (0 until body.size).associate { body.name(it) to body.value(it) }
            assertEquals("full", values["format"])
            assertEquals("10", values["limit"])
            assertEquals("kottke", values["term"])
            assertEquals("kottke.org", result.label)
            assertEquals("https://feeds.kottke.org/main", result.url)
            assertEquals("2d ago", SiteFreshness.from(result.lastStorySecondsAgo)?.text)
            assertEquals(15430, result.numberOfSubscriber)
        }
}
