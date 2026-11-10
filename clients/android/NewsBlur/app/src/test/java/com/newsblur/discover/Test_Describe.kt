package com.newsblur.discover

import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.MainDispatcherRule
import com.newsblur.network.FeedApi
import com.newsblur.preference.DiscoveryPreferencesFixture
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

// Test_Describe.kt covers the payload parsing in DescribeModels.kt and the search lifecycle in DiscoveryViewModel.kt.
@OptIn(ExperimentalCoroutinesApi::class)
class Test_Describe {
    @get:Rule val main = MainDispatcherRule()
    private val api = mockk<DiscoveryApi>()
    private val feeds = mockk<FeedApi>()
    private val describe = mockk<DescribeApi>()
    private val viewPreferences = DiscoveryPreferencesFixture().preference

    private fun json(value: String) = JsonParser.parseString(value).asJsonObject

    private fun model(saved: SavedStateHandle = SavedStateHandle()) =
        DiscoveryViewModel(api, feeds, describe, saved, viewPreferences).apply { workerDispatcher = main.dispatcher }

    // Test_Describe.kt: the shape of MDescribeSearch.to_payload() in apps/describe/models.py.
    private fun payload(
        status: String,
        phase: String,
        results: String = "[]",
        message: String = "",
    ) = json(
        """{"id":"abc123","prompt":"reviews of iOS apps","status":"$status","phase":"$phase",
            "created_date":"2026-11-04T22:32:57.202928","completed_date":null,"result_count":0,"request_id":"req-1",
            "phase_message":"$message","sub_queries":["iOS app reviews"],"error":null,"stats":{},"results":$results}""",
    )

    private fun search(
        status: String,
        phase: String,
        results: String = "[]",
        message: String = "",
    ) = DescribeSearch.parse(payload(status, phase, results, message))!!

    private val judgedRow =
        """{"feed_id":42,"feed_title":"App Reviews","feed_address":"https://example.com/rss","feed_link":"https://example.com",
            "source":"index","matched_query":"iOS app reviews","similarity":0.8123,"score":9,
            "reason":"Weekly reviews with screenshots.","judged":true,
            "stories":[{"story_title":"Review: Things 4","story_permalink":"https://example.com/things","story_date":"2026-11-01T10:00:00"}],
            "feed":{"id":42,"feed_title":"App Reviews","feed_address":"https://example.com/rss","feed_link":"https://example.com",
                "num_subscribers":120,"average_stories_per_month":8,"last_story_date":"2026-11-01T10:00:00",
                "favicon_url":"https://example.com/favicon.png","favicon_color":"ffffff"}}"""

    private val pendingRow =
        """{"feed_id":7,"feed_title":"Web Find","feed_address":"https://web.example/feed","feed_link":"https://web.example",
            "source":"web","matched_query":"","similarity":null,"score":null,"reason":null,"judged":false,"stories":[],
            "feed":{"id":7,"feed_title":"Web Find","feed_address":"https://web.example/feed","feed_link":"https://web.example","num_subscribers":0}}"""

    @Test fun test_search_payload_parses_results_and_hydrated_feed() {
        val search = search("running", "judging", "[$judgedRow,$pendingRow]", "Judging 2 feeds")
        assertEquals("abc123", search.id)
        assertTrue(search.running)
        assertEquals(DescribePhase.JUDGING, DescribePhase.entries[DescribePhase.indexOf(search.phase)])
        assertEquals(listOf("iOS app reviews"), search.subQueries)
        assertEquals("Judging 2 feeds", search.phaseMessage)
        assertEquals(2, search.summary.resultCount)

        val judged = search.results[0]
        assertEquals("42", judged.feedId)
        assertEquals("42", judged.feed.id)
        assertEquals("https://example.com/rss", judged.feed.url)
        assertEquals("https://example.com", judged.feed.link)
        assertEquals(120, judged.feed.subscribers)
        assertEquals(8, judged.feed.storiesPerMonth)
        assertEquals("https://example.com/favicon.png", judged.feed.image)
        assertEquals(9, judged.score)
        assertTrue(judged.judged)
        assertFalse(judged.fromWeb)
        assertEquals(0.8123, judged.similarity!!, 0.0001)
        assertEquals("Review: Things 4", judged.feed.stories.single().title)
        assertNotNull(judged.feed.stories.single().timestamp)

        val pending = search.results[1]
        assertEquals("7", pending.feed.id)
        assertNull(pending.score)
        assertFalse(pending.judged)
        assertTrue(pending.fromWeb)
        assertNull(pending.similarity)
        assertEquals("", pending.reason)
        assertNull(DescribeResult.parse(json("""{"feed_id":0,"feed_address":"https://example.com/rss"}""")))
    }

