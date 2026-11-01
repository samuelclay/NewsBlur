package com.newsblur.listen

import android.graphics.drawable.GradientDrawable
import android.view.View
import android.webkit.WebView
import android.widget.TextView
import androidx.core.widget.NestedScrollView
import com.newsblur.design.ListenPalette
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * ListenStoryFollower.kt is the native half of Listen's follow-along (listenFollowAlong.js): in the story on
 * screen, it highlights the paragraphs being read, scrolls them gently into view, and turns paragraph taps
 * into jumps. ReadingItemFragment.kt owns one per story page.
 */
class ListenStoryFollower(
    private val storyHash: () -> String?,
    private val webView: () -> WebView?,
    private val scrollView: NestedScrollView,
    private val titleView: TextView,
    private val theme: ThemeValue,
    private val isUserScrolling: () -> Boolean,
    private val onParagraphTapped: (storyHash: String, paragraph: Int) -> Unit,
) {
    private var documentReady = false
    private var collecting = false
    private var mappedParagraphs: List<ListenParagraph>? = null
    private var blockToParagraph: Map<Int, Int> = emptyMap()
    private var appliedKey: String? = null
    private var titleHighlighted = false
    private var latest: ListenUiState? = null
    private var highlightEnabled = true
    private var active = false

    fun onStateChanged(
        state: ListenUiState,
        highlight: Boolean,
    ) {
        latest = state
        highlightEnabled = highlight
        apply()
    }

    /** A new document was loaded into the WebView (first load, text view switch, font or theme change). */
    fun onDocumentLoaded() {
        documentReady = true
        mappedParagraphs = null
        blockToParagraph = emptyMap()
        appliedKey = null
        active = false
        apply()
    }

    fun onDocumentReleased() {
        documentReady = false
        mappedParagraphs = null
        blockToParagraph = emptyMap()
        appliedKey = null
        active = false
    }

    /** A JSON message from listenFollowAlong.js. */
    fun onMessage(json: String) {
        val hash = storyHash() ?: return
        val paragraph =
            try {
                val message = JSONObject(json)
                if (message.optString("type") != "paragraph") return
                message.getInt("paragraph")
            } catch (_: JSONException) {
                return
            }
        if (latest?.isStory(hash) == true) onParagraphTapped(hash, paragraph)
    }

    private fun apply() {
        val state = latest ?: return
        val hash = storyHash()
        val playingHere =
            state.isStory(hash) &&
                state.phase != ListenPhase.IDLE &&
                state.phase != ListenPhase.ENDED
        if (!playingHere) {
            clear()
            return
        }
        val view = webView()
        if (view == null || !documentReady) return
        if (state.paragraphs.isEmpty()) return
        if (mappedParagraphs != state.paragraphs) {
            collectBlocks(view, state.paragraphs)
            return
        }
        if (!active) {
            active = true
            view.evaluateJavascript("NB_listen_set_active(true);", null)
        }
        val highlighted = if (highlightEnabled) state.highlightedParagraphs else emptyList()
        val key = "${state.segmentIndex}:${highlighted.joinToString(",")}"
        if (key == appliedKey) return
        appliedKey = key
        setTitleHighlighted(
            highlighted.any { index ->
                state.paragraphs
                    .firstOrNull {
                        it.index == index
                    }?.isTitle == true
            },
        )
        val blocks = ListenParagraphMatcher.blocksFor(highlighted, blockToParagraph)
        view.evaluateJavascript("NB_listen_highlight(${JSONArray(blocks)});") { result ->
            scrollIntoView(view, result)
        }
    }

    private fun collectBlocks(
        view: WebView,
        paragraphs: List<ListenParagraph>,
    ) {
        if (collecting) return
        collecting = true
        view.evaluateJavascript("NB_listen_collect_blocks();") { result ->
            collecting = false
            if (webView() !== view || !documentReady) return@evaluateJavascript
            val texts =
                try {
                    val array = JSONArray(result ?: "[]")
                    List(array.length()) { array.optString(it) }
                } catch (_: JSONException) {
                    emptyList()
                }
            blockToParagraph = ListenParagraphMatcher.match(paragraphs, texts)
            mappedParagraphs = paragraphs
            appliedKey = null
            val map =
                JSONObject().apply {
                    blockToParagraph.forEach { (block, paragraph) -> put(block.toString(), paragraph) }
                }
            view.evaluateJavascript("NB_listen_set_map($map);", null)
            apply()
        }
    }

    private fun clear() {
        if (titleHighlighted) setTitleHighlighted(false)
        if (active || appliedKey != null) {
            active = false
            appliedKey = null
            webView()?.evaluateJavascript("NB_listen_set_active(false);", null)
        }
    }

    private fun setTitleHighlighted(highlighted: Boolean) {
        if (highlighted == titleHighlighted) return
        titleHighlighted = highlighted
        titleView.background =
            if (highlighted) {
                GradientDrawable().apply {
                    cornerRadius = UIUtils.dp2px(titleView.context, 6).toFloat()
                    setColor(ListenPalette.highlightArgb(theme))
                }
            } else {
                null
            }
    }

    /** Scrolls a highlighted block into view only when it's off screen and the reader isn't scrolling. */
    private fun scrollIntoView(
        view: WebView,
        result: String?,
    ) {
        if (result == null || result == "null" || isUserScrolling()) return
        val rect =
            try {
                JSONObject(result)
            } catch (_: JSONException) {
                return
            }
        val viewportWidth = rect.optDouble("viewportWidth", 0.0)
        if (viewportWidth <= 0.0 || view.width <= 0) return
        val scale = view.width / viewportWidth
        val webTop = offsetWithinScroll(view) ?: return
        val blockTop = webTop + (rect.optDouble("top") * scale).toInt()
        val blockBottom = webTop + (rect.optDouble("bottom") * scale).toInt()
        val margin = UIUtils.dp2px(view.context, 24)
        // The mini player and reading controls cover the bottom of the screen.
        val bottomCovered = UIUtils.dp2px(view.context, 150)
        val visibleTop = scrollView.scrollY + margin
        val visibleBottom = scrollView.scrollY + scrollView.height - bottomCovered
        if (blockTop >= visibleTop && blockBottom <= visibleBottom) return
        if (blockTop >= visibleTop &&
            blockTop < visibleBottom &&
            blockBottom - blockTop > visibleBottom - visibleTop
        ) {
            return
        }
        val target = (blockTop - (scrollView.height * 0.25f).toInt()).coerceAtLeast(0)
        scrollView.smoothScrollTo(0, target)
    }

    private fun offsetWithinScroll(view: View): Int? {
        var offset = 0
        var current: View = view
        val content = scrollView.getChildAt(0) ?: return null
        while (current !== content) {
            offset += current.top
            current = current.parent as? View ?: return null
        }
        return offset
    }
}
