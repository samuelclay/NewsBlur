package com.newsblur.activity

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.SystemClock
import android.webkit.WebView
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt

@RunWith(AndroidJUnit4::class)
class ReaderPositionRegressionTest {
    @Test
    fun rotatingReaderKeepsSameParagraphVisible() {
        ActivityScenario.launch(ReaderPositionTestActivity::class.java).use { scenario ->
            forcePortrait(scenario)
            loadSyntheticStory(scenario)

            lateinit var originalActivity: ReaderPositionTestActivity
            lateinit var originalWebView: WebView
            var portraitWidth = 0
            scenario.onActivity { activity ->
                originalActivity = activity
                originalWebView = activity.webView
                portraitWidth = activity.webView.width
            }

            scrollToTargetAndCaptureAnchor(scenario)
            val portraitDocumentHeight = documentHeight(scenario)

            requestOrientation(
                scenario = scenario,
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,
                expectedOrientation = Configuration.ORIENTATION_LANDSCAPE,
            )
            waitForCondition("story did not reflow in landscape") {
                webViewWidth(scenario) != portraitWidth &&
                    documentHeight(scenario) != portraitDocumentHeight
            }
            assertSameActivityAndWebView(scenario, originalActivity, originalWebView)
            assertNotEquals(TARGET_MARKER, markerAtReadingPosition(scenario))

            restoreCapturedAnchor(scenario)
            assertTargetAtReadingPosition(scenario)
            scrollToCurrentPositionAndCaptureAnchor(scenario)
            val landscapeDocumentHeight = documentHeight(scenario)

            requestOrientation(
                scenario = scenario,
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT,
                expectedOrientation = Configuration.ORIENTATION_PORTRAIT,
            )
            waitForCondition("story did not reflow after returning to portrait") {
                documentHeight(scenario) != landscapeDocumentHeight
            }
            assertSameActivityAndWebView(scenario, originalActivity, originalWebView)
            assertNotEquals(TARGET_MARKER, markerAtReadingPosition(scenario))

            restoreCapturedAnchor(scenario)
            assertTargetAtReadingPosition(scenario)
        }
    }

    @Test
    fun returningFromBackgroundKeepsScrollAndLiveAnchor() {
        ActivityScenario.launch(ReaderPositionTestActivity::class.java).use { scenario ->
            forcePortrait(scenario)
            loadSyntheticStory(scenario)
            scrollToTargetAndCaptureAnchor(scenario)

            lateinit var originalActivity: ReaderPositionTestActivity
            lateinit var originalWebView: WebView
            var originalScrollY = 0
            scenario.onActivity { activity ->
                originalActivity = activity
                originalWebView = activity.webView
                originalScrollY = activity.scrollView.scrollY
            }

            scenario.moveToState(Lifecycle.State.CREATED)
            scenario.moveToState(Lifecycle.State.RESUMED)
            waitForCondition("reader did not resume") {
                javascript(scenario, "document.readyState === 'complete';") == "true"
            }

            assertSameActivityAndWebView(scenario, originalActivity, originalWebView)
            scenario.onActivity { activity ->
                assertTrue(
                    "reader scroll changed from $originalScrollY to ${activity.scrollView.scrollY}",
                    abs(activity.scrollView.scrollY - originalScrollY) <= SCROLL_TOLERANCE_PX,
                )
            }
            assertTargetAtReadingPosition(scenario)

            val resolvedAnchor = JSONArray(javascript(scenario, "NB_resolve_reader_anchor();"))
            assertTrue(
                "live reader anchor moved while the app was backgrounded",
                targetContainsDocumentFraction(scenario, resolvedAnchor.getDouble(0)),
            )
        }
    }

    private fun forcePortrait(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        requestOrientation(
            scenario = scenario,
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT,
            expectedOrientation = Configuration.ORIENTATION_PORTRAIT,
        )
    }

    private fun requestOrientation(
        scenario: ActivityScenario<ReaderPositionTestActivity>,
        requestedOrientation: Int,
        expectedOrientation: Int,
    ) {
        scenario.onActivity { activity ->
            activity.requestedOrientation = requestedOrientation
        }
        waitForCondition("reader did not enter the requested orientation") {
            var orientation = Configuration.ORIENTATION_UNDEFINED
            scenario.onActivity { activity ->
                orientation = activity.resources.configuration.orientation
            }
            orientation == expectedOrientation
        }
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
    }

