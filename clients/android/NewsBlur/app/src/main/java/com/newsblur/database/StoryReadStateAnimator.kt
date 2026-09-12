package com.newsblur.database

import android.animation.ValueAnimator
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import androidx.core.graphics.ColorUtils
import kotlin.math.roundToInt

// StoryViewAdapter.kt changes read appearance without rebinding text, images, or row geometry.
internal class StoryReadStateAnimator {
    private var animator: ValueAnimator? = null

    fun cancel() {
        animator?.cancel()
        animator = null
    }

    fun update(
        textColors: List<Pair<TextView, Int>>,
        imageAlphas: List<Pair<ImageView, Int>>,
        viewAlphas: List<Pair<View, Float>> = emptyList(),
        drawableAlphas: List<Pair<Drawable, Int>> = emptyList(),
        animated: Boolean,
    ) {
        cancel()
        if (!animated) {
            textColors.forEach { (view, color) -> view.setTextColor(color) }
            imageAlphas.forEach { (view, alpha) -> view.imageAlpha = alpha }
            viewAlphas.forEach { (view, alpha) -> view.alpha = alpha }
            drawableAlphas.forEach { (drawable, alpha) -> drawable.alpha = alpha }
            return
        }
        val initialColors = textColors.map { it.first.currentTextColor }
        val initialImages = imageAlphas.map { it.first.imageAlpha }
        val initialViews = viewAlphas.map { it.first.alpha }
        val initialDrawables = drawableAlphas.map { it.first.alpha }
        fun apply(fraction: Float) {
            textColors.forEachIndexed { index, (view, color) ->
                view.setTextColor(ColorUtils.blendARGB(initialColors[index], color, fraction))
            }
            imageAlphas.forEachIndexed { index, (view, alpha) ->
                view.imageAlpha = (initialImages[index] + (alpha - initialImages[index]) * fraction).roundToInt()
            }
            viewAlphas.forEachIndexed { index, (view, alpha) ->
                view.alpha = initialViews[index] + (alpha - initialViews[index]) * fraction
            }
            drawableAlphas.forEachIndexed { index, (drawable, alpha) ->
                drawable.alpha = (initialDrawables[index] + (alpha - initialDrawables[index]) * fraction).roundToInt()
            }
        }
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 220L
            addUpdateListener { apply(it.animatedValue as Float) }
            start()
        }
    }
}
