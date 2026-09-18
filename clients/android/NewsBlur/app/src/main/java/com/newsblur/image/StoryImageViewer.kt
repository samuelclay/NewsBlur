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
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.newsblur.R
import com.newsblur.util.FileCache
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

/** StoryImageViewer.kt presents above the reader without replacing its WebView or changing its scroll. */
class StoryImageViewer(
    activity: Activity,
    private val source: StoryImageSource,
    preview: Bitmap?,
    private val origin: RectF,
    private val cache: FileCache,
    private val client: OkHttpClient,
    private val returnRect: ((RectF?) -> Unit) -> Unit,
    private val onClosed: () -> Unit,
) : Dialog(activity, android.R.style.Theme_Material_NoActionBar) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val root = FrameLayout(context)
    private val backdrop = View(context).apply { setBackgroundColor(Color.BLACK) }
    private val image = StoryImageView(context, source).apply { bitmap = preview }
    private val transition = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
    private val close = ImageButton(context)
    private val status = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
    private val spinner = ProgressBar(context).apply { indeterminateTintList = ColorStateList.valueOf(Color.WHITE) }
    private val message = TextView(context).apply { setTextColor(Color.WHITE); gravity = Gravity.CENTER; textSize = 14f }
    private val retry = TextView(context).apply {
        setText(R.string.image_viewer_retry)
        setTextColor(Color.WHITE)
        textSize = 16f
        gravity = Gravity.CENTER
        setPadding(dp(20), dp(12), dp(20), dp(12))
        isClickable = true
        isFocusable = true
        setOnClickListener { load() }
    }
    private var loader: StoryImageLoader? = null
    private var animation: ValueAnimator? = null
    private var closing = false
    private var entered = false

    init {
        window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            WindowCompat.setDecorFitsSystemWindows(this, false)
        }
        root.addView(backdrop, match())
        root.addView(image, match())
        root.addView(transition, FrameLayout.LayoutParams(1, 1))
        status.addView(spinner, LinearLayout.LayoutParams(dp(28), dp(28)))
        status.addView(message, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12) })
        status.addView(retry)
        root.addView(status, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply {
            setMargins(dp(24), 0, dp(24), dp(36))
        })
        close.apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            imageTintList = ColorStateList.valueOf(Color.WHITE)
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0xD9333333.toInt()) }
            contentDescription = context.getString(R.string.image_viewer_close)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setOnClickListener { closeAnimated() }
        }
        root.addView(close, FrameLayout.LayoutParams(dp(48), dp(48), Gravity.TOP or Gravity.START))
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val safe = insets.getInsetsIgnoringVisibility(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            (close.layoutParams as FrameLayout.LayoutParams).apply {
                leftMargin = safe.left + dp(16)
                topMargin = safe.top + dp(12)
                close.layoutParams = this
            }
            (status.layoutParams as FrameLayout.LayoutParams).apply {
                bottomMargin = safe.bottom + dp(32)
                status.layoutParams = this
            }
            insets
        }
        image.onDismiss = { closeAnimated() }
        image.onDrag = { fraction ->
            backdrop.alpha = 1f - fraction
            close.alpha = (1f - fraction * 3.2f).coerceAtLeast(0f)
            status.alpha = close.alpha
        }
        image.onGeometryChanged = {
            if (entered && !closing) {
                animation?.cancel()
                transition.visibility = View.GONE
                image.visibility = View.VISIBLE
                backdrop.alpha = 1f
                close.alpha = 1f
            }
        }
        setContentView(root)
        setOnShowListener {
            window?.let {
                it.setLayout(-1, -1)
                WindowCompat.getInsetsController(it, root).apply {
                    systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    hide(WindowInsetsCompat.Type.systemBars())
                }
            }
            root.post { if (!closing) { enter(); load() } }
        }
        setOnDismissListener {
            closing = true
            loader?.cancel()
            animation?.cancel()
            scope.cancel()
            image.bitmap = null
            transition.setImageDrawable(null)
            onClosed()
        }
        setOnCancelListener { }
    }

    @Deprecated("Dialog back handling")
    override fun onBackPressed() { closeAnimated() }

    private fun enter() {
        entered = true
        animateImage(origin, image.imageRect(), true) {
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
                val bitmap = current.load(source)
                if (closing || loader !== current) return@launch
                image.bitmap = bitmap
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
            animateImage(image.imageRect(), rect ?: image.imageRect(), false) { dismiss() }
        }
        // StoryImageViewer.kt never lets an unavailable/replaced WebView hold dismissal open.
        root.postDelayed({ finish(null) }, 150)
        returnRect { finish(it) }
    }

    private fun animateImage(from: RectF, to: RectF, opening: Boolean, complete: () -> Unit) {
        val startBackdrop = backdrop.alpha
        val startClose = close.alpha
        transition.setImageBitmap(image.bitmap)
        transition.visibility = View.VISIBLE
        image.visibility = View.INVISIBLE
        animation = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = if (opening) 300 else 240
            addUpdateListener {
                val t = it.animatedValue as Float
                val rect = RectF(from.left + (to.left - from.left) * t, from.top + (to.top - from.top) * t,
                    from.right + (to.right - from.right) * t, from.bottom + (to.bottom - from.bottom) * t)
                transition.layoutParams = FrameLayout.LayoutParams(maxOf(1, rect.width().toInt()), maxOf(1, rect.height().toInt()))
                transition.x = rect.left
                transition.y = rect.top
                backdrop.alpha = if (opening) t else startBackdrop * (1 - t)
                close.alpha = if (opening) t else startClose * (1 - t)
                status.alpha = close.alpha
                transition.alpha = if (opening) 1f else 1f - t
            }
            addListener(object : AnimatorListenerAdapter() {
                private var cancelled = false
                override fun onAnimationCancel(animation: Animator) { cancelled = true }
                override fun onAnimationEnd(animation: Animator) {
                    if (!cancelled) { transition.visibility = View.GONE; complete() }
                }
            })
            start()
        }
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
    private fun match() = ViewGroup.LayoutParams(-1, -1)
}
