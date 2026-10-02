package com.newsblur.activity

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.activity.OnBackPressedCallback
import androidx.core.view.doOnPreDraw
import androidx.core.view.drawToBitmap
import com.newsblur.R
import com.newsblur.util.PendingTransitionUtils
import com.newsblur.util.StorySplitView
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import java.lang.ref.WeakReference
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * The feed list as a slide-over on tablets. Main.java's whole screen (header, search, folders,
 * filters, sync status) moves into a panel on the left, over a dimmed scrim that covers both the
 * story list and the reader beneath it. StorySplitView.kt always expands this activity to the
 * whole window, so it sits above both panes. The panel is as wide as the story list pane, so it
 * hides that pane exactly.
 *
 * This is a new activity every time it opens, which takes a moment to reach the screen. So as it
 * closes it keeps a picture of its panel, and the next open slides that picture over the story
 * list's pane at once (showSnapshot). The real panel arrives already open on top of the picture,
 * which it then removes unseen.
 *
 * Picking a feed switches the story list beneath to it in place (ItemsList.switchStoryList) and
 * slides the panel away to the left, uncovering the list as it fills in, the way the iPad's feeds
 * column slides off its story titles. Tapping the scrim, Back, or swiping the panel left closes it.
 * A swipe that starts on the story list opens it under the finger (beginOpenGesture).
 */
@AndroidEntryPoint
class FeedListDrawer : Main() {
    private lateinit var scrim: View
    private lateinit var panel: FrameLayout
    private var panelWidth = 1
    private var pendingFinish: Runnable? = null
    private var closing = false

    // A feed or folder was picked, so the story list beneath already switched to it.
    private var pickedStoryList = false