    private fun loadSyntheticStory(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        lateinit var pageLoadedLatch: CountDownLatch
        scenario.onActivity { activity ->
            activity.loadStory(syntheticStoryHtml())
            pageLoadedLatch = activity.pageLoadedLatch
        }
        assertTrue(
            "timed out loading synthetic reader story",
            pageLoadedLatch.await(WAIT_TIMEOUT_SECONDS, TimeUnit.SECONDS),
        )
        waitForCondition("synthetic reader story did not finish layout") {
            javascript(
                scenario,
                """
                typeof NB_capture_reader_anchor === 'function' &&
                    typeof NB_resolve_reader_anchor === 'function' &&
                    document.querySelector('[data-marker="$TARGET_MARKER"]') !== null;
                """.trimIndent(),
            ) == "true"
        }
        val documentHeight = documentHeight(scenario)
        assertTrue(
            "synthetic reader story was too short: $documentHeight",
            documentHeight >= MINIMUM_STORY_HEIGHT_PX,
        )
    }

    private fun scrollToTargetAndCaptureAnchor(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        val targetPosition =
            JSONArray(
                javascript(
                    scenario,
                    """
                    (function() {
                        var target = document.querySelector('[data-marker="$TARGET_MARKER"]');
                        var rect = target.getBoundingClientRect();
                        return [(rect.top + rect.height * 0.35) / NB_reader_document_height()];
                    })();
                    """.trimIndent(),
                ),
            ).getDouble(0)
        scrollToDocumentFraction(scenario, targetPosition)
        scrollToCurrentPositionAndCaptureAnchor(scenario)
        assertEquals(TARGET_MARKER, capturedAnchorMarker(scenario))
        assertTargetAtReadingPosition(scenario)
    }

    private fun scrollToCurrentPositionAndCaptureAnchor(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        val currentPosition = currentDocumentFraction(scenario)
        assertEquals(
            "true",
            javascript(scenario, "NB_capture_reader_anchor($currentPosition);"),
        )
    }

    private fun restoreCapturedAnchor(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        val resolution = JSONArray(javascript(scenario, "NB_resolve_reader_anchor();"))
        assertTrue("reader anchor did not observe a layout change", resolution.getBoolean(1))
        scrollToDocumentFraction(scenario, resolution.getDouble(0))
    }

    private fun capturedAnchorMarker(scenario: ActivityScenario<ReaderPositionTestActivity>): String =
        unquote(
            javascript(
                scenario,
                """
                (function() {
                    var anchor = window.NB_reader_anchor;
                    if (!anchor) return null;
                    var node = anchor.range ? anchor.range.startContainer : anchor.element;
                    var element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
                    var marker = element ? element.closest('[data-marker]') : null;
                    return marker ? marker.getAttribute('data-marker') : null;
                })();
                """.trimIndent(),
            ),
        )

    private fun assertTargetAtReadingPosition(scenario: ActivityScenario<ReaderPositionTestActivity>) {
        assertEquals(TARGET_MARKER, markerAtReadingPosition(scenario))
        assertTrue(
            "restored position was outside the target paragraph",
            targetContainsDocumentFraction(scenario, currentDocumentFraction(scenario)),
        )
    }

    private fun markerAtReadingPosition(scenario: ActivityScenario<ReaderPositionTestActivity>): String {
        val documentFraction = currentDocumentFraction(scenario)
        return unquote(
            javascript(
                scenario,
                """
                (function() {
                    var documentY = NB_reader_document_height() * $documentFraction;
                    var markers = document.querySelectorAll('[data-marker]');
                    for (var i = 0; i < markers.length; i++) {
                        var rect = markers[i].getBoundingClientRect();
                        if (rect.top <= documentY && rect.bottom > documentY) {
                            return markers[i].getAttribute('data-marker');
                        }
                    }
                    return null;
                })();
                """.trimIndent(),
            ),
        )
    }

    private fun targetContainsDocumentFraction(
        scenario: ActivityScenario<ReaderPositionTestActivity>,
        documentFraction: Double,
    ): Boolean =
        javascript(
            scenario,
            """
            (function() {
                var documentY = NB_reader_document_height() * $documentFraction;
                var rect = document.querySelector('[data-marker="$TARGET_MARKER"]').getBoundingClientRect();
                return documentY >= rect.top - 2 && documentY <= rect.bottom + 2;
            })();
            """.trimIndent(),
        ) == "true"

