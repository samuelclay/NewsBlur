package com.newsblur.view

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.LinearInterpolator
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.PrefConstants.ThemeValue

/** StoryLoadingBar.kt mirrors reader.css's 1.7-second blue pulse and stops while detached or hidden. */
class StoryLoadingBar @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var ready = false
    private val paint = Paint()
    private var lowColor = ReaderSheetPalette.loadingLowArgb(ThemeValue.LIGHT)
    private var highColor = ReaderSheetPalette.loadingHighArgb(ThemeValue.LIGHT)
    private val colorEvaluator = ArgbEvaluator()
    private val easing = AccelerateDecelerateInterpolator()
    private var animator: ValueAnimator? = null

    init {
        paint.color = lowColor
        contentDescription = context.getString(R.string.story_loading_description)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        ready = true
    }

    fun setTheme(theme: ThemeValue) {
        lowColor = ReaderSheetPalette.loadingLowArgb(theme)
        highColor = ReaderSheetPalette.loadingHighArgb(theme)
        paint.color = lowColor
        invalidate()
    }

    override fun getAccessibilityClassName(): CharSequence = "android.widget.ProgressBar"

    override fun onDraw(canvas: Canvas) {
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private fun updateAnimation() {
        if (!ready) return
        val active = isAttachedToWindow && isShown && windowVisibility == VISIBLE && isEnabled && ValueAnimator.areAnimatorsEnabled()
        if (!active) {
            animator?.cancel()
            animator = null
            paint.color = lowColor
            invalidate()
        } else if (animator == null) {
            animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 1700L
                repeatCount = ValueAnimator.INFINITE
                interpolator = LinearInterpolator()
                addUpdateListener {
                    val phase = it.animatedValue as Float
                    val intensity = if (phase < 0.38f) phase / 0.38f else (1f - phase) / 0.62f
                    paint.color = colorEvaluator.evaluate(easing.getInterpolation(intensity), lowColor, highColor) as Int
                    invalidate()
                }
                start()
            }
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        updateAnimation()
    }
    override fun onDetachedFromWindow() {
        animator?.cancel()
        animator = null
        super.onDetachedFromWindow()
    }
    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        updateAnimation()
    }
    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        updateAnimation()
    }
    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        updateAnimation()
    }
}
