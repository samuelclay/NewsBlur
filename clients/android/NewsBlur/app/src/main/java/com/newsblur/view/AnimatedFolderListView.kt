package com.newsblur.view

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.ExpandableListView
import com.newsblur.R
import com.newsblur.util.UIUtils
import com.newsblur.util.ViewUtils
import kotlin.math.abs
import kotlin.math.roundToInt

/** Keeps FolderListAdapter.java's visible rows continuous across native group changes. */
class AnimatedFolderListView
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
        defStyleAttr: Int = android.R.attr.expandableListViewStyle,
    ) : ExpandableListView(context, attrs, defStyleAttr) {
        private data class Snapshot(
            val row: FolderListTransition.Row,
            val bitmap: Bitmap,
            val left: Float,
        )

        private data class MovingView(
            val view: View,
            val motion: FolderListTransition.Motion,
        )

        private data class LeavingRow(
            val snapshot: Snapshot,
            val motion: FolderListTransition.Motion,
        )

        private val snapshotPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        private var transitionBackground: Drawable? = null
        private var movingViews = emptyList<MovingView>()
        private var leavingRows = emptyList<LeavingRow>()
        private var animator: ValueAnimator? = null
        private var pendingLayout: ViewTreeObserver.OnPreDrawListener? = null
        private var preparingChange = false
        private var progress = 0f
        private var touchDownY = 0f
        private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
        private val seenRows = mutableSetOf<Long>()

        fun animateFilterChange(change: Runnable) {
            val animate =
                isLaidOut && isAttachedToWindow && ValueAnimator.areAnimatorsEnabled() &&
                    !ViewUtils.isPowerSaveMode(context)
            val before = if (animate) captureVisibleRows() else emptyList()
            finishTransition()
            for (index in 0 until childCount) getChildAt(index).clearAnimation()
            seenRows.clear()
            preparingChange = true
            try {
                // AnimatedFolderListView.kt changes the real filter immediately, including during a previous transition.
                change.run()
            } finally {
                preparingChange = false
            }
            if (!animate) return

            val listener =
                object : ViewTreeObserver.OnPreDrawListener {
                    override fun onPreDraw(): Boolean {
                        viewTreeObserver.removeOnPreDrawListener(this)
                        pendingLayout = null
                        val lift = resources.displayMetrics.density * 8f
                        leavingRows = before.map { snapshot ->
                            LeavingRow(
                                snapshot,
                                FolderListTransition.Motion(
                                    snapshot.row,
                                    snapshot.row.copy(top = snapshot.row.top - lift, alpha = 0f),
                                ),
                            )
                        }
                        progress = 0f
                        animator =
                            ValueAnimator.ofFloat(0f, 1f).apply {
                                duration = 180L
                                interpolator = DecelerateInterpolator(1.5f)
                                addUpdateListener {
                                    progress = it.animatedValue as Float
                                    invalidate()
                                }
                                addListener(
                                    object : AnimatorListenerAdapter() {
                                        override fun onAnimationEnd(animation: Animator) {
                                            if (animator === animation) finishTransition()
                                        }
                                    },
                                )
                                start()
                            }
                        return true
                    }
                }
            pendingLayout = listener
            viewTreeObserver.addOnPreDrawListener(listener)
        }

        fun animateGroupChange(
            groupPosition: Int,
            expanding: Boolean,
            change: Runnable,
        ) {
            val groups = expandableListAdapter
            if (!isLaidOut || !isAttachedToWindow || !ValueAnimator.areAnimatorsEnabled() || groups == null) {
                finishTransition()
                change.run()
                return
            }

            val anchorId = groups.getGroupId(groupPosition)
            val anchorPosition = getFlatListPosition(getPackedPositionForGroup(groupPosition))
            val anchorView = getChildAt(anchorPosition - firstVisiblePosition)
            val anchorTop = anchorView?.let { it.top + it.translationY }
            val anchorBottom = anchorTop?.plus(anchorView.height) ?: paddingTop.toFloat()
            val before = captureVisibleRows()
            finishTransition()

            preparingChange = true
            try {
                change.run()
                if (anchorTop != null) {
                    val newGroupPosition = (0 until groups.groupCount).firstOrNull { groups.getGroupId(it) == anchorId }
                    if (newGroupPosition != null) {
                        val flatPosition = getFlatListPosition(getPackedPositionForGroup(newGroupPosition))
                        setSelectionFromTop(flatPosition, anchorTop.roundToInt() - paddingTop)
                    }
                }
            } finally {
                preparingChange = false
            }

            val listener =
                object : ViewTreeObserver.OnPreDrawListener {
                    override fun onPreDraw(): Boolean {
                        viewTreeObserver.removeOnPreDrawListener(this)
                        pendingLayout = null
                        startTransition(before, anchorBottom, expanding)
                        return true
                    }
                }
            pendingLayout = listener
            viewTreeObserver.addOnPreDrawListener(listener)
        }

        private fun captureVisibleRows(): List<Snapshot> {
            val snapshots = mutableListOf<Snapshot>()
            // AnimatedFolderListView.kt retains only rows intersecting this viewport, never the whole feed list.
            for (index in 0 until childCount) {
                val child = getChildAt(index)
                val row = geometry(child, index)
                if (child.width == 0 || child.height == 0 || row.top >= height || row.top + row.height <= 0f) continue
                val bitmap = Bitmap.createBitmap(child.width, child.height, Bitmap.Config.ARGB_8888)
                child.draw(Canvas(bitmap))
                snapshots.add(Snapshot(row, bitmap, child.left.toFloat()))
            }
            val visibleIds = snapshots.mapTo(mutableSetOf()) { it.row.id }
            for (leaving in leavingRows) {
                val motion = leaving.motion
                val top = interpolate(motion.before.top, motion.after.top)
                val alpha = interpolate(motion.before.alpha, motion.after.alpha)
                if (motion.before.id !in visibleIds && alpha > 0f && top < height && top + motion.before.height > 0f) {
                    snapshots.add(leaving.snapshot.copy(row = leaving.snapshot.row.copy(top = top, alpha = alpha)))
                }
            }
            return snapshots
        }

        private fun geometry(child: View, index: Int) =
            FolderListTransition.Row(
                id = getItemIdAtPosition(firstVisiblePosition + index),
                top = child.top + child.translationY,
                height = child.height,
                alpha = child.alpha,
                indicatorRotation = child.findViewById<View>(R.id.row_folder_indicator)?.rotation,
            )

        private fun startTransition(
            snapshots: List<Snapshot>,
            anchorBottom: Float,
            expanding: Boolean,
        ) {
            val currentViews = (0 until childCount).map { index -> geometry(getChildAt(index), index) to getChildAt(index) }
            // AnimatedFolderListView.kt's group transition already presents these rows; a redraw must not also cascade them.
            seenRows.addAll(currentViews.map { it.first.id })
            val motions =
                FolderListTransition.plan(
                    before = snapshots.map { it.row },
                    after = currentViews.map { it.first },
                    viewportBottom = (height - paddingBottom).toFloat(),
                    anchorBottom = anchorBottom,
                    expanding = expanding,
                    revealDistance = resources.displayMetrics.density * 16f,
                ).associateBy { it.after.id }
            movingViews = currentViews.map { (row, view) -> MovingView(view, motions.getValue(row.id)) }
            val visibleIds = currentViews.mapTo(mutableSetOf()) { it.first.id }
            leavingRows = snapshots.filter { it.row.id !in visibleIds }.map { LeavingRow(it, motions.getValue(it.row.id)) }

            progress = 0f
            applyProgress()
            animator =
                ValueAnimator.ofFloat(0f, 1f).apply {
                    duration = if (expanding) 320L else 180L
                    interpolator = if (expanding) android.view.animation.OvershootInterpolator(.45f) else DecelerateInterpolator(1.5f)
                    addUpdateListener {
                        progress = it.animatedValue as Float
                        applyProgress()
                    }
                    addListener(
                        object : AnimatorListenerAdapter() {
                            override fun onAnimationEnd(animation: Animator) {
                                if (animator === animation) finishTransition()
                            }
                        },
                    )
                    start()
                }
        }

        private fun applyProgress() {
            for ((view, motion) in movingViews) {
                view.translationY = interpolate(motion.before.top, motion.after.top) - view.top
                view.alpha = interpolate(motion.before.alpha, motion.after.alpha).coerceIn(0f, 1f)
                val oldRotation = motion.before.indicatorRotation
                val newRotation = motion.after.indicatorRotation
                if (oldRotation != null && newRotation != null) {
                    view.findViewById<View>(R.id.row_folder_indicator)?.rotation = interpolate(oldRotation, newRotation)
                }
            }
            invalidate()
        }

        private fun interpolate(start: Float, end: Float) = start + (end - start) * progress

        private fun finishTransition() {
            pendingLayout?.let { if (viewTreeObserver.isAlive) viewTreeObserver.removeOnPreDrawListener(it) }
            pendingLayout = null
            val previousAnimator = animator
            animator = null
            previousAnimator?.cancel()
            for ((view, motion) in movingViews) {
                view.translationY = 0f
                view.alpha = 1f
                motion.after.indicatorRotation?.let { view.findViewById<View>(R.id.row_folder_indicator)?.rotation = it }
            }
            movingViews = emptyList()
            leavingRows = emptyList()
            invalidate()
        }

        override fun dispatchDraw(canvas: Canvas) {
            presentVisibleRows()
            val checkpoint = canvas.save()
            // AnimatedFolderListView.kt honors Main.java's floating-toolbar padding without cutting off rows behind it.
            val left = if (clipToPadding) paddingLeft else 0
            val top = if (clipToPadding) paddingTop else 0
            val right = width - if (clipToPadding) paddingRight else 0
            val bottom = height - if (clipToPadding) paddingBottom else 0
            canvas.clipRect(left, top, right, bottom)
            if (animator != null) {
                // row_folder.xml supplies every theme's surface; fading snapshots must not uncover
                // the window behind AnimatedFolderListView.kt while following folders are moving.
                val surface =
                    transitionBackground ?: context.getDrawable(
                        UIUtils.getThemedResource(context, R.attr.selectorFolderBackground, android.R.attr.background),
                    )?.mutate()?.also { transitionBackground = it }
                surface?.setBounds(left, top, right, bottom)
                surface?.draw(canvas)
            }
            for ((snapshot, motion) in leavingRows) {
                snapshotPaint.alpha = (255f * interpolate(motion.before.alpha, motion.after.alpha)).roundToInt().coerceIn(0, 255)
                canvas.drawBitmap(snapshot.bitmap, snapshot.left, interpolate(motion.before.top, motion.after.top), snapshotPaint)
            }
            super.dispatchDraw(canvas)
            canvas.restoreToCount(checkpoint)
        }

        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            if (event.actionMasked == MotionEvent.ACTION_DOWN) touchDownY = event.y
            if (event.actionMasked == MotionEvent.ACTION_MOVE && abs(event.y - touchDownY) > touchSlop) finishTransition()
            return super.dispatchTouchEvent(event)
        }

        override fun layoutChildren() {
            // Scrolling, sync updates and rotation in FolderListFragment.java must never recycle a translated row.
            if (!preparingChange && pendingLayout == null) finishTransition()
            super.layoutChildren()
        }

        private fun presentVisibleRows() {
            if (preparingChange || pendingLayout != null || !isAttachedToWindow || !isShown || windowVisibility != View.VISIBLE) return
            val entering = mutableListOf<Pair<Long, View>>()
            val visibleTop = if (clipToPadding) paddingTop else 0
            val visibleBottom = height - if (clipToPadding) paddingBottom else 0
            for (index in 0 until childCount) {
                val child = getChildAt(index)
                if (firstVisiblePosition + index < headerViewsCount) continue
                if (child.bottom <= visibleTop || child.top >= visibleBottom || child.height == 0) continue
                val identity = getItemIdAtPosition(firstVisiblePosition + index)
                if (identity !in seenRows) entering.add(identity to child)
            }
            // AnimatedFolderListView.kt waits until drawing, so detached measurement cannot spend a folder's entrance.
            // AnimatedFolderListView.kt compresses the cascade to keep every visible title in order without a shared hard cap.
            val ordered = entering.sortedBy { it.second.top }
            val step = if (ordered.size > 1) minOf(35.0, 175.0 / (ordered.size - 1)) else 0.0
            ordered.forEachIndexed { index, (identity, child) ->
                if (!ValueAnimator.areAnimatorsEnabled() ||
                    ViewUtils.isPowerSaveMode(context) ||
                    ReaderMotion.enter(child, (index * step).toLong(), 12f)
                ) {
                    seenRows.add(identity)
                }
            }
        }

        override fun onDetachedFromWindow() {
            finishTransition()
            super.onDetachedFromWindow()
        }
    }
