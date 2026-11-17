package com.newsblur.view

import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.color.MaterialColors
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.realtime.RealtimeUpdates
import com.newsblur.realtime.RealtimeUpdates.NewStories.Placement
import com.newsblur.util.FeedSet
import com.newsblur.util.UIUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The "N new stories" pill over ItemSetFragment.java's list. RealtimeUpdates.kt fetches stories that
 * arrive for the open list; a tap adds them to the reading session and ItemSetFragment.java scrolls to
 * them. Nothing moves under the reader's finger until then.
 */
class NewStoriesPill(
    private val fragment: Fragment,
    private val pill: TextView,
    private val bottomAnchor: View,
    private val realtimeUpdates: RealtimeUpdates,
    private val dbHelper: BlurDatabaseHelper,
    private val feedSet: () -> FeedSet?,
    private val onStoriesAdded: (List<String>, Placement) -> Unit,
) {
    private var placement = Placement.TOP

    fun start() {
        applyTheme()
        pill.setOnClickListener { addStories() }
        val owner = fragment.viewLifecycleOwner
        owner.lifecycleScope.launch {
            owner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                realtimeUpdates.newStories.collect(::render)
            }
        }
    }

    /** Uses the story list status banner's per-theme colors (theme.xml), so every theme styles it. */
    fun applyTheme() {
        val radius = pill.resources.displayMetrics.density * 18f
        pill.background =
            GradientDrawable().apply {
                cornerRadius = radius
                setColor(MaterialColors.getColor(pill, R.attr.storyStatusFetchingBackgroundColor))
                setStroke(UIUtils.dp2px(pill.context, 1), MaterialColors.getColor(pill, R.attr.storyStatusFetchingBorderColor))
            }
        pill.setTextColor(MaterialColors.getColor(pill, R.attr.storyStatusFetchingTextColor))
    }

    /**
     * ItemSetFragment.java calls this as the next-site control and the floating toolbar move, which
     * happens on every scroll, so it only touches the layout when the pill's position changes.
     */
    fun refreshPosition() {
        val params = pill.layoutParams as? RelativeLayout.LayoutParams ?: return
        val gap = UIUtils.dp2px(pill.context, 12)
        val atTop = placement == Placement.TOP
        val bottomMargin =
            if (atTop) {
                0
            } else {
                // Sit above the next-site control and the floating story toolbar it already clears.
                val anchorMargin = (bottomAnchor.layoutParams as? RelativeLayout.LayoutParams)?.bottomMargin ?: 0
                val anchorHeight = if (bottomAnchor.visibility == View.VISIBLE) bottomAnchor.height + gap else 0
                anchorMargin + anchorHeight
            }
        val topMargin = if (atTop) gap else 0
        val alignedTop = params.getRule(RelativeLayout.ALIGN_PARENT_TOP) != 0
        if (alignedTop == atTop && params.topMargin == topMargin && params.bottomMargin == bottomMargin) return
        if (atTop) {
            params.removeRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
            params.addRule(RelativeLayout.ALIGN_PARENT_TOP)
        } else {
            params.removeRule(RelativeLayout.ALIGN_PARENT_TOP)
            params.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
        }
        params.topMargin = topMargin
        params.bottomMargin = bottomMargin
        pill.layoutParams = params
    }

    private fun render(state: RealtimeUpdates.NewStories) {
        val current = feedSet()
        if (current == null || state.feedSet != current || state.storyHashes.isEmpty()) {
            ReaderMotion.visibility(pill, View.GONE)
            return
        }
        placement = state.placement
        val count = state.storyHashes.size
        pill.text = pill.resources.getQuantityString(R.plurals.new_stories_pill, count, count)
        pill.contentDescription = pill.text
        applyTheme()
        refreshPosition()
        ReaderMotion.visibility(pill, View.VISIBLE)
    }

    private fun addStories() {
        val fs = feedSet() ?: return
        val shownPlacement = placement
        val hashes = realtimeUpdates.takeNewStories(fs)
        if (hashes.isEmpty()) return
        fragment.viewLifecycleOwner.lifecycleScope.launch {
            withContext(Dispatchers.IO) { dbHelper.addStoriesToReadingSession(hashes) }
            onStoriesAdded(hashes, shownPlacement)
        }
    }
}
