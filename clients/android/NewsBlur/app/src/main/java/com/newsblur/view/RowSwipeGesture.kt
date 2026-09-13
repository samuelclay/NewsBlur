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
import androidx.appcompat.content.res.AppCompatResources
import com.newsblur.util.GestureLabels
import com.newsblur.util.GestureSwipeAction
import kotlin.math.abs

/** RowSwipeGesture.kt shares cancelable, finger-following motion between the two native lists. */
class RowSwipeGesture(
    private val row: View,
    private val action: (Boolean) -> GestureSwipeAction?,
    private val perform: (GestureSwipeAction) -> Unit,
    private val claim: () -> Unit = {},
    private val colors: () -> com.newsblur.util.GestureThemeStyle.Palette,
    private val actionDescription: (GestureSwipeAction) -> String = { GestureLabels.title(row.context, it.action) },
) {
    private val density = row.resources.displayMetrics.density
    private val slop = ViewConfiguration.get(row.context).scaledTouchSlop.toFloat()
    private var downX = 0f
    private var downY = 0f
    private val decision = RowSwipeDecision(slop)
    private var dragging = false
    private var animator: ValueAnimator? = null
    private var parent: ViewGroup? = null
    private var revealedAction: GestureSwipeAction? = null
    private var actionIcon: Drawable? = null
    private var iconTint: Int? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val underlay =
        object : Drawable() {
            override fun draw(canvas: Canvas) {
                val dx = row.translationX
                if (dx == 0f) return
                val palette = colors()
                paint.color = palette.background
                paint.alpha = if (abs(dx) >= row.width * .2f) 255 else 190
                val left = row.left.toFloat()
                val top = row.top.toFloat()
                val edge = if (dx > 0) left else left + row.width + dx
                canvas.drawRect(edge, top, edge + abs(dx), top + row.height, paint)
                canvas.save()
                canvas.clipRect(edge, top, edge + abs(dx), top + row.height)
                val size = (28 * density).toInt()
                val iconLeft = (if (dx > 0) left + 16 * density else left + row.width - 16 * density - size).toInt()
                val iconTop = (top + (row.height - size) / 2f).toInt()
                actionIcon?.let { icon ->
                    if (iconTint != palette.foreground) {
                        icon.setTint(palette.foreground)
                        iconTint = palette.foreground
                    }
                    icon.setBounds(iconLeft, iconTop, iconLeft + size, iconTop + size)
                    icon.draw(canvas)
                }
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
                val nextAction = action(dx > 0)
                if (!decision.move(dx, dy, nextAction != null)) return false
                if (!wasDragging) {
                    if (nextAction == null) return false
                    dragging = true
                    parent = row.parent as? ViewGroup
                    underlay.setBounds(row.left, row.top, row.right, row.bottom)
                    parent?.overlay?.add(underlay)
                    row.cancelLongPress()
                    row.isPressed = false
                    row.parent?.requestDisallowInterceptTouchEvent(true)
                    claim()
                }
                if (nextAction != null) reveal(nextAction)
                row.translationX = if (nextAction == null) 0f else dx.coerceIn(-row.width * .8f, row.width * .8f)
                underlay.invalidateSelf()
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!dragging) return false
                val offset = row.translationX
                val selected = revealedAction
                val commit = decision.finish(offset, row.width, action(offset > 0) != null)
                settle()
                if (commit && selected != null) perform(selected)
                return true
            }
        }
        return dragging
    }

    private fun reveal(nextAction: GestureSwipeAction) {
        if (revealedAction == nextAction) return
        revealedAction = nextAction
        actionIcon = AppCompatResources.getDrawable(row.context, nextAction.iconRes)?.mutate()
        iconTint = null
        // RowSwipeGesture.kt keeps the destination action available to TalkBack without drawing text over the row.
        row.announceForAccessibility(actionDescription(nextAction))
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
        revealedAction = null
        actionIcon = null
        iconTint = null
    }
}