    private fun currentDocumentFraction(scenario: ActivityScenario<ReaderPositionTestActivity>): Double {
        var documentFraction = 0.0
        scenario.onActivity { activity ->
            val visibleWebViewY = activity.scrollView.scrollY - activity.webView.top
            documentFraction = visibleWebViewY.toDouble() / activity.webView.height.toDouble()
        }
        return documentFraction.coerceIn(0.0, 1.0)
    }

    private fun scrollToDocumentFraction(
        scenario: ActivityScenario<ReaderPositionTestActivity>,
        documentFraction: Double,
    ) {
        scenario.onActivity { activity ->
            val desiredScrollY =
                activity.webView.top +
                    (activity.webView.height * documentFraction.coerceIn(0.0, 1.0)).roundToInt()
            activity.scrollView.scrollTo(0, desiredScrollY)
        }
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
    }

    private fun documentHeight(scenario: ActivityScenario<ReaderPositionTestActivity>): Int =
        javascript(scenario, "Math.round(NB_reader_document_height());")
            .toInt()

    private fun webViewWidth(scenario: ActivityScenario<ReaderPositionTestActivity>): Int {
        var width = 0
        scenario.onActivity { activity ->
            width = activity.webView.width
        }
        return width
    }

    private fun assertSameActivityAndWebView(
        scenario: ActivityScenario<ReaderPositionTestActivity>,
        expectedActivity: ReaderPositionTestActivity,
        expectedWebView: WebView,
    ) {
        scenario.onActivity { activity ->
            assertSame(expectedActivity, activity)
            assertSame(expectedWebView, activity.webView)
        }
    }

    private fun javascript(
        scenario: ActivityScenario<ReaderPositionTestActivity>,
        script: String,
    ): String {
        val resultLatch = CountDownLatch(1)
        var result: String? = null
        scenario.onActivity { activity ->
            activity.webView.evaluateJavascript(script) { value ->
                result = value
                resultLatch.countDown()
            }
        }
        assertTrue(
            "timed out evaluating reader JavaScript",
            resultLatch.await(WAIT_TIMEOUT_SECONDS, TimeUnit.SECONDS),
        )
        return requireNotNull(result) { "reader JavaScript returned null" }
    }

    private fun waitForCondition(
        failureMessage: String,
        condition: () -> Boolean,
    ) {
        val deadline = SystemClock.uptimeMillis() + TimeUnit.SECONDS.toMillis(WAIT_TIMEOUT_SECONDS)
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(POLL_INTERVAL_MS)
        }
        assertTrue(failureMessage, condition())
    }

    private fun unquote(value: String): String {
        require(value != "null") { "reader JavaScript returned null" }
        return if (value.length >= 2 && value.first() == '"' && value.last() == '"') {
            value.substring(1, value.length - 1)
        } else {
            value
        }
    }

    private fun syntheticStoryHtml(): String {
        val paragraphs =
            (1..PARAGRAPH_COUNT).joinToString("\n") { index ->
                """
                <p data-marker="paragraph-$index">
                  <strong>Paragraph $index.</strong>
                  NewsBlur keeps this deliberately long sentence in the reader regression fixture so
                  portrait and landscape layouts wrap it onto substantially different lines while the
                  paragraph identity remains deterministic and independent of accounts or the network.
                </p>
                """.trimIndent()
            }
        return """
            <!doctype html>
            <html>
              <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { margin: 0; padding: 0; }
                  .NB-story {
                    box-sizing: border-box;
                    padding: 24px;
                    font-family: sans-serif;
                    font-size: 20px;
                    line-height: 1.55;
                  }
                  p { margin: 0 0 24px 0; }
                </style>
                <script src="storyDetailView.js"></script>
              </head>
              <body>
                <article class="NB-story">$paragraphs</article>
              </body>
            </html>
            """.trimIndent()
    }

    companion object {
        private const val TARGET_MARKER = "paragraph-36"
        private const val PARAGRAPH_COUNT = 72
        private const val SCROLL_TOLERANCE_PX = 2
        private const val MINIMUM_STORY_HEIGHT_PX = 4_000
        private const val WAIT_TIMEOUT_SECONDS = 15L
        private const val POLL_INTERVAL_MS = 50L
    }
}
