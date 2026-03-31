package com.newsblur

import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DailyBriefingReaderAssetsTest {
    @Test
    fun daily_briefing_images_keep_inline_styles_light_theme() {
        verifyInlineStyles("light_reading.css")
    }

    @Test
    fun daily_briefing_images_keep_inline_styles_dark_theme() {
        verifyInlineStyles("dark_reading.css")
    }

    @Test
    fun daily_briefing_images_keep_inline_styles_black_theme() {
        verifyInlineStyles("black_reading.css")
    }

    private fun verifyInlineStyles(themeStylesheet: String) {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val pageLoaded = AtomicBoolean(false)
        val metricsRef = AtomicReference<String>()
        val latch = CountDownLatch(1)
        val webViewRef = AtomicReference<WebView>()

        instrumentation.runOnMainSync {
            val webView = WebView(context)
            webView.settings.javaScriptEnabled = true
            webView.webViewClient =
                object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String?) {
                        if (!pageLoaded.compareAndSet(false, true)) {
                            return
                        }
                        view.evaluateJavascript(
                            """
                            (function() {
                                loadImages();
                                function width(selector) {
                                    return Math.round(document.querySelector(selector).getBoundingClientRect().width).toString();
                                }
                                function style(selector, propertyName) {
                                    return Math.round(parseFloat(getComputedStyle(document.querySelector(selector))[propertyName])).toString();
                                }
                                return [
                                    document.querySelector('.NB-briefing-section-icon').className,
                                    width('.NB-briefing-section-icon'),
                                    document.querySelector('.NB-briefing-inline-favicon').className,
                                    width('.NB-briefing-inline-favicon'),
                                    style('.NB-briefing-inline-favicon', 'marginRight'),
                                    document.querySelector('.NB-classifier-icon-like').className,
                                    width('.NB-classifier-icon-like')
                                ].join('|');
                            })();
                            """.trimIndent(),
                        ) { value ->
                            metricsRef.set(unquote(value))
                            latch.countDown()
                        }
                    }
                }
            webView.loadDataWithBaseURL(
                "file:///android_asset/",
                testHtml(themeStylesheet),
                "text/html",
                "utf-8",
                null,
            )
            webViewRef.set(webView)
        }

        try {
            assertTrue("Timed out waiting for Daily Briefing webview metrics", latch.await(10, TimeUnit.SECONDS))
            val metrics =
                requireNotNull(metricsRef.get()) {
                    "Daily Briefing webview metrics missing"
                }.split('|')

            assertEquals("NB-briefing-section-icon", metrics[0])
            assertEquals("16", metrics[1])
            assertEquals("NB-briefing-inline-favicon", metrics[2])
            assertEquals("16", metrics[3])
            assertEquals("4", metrics[4])
            assertEquals("NB-classifier-icon-like", metrics[5])
            assertEquals("12", metrics[6])
        } finally {
            instrumentation.runOnMainSync {
                webViewRef.get()?.destroy()
            }
        }
    }

    private fun unquote(value: String?): String {
        requireNotNull(value) { "Javascript returned null" }
        if (value.length >= 2 && value.first() == '"' && value.last() == '"') {
            return value.substring(1, value.length - 1)
        }
        return value
    }

    companion object {
        private const val SECTION_ICON =
            "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='150' height='150' viewBox='0 0 150 150'%3E%3Crect width='150' height='150' rx='10' fill='%2395968E'/%3E%3C/svg%3E"
        private const val FAVICON =
            "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='8' fill='%233E7AD6'/%3E%3C/svg%3E"
        private const val CLASSIFIER_ICON =
            "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='150' height='150' viewBox='0 0 150 150'%3E%3Ccircle cx='75' cy='75' r='60' fill='%23FFFFFF'/%3E%3C/svg%3E"

        private fun testHtml(themeStylesheet: String): String =
            """
            <html>
            <head>
              <meta charset="utf-8">
              <link rel="stylesheet" href="reading.css">
              <link rel="stylesheet" href="$themeStylesheet">
              <script src="storyDetailView.js"></script>
            </head>
            <body>
              <div class="NB-story">
                <h3 style="font-size:16px;font-weight:bold;color:#2d5273;margin:24px 0 10px 0;padding-bottom:6px;border-bottom:2px solid #e8e8e8;">
                  <img src="$SECTION_ICON" class="NB-briefing-section-icon" style="display:inline-block;width:1em;height:1em;vertical-align:-0.1em;margin:0 0.3em 0 0;">
                  From infrequent sites
                </h3>
                <div style="margin:0 0 12px 0;padding:0 0 0 22px;line-height:1.5;font-size:18px;">
                  <table cellpadding="0" cellspacing="0" border="0" style="width:100%;">
                    <tr>
                      <td style="width:22px;vertical-align:top;padding-top:0;">
                        <img src="$FAVICON" class="NB-briefing-inline-favicon" style="width:16px;height:16px;border-radius:2px;margin:4px 4px 0 0;vertical-align:top;" title="Example">
                      </td>
                      <td style="vertical-align:top;font-size:18px;line-height:1.5;">
                        <a href="https://www.newsblur.com/briefing?story=example" class="NB-briefing-story-link" data-story-hash="example">Story title</a>
                        <span style="display:inline-block;background-color:#34912E;border:1px solid #202020;border-radius:14px;padding:1px 8px;font-size:11px;line-height:16px;margin:0 4px 0 0;white-space:nowrap;vertical-align:text-bottom;text-decoration:none;" class="NB-classifier NB-classifier-title NB-classifier-like NB-briefing-classifier">
                          <img src="$CLASSIFIER_ICON" class="NB-classifier-icon-like" style="display:inline-block;width:12px;height:12px;vertical-align:middle;margin:0 3px 0 0;" alt="">
                          <label style="color:white;text-decoration:none;">
                            <b style="color:rgba(255,255,255,0.7);font-weight:normal;text-decoration:none;">TITLE: </b>
                            <span style="color:white;text-shadow:1px 1px 0 rgba(0,0,0,0.5);text-decoration:none;">Example</span>
                          </label>
                        </span>
                      </td>
                    </tr>
                  </table>
                </div>
              </div>
            </body>
            </html>
            """.trimIndent()
    }
}
