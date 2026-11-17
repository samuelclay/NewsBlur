package com.newsblur.view

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Rect
import android.view.View
import android.view.ViewTreeObserver
import android.view.animation.LinearInterpolator
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.database.StoryViewAdapter

/**
 * NewStoriesEntrance.kt's timing and push model, kept apart from views so the cascade can be checked on the JVM.
 * The web (common/motion.js arrive) and iOS (NewStoriesPill.swift) pills use the same numbers.
 */
internal object NewStoriesTimeline {
    const val DURATION_MS = 320f
    const val STAGGER_MS = 70f
    const val MAX_CASCADE_MS = 400f

    // NewStoriesTimeline caps the whole cascade, so a dozen new stories don't take seconds to arrive.
    fun stagger(rows: Int): Float = if (rows > 1) minOf(STAGGER_MS, MAX_CASCADE_MS / (rows - 1)) else 0f

    fun totalMs(rows: Int): Float = DURATION_MS + stagger(rows) * maxOf(rows - 1, 0)

    fun progress(
        elapsedMs: Float,
        delayMs: Float,
    ): Float = ease(((elapsedMs - delayMs) / DURATION_MS).coerceIn(0f, 1f))

    /**
     * How far along each new row is at [elapsedMs], rows listed top to bottom. The bottom-most row drops in first
     * and each row above it follows one stagger later.
     */
    fun rowProgress(
        rows: Int,
        elapsedMs: Float,
    ): FloatArray {
        val step = stagger(rows)
        return FloatArray(rows) { row -> progress(elapsedMs, (rows - 1 - row) * step) }
    }

    /**
     * How far each row is drawn above its final place: the part of every new row at or above it that has yet to
     * drop in. Rows that were already listed pass a progress of 1.
     */
    fun pushOffsets(
        heights: FloatArray,
        progress: FloatArray,
    ): FloatArray {
        var hidden = 0f
        return FloatArray(heights.size) { row ->
            hidden += heights[row] * (1f - progress[row])
            hidden
        }
    }

    /** cubic-bezier(0.22, 1, 0.36, 1): the curve the web and iOS pills slide with. */
    fun ease(x: Float): Float {
        if (x <= 0f) return 0f
        if (x >= 1f) return 1f
        var low = 0f
        var high = 1f
        var t = x
        repeat(24) {
            val current = bezier(t, 0.22f, 0.36f)
            if (kotlin.math.abs(current - x) < 1e-5f) return bezier(t, 1f, 1f)
            if (current < x) low = t else high = t
            t = (low + high) / 2f
        }
        return bezier(t, 1f, 1f)
    }

    private fun bezier(
        t: Float,
        first: Float,
        second: Float,
    ): Float {
        val inverse = 1f - t
        return 3f * inverse * inverse * t * first + 3f * inverse * t * t * second + t * t * t
    }
}

/**
 * NewStoriesEntrance.kt brings the stories NewStoriesPill.kt added into the story list (ItemSetFragment.java).
 * A newest-first list gains them in date order, mostly at its top: each new row drops in from under the row above
 * it (or the list's top edge) and pushes every row below it down with it, the bottom-most new row first, so the
 * rows that were on screen glide down from where they were. An oldest-first list gains them at its end, where each new row rises from its own height below its
 * place while the list scrolls to it, the topmost first.
 */
