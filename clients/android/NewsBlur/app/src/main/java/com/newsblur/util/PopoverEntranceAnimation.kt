package com.newsblur.util

import android.animation.ValueAnimator
import android.view.View
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.PopupWindow

/** PopoverEntranceAnimation.kt gives every custom menu the same motion without owning its dismiss callback. */
object PopoverEntranceAnimation {
    private const val DURATION_MS = 200L
    private const val INITIAL_SCALE = 0.94f

    internal data class Pivot(val x: Float, val y: Float)

    internal fun pivot(
        anchorX: Float,
        anchorY: Float,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
    ) = Pivot(
        (anchorX - x).coerceIn(0f, width.coerceAtLeast(0).toFloat()),
        (anchorY - y).coerceIn(0f, height.coerceAtLeast(0).toFloat()),
    )

    fun show(
        anchor: View,
        popup: PopupWindow,
        gravity: Int,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        anchorCenterX: Float,
        anchorCenterY: Float,
    ) {
        if (popup.isShowing) {
            popup.update(x, y, width, height)
            return
        }
        popup.width = width
        popup.height = height
        // PopoverEntranceAnimation.kt replaces platform window entrance effects with one content animation.
        popup.animationStyle = 0
        popup.enterTransition = null
        // PopoverEntranceAnimation.kt keeps the anchor center in the caller's popup coordinate space.
        val pivot = pivot(anchorCenterX, anchorCenterY, x, y, width, height)
        val entrance = if (ValueAnimator.areAnimatorsEnabled()) Entrance(popup.contentView, pivot) else null
        try {
            popup.showAtLocation(anchor.rootView, gravity, x, y)
        } catch (error: RuntimeException) {
            entrance?.finish()
            throw error
        }
    }

    private class Entrance(
        private val content: View,
        pivot: Pivot,
    ) : View.OnAttachStateChangeListener, ViewTreeObserver.OnPreDrawListener {
        private var observer: ViewTreeObserver? = null
        private var finished = false

        init {
            content.animate().cancel()
            content.pivotX = pivot.x
            content.pivotY = pivot.y
            content.alpha = 0f
            content.scaleX = INITIAL_SCALE
            content.scaleY = INITIAL_SCALE
            content.addOnAttachStateChangeListener(this)
            if (content.isAttachedToWindow) onViewAttachedToWindow(content)
        }

        override fun onViewAttachedToWindow(view: View) {
            observer = content.viewTreeObserver.also { it.addOnPreDrawListener(this) }
        }

        override fun onPreDraw(): Boolean {
            removePreDrawListener()
            if (!finished) {
                content.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setStartDelay(0L)
                    .setDuration(DURATION_MS)
                    .setInterpolator(DecelerateInterpolator(1.5f))
                    .withEndAction { finish() }
                    .start()
            }
            return true
        }

        override fun onViewDetachedFromWindow(view: View) = finish()

        fun finish() {
            if (finished) return
            finished = true
            removePreDrawListener()
            content.removeOnAttachStateChangeListener(this)
            content.animate().cancel()
            content.alpha = 1f
            content.scaleX = 1f
            content.scaleY = 1f
        }

        private fun removePreDrawListener() {
            observer?.takeIf { it.isAlive }?.removeOnPreDrawListener(this)
            observer = null
        }
    }
}
