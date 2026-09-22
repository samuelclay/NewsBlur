package com.newsblur.web

import android.util.Log
import android.webkit.WebView
import com.newsblur.fragment.ReadingItemFragment
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Test

class NewsblurWebviewReadinessTest {
    @Test
    fun aZeroHeightArticleCannotReportVisualReadiness() = withFixture { fixture ->
        every { fixture.webview.height } returns 0
        fixture.requestVisualState()
        verify(exactly = 0) { fixture.webview.postVisualStateCallback(any(), any()) }
    }

    @Test
    fun aPendingLayoutCannotReportVisualReadiness() = withFixture { fixture ->
        every { fixture.webview.isLayoutRequested } returns true
        fixture.requestVisualState()
        verify(exactly = 0) { fixture.webview.postVisualStateCallback(any(), any()) }
    }

    @Test
    fun contentMustStillHaveAPositiveHeightWhenTheFrameCompletes() = withFixture { fixture ->
        fixture.requestVisualState()
        every { fixture.webview.height } returns 0
        fixture.callbacks.single().onComplete(1L)
        verify(exactly = 0) { fixture.fragment.onWebVisualStateReady() }
    }

    @Test
    fun layoutFollowedByACompositorFrameMakesTheArticleReadyOnlyOnce() = withFixture { fixture ->
        every { fixture.webview.height } returns 0
        fixture.requestVisualState()
        every { fixture.webview.height } returns 900
        fixture.requestVisualState()
        fixture.requestVisualState()
        fixture.callbacks.last().onComplete(1L)
        fixture.requestVisualState()
        verify(exactly = 1) { fixture.webview.postVisualStateCallback(1L, any()) }
        verify(exactly = 1) { fixture.fragment.onWebVisualStateReady() }
    }

    private fun withFixture(test: (Fixture) -> Unit) {
        mockkStatic(Log::class)
        every { Log.d(any(), any()) } returns 0
        try {
            test(Fixture())
        } finally {
            unmockkStatic(Log::class)
        }
    }

    private class Fixture {
        val webview = mockk<NewsblurWebview>(relaxed = true)
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        val callbacks = mutableListOf<WebView.VisualStateCallback>()

        init {
            webview.fragment = fragment
            setField("activeVisualStateRequestId", 1L)
            setField("completedVisualStateRequestId", -1L)
            every { webview.width } returns 1080
            every { webview.height } returns 900
            every { webview.isLaidOut } returns true
            every { webview.isLayoutRequested } returns false
            every { webview["requestVisualState"]() } answers { callOriginal() }
            every { webview.postVisualStateCallback(any(), any()) } answers { callbacks.add(secondArg()); Unit }
        }

        fun requestVisualState() {
            NewsblurWebview::class.java.getDeclaredMethod("requestVisualState").apply {
                isAccessible = true
                invoke(webview)
            }
        }

        private fun setField(name: String, value: Any) {
            NewsblurWebview::class.java.getDeclaredField(name).apply {
                isAccessible = true
                set(webview, value)
            }
        }
    }
}
