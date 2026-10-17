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
import com.newsblur.NbApplication
import com.newsblur.R
import com.newsblur.activity.FeedListDrawer
import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading

/** Each pane draws half a shared handle, centered on StorySplitView.kt's column boundary. */
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
    private var ratio = 0f
    private val prefs get() = (activity.applicationContext as NbApplication).prefsRepo.get()
    private val frameUpdate = Runnable { StorySplitView.resizePane(activity, feeds, ratio, false) }

    init {
        visibility = GONE
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        elevation = 8 * density
    }

    fun update(splits: List<SplitInfo>) {
        if (splits.isEmpty()) {
            visibility = GONE
            removeCallbacks(frameUpdate)
            if (dragging) parent?.requestDisallowInterceptTouchEvent(false)
            dragging = false
            return
        }
        // Reading.kt may cover a still-alive FeedListDrawer.kt. Prefer the foreground reader
        // pair so the titles' half-handle never changes the hidden feed column's preference.
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
        visibility = if (split == null) GONE else VISIBLE
        if (split == null) {
            removeCallbacks(frameUpdate)
            if (dragging) parent?.requestDisallowInterceptTouchEvent(false)
            dragging = false
            return
        }
        val feedList = FeedListDrawer.peek(activity.taskId)
        feeds = readerSplit == null && feedList != null && feedList in split.secondaryActivityStack
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
        val edge = if (rightEdge) width.toFloat() else 0f
        val center = height / 2f
        paint.color = context.getColor(
            when (prefs.getResolvedTheme(context)) {
                PrefConstants.ThemeValue.DARK -> R.color.segmented_control_border_dark
                PrefConstants.ThemeValue.BLACK -> R.color.segmented_control_border_black
                PrefConstants.ThemeValue.SEPIA -> R.color.segmented_control_border_sepia
                else -> R.color.segmented_control_border_light
            }
        )
        canvas.drawRect(edge - density / 2, 0f, edge + density / 2, height.toFloat(), paint)
        val colors = context.obtainStyledAttributes(
            intArrayOf(android.R.attr.colorBackground, android.R.attr.textColorSecondary)
        )
        paint.color = colors.getColor(0, paint.color)
        canvas.drawRoundRect(
            edge - 7 * density,
            center - 25 * density,
            edge + 7 * density,
            center + 25 * density,
            7 * density,
            7 * density,
            paint
        )
        paint.color = colors.getColor(1, paint.color)
        colors.recycle()
        paint.alpha = if (dragging || isFocused) 255 else 170
        canvas.drawRoundRect(
            edge - 2 * density,
            center - 15 * density,
            edge + 2 * density,
            center + 15 * density,
            2 * density,
            2 * density,
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
            Reading.peekReader(activity.taskId)
        }
        if (titles != null) bounds.union(titles.windowManager.currentWindowMetrics.bounds)
        if (secondary != null) bounds.union(secondary.windowManager.currentWindowMetrics.bounds)
        parentWidth = bounds.width().toFloat().coerceAtLeast(1f)
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
                if (kotlin.math.abs(event.y - height / 2f) > 32 * density) return false
                prepareDrag()
                startX = event.rawX
                dragging = true
                parent.requestDisallowInterceptTouchEvent(true)
                invalidate()
            }
            MotionEvent.ACTION_MOVE -> {
                if (!dragging) return false
                val requested = TabletPaneSizing.draggedRatio(
                    startRatio,
                    event.rawX - startX,
                    parentWidth,
                    layoutDirection == LAYOUT_DIRECTION_RTL
                )
                ratio = if (feeds) {
                    TabletPaneSizing.feedRatio(requested, parentWidth / density)
                } else {
                    TabletPaneSizing.storyRatio(requested, parentWidth / density)
                }
                removeCallbacks(frameUpdate)
                postOnAnimation(frameUpdate)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (!dragging) return false
                dragging = false
                removeCallbacks(frameUpdate)
                StorySplitView.resizePane(activity, feeds, ratio, true)
                parent.requestDisallowInterceptTouchEvent(false)
                invalidate()
                if (event.actionMasked == MotionEvent.ACTION_UP) performClick()
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
                (activity !is ItemsList && activity !is Reading && activity !is FeedListDrawer)
            ) {
                return null
            }
            return TabletPaneDivider(activity).also {
                activity.addContentView(
                    it,
                    FrameLayout.LayoutParams(
                        (24 * it.density).toInt(),
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        Gravity.RIGHT
                    )
                )
            }
        }
    }
}