    @Test fun test_start_reply_distinguishes_started_from_upgrade_denial() {
        val started =
            DescribeStart.parse(
                json(
                    """{"code":1,"search":${payload("queued", "queued")},
                        "usage":{"tier":"premium","limit":10,"used":3,"remaining":7,"resets_in":"5 hours"}}""",
                ),
            ) as DescribeStart.Started
        assertEquals("abc123", started.search.id)
        assertEquals(7, started.usage?.remaining)
        assertEquals(10, started.usage?.limit)
        assertFalse(started.usage!!.locked)

        val denied =
            DescribeStart.parse(
                json(
                    """{"code":-1,"message":"Upgrade to search.","upgrade":true,
                        "usage":{"tier":"free","limit":0,"used":0,"remaining":0,"resets_in":null}}""",
                ),
            ) as DescribeStart.Denied
        assertTrue(denied.upgrade)
        assertTrue(denied.usage!!.locked)
        assertEquals("Upgrade to search.", denied.message)

        val unlimited = DescribeUsage.parse(json("""{"tier":"pro","limit":null,"used":0,"remaining":null,"resets_in":null}"""))!!
        assertNull(unlimited.limit)
        assertFalse(unlimited.locked)
        assertNull(DescribeUsage.parse(null))
    }

    @Test fun test_polling_updates_results_in_place_until_complete() = runTest {
        coEvery { describe.history() } returns DescribeHistory(emptyList(), DescribeUsage("pro", null, 0, null, ""))
        coEvery { describe.start("reviews of iOS apps", null, any()) } returns DescribeStart.Started(search("queued", "queued"), null)
        coEvery { describe.status("abc123") } returnsMany
            listOf(
                search("running", "searching", "[$pendingRow]", "Searching"),
                search("running", "judging", "[$judgedRow,$pendingRow]", "Judging"),
                search("complete", "complete", "[$judgedRow]"),
            )
        val saved = SavedStateHandle()
        val model = model(saved)
        model.selectTab(DiscoveryTab.DESCRIBE)
        model.describeEdit("reviews of iOS apps")
        model.describeStart()
        runCurrent()
        assertEquals("queued", model.state.value.describe.search?.status)
        assertEquals(listOf("abc123"), model.state.value.describe.history.map { it.id })
        assertFalse(model.state.value.describe.starting)

        // Test_Describe.kt: DiscoveryViewModel.kt polls status every 2.5 seconds while the search is queued or running.
        advanceTimeBy(2600)
        runCurrent()
        assertEquals(listOf("7"), model.state.value.describe.search?.results?.map { it.feedId })
        model.describeEdit("typing a new prompt")
        advanceTimeBy(2500)
        runCurrent()
        assertEquals(listOf("42", "7"), model.state.value.describe.search?.results?.map { it.feedId })
        assertEquals(9, model.state.value.describe.search?.results?.first()?.score)
        // A poll never overwrites what is being typed in the composer.
        assertEquals("typing a new prompt", model.state.value.describe.prompt)
        advanceTimeBy(2500)
        runCurrent()
        assertEquals("complete", model.state.value.describe.search?.status)
        assertEquals(listOf("42"), model.state.value.describe.search?.results?.map { it.feedId })
        assertEquals(1, model.state.value.describe.history.single().resultCount)
        assertEquals("abc123", saved.get<String>(DiscoveryViewModel.DESCRIBE_SEARCH_ID))
        advanceUntilIdle()
        coVerify(exactly = 3) { describe.status("abc123") }
    }

    @Test fun test_history_replay_resumes_polling_and_delete_clears_the_open_search() = runTest {
        val running = DescribeSummary("abc123", "reviews of iOS apps", "running", "judging", "2026-11-04T22:32:57", "", 0)
        val done = DescribeSummary("old1", "cities", "complete", "complete", "2026-11-03T10:00:00", "2026-11-03T10:01:00", 3)
        coEvery { describe.history() } returns DescribeHistory(listOf(running, done), null)
        coEvery { describe.status("abc123") } returnsMany
            listOf(search("running", "judging", "[$pendingRow]"), search("complete", "complete", "[$judgedRow]"))
        coEvery { describe.delete("abc123") } returns listOf(done)
        val model = model()
        model.selectTab(DiscoveryTab.DESCRIBE)
        runCurrent()
        assertEquals(listOf("abc123", "old1"), model.state.value.describe.history.map { it.id })

        model.describeOpen("abc123")
        assertTrue(model.state.value.describe.loading)
        runCurrent()
        assertFalse(model.state.value.describe.loading)
        assertEquals("reviews of iOS apps", model.state.value.describe.prompt)
        assertTrue(model.state.value.describe.search!!.running)
        advanceTimeBy(2600)
        runCurrent()
        assertEquals("complete", model.state.value.describe.search?.status)
        assertEquals(1, model.state.value.describe.history.first { it.id == "abc123" }.resultCount)

        model.describeDelete("abc123")
        runCurrent()
        assertNull(model.state.value.describe.search)
        assertEquals("", model.state.value.describe.prompt)
        assertEquals(listOf("old1"), model.state.value.describe.history.map { it.id })
        advanceUntilIdle()
        coVerify(exactly = 2) { describe.status("abc123") }
    }

