package com.newsblur.onboarding

import android.content.Context
import com.google.gson.JsonParser
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SetupQueueTest {
    private val dispatcher = StandardTestDispatcher()
    private val account = SetupAccount("https://test", "cookie", "login-1")
    private val api = mockk<OnboardingApi>()
    private val feed = DiscoveryFeed("https://a.test/rss", "A", "10")

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        mockkObject(FeedUtils.Companion)
        every { FeedUtils.triggerSync(any()) } just Runs
        every { api.isCurrent(account) } returns true
    }

    @After fun tearDown() {
        unmockkAll()
        Dispatchers.resetMain()
    }

    private fun queue() = SetupQueue(api, mockk<SyncServiceState>(relaxed = true), mockk<Context>()).apply { bind(account) }

    private fun response(value: String) = SetupResponse(JsonParser.parseString(value).asJsonObject, null)

    @Test fun accountChangeDuringCapabilityProbePreventsEveryWrite() =
        runTest(dispatcher) {
            coEvery { api.request(any(), any(), any(), any(), any(), any()) } coAnswers {
                every { api.isCurrent(account) } returns false
                response("""{"batch_add_supported":true}""")
            }
            queue().enqueue(listOf(feed), "Science")
            advanceUntilIdle()
            coVerify(exactly = 0) { api.request(any(), any(), true, any(), any(), any()) }
        }

    @Test fun ambiguousBatchFailureNeverFallsBackAndIsExcludedFromAcceptedSummary() =
        runTest(dispatcher) {
            coEvery { api.request("/reader/add_feeds", any(), false, any(), any(), any()) } returns
                response("""{"batch_add_supported":true}""")
            coEvery { api.request("/reader/add_feeds", any(), true, any(), any(), any()) } throws java.io.IOException("connection lost")
            val queue = queue()
            queue.enqueue(listOf(feed), "Science")
            advanceUntilIdle()
            coVerify(exactly = 0) { api.request("/reader/add_url", any(), any(), any(), any(), any()) }
            assertTrue(
                queue.state.value.added
                    .isEmpty(),
            )
            assertTrue(
                queue.state.value.queued
                    .isEmpty(),
            )
            assertEquals(
                listOf(feed),
                queue.state.value.failures
                    .single()
                    .feeds,
            )
        }

    @Test fun partialBatchRetriesOnlyFailedFeedsInOriginalNestedFolder() =
        runTest(dispatcher) {
            val second = feed.copy(id = "11", url = "https://b.test/rss")
            coEvery { api.request("/reader/add_feeds", any(), false, any(), any(), any()) } returns
                response("""{"batch_add_supported":true}""")
            coEvery { api.request("/reader/add_feeds", any(), true, any(), any(), any()) } returnsMany
                listOf(
                    response("""{"results":[{"code":1,"feed_id":10},{"code":-1,"feed_id":11}]}"""),
                    response("""{"results":[{"code":1,"feed_id":11}]}"""),
                )
            val queue = queue()
            queue.enqueue(listOf(feed, second), "News ▸ Local", existing = true)
            advanceUntilIdle()
            queue.retry(
                queue.state.value.failures
                    .single(),
            )
            advanceUntilIdle()
            coVerify(exactly = 1) {
                api.request(
                    "/reader/add_feeds",
                    match {
                        it["feed_ids"] == "[11]" &&
                            it["folder_path"] == "[\"News\",\"Local\"]" &&
                            "new_folder" !in it
                    },
                    true,
                    account,
                    any(),
                    any(),
                )
            }
            assertEquals(setOf(feed.url, second.url), queue.state.value.added)
            assertTrue(
                queue.state.value.failures
                    .isEmpty(),
            )
        }
}
