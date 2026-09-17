package com.newsblur.discover

import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.MainDispatcherRule
import com.newsblur.domain.Feed
import com.newsblur.network.FeedApi
import com.newsblur.network.domain.AddFeedResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_Discovery {
    @get:Rule val main = MainDispatcherRule()
    private val api = mockk<DiscoveryApi>()
    private val feeds = mockk<FeedApi>()

    private fun json(value: String) = JsonParser.parseString(value).asJsonObject

    private fun model(saved: SavedStateHandle = SavedStateHandle()) =
        DiscoveryViewModel(api, feeds, saved).apply {
            workerDispatcher =
                main.dispatcher
        }

    private fun result(url: String) = json("""{"feeds":[{"feed_url":"$url","title":"Test"}]}""")

    @Test fun test_catalog_id_is_not_a_feed_id() {
        val feed = DiscoveryFeed.parse(json("""{"id":912,"feed_url":"https://example.com/rss","title":"Example"}"""))!!
        assertEquals("", feed.id)
        assertEquals("Example", feed.title)
    }

    @Test fun test_nested_feed_and_source_shapes() {
        val feed =
            DiscoveryFeed.parse(
                json(
                    """{"feed_id":12,"feed":{"id":42,"feed_address":"https://example.com/rss","feed_title":"Example"},"stories":[{"story_title":"Hello"}]}""",
                ),
            )!!
        assertEquals("42", feed.id)
        assertEquals(listOf("Hello"), feed.stories)
        val source =
            DiscoveryFeed.parse(
                json(
                    """{"id":"external-id","name":"Channel","feed_url":"https://youtube.com/rss","thumbnail":"https://example.com/image"}""",
                ),
            )!!
        assertEquals("", source.id)
        assertEquals("Channel", source.title)
        assertEquals("https://example.com/image", source.image)
    }

    @Test fun test_autocomplete_and_missing_address() {
        assertEquals("9", DiscoveryFeed.parse(json("""{"id":9,"value":"https://example.com","label":"Example"}"""), true)!!.id)
        assertNull(DiscoveryFeed.parse(json("""{"id":9,"title":"No URL"}""")))
    }

    @Test fun test_search_debounce_and_stale_completion() =
        runTest {
            val old = CompletableDeferred<com.google.gson.JsonObject>()
            coEvery { api.request("/discover/autocomplete", match { it["term"] == "old" }, false) } coAnswers
                { withContext(NonCancellable) { old.await() } }
            coEvery { api.request("/discover/autocomplete", match { it["term"] == "new" }, false) } returns result("https://new")
            val model = model()
            model.queryChanged("o")
            advanceTimeBy(200)
            model.queryChanged("old")
            advanceTimeBy(350)
            runCurrent()
            model.queryChanged("new")
            advanceTimeBy(350)
            runCurrent()
            old.complete(result("https://old"))
            advanceUntilIdle()
            assertEquals(
                listOf("https://new"),
                model.state.value.page.feeds
                    .map { it.url },
            )
            coVerify(exactly = 0) { api.request(any(), match { it["term"] == "o" }, any()) }
        }

    @Test fun test_clear_search_restores_trending() =
        runTest {
            coEvery { api.request("/discover/trending", any(), false) } returns
                json("""{"trending_feeds":{"7":{"feed":{"id":7,"feed_address":"https://trending","feed_title":"Trending"}}}}""")
            val model = model()
            model.queryChanged("draft")
            model.queryChanged("")
            advanceUntilIdle()
            assertEquals(
                "7",
                model.state.value.page.feeds
                    .single()
                    .id,
            )
            assertFalse(model.state.value.page.loading)
        }

    @Test fun test_source_failure_preserves_catalog_results() =
        runTest {
            coEvery { api.request("/discover/popular_feeds", any(), false) } returns result("https://catalog")
            coEvery { api.request("/discover/youtube/search", any(), false) } throws java.io.IOException("Source unavailable")
            val model = model()
            model.selectTab(DiscoveryTab.YOUTUBE)
            advanceUntilIdle()
            model.queryChanged("cats")
            advanceUntilIdle()
            assertEquals(
                "https://catalog",
                model.state.value.page.feeds
                    .single()
                    .url,
            )
            assertNull(model.state.value.page.error)
            assertFalse(model.state.value.page.loading)
        }

    @Test fun test_source_merge_deduplicates_and_prefers_linked_catalog() =
        runTest {
            coEvery { api.request("/discover/popular_feeds", any(), false) } returns
                json("""{"feeds":[{"feed_id":8,"feed_url":"https://same","title":"Catalog"}]}""")
            coEvery { api.request("/discover/reddit/search", any(), false) } returns
                json("""{"results":[{"feed_url":"https://same","name":"Source"},{"feed_url":"https://other","name":"Other"}]}""")
            val model = model()
            model.selectTab(DiscoveryTab.REDDIT)
            advanceUntilIdle()
            model.queryChanged("news")
            advanceUntilIdle()
            assertEquals(2, model.state.value.page.feeds.size)
            assertEquals(
                "8",
                model.state.value.page.feeds
                    .first()
                    .id,
            )
        }

    @Test fun test_pagination_uses_raw_count_and_deduplicates() =
        runTest {
            coEvery { api.request("/discover/popular_feeds", match { it["offset"] == "0" }, false) } returns
                json("""{"feeds":[{"feed_url":"https://one"},{"title":"Malformed"}],"has_more":true}""")
            coEvery { api.request("/discover/popular_feeds", match { it["offset"] == "2" }, false) } returns
                json("""{"feeds":[{"feed_url":"https://one"},{"feed_url":"https://two"}],"has_more":false}""")
            val model = model()
            model.selectTab(DiscoveryTab.POPULAR)
            advanceUntilIdle()
            model.more()
            advanceUntilIdle()
            assertEquals(
                listOf("https://one", "https://two"),
                model.state.value.page.feeds
                    .map { it.url },
            )
            assertFalse(model.state.value.page.hasMore)
        }

    @Test fun test_tab_and_query_survive_recreation() =
        runTest {
            val saved = SavedStateHandle()
            coEvery { api.request(any(), any(), any()) } returns result("https://example")
            val model = model(saved)
            model.selectTab(DiscoveryTab.PODCASTS)
            model.queryChanged("science")
            model.chooseFolder("Science")
            model.toggleGrid()
            advanceUntilIdle()
            val restored = model(saved)
            assertEquals(DiscoveryTab.PODCASTS, restored.state.value.tab)
            assertEquals("science", restored.state.value.page.query)
            assertEquals("Science", restored.state.value.folder)
            assertFalse(restored.state.value.grid)
        }

    @Test fun test_newsletter_url_conversion() =
        runTest {
            coEvery { api.request("/discover/popular_feeds", any(), false) } returns result("https://catalog")
            coEvery { api.request("/discover/newsletter/convert", mapOf("url" to "example.substack.com"), false) } returns
                json("""{"code":1,"feed_url":"https://example.substack.com/feed"}""")
            val model = model()
            model.selectTab(DiscoveryTab.NEWSLETTERS)
            model.queryChanged("example.substack.com")
            advanceUntilIdle()
            assertEquals(
                "https://example.substack.com/feed",
                model.state.value.page.feeds
                    .single()
                    .url,
            )
        }

    @Test fun test_double_add_and_duplicate_subscription_are_guarded() =
        runTest {
            val pending = CompletableDeferred<AddFeedResponse>()
            coEvery { feeds.addFeed("https://example", any()) } coAnswers { pending.await() }
            val model = model()
            val feed = DiscoveryFeed("https://example", "Example")
            model.add(feed)
            model.add(feed)
            runCurrent()
            pending.complete(
                AddFeedResponse().apply {
                    code = 1
                    this.feed = Feed().apply { feedId = "42" }
                },
            )
            advanceUntilIdle()
            model.add(feed)
            advanceUntilIdle()
            coVerify(exactly = 1) { feeds.addFeed("https://example", any()) }
            assertEquals(1, model.state.value.revision)
            assertTrue("https://example" in model.state.value.added)
        }

    @Test fun test_preview_resolves_source_id_without_subscribing() =
        runTest {
            coEvery { api.request("/discover/link_popular_feed", mapOf("feed_url" to "https://example"), false) } returns
                json("""{"feed_id":42}""")
            val model = model()
            model.preview(DiscoveryFeed("https://example", "Example"))
            advanceUntilIdle()
            assertEquals(
                "42",
                model.state.value.preview!!
                    .feedId,
            )
            coVerify(exactly = 0) { feeds.addFeed(any(), any()) }
        }

    @Test fun test_google_news_query_and_language() =
        runTest {
            coEvery { api.request("/discover/google-news/feed", mapOf("query" to "C++", "language" to "fr"), false) } returns
                json("""{"feed_url":"https://news.example"}""")
            coEvery { feeds.addFeed("https://news.example", "News") } returns
                AddFeedResponse().apply {
                    code = 1
                    feed = Feed().apply { feedId = "23" }
                }
            val model = model()
            model.news(query = "C++", language = "fr")
            model.chooseFolder("News")
            model.addNews()
            advanceUntilIdle()
            assertEquals(1, model.state.value.revision)
        }

    @Test fun test_web_rss_short_circuit() =
        runTest {
            coEvery { api.request("/webfeed/analyze", any(), true) } returns json("""{"code":2,"feed_address":"https://example/rss"}""")
            val model = model()
            model.webEdit { it.copy(url = "https://example") }
            model.analyze()
            advanceUntilIdle()
            assertEquals("https://example/rss", model.state.value.web.detectedFeed)
            assertFalse(model.state.value.web.loading)
            coVerify(exactly = 0) { api.request("/webfeed/status", any(), any()) }
        }

    @Test fun test_web_variants_and_subscription_keep_analyzed_url() =
        runTest {
            coEvery { api.request("/webfeed/analyze", any(), true) } returns json("""{"code":1}""")
            coEvery { api.request("/webfeed/status", any(), false) } returns
                json(
                    """{"type":"complete","variants_data":{"page_title":"Page","html_hash":"hash","variants":[{"label":"Articles","story_container":"//article","title":".//h2","preview_stories":[{"title":"Hello"}]}]}}""",
                )
            coEvery {
                api.request(
                    "/webfeed/subscribe",
                    match {
                        it["url"] == "https://original" &&
                            it["story_container_xpath"] == "//article" &&
                            it["html_hash"] == "hash"
                    },
                    true,
                )
            } returns json("""{"code":1}""")
            val model = model()
            model.webEdit { it.copy(url = "https://original") }
            model.analyze()
            advanceUntilIdle()
            assertEquals(
                listOf("Hello"),
                model.state.value.web.variants
                    .single()
                    .stories,
            )
            model.webEdit { it.copy(url = "https://edited") }
            model.subscribeWeb()
            advanceUntilIdle()
            assertTrue("webfeed:https://original" in model.state.value.added)
        }

    @Test fun test_web_timeout_and_server_error_are_retryable() =
        runTest {
            coEvery { api.request("/webfeed/analyze", any(), true) } returns json("""{"code":1}""")
            coEvery { api.request("/webfeed/status", any(), false) } returns json("""{"status":"unknown"}""")
            val model = model()
            model.webEdit { it.copy(url = "https://example") }
            model.analyze()
            advanceUntilIdle()
            assertFalse(model.state.value.web.loading)
            assertTrue(
                model.state.value.web.error!!
                    .contains("timed out"),
            )
            coEvery { api.request("/webfeed/analyze", any(), true) } throws java.io.IOException("Archive required")
            model.analyze()
            advanceUntilIdle()
            assertEquals("Archive required", model.state.value.web.error)
        }
}
