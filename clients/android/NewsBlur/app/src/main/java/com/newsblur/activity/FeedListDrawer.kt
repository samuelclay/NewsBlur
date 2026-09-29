package com.newsblur.activity

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import com.newsblur.R
import com.newsblur.util.PendingTransitionUtils
import com.newsblur.util.StorySplitView
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import java.lang.ref.WeakReference
import kotlin.math.abs
import kotlin.math.min

/**
 * The feed list as a slide-over on tablets. Main.java's whole screen (header, search, folders,
 * filters, sync status) moves into a panel on the left, over a dimmed scrim that covers both the
 * story list and the reader beneath it. StorySplitView.kt always expands this activity to the
 * whole window, so it sits above both panes. Picking a feed replaces the story list beneath and
 * takes the panel away with the old one; tapping the scrim, Back, or swiping the panel left
 * closes it. A swipe that starts on the story list opens it under the finger (beginOpenGesture).
 */
@AndroidEntryPoint
class FeedListDrawer : Main() {
    private lateinit var scrim: View
    private lateinit var panel: FrameLayout
    private var panelWidth = 1
    private var animator: ValueAnimator? = null
    private var closing = false

    // Swiping the panel left to close it.
    private var downRawX = 0f
    private var downRawY = 0f
    private var isDraggingClosed = false
    private var velocityTracker: VelocityTracker? = null

    override fun isFeedDrawer(): Boolean = true

