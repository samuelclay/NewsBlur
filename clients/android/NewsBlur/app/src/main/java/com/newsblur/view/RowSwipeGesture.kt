package com.newsblur.view

import android.animation.ValueAnimator
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import kotlin.math.abs

/** RowSwipeGesture.kt shares cancelable, finger-following motion between the two native lists. */
class RowSwipeGesture(
    private val row: View,
    private val label: (Boolean) -> String?,
    private val perform: (Boolean) -> Unit,
    private val claim: () -> Unit = {},
    private val colors: () -> com.newsblur.util.GestureThemeStyle.Palette,
) {
    private val density = row.resources.displayMetrics.density
    private val slop = ViewConfiguration.get(row.context).scaledTouchSlop.toFloat()
    private var downX = 0f
    private var downY = 0f
    private val decision = RowSwipeDecision(slop)
    private var dragging = false
    private var animator: ValueAnimator? = null
    private var parent: ViewGroup? = null
    private var actionLabel = ""
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val underlay =
        object : Drawable() {
            override fun draw(canvas: Canvas) {
                val dx = row.translationX
                if (dx == 0f) return
                paint.color = colors().background
                paint.alpha = if (abs(dx) >= row.width * .2f) 255 else 190
                val left = row.left.toFloat()
                val top = row.top.toFloat()
                val edge = if (dx > 0) left else left + row.width + dx
                canvas.drawRect(edge, top, edge + abs(dx), top + row.height, paint)
                canvas.save()
                canvas.clipRect(edge, top, edge + abs(dx), top + row.height)
                paint.color = colors().foreground
                paint.textSize = 13f * row.resources.displayMetrics.scaledDensity
                paint.textAlign = if (dx > 0) Paint.Align.LEFT else Paint.Align.RIGHT
                canvas.drawText(
                    actionLabel,
                    if (dx > 0) left + 16 * density else left + row.width - 16 * density,
                    top + row.height / 2f - (paint.ascent() + paint.descent()) / 2f,
                    paint,
                )
                canvas.restore()
            }

            override fun setAlpha(alpha: Int) {}

            override fun setColorFilter(filter: ColorFilter?) {}

            @Deprecated("Drawable opacity is unused")
            override fun getOpacity() = PixelFormat.TRANSLUCENT
        }

    fun onTouch(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                cancel()
                downX = event.rawX
                downY = event.rawY
                decision.begin()
            }
            MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_CANCEL -> {
                val consumed = dragging
                decision.cancel()
                settle()
                return consumed
            }
            MotionEvent.ACTION_MOVE -> {
                val wasDragging = dragging
                val dx = event.rawX - downX
                val dy = event.rawY - downY
                val nextLabel = label(dx > 0)
                if (!decision.move(dx, dy, nextLabel != null)) return false
                if (!wasDragging) {
                    actionLabel = nextLabel ?: return false
                    dragging = true
                    parent = row.parent as? ViewGroup
                    underlay.setBounds(row.left, row.top, row.right, row.bottom)
                    parent?.overlay?.add(underlay)
                    row.cancelLongPress()
                    row.isPressed = false
                    row.parent?.requestDisallowInterceptTouchEvent(true)
                    claim()
                }
                val allowed = label(dx > 0)
                if (allowed != null) actionLabel = allowed
                row.translationX = if (allowed == null) 0f else dx.coerceIn(-row.width * .8f, row.width * .8f)
                underlay.invalidateSelf()
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!dragging) return false
                val offset = row.translationX
                val commit = decision.finish(offset, row.width, label(offset > 0) != null)
                settle()
                if (commit) perform(offset > 0)
                return true
            }
        }
        return dragging
    }

    private fun settle() {
        dragging = false
        row.parent?.requestDisallowInterceptTouchEvent(false)
        animator?.cancel()
        animator =
            ValueAnimator.ofFloat(row.translationX, 0f).apply {
                duration = 180
                interpolator = DecelerateInterpolator()
                addUpdateListener {
                    row.translationX = it.animatedValue as Float
                    underlay.invalidateSelf()
                    if (it.animatedFraction == 1f) removeUnderlay()
                }
                start()
            }
    }

    fun cancel() {
        if (dragging) row.parent?.requestDisallowInterceptTouchEvent(false)
        animator?.cancel()
        animator = null
        dragging = false
        decision.cancel()
        row.translationX = 0f
        removeUnderlay()
    }

    private fun removeUnderlay() {
        parent?.overlay?.remove(underlay)
        parent = null
    }
}
