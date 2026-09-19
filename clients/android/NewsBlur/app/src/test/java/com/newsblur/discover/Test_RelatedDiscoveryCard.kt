package com.newsblur.discover

import com.google.gson.Gson
import com.newsblur.domain.DiscoverFeedPayload
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class Test_RelatedDiscoveryCard {
    @Test fun test_related_api_retains_fields_needed_by_the_shared_story_card() {
        val gson = Gson()
        val payload = gson.fromJson("""{
            "feed":{"id":42,"feed_address":"https://example.com/rss","feed_title":"Example"},
            "stories":[{
                "story_hash":"42:second-story","story_title":"A story headline",
                "story_authors":"Ada","story_timestamp":"1789444800",
                "story_permalink":"https://example.com/second-story",
                "story_content":"<p>A useful preview.</p>",
                "image_urls":["http://example.com/photo.jpg"],
                "secure_image_thumbnails":{"http://example.com/photo.jpg":"https://imageproxy.newsblur.com/thumbnail"}
            }]
        }""", DiscoverFeedPayload::class.java)
        // Test_RelatedDiscoveryCard.kt catches data discarded before the shared card can render it.
        val story = DiscoveryFeed.parse(gson.toJsonTree(payload).asJsonObject)!!.stories.single()
        assertEquals("A useful preview.", story.excerpt)
        assertEquals("https://imageproxy.newsblur.com/thumbnail", story.imageUrl)
        assertEquals(1789444800L, story.timestamp)
        assertEquals("42:second-story", story.hash)
        assertEquals(story, payload.asDiscoveryFeed().stories.single())
        assertEquals("https://example.com/second-story", payload.asDiscoveryFeed().stories.single().permalink)
    }

    @Test fun test_related_story_uses_shared_html_sanitization_and_secure_image_fallback() {
        val payload = parse("""{
            "feed":{"id":42,"feed_address":"https://example.com/rss","feed_title":"Example"},
            "stories":[{
                "story_title":"A &amp; B",
                "story_content":"<style>hidden css</style><script>hidden script</script><p>First &amp; second</p><div>Next<br>line</div>",
                "image_urls":[null,"javascript:alert(1)","http://example.com/image.jpg"],
                "secure_image_thumbnails":{"http://example.com/image.jpg":"javascript:invalid"},
                "secure_image_urls":{"http://example.com/image.jpg":"https://proxy.example.com/image"}
            }]
        }""")
        val story = payload.asDiscoveryFeed().stories.single()
        assertEquals("A &amp; B", story.title)
        assertEquals("First &amp; second Next line", story.excerpt)
        assertEquals("https://proxy.example.com/image", story.imageUrl)
    }

    @Test fun test_related_story_preserves_content_image_and_date_fallbacks() {
        val feed = parse("""{
            "feed":{"id":"42","feed_address":"https://example.com/rss"},
            "stories":[{
                "story_title":"Example", "story_timestamp":"invalid", "story_date":"2026-09-15 04:00:00",
                "story_content":"<p>Preview</p><img src='//example.com/photo.jpg'>",
                "image_urls":null, "secure_image_urls":null, "secure_image_thumbnails":null
            }]
        }""").asDiscoveryFeed()
        assertEquals("https://example.com/photo.jpg", feed.stories.single().imageUrl)
        assertEquals(java.time.Instant.parse("2026-09-15T04:00:00Z").epochSecond, feed.stories.single().timestamp)
        assertEquals("https://example.com/rss", feed.title)
    }

    @Test fun test_numeric_timestamp_and_secure_thumbnail_take_precedence() {
        val story = parse("""{
            "feed":{"id":42,"feed_address":"https://example.com/rss"},
            "stories":[{
                "story_title":"Example", "story_timestamp":1789444800, "story_date":"2020-01-01 00:00:00",
                "image_urls":["http://example.com/photo.jpg"],
                "secure_image_urls":{"http://example.com/photo.jpg":"https://proxy.example.com/full"},
                "secure_image_thumbnails":{"http://example.com/photo.jpg":"https://proxy.example.com/thumbnail"}
            }]
        }""").asDiscoveryFeed().stories.single()
        assertEquals(1789444800L, story.timestamp)
        assertEquals("https://proxy.example.com/thumbnail", story.imageUrl)
    }

    @Test fun test_related_feed_preserves_metadata_and_tolerates_sparse_stories() {
        val feed = parse("""{
            "feed":{"id":42,"feed_address":"https://example.com/rss","feed_title":"Example", "feed_link":"https://example.com/",
                "favicon_url":"https://example.com/favicon.png","num_subscribers":"1234"},
            "stories":[null, {"story_content":"Untitled"}, {"story_title":"Only a title","story_hash":null,
                "story_permalink":null,"story_content":null,"story_authors":null,"story_timestamp":null,"image_urls":null}]
        }""").asDiscoveryFeed()
        assertEquals("42", feed.id)
        assertEquals("https://example.com/rss", feed.url)
        assertEquals("Example", feed.title)
        assertEquals("https://example.com/", feed.link)
        assertEquals("https://example.com/favicon.png", feed.image)
        assertEquals(1234, feed.subscribers)
        val story = feed.stories.single()
        assertEquals("Only a title", story.title)
        assertEquals("", story.hash)
        assertEquals("", story.permalink)
        assertEquals("", story.excerpt)
        assertEquals("", story.authors)
        assertEquals("", story.imageUrl)
        assertNull(story.timestamp)
    }

    @Test fun test_missing_feed_and_null_metadata_do_not_crash_or_invent_values() {
        listOf("{}", """{"feed":null,"stories":null}""", """{"feed":{},"stories":[]}""").forEach { json ->
            assertEquals(DiscoveryFeed(url = "", title = ""), parse(json).asDiscoveryFeed())
        }
        val sparse = parse("""{"feed":{"id":42,"feed_address":null,"feed_title":null,"feed_link":"https://example.com/","num_subscribers":null}}""").asDiscoveryFeed()
        assertEquals("42", sparse.id)
        assertEquals("https://example.com/", sparse.url)
        assertEquals(sparse.url, sparse.title)
        assertEquals(0, sparse.subscribers)
    }

    private fun parse(json: String): DiscoverFeedPayload = Gson().fromJson(json, DiscoverFeedPayload::class.java)
}
