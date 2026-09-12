package com.newsblur.view

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.ExpandableListView
import com.newsblur.R
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
        private var movingViews = emptyList<MovingView>()
        private var leavingRows = emptyList<LeavingRow>()
        private var animator: ValueAnimator? = null
        private var pendingLayout: ViewTreeObserver.OnPreDrawListener? = null
        private var preparingChange = false
        private var progress = 0f
        private var touchDownY = 0f
        private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

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
                    duration = 220L
                    interpolator = DecelerateInterpolator(1.5f)
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
                view.alpha = interpolate(motion.before.alpha, motion.after.alpha)
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
            val checkpoint = canvas.save()
            canvas.clipRect(paddingLeft, paddingTop, width - paddingRight, height - paddingBottom)
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

        override fun onDetachedFromWindow() {
            finishTransition()
            super.onDetachedFromWindow()
        }
    }