    // The story list and reader stay visible, dimmed, beneath the panel.
    override fun shouldUseTranslucentTheme(): Boolean = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        PendingTransitionUtils.overrideNoEnterTransition(this)
        wrapInPanel()
        activeDrawer = WeakReference(this)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = close()
            },
        )
        when {
            // A rotation recreates the panel already open, so it stays put instead of sliding in again.
            savedInstanceState != null -> setOpenFraction(1f)
            openGesture?.taskId == taskId -> followOpenGesture()
            else -> animateTo(open = true)
        }
    }

    override fun onDestroy() {
        if (activeDrawer.get() === this) activeDrawer.clear()
        animator?.cancel()
        velocityTracker?.recycle()
        velocityTracker = null
        super.onDestroy()
    }

    // Picking a feed starts its story list as the root of a fresh task, which forms a new split with
    // the placeholder pane and takes this panel away along with the old story list and reader.
    @Deprecated("Activity result APIs")
    override fun startActivityForResult(
        intent: Intent,
        requestCode: Int,
        options: Bundle?,
    ) {
        if (StorySplitView.isStoryList(intent)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        @Suppress("DEPRECATION")
        super.startActivityForResult(intent, requestCode, options)
    }

    /** Slides the panel away, then finishes. */
    fun close() {
        if (closing) return
        closing = true
        animateTo(open = false)
    }

    private fun wrapInPanel() {
        val content = findViewById<ViewGroup>(android.R.id.content)
        val mainScreen = content.getChildAt(0)
        content.removeView(mainScreen)
        panelWidth = min(UIUtils.dp2px(this, PANEL_MAX_WIDTH_DP), (resources.displayMetrics.widthPixels * PANEL_MAX_FRACTION).toInt())
        scrim =
            View(this).apply {
                setBackgroundColor(SCRIM_COLOR)
                alpha = 0f
                setOnClickListener { close() }
            }
        panel =
            FrameLayout(this).apply {
                background = listBackground()
                elevation = UIUtils.dp2px(this@FeedListDrawer, PANEL_ELEVATION_DP).toFloat()
                translationX = -panelWidth.toFloat()
                addView(mainScreen, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            }
        val root = FrameLayout(this)
        root.addView(scrim, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        root.addView(panel, FrameLayout.LayoutParams(panelWidth, ViewGroup.LayoutParams.MATCH_PARENT))
        setContentView(root)
    }

    // Main.java's screen has no background of its own, so the panel paints the theme's list background.
    private fun listBackground(): android.graphics.drawable.Drawable? {
        val styleAttr = TypedValue()
        if (!theme.resolveAttribute(R.attr.listBackground, styleAttr, true)) return null
        val attrs = obtainStyledAttributes(styleAttr.resourceId, intArrayOf(android.R.attr.background))
        return try {
            attrs.getDrawable(0)
        } finally {
            attrs.recycle()
        }
    }

    private fun openFraction(): Float = 1f + panel.translationX / panelWidth

    private fun setOpenFraction(fraction: Float) {
        panel.translationX = -panelWidth * (1f - fraction)
        scrim.alpha = fraction
    }

    private fun animateTo(open: Boolean) {
        animator?.cancel()
        val start = openFraction()
        val end = if (open) 1f else 0f
        animator =
            ValueAnimator.ofFloat(start, end).apply {
                duration = (SLIDE_DURATION_MS * abs(end - start)).toLong().coerceAtLeast(1L)
                interpolator = SLIDE_INTERPOLATOR
                addUpdateListener { setOpenFraction(it.animatedValue as Float) }
                addListener(
                    object : AnimatorListenerAdapter() {
                        private var cancelled = false

                        override fun onAnimationCancel(animation: Animator) {
                            cancelled = true
                        }

                        override fun onAnimationEnd(animation: Animator) {
                            if (!cancelled && !open) finishWithoutAnimation()
                        }
                    },
                )
                start()
            }
    }

    private fun finishWithoutAnimation() {
        if (!isFinishing) finish()
        PendingTransitionUtils.overrideNoExitTransition(this)
    }

    private fun followOpenGesture() {
        val gesture = openGesture?.takeIf { it.taskId == taskId } ?: return
        if (gesture.released) {
            openGesture = null
            if (gesture.releasedOpen) animateTo(open = true) else close()
            return
        }
        animator?.cancel()
        setOpenFraction((gesture.offsetPx / panelWidth).coerceIn(0f, 1f))
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (closing || openGesture?.taskId == taskId) return super.dispatchTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                isDraggingClosed = false
                velocityTracker?.recycle()
                velocityTracker = VelocityTracker.obtain().also { it.addMovement(event) }
            }

            MotionEvent.ACTION_MOVE -> {
                velocityTracker?.addMovement(event)
                val deltaX = event.rawX - downRawX
                val deltaY = event.rawY - downRawY
                if (!isDraggingClosed &&
                    deltaX < -ViewConfiguration.get(this).scaledTouchSlop &&
                    abs(deltaX) > abs(deltaY) * CLOSE_GESTURE_DIRECTION_RATIO
                ) {
                    isDraggingClosed = true
                    animator?.cancel()
                    // The folder list stops tracking this touch once the panel takes it over.
                    val cancel = MotionEvent.obtain(event).apply { action = MotionEvent.ACTION_CANCEL }
                    super.dispatchTouchEvent(cancel)
                    cancel.recycle()
                }
                if (isDraggingClosed) {
                    setOpenFraction((1f + deltaX / panelWidth).coerceIn(0f, 1f))
                    return true
                }
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isDraggingClosed) {
                    isDraggingClosed = false
                    velocityTracker?.addMovement(event)
                    velocityTracker?.computeCurrentVelocity(1000)
                    val velocityX = velocityTracker?.xVelocity ?: 0f
                    val flungClosed = velocityX < -ViewConfiguration.get(this).scaledMinimumFlingVelocity * CLOSE_FLING_MULTIPLIER
                    if (event.actionMasked == MotionEvent.ACTION_UP && (openFraction() < CLOSE_THRESHOLD || flungClosed)) {
                        close()
                    } else {
                        animateTo(open = true)
                    }
                    return true
                }
            }
        }
        return super.dispatchTouchEvent(event)
    }

    // A swipe on the story list that is opening the panel, tracked before the panel exists. The task
    // keeps a second NewsBlur window (desktop mode) from following another window's swipe.
    private class OpenGesture(
        val taskId: Int,
    ) {
        var offsetPx = 0f
        var released = false
        var releasedOpen = false
    }

    companion object {
        private const val PANEL_MAX_WIDTH_DP = 400
        private const val PANEL_MAX_FRACTION = 0.85f
        private const val PANEL_ELEVATION_DP = 16
        private const val SCRIM_COLOR = 0x66000000
        private const val SLIDE_DURATION_MS = 260L
        private const val CLOSE_THRESHOLD = 0.6f
        private const val CLOSE_GESTURE_DIRECTION_RATIO = 1.2f
        private const val CLOSE_FLING_MULTIPLIER = 4f
        private val SLIDE_INTERPOLATOR = DecelerateInterpolator(1.5f)

        private var activeDrawer = WeakReference<FeedListDrawer>(null)
        private var openGesture: OpenGesture? = null

        /**
         * Slides the feed list over the story list and reader. [forceShowFeedId] keeps a feed just
         * added visible in the list, as Main.java's EXTRA_FORCE_SHOW_FEED_ID does.
         */
        @JvmStatic
        @JvmOverloads
        fun open(
            from: Activity,
            forceShowFeedId: String? = null,
        ) {
            openGesture = null
            launch(from, forceShowFeedId)
        }

        /** ItemsList.java starts opening the panel under a swipe; updates follow with the finger's offset. */
        @JvmStatic
        fun beginOpenGesture(from: Activity) {
            openGesture = OpenGesture(from.taskId)
            launch(from)
        }

        @JvmStatic
        fun updateOpenGesture(offsetPx: Float) {
            openGesture?.offsetPx = offsetPx
            activeDrawer.get()?.followOpenGesture()
        }

        /** Settles an open swipe: fully open, or back off screen. */
        @JvmStatic
        fun endOpenGesture(open: Boolean) {
            openGesture?.let { gesture ->
                gesture.released = true
                gesture.releasedOpen = open
            }
            activeDrawer.get()?.followOpenGesture()
        }

        private fun launch(
            from: Activity,
            forceShowFeedId: String? = null,
        ) {
            val showing = activeDrawer.get()
            if (showing != null && !showing.isFinishing && showing.taskId == from.taskId) {
                showing.followOpenGesture()
                return
            }
            from.startActivity(Intent(from, FeedListDrawer::class.java).putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, forceShowFeedId))
            // On API 34+ the drawer turns off its own open animation in onCreate.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                PendingTransitionUtils.overrideNoEnterTransition(from)
            }
        }
    }
}
