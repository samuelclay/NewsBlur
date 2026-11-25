package com.newsblur.view

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.core.view.doOnPreDraw
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
 * them. Nothing moves under the reader's finger until then. Past RealtimeUpdates.NEW_STORIES_CAP, a tap on a
 * newest-first list instead shows only the newest of them and pages the rest of the list again
 * ([onReplacedWithNewest]).
 *
 * The pill slides out from under the toolbar it sits against, and steps aside five seconds after the reader
 * first scrolls away from it (PillScrollAway.kt).
 */
class NewStoriesPill(
    private val fragment: Fragment,
    private val pill: TextView,
    private val bottomAnchor: View,
    private val realtimeUpdates: RealtimeUpdates,
    private val dbHelper: BlurDatabaseHelper,
    private val feedSet: () -> FeedSet?,
    private val onStoriesAdded: (List<String>, Placement) -> Unit,
    // Past the cap on a newest-first list: the list now holds only these, its newest stories.
    private val onReplacedWithNewest: (List<String>) -> Unit,
    // ItemSetFragment.java shows an "N new stories" row at the list's edge while this hides; 0 removes it.
    private val onInlineRowChanged: (Int, Placement) -> Unit,
) {
    private var placement = Placement.TOP
    private var storiesWaiting = false
    private var waitingCount = 0
    // ItemSetFragment.java reports whether any part of the "N new stories" row is on screen.
    private var rowOnScreen = false
    private var shown = false
    private var slide: ValueAnimator? = null
    private val scrollAway = PillScrollAway(android.os.SystemClock::uptimeMillis)
    private val returnCheck = Runnable { returnAfterIdle() }
    private val hideCheck = Runnable { hideAfterScrollingAway() }

    fun start() {
        applyTheme()
        pill.setOnClickListener { tap() }
        val owner = fragment.viewLifecycleOwner
        owner.lifecycleScope.launch {
            owner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                realtimeUpdates.newStories.collect(::render)
            }
        }
    }

    /** Uses the story list status banner's per-theme colors (theme.xml), so every theme styles it. */
    fun applyTheme() = style(pill)

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

    /** ItemSetFragment.java's view is going away. */
    fun stop() {
        pill.removeCallbacks(returnCheck)
        pill.removeCallbacks(hideCheck)
        slide?.cancel()
    }

    /** ItemSetFragment.java's "N new stories" row came into view or left it; the pill makes way for it. */
    fun setInlineRowOnScreen(onScreen: Boolean) {
        if (rowOnScreen == onScreen) return
        rowOnScreen = onScreen
        setShown(scrollAway.pillShows(storiesWaiting, rowOnScreen))
    }

    /** ItemSetFragment.java reports each scroll of the list; the first scroll away from the pill starts its hide timer. */
    fun onListScrolled(dy: Int) {
        if (dy == 0 || !storiesWaiting) return
        if (!shown && !scrollAway.hiddenByScroll) return
        val movedAway = if (placement == Placement.TOP) dy > 0 else dy < 0
        if (scrollAway.onScroll(movedAway)) scrollAway.millisUntilHide()?.let { pill.postDelayed(hideCheck, it) }
        if (scrollAway.hiddenByScroll) scheduleReturn()
    }

    private fun hideAfterScrollingAway() {
        if (!scrollAway.hidesNow()) {
            // NewStoriesPill.kt's timer can fire a frame early; check back when it is really up.
            scrollAway.millisUntilHide()?.let { pill.postDelayed(hideCheck, maxOf(it, 1L)) }
            return
        }
        setShown(false)
        scheduleReturn()
    }

    private fun scheduleReturn() {
        pill.removeCallbacks(returnCheck)
        scrollAway.millisUntilReturn()?.let { pill.postDelayed(returnCheck, it) }
    }

    private fun returnAfterIdle() {
        if (scrollAway.returnsNow(storiesWaiting)) {
            setShown(scrollAway.pillShows(storiesWaiting, rowOnScreen))
        } else if (scrollAway.hiddenByScroll) {
            scheduleReturn()
        }
    }

    // While stories wait the list carries the row; the pill makes way whenever the row is on screen.
    private fun updateInlineRow() {
        onInlineRowChanged(if (scrollAway.showsInlineRow(storiesWaiting)) waitingCount else 0, placement)
    }

    private fun render(state: RealtimeUpdates.NewStories) {
        val current = feedSet()
        if (current == null || state.feedSet != current || state.count == 0) {
            // Another list, a reload, a tap, or every waiting story read elsewhere: start over.
            storiesWaiting = false
            waitingCount = 0
            scrollAway.reset()
            pill.removeCallbacks(returnCheck)
            pill.removeCallbacks(hideCheck)
            setShown(false)
            updateInlineRow()
            return
        }
        storiesWaiting = true
        placement = state.placement
        val count = state.count
        waitingCount = count
        pill.text = pill.resources.getQuantityString(R.plurals.new_stories_pill, count, count)
        pill.contentDescription = pill.text
        applyTheme()
        refreshPosition()
        // A pill the reader scrolled away from keeps counting while hidden and returns after an idle wait.
        setShown(scrollAway.pillShows(storiesWaiting, rowOnScreen))
        updateInlineRow()
    }

    private fun setShown(show: Boolean) {
        if (shown == show) return
        shown = show
        slide?.cancel()
        slide = null
        if (!pill.isAttachedToWindow || !ReaderMotion.canSlide(pill.context)) {
            pill.translationY = 0f
            pill.clipBounds = null
            ReaderMotion.visibility(pill, if (show) View.VISIBLE else View.GONE)
            return
        }
        if (show) {
            pill.alpha = 1f
            pill.visibility = View.VISIBLE
            // NewStoriesPill.kt needs the pill's laid-out place to know how far it slides.
            pill.doOnPreDraw { if (shown) startSlide(fromHidden = true) }
            applySlide(0f)
            pill.invalidate()
        } else {
            if (pill.visibility != View.VISIBLE || pill.height == 0) {
                pill.visibility = View.GONE
                return
            }
            startSlide(fromHidden = false)
        }
    }

    private fun startSlide(fromHidden: Boolean) {
        val start = if (fromHidden) 0f else currentSlideProgress()
        val end = if (fromHidden) 1f else 0f
        applySlide(start)
        slide =
            ValueAnimator.ofFloat(start, end).apply {
                duration = PillScrollAway.SLIDE_MILLIS
                interpolator = android.animation.TimeInterpolator(NewStoriesTimeline::ease)
                addUpdateListener { applySlide(it.animatedValue as Float) }
                addListener(
                    object : AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: Animator) {
                            if (slide !== animation) return
                            slide = null
                            if (!shown) pill.visibility = View.GONE
                            applySlide(if (shown) 1f else 0f)
                        }
                    },
                )
                start()
            }
    }

    private var slideProgress = 1f

    private fun currentSlideProgress(): Float = slideProgress

    /**
     * Places the pill [progress] of the way out from the toolbar edge it hides behind: the top of the list
     * for the top pill, the bar under the bottom pill. The part still behind that edge is clipped away, so
     * the pill never draws over the toolbar.
     */
    private fun applySlide(progress: Float) {
        slideProgress = progress
        if (pill.height == 0) return
        val gap = UIUtils.dp2px(pill.context, 12)
        if (placement == Placement.TOP) {
            val hidden = -(pill.top + pill.height).toFloat()
            pill.translationY = hidden * (1f - progress)
            val clipTop = (-(pill.top + pill.translationY)).toInt().coerceIn(0, pill.height)
            pill.clipBounds = if (clipTop > 0) Rect(0, clipTop, pill.width, pill.height) else null
        } else {
            val edge = pill.bottom + gap
            val hidden = (edge - pill.top).toFloat()
            pill.translationY = hidden * (1f - progress)
            val clipBottom = (edge - (pill.top + pill.translationY)).toInt().coerceIn(0, pill.height)
            pill.clipBounds = if (clipBottom < pill.height) Rect(0, 0, pill.width, clipBottom) else null
        }
    }

    /** A tap on the pill, or on ItemSetFragment.java's row standing in for it. */
    fun tap() {
        val fs = feedSet() ?: return
        scrollAway.reset()
        pill.removeCallbacks(returnCheck)
        pill.removeCallbacks(hideCheck)
        // NewStoriesPill.kt's fetch can outlast this list (a tablet switches feeds in place, a reload restarts it);
        // the stories only go into the session they were tapped for.
        val session = realtimeUpdates.readingSession()
        fragment.viewLifecycleOwner.lifecycleScope.launch {
            when (val result = withContext(Dispatchers.IO) { realtimeUpdates.takeNewStoriesForTap(fs) }) {
                RealtimeUpdates.TapResult.None -> Unit
                is RealtimeUpdates.TapResult.Insert -> {
                    if (withContext(Dispatchers.IO) { realtimeUpdates.addToOpenList(result.storyHashes, session) }) {
                        onStoriesAdded(result.storyHashes, result.placement)
                    }
                }
                is RealtimeUpdates.TapResult.Replace -> {
                    if (withContext(Dispatchers.IO) { realtimeUpdates.showOnly(fs, result.storyHashes, session) }) {
                        onReplacedWithNewest(result.storyHashes)
                    }
                }
            }
        }
    }

    companion object {
        /** The pill's look, shared by ItemSetFragment.java's inline row so both read as the same button. */
        @JvmStatic
        fun style(view: TextView) {
            view.background =
                GradientDrawable().apply {
                    cornerRadius = view.resources.displayMetrics.density * 18f
                    setColor(MaterialColors.getColor(view, R.attr.storyStatusFetchingBackgroundColor))
                    setStroke(UIUtils.dp2px(view.context, 1), MaterialColors.getColor(view, R.attr.storyStatusFetchingBorderColor))
                }
            view.setTextColor(MaterialColors.getColor(view, R.attr.storyStatusFetchingTextColor))
        }
    }
}