class NewStoriesEntrance private constructor(
    private val list: RecyclerView,
    private val layoutManager: StoryGridLayoutManager,
    private val adapter: StoryViewAdapter,
    private val newStoryHashes: Set<String>,
    private val atTop: Boolean,
) {
    private class Moving(
        val view: View,
        val position: Int,
        val row: Int,
        val isNew: Boolean,
        val topInset: Int,
        val correctionX: Float,
        val correctionY: Float,
        val originalClip: Rect?,
    )

    private val animator = ValueAnimator()
    private val observer: ViewTreeObserver = list.viewTreeObserver
    private var finished = false
    private var waitingSince = 0L
    private var relayouts = 0
    private var prepared = false
    private var elapsedMs = 0f

    // A newest-first list's rows (grid rows, in a grid) top to bottom, and which of them hold new stories.
    private val moving = mutableListOf<Moving>()
    private var rowHeights = FloatArray(0)
    private var newRows = IntArray(0)

    // An oldest-first list's new rows: their display positions, and when each started rising once it was laid out.
    private val newPositions = adapter.displayPositionsOfStories(newStoryHashes)
    private val risingStarts = HashMap<Int, Float>()
    private val risingViews = HashMap<View, Rect?>()

    private val preDrawListener =
        ViewTreeObserver.OnPreDrawListener {
            if (finished) return@OnPreDrawListener true
            if (atTop) {
                if (prepared) true else prepareTop()
            } else {
                applyRising(elapsedMs)
                true
            }
        }

    private val scrollListener =
        object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(
                recyclerView: RecyclerView,
                newState: Int,
            ) {
                // NewStoriesEntrance.kt hands the list back the moment the reader starts dragging it.
                if (newState == RecyclerView.SCROLL_STATE_DRAGGING) finish()
            }
        }

    private val detachListener =
        object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) = Unit

            override fun onViewDetachedFromWindow(view: View) = finish()
        }

    private fun begin() {
        if (atTop) {
            // NewStoriesEntrance.kt lays out a screen below the end up front; prepareTop asks for more when the new
            // stories are taller than that.
            layoutManager.extraEndSpacePx = list.height
        }
        observer.addOnPreDrawListener(preDrawListener)
        list.addOnScrollListener(scrollListener)
        list.addOnAttachStateChangeListener(detachListener)
        if (!atTop) {
            val total = SCROLL_WINDOW_MS + NewStoriesTimeline.totalMs(newPositions.size)
            startAnimator(total) { applyRising(it) }
        }
        list.postInvalidateOnAnimation()
    }

    /** Runs before the first frame that shows the new stories; returns whether that frame may draw. */
    private fun prepareTop(): Boolean {
        val now = android.os.SystemClock.uptimeMillis()
        if (waitingSince == 0L) waitingSince = now
        // ItemSetFragment.java scrolled in the same frame as the commit; wait for the layout that places the rows.
        if (list.isLayoutRequested || list.hasPendingAdapterUpdates()) return waitForLayout(now)
        val children =
            (0 until list.childCount)
                .map { list.getChildAt(it) }
                .mapNotNull { view ->
                    val position = list.getChildAdapterPosition(view)
                    if (position == RecyclerView.NO_POSITION) null else view to position
                }.sortedBy { it.second }
        val isNew = children.map { (_, position) -> adapter.storyHashAtDisplayPosition(position) in newStoryHashes }
        if (isNew.none { it }) return waitForLayout(now)
        // NewStoriesEntrance.kt replaces the item animator's moves for this update; otherwise the old rows slide
        // down first and the new ones appear in the gap.
        list.itemAnimator?.endAnimations()

        // A grid row holds several tiles; a list row holds one story or cluster row.
        val rowTops = mutableListOf<Int>()
        val rowBottoms = mutableListOf<Int>()
        val rowHasNew = mutableListOf<Boolean>()
        val rowOf = IntArray(children.size)
        children.forEachIndexed { index, (view, _) ->
            val top = layoutManager.getDecoratedTop(view)
            if (rowTops.isEmpty() || top != rowTops.last()) {
                rowTops.add(top)
                rowBottoms.add(layoutManager.getDecoratedBottom(view))
                rowHasNew.add(false)
            } else {
                rowBottoms[rowBottoms.size - 1] = maxOf(rowBottoms.last(), layoutManager.getDecoratedBottom(view))
            }
            if (isNew[index]) rowHasNew[rowHasNew.size - 1] = true
            rowOf[index] = rowTops.size - 1
        }
        val heights = FloatArray(rowTops.size) { row -> ((rowTops.getOrNull(row + 1) ?: rowBottoms[row]) - rowTops[row]).toFloat() }

        // The rows that were on screen start higher by every new row above them, so the layout must reach that far
        // below the screen to keep drawing them.
        var hiddenAbove = 0f
        var neededBottom = -1f
        for (row in rowTops.indices) {
            if (rowTops[row] - hiddenAbove >= list.height) {
                neededBottom = list.height + hiddenAbove
                break
            }
            if (rowHasNew[row]) hiddenAbove += heights[row]
        }
        val itemCount = list.adapter?.itemCount ?: 0
        val reachesEnd = children.last().second >= itemCount - 1
        if (neededBottom < 0 && !reachesEnd) neededBottom = list.height + hiddenAbove + heights.last()
        if (neededBottom > rowBottoms.last() && !reachesEnd && relayouts < MAX_RELAYOUTS) {
            relayouts += 1
            layoutManager.extraEndSpacePx = maxOf(layoutManager.extraEndSpacePx, neededBottom.toInt() + list.height / 4)
            list.requestLayout()
            // NewStoriesEntrance.kt skips this frame rather than show the old rows with nothing below them.
            return false
        }

        newRows = rowHasNew.indices.filter { rowHasNew[it] }.toIntArray()
        rowHeights = heights
        val startOffsets = NewStoriesTimeline.pushOffsets(heights, FloatArray(heights.size) { if (rowHasNew[it]) 0f else 1f })

        // A grid that gains a number of stories that isn't a whole number of rows moves its old tiles across too:
        // each starts at the cell it held before, approximated by the cell now holding the story that many places
        // earlier.
        val columns = layoutManager.spanCount
        val decoratedLeft = HashMap<Int, Int>()
        val decoratedTop = HashMap<Int, Int>()
        children.forEach { (view, position) ->
            decoratedLeft[position] = layoutManager.getDecoratedLeft(view)
            decoratedTop[position] = layoutManager.getDecoratedTop(view)
        }
        val newPositionsSorted = newPositions.sorted()
        children.forEachIndexed { index, (view, position) ->
            var correctionX = 0f
            var correctionY = 0f
            val shift = newPositionsSorted.count { it < position }
            val earlier = position - shift
            if (!isNew[index] && columns > 1 && shift % columns != 0 && decoratedLeft.containsKey(earlier)) {
                correctionX = (decoratedLeft.getValue(earlier) - decoratedLeft.getValue(position)).toFloat()
                correctionY = decoratedTop.getValue(earlier) - decoratedTop.getValue(position) + startOffsets[rowOf[index]]
            }
            moving.add(
                Moving(
                    view = view,
                    position = position,
                    row = rowOf[index],
                    isNew = isNew[index],
                    topInset = view.top - layoutManager.getDecoratedTop(view),
                    correctionX = correctionX,
                    correctionY = correctionY,
                    originalClip = view.clipBounds,
                ),
            )
        }
        prepared = true
        applyPush(0f)
        startAnimator(NewStoriesTimeline.totalMs(newRows.size)) { applyPush(it) }
        return true
    }

    private fun waitForLayout(now: Long): Boolean {
        if (now - waitingSince > MAX_LAYOUT_WAIT_MS) finish() else list.postInvalidateOnAnimation()
        return true
    }

    private fun applyPush(elapsedMs: Float) {
        val newRowProgress = NewStoriesTimeline.rowProgress(newRows.size, elapsedMs)
        val progress = FloatArray(rowHeights.size) { 1f }
        newRows.forEachIndexed { rank, row -> progress[row] = newRowProgress[rank] }
        val offsets = NewStoriesTimeline.pushOffsets(rowHeights, progress)
        val total = NewStoriesTimeline.totalMs(newRows.size)
        val settling = 1f - NewStoriesTimeline.ease((elapsedMs / total).coerceIn(0f, 1f))
        for (row in moving) {
            val view = row.view
            if (!view.isAttachedToWindow || list.getChildAdapterPosition(view) != row.position) {
                reset(view, row.originalClip)
                continue
            }
            view.translationX = row.correctionX * settling
            view.translationY = -offsets[row.row] + row.correctionY * settling
            if (!row.isNew) continue
            // The part of a new row still hidden is clipped away, so it emerges from under the row above it (or
            // the list's top edge) instead of drawing over it.
            val hidden = rowHeights[row.row] * (1f - progress[row.row])
            val clipTop = (hidden - row.topInset).toInt().coerceIn(0, view.height)
            view.clipBounds = if (clipTop > 0) Rect(0, clipTop, view.width, view.height) else row.originalClip
            view.alpha = progress[row.row]
        }
    }

    private fun applyRising(elapsedMs: Float) {
        val step = NewStoriesTimeline.stagger(newPositions.size)
        var allDone = risingStarts.size == newPositions.size
        val seen = HashSet<View>()
        for (index in 0 until list.childCount) {
            val view = list.getChildAt(index)
            val rank = newPositions.indexOf(list.getChildAdapterPosition(view))
            if (rank < 0) continue
            seen.add(view)
            if (!risingViews.containsKey(view)) risingViews[view] = view.clipBounds
            // A row first laid out after its turn (the list was still scrolling to it) rises from that moment.
            val start = risingStarts.getOrPut(rank) { maxOf(elapsedMs, rank * step) }
            val progress = NewStoriesTimeline.progress(elapsedMs, start)
            view.translationY = view.height * (1f - progress)
            view.alpha = progress
            if (progress < 1f) allDone = false
        }
        // A rising row the list recycled for another story goes back to normal.
        risingViews.keys.filter { it !in seen }.forEach { view -> reset(view, risingViews.remove(view)) }
        if (allDone && risingStarts.isNotEmpty()) list.post { finish() }
    }

    private fun startAnimator(
        totalMs: Float,
        apply: (Float) -> Unit,
    ) {
        animator.setFloatValues(0f, totalMs)
        animator.duration = totalMs.toLong()
        animator.interpolator = LinearInterpolator()
        animator.addUpdateListener {
            if (finished) return@addUpdateListener
            elapsedMs = it.animatedValue as Float
            apply(elapsedMs)
        }
        animator.addListener(
            object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) = finish()
            },
        )
        animator.start()
    }

    /** Puts every row at its final place at once. */
    fun finish() {
        if (finished) return
        finished = true
        animator.removeAllUpdateListeners()
        animator.removeAllListeners()
        animator.cancel()
        if (observer.isAlive) observer.removeOnPreDrawListener(preDrawListener)
        list.viewTreeObserver.removeOnPreDrawListener(preDrawListener)
        list.removeOnScrollListener(scrollListener)
        list.removeOnAttachStateChangeListener(detachListener)
        moving.forEach { reset(it.view, it.originalClip) }
        moving.clear()
        risingViews.forEach { (view, clip) -> reset(view, clip) }
        risingViews.clear()
        layoutManager.extraEndSpacePx = 0
    }

    private fun reset(
        view: View,
        clip: Rect?,
    ) {
        view.translationX = 0f
        view.translationY = 0f
        view.alpha = 1f
        view.clipBounds = clip
    }

    companion object {
        // An oldest-first list scrolls to its new stories while they rise; rows that scroll in late still rise.
        private const val SCROLL_WINDOW_MS = 1500f
        private const val MAX_LAYOUT_WAIT_MS = 500L
        private const val MAX_RELAYOUTS = 2

        /** The rows just appear when the system or NewsBlur's own setting turns motion off. */
        @JvmStatic
        fun isEnabled(context: Context): Boolean = ReaderMotion.canSlide(context)

        /**
         * Starts the entrance for stories the adapter has just committed. ItemSetFragment.java calls this from the
         * commit, before the frame that first lays them out.
         */
        @JvmStatic
        fun start(
            list: RecyclerView,
            adapter: StoryViewAdapter,
            newStoryHashes: Set<String>,
            atTop: Boolean,
        ): NewStoriesEntrance? {
            val layoutManager = list.layoutManager as? StoryGridLayoutManager ?: return null
            if (!isEnabled(list.context) || !list.isAttachedToWindow || newStoryHashes.isEmpty()) return null
            val entrance = NewStoriesEntrance(list, layoutManager, adapter, newStoryHashes, atTop)
            if (entrance.newPositions.isEmpty()) return null
            entrance.begin()
            return entrance
        }
    }
}
