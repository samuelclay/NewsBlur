package com.newsblur.fragment

import com.newsblur.web.NewsblurWebview
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class ReadingPageReleaseTest {
    @Test
    fun releasingAnOffscreenPageDoesNotPauseTheVisiblePagesJavascript() {
        val webview = mockk<NewsblurWebview>(relaxed = true)
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        every { fragment["destroyReadingWebviewForBackground"]() } answers { callOriginal() }
        ReadingItemFragment::class.java.getDeclaredField("readingWebview").apply {
            isAccessible = true
            set(fragment, webview)
        }
        ReadingItemFragment::class.java.getDeclaredField("articleReveal").apply {
            isAccessible = true
            set(fragment, ReaderArticleReveal {})
        }
        ReadingItemFragment::class.java.getDeclaredField("documentRenderer").apply {
            isAccessible = true
            set(fragment, LatestReaderRender<Any, Any>())
        }

        ReadingItemFragment::class.java.getDeclaredMethod("destroyReadingWebviewForBackground").apply {
            isAccessible = true
            invoke(fragment)
        }

        // ReadingItemFragment.kt releases adjacent pages during an ordinary pager animation.
        verify(exactly = 0) { webview.pauseTimers() }
        verify(exactly = 1) { webview.onPause() }
        verify(exactly = 1) { webview.destroy() }
    }
}
