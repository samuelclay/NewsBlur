package com.newsblur.activity

import android.app.Activity
import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Space
import java.util.concurrent.CountDownLatch

class ReaderPositionTestActivity : Activity() {
    lateinit var scrollView: ScrollView
        private set

    lateinit var webView: WebView
        private set

    @Volatile
    var configurationChangeCount = 0
        private set

    @Volatile
    var pageLoadedLatch = CountDownLatch(1)
        private set

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        scrollView =
            ScrollView(this).apply {
                isFillViewport = true
                setBackgroundColor(Color.WHITE)
            }
        val content =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }
        content.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                HEADER_HEIGHT_PX,
            ),
        )
        webView =
            WebView(this).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                isVerticalScrollBarEnabled = false
                isHorizontalScrollBarEnabled = false
                webViewClient =
                    object : WebViewClient() {
                        override fun onPageFinished(
                            view: WebView,
                            url: String?,
                        ) {
                            pageLoadedLatch.countDown()
                        }
                    }
            }
        content.addView(
            webView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        content.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                FOOTER_HEIGHT_PX,
            ),
        )
        scrollView.addView(
            content,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        setContentView(scrollView)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        configurationChangeCount++
    }

    override fun onPause() {
        webView.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::webView.isInitialized) {
            webView.onResume()
        }
    }

    override fun onDestroy() {
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
        super.onDestroy()
    }

    fun loadStory(html: String) {
        pageLoadedLatch = CountDownLatch(1)
        webView.loadDataWithBaseURL(
            "file:///android_asset/",
            html,
            "text/html",
            "utf-8",
            null,
        )
    }

    companion object {
        private const val HEADER_HEIGHT_PX = 120
        private const val FOOTER_HEIGHT_PX = 600
    }
}
