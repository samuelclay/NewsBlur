package com.newsblur.image

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.app.Dialog
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.doOnPreDraw
import com.newsblur.R
import com.newsblur.util.FileCache
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import kotlin.math.max
import kotlin.math.min

/**
 * StoryImageViewer.kt presents above the reader without replacing its WebView or changing its scroll.
 *
 * A long-press on the story's photo (StoryImageSource.showActions), or on the photo here, also
 * shows the photo's title text in a panel above it and a Copy, Save, and Share menu below it, or
 * beside it when the screen is wide, like the iOS app. A linked photo adds Open Link.
 */
class StoryImageViewer(
    private val hostActivity: Activity,
    private val source: StoryImageSource,
    preview: Bitmap?,
    private val origin: RectF,
    private val cache: FileCache,
    private val client: OkHttpClient,
    private val returnRect: ((RectF?) -> Unit) -> Unit,
    private val onClosed: () -> Unit,
    private val onOpenLink: (String) -> Unit = {},
) : Dialog(hostActivity, android.R.style.Theme_Material_NoActionBar) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val root = FrameLayout(context)
    private val backdrop = View(context).apply { setBackgroundColor(Color.BLACK) }
    private val image = StoryImageView(context, source).apply { bitmap = preview }
    private val transition = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
    private val close = ImageButton(context)
    private val status =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
    private val spinner = ProgressBar(context).apply { indeterminateTintList = ColorStateList.valueOf(Color.WHITE) }
    private val message =
        TextView(context).apply {
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            textSize = 14f
        }
    private val retry =
        TextView(context).apply {
            setText(R.string.image_viewer_retry)
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(12), dp(20), dp(12))
            isClickable = true
            isFocusable = true
            setOnClickListener { load() }
        }

    // The photo's title text, which scrolls when it is longer than a third of the screen.
    private val hoverText =
        TextView(context).apply {
            text = source.hoverText
            setTextColor(Color.WHITE)
            textSize = 16f
            setLineSpacing(0f, 1.15f)
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }
    private val hoverPanel =
        ScrollView(context).apply {
            background = panelBackground()
            clipToOutline = true
            isVerticalScrollBarEnabled = true
            addView(hoverText, FrameLayout.LayoutParams(-1, -2))
        }
    private val actionsPanel =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = panelBackground()
            clipToOutline = true
        }
    private val actionRows = mutableListOf<View>()
    private val actionLabels = mutableListOf<TextView>()

    private var loader: StoryImageLoader? = null
    private var animation: ValueAnimator? = null
    private var closing = false
    private var entered = false

    // True once the enter zoom has landed and the photo can be dragged to dismiss.
    private var settled = false

    // Whether the title text and actions show; a tap opens the viewer without them.
    private var disclosuresVisible = source.showActions

    // The photo's original bytes, which Copy, Save, and Share need; they wait until it has loaded.
    private var imageData: ByteArray? = null
    private var safeInsets = Insets.NONE

    init {
        window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            WindowCompat.setDecorFitsSystemWindows(this, false)
        }
        root.addView(backdrop, match())
        root.addView(image, FrameLayout.LayoutParams(-1, -1, Gravity.TOP or Gravity.START))
        root.addView(transition, FrameLayout.LayoutParams(1, 1))
        status.addView(spinner, LinearLayout.LayoutParams(dp(28), dp(28)))
        status.addView(message, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12) })
        status.addView(retry)
        root.addView(
            status,
            FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply {
                setMargins(dp(24), 0, dp(24), dp(36))
            },
        )
        addActionRow(R.string.image_viewer_copy, R.drawable.ic_image_action_copy) { copyImage() }
        addActionRow(R.string.image_viewer_save, R.drawable.ic_image_action_save) { saveImage() }
        addActionRow(R.string.image_viewer_share, R.drawable.ic_image_action_share) { shareImage() }
        source.linkUrl?.let { link -> addActionRow(R.string.image_viewer_open_link, R.drawable.ic_image_action_link) { openLink(link) } }
        root.addView(hoverPanel, FrameLayout.LayoutParams(1, 1, Gravity.TOP or Gravity.START))
        root.addView(actionsPanel, FrameLayout.LayoutParams(1, -2, Gravity.TOP or Gravity.START))
        updateActionsEnabled()
        close.apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            imageTintList = ColorStateList.valueOf(Color.WHITE)
            background =
                GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(0xD9333333.toInt())
                }
            contentDescription = context.getString(R.string.image_viewer_close)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setOnClickListener { closeAnimated() }
        }
        root.addView(close, FrameLayout.LayoutParams(dp(48), dp(48), Gravity.TOP or Gravity.START))
        // StoryImageViewer.kt starts hidden, because its first frame can draw before enter() runs,
        // and would flash the finished viewer full screen before zooming up from the story's photo.
        // image.onDrag below stays quiet until then for the same reason.
        backdrop.alpha = 0f
        close.alpha = 0f
        status.alpha = 0f
        setPanelsAlpha(0f)
        retry.visibility = View.GONE
        image.visibility = View.INVISIBLE
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val safe = insets.getInsetsIgnoringVisibility(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            safeInsets = safe
            (close.layoutParams as FrameLayout.LayoutParams).apply {
                leftMargin = safe.left + dp(16)
                topMargin = safe.top + dp(12)
                close.layoutParams = this
            }
            layoutPanels()
            insets
        }
        // A rotation or a window resize (the tablet split) moves the panels with the window.
        root.addOnLayoutChangeListener { _, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            if (right - left != oldRight - oldLeft || bottom - top != oldBottom - oldTop) root.post { layoutPanels() }
        }
        image.onDismiss = { closeAnimated() }
        image.onDrag = { fraction ->
            // StoryImageView.kt reports a zero drag on every layout, including the first one before
            // the enter zoom, which would show the backdrop and controls ahead of the photo.
            if (settled && !closing) {
                backdrop.alpha = 1f - fraction
                close.alpha = (1f - fraction * 3.2f).coerceAtLeast(0f)
                status.alpha = close.alpha
                setPanelsAlpha(close.alpha)
            }
        }
        image.onGeometryChanged = {
            if (entered && !closing) {
                animation?.cancel()
                settled = true
                transition.visibility = View.GONE
                image.visibility = View.VISIBLE
                backdrop.alpha = 1f
                close.alpha = 1f
                setPanelsAlpha(1f)
            }
        }
        image.onLongPress = { revealActions() }
        ViewCompat.addAccessibilityAction(image, context.getString(R.string.image_viewer_show_actions)) { _, _ ->
            revealActions()
            true
        }
        setContentView(root)
        setOnShowListener {
            window?.let {
                it.setLayout(-1, -1)
                WindowCompat.getInsetsController(it, root).apply {
                    isAppearanceLightStatusBars = false
                    isAppearanceLightNavigationBars = false
                    show(WindowInsetsCompat.Type.systemBars())
                }
            }
            root.post {
                if (closing) return@post
                // The photo zooms into the space the panels leave it, so they are laid out first.
                layoutPanels()
                root.doOnPreDraw {
                    if (!closing) {
                        enter()
                        load()
                    }
                }
                root.invalidate()
            }
        }
        setOnDismissListener {
            closing = true
            loader?.cancel()
            animation?.cancel()
            scope.cancel()
            image.bitmap = null
            imageData = null
            transition.setImageDrawable(null)
            onClosed()
        }
        setOnCancelListener { }
    }

    @Deprecated("Dialog back handling")
    override fun onBackPressed() {
        closeAnimated()
    }

    private fun enter() {
        entered = true
        animateImage(origin, imageRectOnScreen(), Mode.OPEN) {
            settled = true
            image.visibility = View.VISIBLE
            image.sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_FOCUSED)
        }
    }

    private fun load() {
        loader?.cancel()
        val current = StoryImageLoader(cache, client)
        loader = current
        spinner.visibility = View.VISIBLE
        retry.visibility = View.GONE
        message.setText(R.string.image_viewer_loading)
        status.visibility = View.VISIBLE
        scope.launch {
            try {
                val loaded = current.load(source)
                if (closing || loader !== current) return@launch
                image.bitmap = loaded.bitmap
                imageData = loaded.data
                updateActionsEnabled()
                status.visibility = View.GONE
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                if (closing || loader !== current) return@launch
                spinner.visibility = View.GONE
                message.setText(R.string.image_viewer_failed)
                retry.visibility = View.VISIBLE
            }
        }
    }

    fun closeAnimated() {
        if (closing) return
        closing = true
        loader?.cancel()
        animation?.cancel()
        var finished = false

        fun finish(rect: RectF?) {
            if (finished || !isShowing) return
            finished = true
            animateImage(imageRectOnScreen(), rect ?: imageRectOnScreen(), Mode.CLOSE) { dismiss() }
        }
        // StoryImageViewer.kt never lets an unavailable/replaced WebView hold dismissal open.
        root.postDelayed({ finish(null) }, 150)
        returnRect { finish(it) }
    }

    // A long-press on the photo here brings up what a long-press in the story would have shown.
    private fun revealActions() {
        if (disclosuresVisible || closing || !settled) return
        val from = imageRectOnScreen()
        disclosuresVisible = true
        layoutPanels()
        root.doOnPreDraw {
            if (closing) return@doOnPreDraw
            animateImage(from, imageRectOnScreen(), Mode.RESIZE) { image.visibility = View.VISIBLE }
            // The photo's new size already reset every control to fully shown, so the panels
            // start their fade from here, after that layout.
            setPanelsAlpha(0f)
            listOf(hoverPanel, actionsPanel).forEach { it.animate().alpha(1f).setDuration(RESIZE_MS).start() }
            actionsPanel.sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_FOCUSED)
        }
    }

    /**
     * Gives the photo the space the panels leave, the way the iOS viewer lays them out: the title
     * text on top, the menu underneath, or beside the photo on a wide screen so it stays usable.
     */
    private fun layoutPanels() {
        val width = root.width
        val height = root.height
        if (width == 0 || height == 0) return
        var left = safeInsets.left
        var top = safeInsets.top
        var right = width - safeInsets.right
        var bottom = height - safeInsets.bottom
        hoverPanel.visibility = if (disclosuresVisible && source.hoverText != null) View.VISIBLE else View.GONE
        actionsPanel.visibility = if (disclosuresVisible) View.VISIBLE else View.GONE
        if (disclosuresVisible) {
            left += dp(16)
            right -= dp(16)
            // Below the close button, and clear of the gesture bar.
            top += dp(12) + dp(48) + dp(12)
            bottom -= dp(16)
            val menuWidth = min(dp(MENU_WIDTH_DP), right - left)
            actionsPanel.measure(
                View.MeasureSpec.makeMeasureSpec(menuWidth, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val menuHeight = actionsPanel.measuredHeight
            if (right - left > (bottom - top) * 1.6f && right - left > dp(500)) {
                place(actionsPanel, right - menuWidth, (top + bottom) / 2 - menuHeight / 2, menuWidth, menuHeight)
                right -= menuWidth + dp(16)
            } else {
                place(actionsPanel, (left + right) / 2 - menuWidth / 2, bottom - menuHeight, menuWidth, menuHeight)
                bottom -= menuHeight + dp(16)
            }
            if (hoverPanel.visibility == View.VISIBLE) {
                hoverText.measure(
                    View.MeasureSpec.makeMeasureSpec(right - left, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                )
                val hoverHeight = min(hoverText.measuredHeight, max(dp(44), ((bottom - top) * 0.35f).toInt()))
                place(hoverPanel, left, top, right - left, hoverHeight)
                top += hoverHeight + dp(12)
            }
        }
        place(image, left, top, right - left, max(1, bottom - top))
        // The loading and failure messages sit inside the photo's space, clear of the panels.
        (status.layoutParams as FrameLayout.LayoutParams).apply {
            gravity = Gravity.TOP or Gravity.START
            val statusWidth = max(1, right - left - dp(48))
            status.measure(
                View.MeasureSpec.makeMeasureSpec(statusWidth, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            this.width = statusWidth
            leftMargin = left + dp(24)
            topMargin = if (disclosuresVisible) (top + bottom) / 2 - status.measuredHeight / 2 else bottom - dp(32) - status.measuredHeight
            rightMargin = 0
            bottomMargin = 0
            status.layoutParams = this
        }
    }

    private fun place(
        view: View,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
    ) {
        val params = view.layoutParams as FrameLayout.LayoutParams
        if (params.leftMargin == x && params.topMargin == y && params.width == width && params.height == height) return
        params.gravity = Gravity.TOP or Gravity.START
        params.leftMargin = x
        params.topMargin = y
        params.width = width
        params.height = height
        view.layoutParams = params
    }

    // StoryImageView.kt reports its photo within its own bounds, which the panels can move.
    private fun imageRectOnScreen(): RectF = image.imageRect().apply { offset(image.x, image.y) }

    private fun addActionRow(
        @StringRes title: Int,
        @DrawableRes icon: Int,
        action: () -> Unit,
    ) {
        if (actionRows.isNotEmpty()) {
            actionsPanel.addView(
                View(context).apply { setBackgroundColor(SEPARATOR_COLOR) },
                LinearLayout.LayoutParams(-1, max(1, dp(1) / 2)).apply { marginStart = dp(16) },
            )
        }
        val row =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(48)
                setPadding(dp(16), dp(10), dp(16), dp(10))
                background = RippleDrawable(ColorStateList.valueOf(0x33FFFFFF), null, ColorDrawable(Color.WHITE))
                isClickable = true
                isFocusable = true
                contentDescription = context.getString(title)
                setOnClickListener { action() }
            }
        val label =
            TextView(context).apply {
                setText(title)
                setTextColor(Color.WHITE)
                textSize = 16f
            }
        row.addView(label, LinearLayout.LayoutParams(0, -2, 1f))
        actionLabels.add(label)
        row.addView(
            ImageView(context).apply {
                setImageResource(icon)
                imageTintList = ColorStateList.valueOf(Color.WHITE)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            },
            LinearLayout.LayoutParams(dp(20), dp(20)).apply { marginStart = dp(16) },
        )
        actionsPanel.addView(row, LinearLayout.LayoutParams(-1, -2))
        actionRows.add(row)
    }

    // Copy, Save, and Share wait for the photo's bytes; Open Link never does.
    private fun updateActionsEnabled() {
        val loaded = imageData != null
        actionRows.forEachIndexed { index, row ->
            val enabled = loaded || index == LINK_ROW_INDEX
            row.isEnabled = enabled
            row.alpha = if (enabled) 1f else 0.4f
        }
    }

    private fun copyImage() {
        val data = imageData ?: return
        scope.launch {
            try {
                StoryImageActions.copy(context, source, data)
                // Android 13 and later confirm a copy themselves.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) confirmInRow(COPY_ROW_INDEX, R.string.image_viewer_copied)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                confirmInRow(COPY_ROW_INDEX, R.string.image_viewer_share_failed)
            }
        }
    }

    private fun saveImage() {
        val data = imageData ?: return
        if (!StoryImageActions.canSave(hostActivity)) {
            toast(R.string.image_viewer_storage_permission)
            return
        }
        scope.launch {
            try {
                StoryImageActions.save(context, source, data)
                confirmInRow(SAVE_ROW_INDEX, R.string.image_viewer_saved)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                confirmInRow(SAVE_ROW_INDEX, R.string.image_viewer_save_failed)
            }
        }
    }

    private fun shareImage() {
        val data = imageData ?: return
        scope.launch {
            try {
                StoryImageActions.share(hostActivity, source, data)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                confirmInRow(SHARE_ROW_INDEX, R.string.image_viewer_share_failed)
            }
        }
    }

    // The link opens the way a link tapped in the story does, once the photo has zoomed back.
    private fun openLink(link: String) {
        closeAnimated()
        onOpenLink(link)
    }

    private fun toast(
        @StringRes text: Int,
    ) = Toast.makeText(context, text, Toast.LENGTH_SHORT).show()

    // An action's outcome shows in its own row for a moment, where a toast would land on the menu.
    private fun confirmInRow(
        index: Int,
        @StringRes text: Int,
    ) {
        val label = actionLabels.getOrNull(index) ?: return
        val row = actionRows[index]
        label.setText(text)
        row.announceForAccessibility(label.text)
        row.removeCallbacks(row.tag as? Runnable)
        val restore = Runnable { label.setText(ACTION_TITLES[index]) }
        row.tag = restore
        row.postDelayed(restore, CONFIRMATION_MS)
    }

    private fun setPanelsAlpha(alpha: Float) {
        hoverPanel.alpha = alpha
        actionsPanel.alpha = alpha
    }

    private fun panelBackground() =
        GradientDrawable().apply {
            cornerRadius = dp(16).toFloat()
            setColor(PANEL_COLOR)
        }

    private enum class Mode { OPEN, CLOSE, RESIZE }

    private fun animateImage(
        from: RectF,
        to: RectF,
        mode: Mode,
        complete: () -> Unit,
    ) {
        val startBackdrop = backdrop.alpha
        val startClose = close.alpha
        transition.setImageBitmap(image.bitmap)
        transition.visibility = View.VISIBLE
        image.visibility = View.INVISIBLE
        animation =
            ValueAnimator.ofFloat(0f, 1f).apply {
                duration =
                    when (mode) {
                        Mode.OPEN -> 300
                        Mode.CLOSE -> 240
                        Mode.RESIZE -> RESIZE_MS
                    }
                addUpdateListener {
                    val t = it.animatedValue as Float
                    val rect =
                        RectF(
                            from.left + (to.left - from.left) * t,
                            from.top + (to.top - from.top) * t,
                            from.right + (to.right - from.right) * t,
                            from.bottom + (to.bottom - from.bottom) * t,
                        )
                    transition.layoutParams = FrameLayout.LayoutParams(maxOf(1, rect.width().toInt()), maxOf(1, rect.height().toInt()))
                    transition.x = rect.left
                    transition.y = rect.top
                    // Resizing to make room for the panels leaves the backdrop and controls alone.
                    if (mode != Mode.RESIZE) {
                        val opening = mode == Mode.OPEN
                        backdrop.alpha = if (opening) t else startBackdrop * (1 - t)
                        close.alpha = if (opening) t else startClose * (1 - t)
                        status.alpha = close.alpha
                        setPanelsAlpha(close.alpha)
                        transition.alpha = if (opening) 1f else 1f - t
                    }
                }
                addListener(
                    object : AnimatorListenerAdapter() {
                        private var cancelled = false

                        override fun onAnimationCancel(animation: Animator) {
                            cancelled = true
                        }

                        override fun onAnimationEnd(animation: Animator) {
                            if (!cancelled) {
                                transition.visibility = View.GONE
                                complete()
                            }
                        }
                    },
                )
                start()
            }
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()

    private fun match() = ViewGroup.LayoutParams(-1, -1)

    private companion object {
        const val MENU_WIDTH_DP = 260
        const val RESIZE_MS = 220L

        // The menu's rows, in order; Open Link only shows for a linked photo.
        const val COPY_ROW_INDEX = 0
        const val SAVE_ROW_INDEX = 1
        const val SHARE_ROW_INDEX = 2
        const val LINK_ROW_INDEX = 3
        val ACTION_TITLES =
            listOf(R.string.image_viewer_copy, R.string.image_viewer_save, R.string.image_viewer_share, R.string.image_viewer_open_link)
        const val CONFIRMATION_MS = 1_600L

        // UIColor(white: 0.14) and white at 12%, as the iOS viewer's panels and separators use.
        const val PANEL_COLOR = 0xFF242424.toInt()
        const val SEPARATOR_COLOR = 0x1FFFFFFF
    }
}