    @Test fun test_search_again_reruns_in_place_and_moves_to_the_top() = runTest {
        val done = DescribeSummary("old1", "cities", "complete", "complete", "2026-11-03T10:00:00", "2026-11-03T10:01:00", 3)
        val earlier = DescribeSummary("abc123", "reviews of iOS apps", "complete", "complete", "2026-11-02T10:00:00", "", 1)
        coEvery { describe.history() } returns DescribeHistory(listOf(done, earlier), null)
        coEvery { describe.status("abc123") } returns search("complete", "complete", "[$judgedRow]")
        coEvery { describe.start("reviews of iOS apps", "abc123", any()) } returns DescribeStart.Started(search("queued", "queued"), null)
        val model = model()
        model.selectTab(DiscoveryTab.DESCRIBE)
        model.describeOpen("abc123")
        runCurrent()
        assertEquals(listOf("old1", "abc123"), model.state.value.describe.history.map { it.id })
        assertEquals(listOf("42"), model.state.value.describe.search?.results?.map { it.feedId })

        model.describeAgain()
        runCurrent()
        assertEquals("queued", model.state.value.describe.search?.status)
        assertTrue(model.state.value.describe.search!!.results.isEmpty())
        assertEquals(listOf("abc123", "old1"), model.state.value.describe.history.map { it.id })
        coVerify(exactly = 1) { describe.start("reviews of iOS apps", "abc123", any()) }

        model.describeNew()
        assertNull(model.state.value.describe.search)
        assertEquals("", model.state.value.describe.prompt)
        advanceUntilIdle()
        // Test_Describe.kt: "New" cancels the poll; the only status call was the replay.
        coVerify(exactly = 1) { describe.status(any()) }
    }

    @Test fun test_seeded_prompt_opens_describe_tab_and_free_accounts_see_the_upgrade_card() = runTest {
        val free = DescribeUsage("free", 0, 0, 0, "")
        coEvery { describe.history() } returns DescribeHistory(emptyList(), free)
        coEvery { describe.start("indie game devlogs", null, any()) } returns
            DescribeStart.Denied("Upgrade to search by description.", true, free)
        val saved =
            SavedStateHandle(
                mapOf(DiscoveryViewModel.TAB to DiscoveryTab.SEARCH.name, DiscoveryViewModel.DESCRIBE_PROMPT to "indie game devlogs"),
            )
        val model = model(saved)
        model.describeSeed(saved[DiscoveryViewModel.DESCRIBE_PROMPT]!!)
        model.start()
        runCurrent()
        assertEquals(DiscoveryTab.DESCRIBE, model.state.value.tab)
        assertEquals("indie game devlogs", model.state.value.describe.prompt)
        assertEquals("Upgrade to search by description.", model.state.value.describe.upgradeMessage)
        assertTrue(model.state.value.describe.showsUpgrade)
        assertFalse(model.state.value.describe.starting)
        assertNull(model.state.value.describe.search)
        assertNull(model.state.value.describe.error)
        coVerify(exactly = 0) { describe.status(any()) }
    }

    @Test fun test_start_failure_reports_server_message_or_fallback() = runTest {
        coEvery { describe.history() } returns DescribeHistory(emptyList(), null)
        coEvery { describe.start("ab cd", null, any()) } returns
            DescribeStart.Denied("Describe what you'd like to read in a few words.", false, null)
        coEvery { describe.start("offline", null, any()) } throws DescribeRequestException(null)
        val model = model()
        model.selectTab(DiscoveryTab.DESCRIBE)
        model.describeStart("ab cd")
        runCurrent()
        assertEquals(DescribeError.Message("Describe what you'd like to read in a few words."), model.state.value.describe.error)
        assertNull(model.state.value.describe.upgradeMessage)
        assertFalse(model.state.value.describe.showsUpgrade)

        model.describeStart("offline")
        runCurrent()
        assertEquals(DescribeError.StartFailed, model.state.value.describe.error)
        assertFalse(model.state.value.describe.starting)
    }

    @Test fun test_open_search_is_restored_from_history_after_recreation() = runTest {
        val summary = DescribeSummary("abc123", "reviews of iOS apps", "complete", "complete", "2026-11-04T22:32:57", "", 1)
        coEvery { describe.history() } returns DescribeHistory(listOf(summary), null)
        coEvery { describe.status("abc123") } returns search("complete", "complete", "[$judgedRow]")
        val saved = SavedStateHandle(mapOf(DiscoveryViewModel.DESCRIBE_SEARCH_ID to "abc123", DiscoveryViewModel.TAB to "DESCRIBE"))
        val model = model(saved)
        model.start()
        runCurrent()
        assertEquals(listOf("42"), model.state.value.describe.search?.results?.map { it.feedId })
        assertEquals("reviews of iOS apps", model.state.value.describe.prompt)
    }
}