    // The reader pane's own dim (showSnapshot) shows instead of this window's scrim, which stays
    // clear but still takes the tap that closes the panel.
    private var usesReaderPaneDim = false

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
            // At launch the feed list is the first screen, so it is already open (ItemsList.java).
            intent.getBooleanExtra(EXTRA_OPEN_INSTANTLY, false) -> setOpenFraction(1f)
            // The picture slid in already, with the reader pane dimmed beside it (showSnapshot). That
            // dim stands in for this scrim until the panel closes, so the pane never dims twice.
            intent.getBooleanExtra(EXTRA_FROM_SNAPSHOT, false) -> {
                usesReaderPaneDim = readerPaneDim.get() != null
                setOpenFraction(1f)
                if (!usesReaderPaneDim) {
                    scrim.alpha = 0f
                    window.decorView.doOnPreDraw {
                        scrim
                            .animate()
                            .alpha(1f)
                            .setDuration(SCRIM_FADE_MS)
                            .start()
                    }
                }
            }
            openGesture?.taskId == taskId -> followOpenGesture()
            // The slide starts on the first frame, so none of it passes while the window is still
            // on its way to the screen.
            else -> window.decorView.doOnPreDraw { if (!closing) animateTo(open = true) }
        }
    }

    override fun onResume() {
        super.onResume()
        // onEnterAnimationComplete is the signal this window is on screen; this covers a system
        // that never sends it.
        window.decorView.postDelayed({ onScreen() }, SNAPSHOT_HANDOFF_FALLBACK_MS)
    }

    override fun onEnterAnimationComplete() {
        super.onEnterAnimationComplete()
        onScreen()
    }

    // Focus arrives as this window reaches the screen, sooner than onEnterAnimationComplete.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) onScreen()
    }

    // This panel now covers the picture of itself in the story list's pane, so drop the picture.
    private fun onScreen() {
        if (isFinishing || isDestroyed || closing) return
        removePicture()
    }

    override fun onDestroy() {
        if (activeDrawer.get() === this) {
            activeDrawer.clear()
            removeSnapshot()
        }
        cancelSlide()
        cancelSlide()
        velocityTracker?.recycle()
        velocityTracker = null
        super.onDestroy()
    }

    // Picking a feed switches the story list beneath to it and slides this panel away. Opening a
    // new story list activity instead would rebuild the whole split and freeze this panel while
    // it did. Without a story list beneath, the pick starts its story list as the root of a fresh
    // task, which forms a new split with the placeholder pane.
    @Deprecated("Activity result APIs")
    override fun startActivityForResult(
        intent: Intent,
        requestCode: Int,
        options: Bundle?,
    ) {
        if (StorySplitView.isStoryList(intent)) {
            val storyList = storyListBeneath()
            if (storyList != null) {
                pickedStoryList = true
                storyList.switchStoryList(intent)
                close()
                return
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        @Suppress("DEPRECATION")
        super.startActivityForResult(intent, requestCode, options)
    }

    /** Slides the panel away, then finishes. */
    fun close() {
        if (closing) return
        closing = true
        capturePanel()
        removePicture()
        // Closed without a pick: the launch story list beneath starts loading as it is uncovered.
        if (!pickedStoryList) storyListBeneath()?.startDeferredStories()
        animateTo(open = false)
    }

    // The picture the next open slides in before its own panel reaches the screen.
    private fun capturePanel() {
        if (panel.width <= 0 || panel.height <= 0) return
        val location = IntArray(2)
        panel.getLocationOnScreen(location)
        panelSnapshot = runCatching { panel.drawToBitmap() }.getOrNull()
        panelSnapshotTop = location[1]
    }

    // The tablet's root story list under this panel (ItemsList.java claims it on resume).
    private fun storyListBeneath(): ItemsList? =
        ItemsList.peekReadingLaunchParent(taskId)?.takeIf { storyList -> !storyList.isFinishing && storyList.slidesOverFeedDrawer() }

    private fun wrapInPanel() {
        val content = findViewById<ViewGroup>(android.R.id.content)
        val mainScreen = content.getChildAt(0)
        content.removeView(mainScreen)
        // As wide as the story list pane (StorySplitView.kt), so it covers the pane exactly and its
        // picture fits there (showSnapshot). A pane too narrow for a feed list gets a wider panel.
        val windowWidth = resources.displayMetrics.widthPixels
        val storyListPaneWidth = ceil(windowWidth * StorySplitView.STORY_LIST_SPLIT_RATIO).toInt()
        panelWidth = min(max(UIUtils.dp2px(this, PANEL_MIN_WIDTH_DP), storyListPaneWidth), (windowWidth * PANEL_MAX_FRACTION).toInt())
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
        scrim.alpha = if (usesReaderPaneDim) 0f else fraction
        if (usesReaderPaneDim) readerPaneDim.get()?.alpha = fraction
    }

    private fun animateTo(open: Boolean) {
        cancelSlide()
        val end = if (open) 1f else 0f
        val duration = (SLIDE_DURATION_MS * abs(end - openFraction())).toLong().coerceAtLeast(1L)
        // A ViewPropertyAnimator with no listeners runs on the render thread, so the slide stays
        // smooth while the main thread is busy, such as switching the story list beneath to a pick.
        panel
            .animate()
            .translationX(-panelWidth * (1f - end))
            .setDuration(duration)
            .setInterpolator(SLIDE_INTERPOLATOR)
            .start()
        scrim
            .animate()
            .alpha(if (usesReaderPaneDim) 0f else end)
            .setDuration(duration)
            .setInterpolator(SLIDE_INTERPOLATOR)
            .start()
        if (usesReaderPaneDim) fadeReaderPaneDim(end, duration)
        if (!open) {
            val finishSlide = Runnable { if (closing) finishWithoutAnimation() }
            pendingFinish = finishSlide
            window.decorView.postDelayed(finishSlide, duration)
        }
    }

    private fun cancelSlide() {
        panel.animate().cancel()
        scrim.animate().cancel()
        if (usesReaderPaneDim) readerPaneDim.get()?.animate()?.cancel()
        pendingFinish?.let(window.decorView::removeCallbacks)
        pendingFinish = null
    }

    private fun finishWithoutAnimation() {
        removeSnapshot()
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
        cancelSlide()
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
                    cancelSlide()
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
        private const val PANEL_MIN_WIDTH_DP = 280
        private const val EXTRA_OPEN_INSTANTLY = "open_instantly"
        private const val EXTRA_FROM_SNAPSHOT = "from_snapshot"
        private const val SCRIM_FADE_MS = 150L
        private const val SNAPSHOT_HANDOFF_FALLBACK_MS = 600L
        private const val SNAPSHOT_FIT_SLOP_PX = 2
        private const val PANEL_MAX_FRACTION = 0.85f
        private const val PANEL_ELEVATION_DP = 16
        private const val SCRIM_COLOR = 0x66000000

        // ItemsList.java waits this long after a pick to load the picked list, once the panel is gone.
        const val SLIDE_DURATION_MS = 280L
        private const val CLOSE_THRESHOLD = 0.6f
        private const val CLOSE_GESTURE_DIRECTION_RATIO = 1.2f
        private const val CLOSE_FLING_MULTIPLIER = 4f

        // Material's standard easing: a gentle start and a soft landing, for opening and closing.
        private val SLIDE_INTERPOLATOR = PathInterpolator(0.4f, 0f, 0.2f, 1f)

        private var activeDrawer = WeakReference<FeedListDrawer>(null)
        private var openGesture: OpenGesture? = null

        // The picture of the panel from its last close, where it sat on screen, and the view in the
        // story list's window that shows it while the next panel is on its way.
        private var panelSnapshot: Bitmap? = null
        private var panelSnapshotTop = 0
        private var snapshotView = WeakReference<ImageView>(null)

        // The reader pane is its own window, which this panel's scrim can only cover once the panel
        // is on screen. So the picture dims it directly while it slides in (showSnapshot).
        private var readerPaneDim = WeakReference<View>(null)

        // An open is on its way: the picture is sliding in and the panel starts when it lands.
        private var pendingSnapshotOpen = false

        // A swipe on the story list is dragging the picture, before any panel is started.
        private var snapshotGesture = false
        private var snapshotGestureFrom = WeakReference<Activity>(null)

        /**
         * Puts the panel's last picture over [from]'s pane, just off its left edge, when the picture
         * fits the pane. Returns false when there is no picture, or the window changed size since
         * it was taken (a rotation), and the panel just slides in once it arrives.
         */
        private fun showSnapshot(from: Activity): Boolean {
            val snapshot = panelSnapshot ?: return false
            val decor = from.window.decorView as? ViewGroup ?: return false
            if (abs(snapshot.width - decor.width) > SNAPSHOT_FIT_SLOP_PX) return false
            removeSnapshot()
            val decorLocation = IntArray(2)
            decor.getLocationOnScreen(decorLocation)
            val view =
                ImageView(from).apply {
                    setImageBitmap(snapshot)
                    // Drawn at its own size from the top left, never scaled to fit the pane.
                    scaleType = ImageView.ScaleType.MATRIX
                    translationX = -snapshot.width.toFloat()
                    elevation = UIUtils.dp2px(from, PANEL_ELEVATION_DP).toFloat()
                    // Touches during the handoff land on nothing rather than the list beneath.
                    isClickable = true
                }
            val params = FrameLayout.LayoutParams(snapshot.width, snapshot.height)
            params.topMargin = panelSnapshotTop - decorLocation[1]
            decor.addView(view, params)
            snapshotView = WeakReference(view)
            dimReaderPane(from)
            return true
        }

        private fun dimReaderPane(from: Activity) {
            val readerPane: Activity = Reading.peekSplitReader(from.taskId) ?: ReadingPlaceholder.peek(from.taskId) ?: return
            val decor = readerPane.window.decorView as? ViewGroup ?: return
            val dim =
                View(readerPane).apply {
                    setBackgroundColor(SCRIM_COLOR)
                    alpha = 0f
                    // Taps on the pane while the panel is on its way don't reach the reader.
                    isClickable = true
                }
            decor.addView(dim, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            readerPaneDim = WeakReference(dim)
        }

        private fun slideSnapshotTo(open: Boolean) {
            val view = snapshotView.get() ?: return
            fadeReaderPaneDim(if (open) 1f else 0f, SLIDE_DURATION_MS)
            view
                .animate()
                .translationX(if (open) 0f else -view.width.toFloat())
                .setDuration(SLIDE_DURATION_MS)
                .setInterpolator(SLIDE_INTERPOLATOR)
                .start()
            if (!open) view.postDelayed({ if (snapshotView.get() === view) removeSnapshot() }, SLIDE_DURATION_MS)
        }

        private fun fadeReaderPaneDim(
            alpha: Float,
            duration: Long,
        ) {
            val dim = readerPaneDim.get() ?: return
            dim
                .animate()
                .alpha(alpha)
                .setDuration(duration)
                .setInterpolator(SLIDE_INTERPOLATOR)
                .start()
        }

        private fun followSnapshot(offsetPx: Float) {
            val view = snapshotView.get() ?: return
            view.animate().cancel()
            view.translationX = (offsetPx - view.width).coerceIn(-view.width.toFloat(), 0f)
            readerPaneDim.get()?.alpha = 1f + view.translationX / view.width
        }

        /**
         * Drops the picture and the reader pane's dim. ItemsList.java also calls this on resume,
         * for a picture left behind by a panel that never reached the screen.
         */
        @JvmStatic
        fun removeSnapshot() {
            readerPaneDim.get()?.let { dim ->
                readerPaneDim.clear()
                dim.animate().cancel()
                (dim.parent as? ViewGroup)?.removeView(dim)
            }
            removePicture()
        }

        private fun removePicture() {
            val view = snapshotView.get() ?: return
            snapshotView.clear()
            view.animate().cancel()
            (view.parent as? ViewGroup)?.removeView(view)
        }

        /**
         * Slides the feed list over the story list and reader. [forceShowFeedId] keeps a feed just
         * added visible in the list, as Main.java's EXTRA_FORCE_SHOW_FEED_ID does.
         */
        @JvmStatic
        @JvmOverloads
        fun open(
            from: Activity,
            forceShowFeedId: String? = null,
            instantly: Boolean = false,
        ) {
            openGesture = null
            if (pendingSnapshotOpen) return
            if (!instantly && activeDrawer.get() == null && showSnapshot(from)) {
                slideSnapshotTo(open = true)
                launchAfterSnapshotSlide(from, forceShowFeedId)
                return
            }
            launch(from, forceShowFeedId, instantly)
        }

        // Starting an activity holds the story list's frames until the new window is ready, which
        // would freeze the picture mid-slide. So the picture slides in first, then the panel starts
        // and arrives already open on top of it.
        private fun launchAfterSnapshotSlide(
            from: Activity,
            forceShowFeedId: String? = null,
        ) {
            val view = snapshotView.get() ?: return
            pendingSnapshotOpen = true
            view.postDelayed({
                pendingSnapshotOpen = false
                if (!from.isFinishing && !from.isDestroyed && snapshotView.get() === view) {
                    launch(from, forceShowFeedId, fromSnapshot = true)
                }
            }, SLIDE_DURATION_MS)
        }

        /** ItemsList.java starts opening the panel under a swipe; updates follow with the finger's offset. */
        @JvmStatic
        fun beginOpenGesture(from: Activity) {
            if (pendingSnapshotOpen) return
            // With a picture, the swipe drags the picture and only a swipe released open starts
            // the panel (endOpenGesture). Without one, the panel starts now and follows the finger.
            if (activeDrawer.get() == null && showSnapshot(from)) {
                snapshotGesture = true
                snapshotGestureFrom = WeakReference(from)
                return
            }
            openGesture = OpenGesture(from.taskId)
            launch(from)
        }

        @JvmStatic
        fun updateOpenGesture(offsetPx: Float) {
            if (snapshotGesture) {
                followSnapshot(offsetPx)
                return
            }
            openGesture?.offsetPx = offsetPx
            activeDrawer.get()?.followOpenGesture()
        }

        /** Settles an open swipe: fully open, or back off screen. */
        @JvmStatic
        fun endOpenGesture(open: Boolean) {
            if (snapshotGesture) {
                snapshotGesture = false
                slideSnapshotTo(open)
                val from = snapshotGestureFrom.get()
                snapshotGestureFrom.clear()
                if (open && from != null) launchAfterSnapshotSlide(from)
                return
            }
            openGesture?.let { gesture ->
                gesture.released = true
                gesture.releasedOpen = open
            }
            activeDrawer.get()?.followOpenGesture()
        }

        private fun launch(
            from: Activity,
            forceShowFeedId: String? = null,
            instantly: Boolean = false,
            fromSnapshot: Boolean = false,
        ) {
            val showing = activeDrawer.get()
            if (showing != null && !showing.isFinishing && showing.taskId == from.taskId) {
                showing.followOpenGesture()
                return
            }
            from.startActivity(
                Intent(from, FeedListDrawer::class.java)
                    .putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, forceShowFeedId)
                    .putExtra(EXTRA_OPEN_INSTANTLY, instantly)
                    .putExtra(EXTRA_FROM_SNAPSHOT, fromSnapshot),
            )
            // On API 34+ the drawer turns off its own open animation in onCreate.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                PendingTransitionUtils.overrideNoEnterTransition(from)
            }
        }
    }
}
