package com.newsblur.image

import android.app.Activity
import android.content.Intent
import android.net.Uri
import com.newsblur.fragment.ReadingItemFragment
import io.mockk.EqMatcher
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryImageBrowser {
    @After fun tearDown() = unmockkAll()

    @Test fun test_offline_rewrite_retains_original_image_url_separately_from_article_link() {
        val imageUrl = "https://example.com/photo.jpg?a=1&amp;b=2"
        val fragment = ReadingItemFragment().apply {
            storyImageCache = mockk { every { getWebViewImageCache(imageUrl) } returns "/images/123.jpg" }
        }
        val html = "<a href=\"https://example.com/article\"><img src=\"$imageUrl\"></a>"
        val rewritten = ReadingItemFragment::class.java.getDeclaredMethod("swapInOfflineImages", String::class.java).run {
            isAccessible = true
            invoke(fragment, html) as String
        }
        assertEquals(
            "<a href=\"https://example.com/article\"><img src=\"/images/123.jpg\" data-nb-original-src=\"$imageUrl\"></a>",
            rewritten,
        )
    }

    @Test fun test_duplicate_images_keep_the_same_original_url_without_rewriting_added_attributes() {
        val imageUrl = "https://example.com/photo.jpg?a=1&amp;b=2"
        val fragment = ReadingItemFragment().apply {
            storyImageCache = mockk { every { getWebViewImageCache(imageUrl) } returns "/images/123.jpg" }
        }
        val html = "<img src=\"$imageUrl\"><p>Caption</p><img src=\"$imageUrl\">"
        val rewritten = ReadingItemFragment::class.java.getDeclaredMethod("swapInOfflineImages", String::class.java).run {
            isAccessible = true
            invoke(fragment, html) as String
        }
        val cachedImage = "<img src=\"/images/123.jpg\" data-nb-original-src=\"$imageUrl\">"
        assertEquals("$cachedImage<p>Caption</p>$cachedImage", rewritten)
    }

    @Test fun test_browser_action_launches_external_view_intent_with_image_not_article() {
        val imageUrl = "https://example.com/original.jpg"
        val uri = mockk<Uri>()
        val activity = mockk<Activity>(relaxed = true)
        mockkStatic(Uri::class)
        every { Uri.parse(imageUrl) } returns uri
        mockkConstructor(Intent::class)
        every { constructedWith<Intent>(EqMatcher(Intent.ACTION_VIEW)).setData(uri) } answers { self as Intent }
        val source = source().copy(
            url = "${StoryImageSource.READER_ORIGIN}/images/123.jpg",
            originalUrl = imageUrl,
            linkUrl = "https://example.com/article",
        )

        StoryImageActions.openInBrowser(activity, source)

        verify(exactly = 1) { constructedWith<Intent>(EqMatcher(Intent.ACTION_VIEW)).setData(uri) }
        verify(exactly = 1) { activity.startActivity(any()) }
    }

    @Test fun test_non_browser_image_does_not_launch_an_activity() {
        val activity = mockk<Activity>(relaxed = true)
        StoryImageActions.openInBrowser(activity, source().copy(url = "data:image/png;base64,AAAA"))
        verify(exactly = 0) { activity.startActivity(any()) }
    }

    private fun source() = StoryImageSource(1, "1", "https://example.com/a.jpg", "Photo", 400f, 300f, 0f, 0f, 400f, 300f, 400f)
}
