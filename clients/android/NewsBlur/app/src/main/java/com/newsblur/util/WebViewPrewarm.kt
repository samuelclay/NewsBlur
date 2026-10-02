package com.newsblur.util

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebView

/**
 * Starts WebView before the first story opens on a tablet. The first WebView in the app loads
 * Chromium and starts its renderer process, about a second on a Galaxy Tab A8, so the first story
 * tapped into the split's reader pane (Reading.kt) took over two seconds to appear. A story list in
 * a split asks for this once it is on screen (ItemsList.java). The warm WebView loads a blank page
 * when the main thread is next idle, and is let go once a reader shows a story with its own.
 */
object WebViewPrewarm {
    // Long enough for the story list and the feed list beside it to finish their first loads.
    private const val START_DELAY_MS = 1_500L

    private var warmView: WebView? = null
    private var requested = false

    @JvmStatic
    fun startWhenIdle(context: Context) {
        if (requested) return
        requested = true
        val appContext = context.applicationContext
        Handler(Looper.getMainLooper()).postDelayed({
            Looper.myQueue().addIdleHandler {
                warmView =
                    runCatching {
                        WebView(appContext).apply { loadDataWithBaseURL(null, "", "text/html", "utf-8", null) }
                    }.getOrNull()
                false
            }
        }, START_DELAY_MS)
    }

    /** A reader's own WebView keeps Chromium running from here on. */
    @JvmStatic
    fun release() {
        warmView?.destroy()
        warmView = null
    }
}
