package com.newsblur.util

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import androidx.window.embedding.SplitAttributes
import androidx.window.embedding.SplitInfo
import androidx.window.WindowSdkExtensions
import com.newsblur.NbApplication
import com.newsblur.R
import com.newsblur.activity.FeedListDrawer
import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading
import com.newsblur.activity.ReadingPlaceholder

/** A quiet, full-height resize border inside StorySplitView.kt's owning list pane. */
internal class TabletPaneDivider private constructor(private val activity: Activity) :
    View(activity) {
    private val density = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var rightEdge = true
    private var feeds = false
    private var dragging = false
    private var startX = 0f
    private var startRatio = 0f
    private var parentWidth = 1f
    private var parentLeft = 0f
    private var ratio = 0f
    private var frameUpdatePosted = false
    private var previewResize = false
    private var resizeGuide: TabletPaneResizeGuide? = null
    private val prefs get() = (activity.applicationContext as NbApplication).prefsRepo.get()
    private val frameUpdate = Runnable { applyPendingResize() }

    private fun applyPendingResize() {
        frameUpdatePosted = false
        if (dragging && !previewResize) StorySplitView.resizePane(activity, feeds, ratio, false)
    }

    init {
        visibility = GONE
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    fun update(splits: List<SplitInfo>) {
        if (splits.isEmpty()) {
            visibility = GONE
            removeCallbacks(frameUpdate)
            frameUpdatePosted = false
            resizeGuide?.dismiss()
            resizeGuide = null
            if (dragging) parent?.requestDisallowInterceptTouchEvent(false)
            dragging = false
            return
        }
        // Reading.kt may cover a still-alive FeedListDrawer.kt. Prefer the foreground reader
        // pair so the titles' border never changes the hidden feed column's preference.
        val reader = Reading.peekReader(activity.taskId)
        val readerSplit = if (activity is FeedListDrawer ||
            reader == null
        ) {
            null
        } else {
            splits.lastOrNull {
                reader in it.secondaryActivityStack &&
                    (activity in it.primaryActivityStack || activity in it.secondaryActivityStack)
            }
        }
        val split = (
            readerSplit ?: splits.lastOrNull {
                it.splitAttributes.splitType != SplitAttributes.SplitType.SPLIT_TYPE_EXPAND &&
                    (activity in it.primaryActivityStack || activity in it.secondaryActivityStack)
            }
            )?.takeIf {
            it.splitAttributes.splitType != SplitAttributes.SplitType.SPLIT_TYPE_EXPAND
        }
        val feedList = FeedListDrawer.peek(activity.taskId)
        feeds = readerSplit == null && feedList != null &&
            split != null && feedList in split.secondaryActivityStack
        val ownsDivider = if (feeds) activity is FeedListDrawer else activity is ItemsList
        visibility = if (split != null && ownsDivider) VISIBLE else GONE
        if (split == null || !ownsDivider) {
            removeCallbacks(frameUpdate)
            frameUpdatePosted = false
            resizeGuide?.dismiss()
            resizeGuide = null
            if (dragging) parent?.requestDisallowInterceptTouchEvent(false)
            dragging = false
            return
        }
        val primaryOnRight =
            split.splitAttributes.layoutDirection == SplitAttributes.LayoutDirection.RIGHT_TO_LEFT ||
                (
                    split.splitAttributes.layoutDirection == SplitAttributes.LayoutDirection.LOCALE &&
                        layoutDirection == LAYOUT_DIRECTION_RTL
                    )
        rightEdge = (activity in split.primaryActivityStack) != primaryOnRight
        val params = layoutParams as FrameLayout.LayoutParams
        val gravity = if (rightEdge) Gravity.RIGHT else Gravity.LEFT
        if (params.gravity != gravity) {
            params.gravity = gravity
            layoutParams = params
        }
        contentDescription =
            context.getString(if (feeds) R.string.resize_feed_list else R.string.resize_story_list)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        if (dragging && previewResize) return
        val borderWidth = 3 * density
        val left = if (rightEdge) width - borderWidth else 0f
        val right = left + borderWidth
        val center = height / 2f
        val colors = TabletPaneResizeGuide.colors(activity)
        paint.color = colors.border
        // TabletPaneDivider.kt draws wholly inside the list; the adjacent pane stays untouched.
        canvas.drawRect(left, 0f, right, height.toFloat(), paint)
        paint.color = colors.indicator
        paint.alpha = if (dragging || isFocused) 230 else 140
        canvas.drawRoundRect(
            left,
            center - 24 * density,
            right,
            center + 24 * density,
            borderWidth / 2,
            borderWidth / 2,
            paint
        )
        paint.alpha = 255
    }

    private fun prepareDrag() {
        val bounds = Rect(activity.windowManager.currentWindowMetrics.bounds)
        val titles = ItemsList.peekReadingLaunchParent(activity.taskId)
        val secondary = if (feeds) {
            FeedListDrawer.peek(
                activity.taskId
            )
        } else {
            Reading.peekReader(activity.taskId) ?: ReadingPlaceholder.peek(activity.taskId)
        }
        if (titles != null) bounds.union(titles.windowManager.currentWindowMetrics.bounds)
        if (secondary != null) bounds.union(secondary.windowManager.currentWindowMetrics.bounds)
        parentWidth = bounds.width().toFloat().coerceAtLeast(1f)
        parentLeft = bounds.left.toFloat()
        startRatio =
            if (feeds) {
                TabletPaneSizing.feedRatio(
                    prefs.getFeedListWidthRatio(),
                    parentWidth / density
                )
            } else {
                TabletPaneSizing.storyRatio(prefs.getStoryListSplitRatio(), parentWidth / density)
            }
        ratio = startRatio
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // TabletPaneDivider.kt's wider invisible strip must leave toolbar buttons usable.
                for (id in listOf(R.id.toolbar, R.id.bottom_toolbar, R.id.itemlist_story_header, R.id.bottom_next_feed_control)) {
                    val controls = activity.findViewById<View>(id) ?: continue
                    if (!controls.isShown) continue
                    val location = IntArray(2)
                    controls.getLocationOnScreen(location)
                    if (event.rawX >= location[0] && event.rawX < location[0] + controls.width &&
                        event.rawY >= location[1] && event.rawY < location[1] + controls.height
                    ) return false
                }
                prepareDrag()
                startX = event.rawX
                dragging = true
                // API3 embedding on Samsung queues resize animations. Preview the exact width
                // until release; API7's JUMP_CUT in StorySplitView.kt supports live reflow.
                previewResize = WindowSdkExtensions.getInstance().extensionVersion < 7
                if (previewResize) {
                    val peer = if (feeds) ItemsList.peekReadingLaunchParent(activity.taskId)
                        else Reading.peekReader(activity.taskId) ?: ReadingPlaceholder.peek(activity.taskId)
                    val location = IntArray(2)
                    getLocationOnScreen(location)
                    resizeGuide = TabletPaneResizeGuide.show(
                        activity, peer, location[1], location[1] + height, rightEdge, density
                    )
                    resizeGuide?.move(parentLeft + (if (rightEdge) ratio else 1f - ratio) * parentWidth)
                }
                parent.requestDisallowInterceptTouchEvent(true)
                invalidate()
            }
            MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (!dragging) return false
                if (event.actionMasked != MotionEvent.ACTION_CANCEL) {
                    val requested = TabletPaneSizing.draggedRatio(
                        startRatio,
                        event.rawX - startX,
                        parentWidth,
                        // Follow the owner's actual edge, including while its locale is changing.
                        !rightEdge
                    )
                    ratio = if (feeds) {
                        TabletPaneSizing.feedRatio(requested, parentWidth / density)
                    } else {
                        TabletPaneSizing.storyRatio(requested, parentWidth / density)
                    }
                }
                if (event.actionMasked == MotionEvent.ACTION_MOVE) {
                    if (previewResize) {
                        resizeGuide?.move(parentLeft + (if (rightEdge) ratio else 1f - ratio) * parentWidth)
                        return true
                    }
                    // TabletPaneDivider.kt must keep the pending callback: input runs before
                    // animation callbacks, so canceling/reposting on every MOVE starves resizing.
                    if (!frameUpdatePosted) {
                        frameUpdatePosted = true
                        postOnAnimation(frameUpdate)
                    }
                } else {
                    dragging = false
                    removeCallbacks(frameUpdate)
                    frameUpdatePosted = false
                    resizeGuide?.dismiss()
                    resizeGuide = null
                    if (event.actionMasked != MotionEvent.ACTION_CANCEL || !previewResize) {
                        StorySplitView.resizePane(activity, feeds, ratio, true)
                    }
                    parent.requestDisallowInterceptTouchEvent(false)
                    invalidate()
                    if (event.actionMasked == MotionEvent.ACTION_UP) performClick()
                }
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    override fun onDetachedFromWindow() {
        // TabletPaneDivider.kt must not update an old activity pair after its window closes.
        removeCallbacks(frameUpdate)
        frameUpdatePosted = false
        resizeGuide?.dismiss()
        resizeGuide = null
        if (dragging) parent?.requestDisallowInterceptTouchEvent(false)
        dragging = false
        super.onDetachedFromWindow()
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = android.widget.SeekBar::class.java.name
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)
    }

    override fun performAccessibilityAction(action: Int, arguments: android.os.Bundle?): Boolean {
        if (action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD ||
            action == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        ) {
            prepareDrag()
            val requested =
                startRatio +
                    if (action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) .05f else -.05f
            val next = if (feeds) {
                TabletPaneSizing.feedRatio(requested, parentWidth / density)
            } else {
                TabletPaneSizing.storyRatio(requested, parentWidth / density)
            }
            StorySplitView.resizePane(activity, feeds, next, true)
            return true
        }
        return super.performAccessibilityAction(action, arguments)
    }

    companion object {
        fun attach(activity: Activity): TabletPaneDivider? {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                (activity !is ItemsList && activity !is FeedListDrawer)
            ) {
                return null
            }
            return TabletPaneDivider(activity).also {
                activity.addContentView(
                    it,
                    FrameLayout.LayoutParams(
                        (32 * it.density).toInt(),
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        Gravity.RIGHT
                    )
                )
            }
        }
    }
}
