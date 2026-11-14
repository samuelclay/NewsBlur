package com.newsblur.database

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.view.View
import android.graphics.drawable.ColorDrawable

/** ReturnedStoryHighlight.kt keeps a temporary background attached to one bound story identity. */
internal class ReturnedStoryHighlight(
    val view: View,
    val storyHash: String,
    private val currentStoryHash: () -> String?,
    private val highlightColor: Int,
    private val defaultColor: Int,
    private val createAnimator: () -> ValueAnimator = { ValueAnimator.ofObject(ArgbEvaluator(), highlightColor, defaultColor) },
) {
    private var originalBackground = view.background
    private var animator: ValueAnimator? = null
    private var canceled = false
    private var started = false
    private var currentColor = highlightColor
    val isFinished: Boolean get() = canceled

    fun hold() {
        if (!canceled && currentStoryHash() == storyHash) view.background = ColorDrawable(highlightColor)
    }

    fun fade() {
        if (canceled || started || currentStoryHash() != storyHash) return
        started = true
        val animation = createAnimator().apply {
            duration = 1000
            addUpdateListener {
                if (currentStoryHash() == storyHash) {
                    currentColor = it.animatedValue as Int
                    view.setBackgroundColor(currentColor)
                } else {
                    cancel()
                }
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    this@ReturnedStoryHighlight.cancel()
                }
            })
        }
        animator = animation
        animation.start()
    }

    fun beforeRebind() {
        if (!canceled && currentStoryHash() == storyHash) view.background = originalBackground
    }

    fun afterRebind() {
        if (canceled || currentStoryHash() != storyHash) return
        originalBackground = view.background
        view.background = ColorDrawable(currentColor)
    }

    fun cancel() {
        if (canceled) return
        canceled = true
        animator?.removeAllUpdateListeners()
        animator?.removeAllListeners()
        animator?.cancel()
        animator = null
        if (currentStoryHash() == storyHash) view.background = originalBackground
    }
}
