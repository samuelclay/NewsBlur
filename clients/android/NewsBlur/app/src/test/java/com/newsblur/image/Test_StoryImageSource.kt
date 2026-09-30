package com.newsblur.image

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryImageSource {
    private val json = """{"generation":3,"token":"42","src":"https://example.com/image.jpg","title":"An image",
        "naturalWidth":1200,"naturalHeight":800,"rect":{"x":0,"y":-20,"width":400,"height":267,"viewportWidth":400}}"""

    @Test fun test_parses_visible_image_with_partially_scrolled_origin() {
        val image = StoryImageSource.parse(json)!!
        assertEquals(3L, image.generation)
        assertEquals(-20f, image.y, 0f)
        assertEquals("An image", image.title)
    }

    @Test fun test_a_tap_opens_without_actions_or_hover_text() {
        val image = StoryImageSource.parse(json)!!
        assertFalse(image.showActions)
        assertNull(image.hoverText)
        assertNull(image.linkUrl)
    }

    @Test fun test_a_long_press_carries_hover_text_actions_and_its_link() {
        val longPress =
            json.replace(
                "\"title\":\"An image\"",
                "\"title\":\"An image\",\"hoverText\":\"  The comic's punchline  \",\"showActions\":true," +
                    "\"link\":\"https://example.com/story\"",
            )
        val image = StoryImageSource.parse(longPress)!!
        assertTrue(image.showActions)
        assertEquals("The comic's punchline", image.hoverText)
        assertEquals("https://example.com/story", image.linkUrl)
        // The accessibility description stays the alt text, separate from the hover text.
        assertEquals("An image", image.title)
    }

    @Test fun test_blank_hover_text_and_non_web_links_are_dropped() {
        val longPress =
            json.replace(
                "\"title\":\"An image\"",
                "\"title\":\"An image\",\"hoverText\":\"   \",\"showActions\":true,\"link\":\"javascript:alert(1)\"",
            )
        val image = StoryImageSource.parse(longPress)!!
        assertNull(image.hoverText)
        assertNull(image.linkUrl)
    }

    @Test fun test_rejects_missing_fields_invalid_json_tracking_pixels_and_bad_geometry() {
        assertNull(StoryImageSource.parse("{}"))
        assertNull(StoryImageSource.parse("invalid"))
        assertNull(StoryImageSource.parse(json.replace("1200", "1")))
        assertNull(StoryImageSource.parse(json.replace("\"viewportWidth\":400", "\"viewportWidth\":0")))
        assertNull(StoryImageSource.parse(json.replace("\"width\":400", "\"width\":\"Infinity\"")))
    }

    @Test fun test_token_cannot_inject_javascript_or_selectors() {
        assertNull(StoryImageSource.parse(json.replace("\"42\"", "\"');alert(1);//\"")))
    }

    @Test fun test_only_image_data_and_web_urls_can_be_loaded() {
        assertTrue(StoryImageSource.isAllowedUrl("data:image/png;base64,AAAA"))
        assertTrue(StoryImageSource.isAllowedUrl("https://example.com/a.png?x=1"))
        listOf(
            "file:///data/data/com.newsblur/shared_prefs/preferences.xml",
            "content://private/image",
            "javascript:alert(1)",
            "data:text/html,<h1>bad</h1>",
            "https:///missing-host",
        ).forEach { assertFalse(StoryImageSource.isAllowedUrl(it)) }
    }

    @Test fun test_offline_cache_paths_are_confined_to_image_files() {
        val root = StoryImageSource.READER_ORIGIN
        assertEquals("12345.jpg", StoryImageSource.cachedFileName("$root/images/12345.jpg"))
        listOf(
            "$root/images/../preferences.xml",
            "$root/images/%2e%2e%2fpreferences.xml",
            "$root/assets/storyDetailView.js",
            "$root/images/../assets/a.jpg",
            "$root:123/images/a.jpg",
        ).forEach {
            assertNull(StoryImageSource.cachedFileName(it))
            assertFalse(StoryImageSource.isAllowedUrl(it))
        }
    }
}
