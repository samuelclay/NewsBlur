package com.newsblur.util

import android.app.Activity
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.view.View
import com.newsblur.NbApplication
import com.newsblur.R

/** TabletPaneDivider.kt's preview spans both activity windows without moving either window. */
internal class TabletPaneResizeGuide private constructor(
    private val hosts: List<Pair<View, GuideLine>>,
    private val top: Int,
    private val bottom: Int
) {
    fun move(screenX: Float) {
        for ((host, line) in hosts) {
            val location = IntArray(2)
            host.getLocationOnScreen(location)
            line.x = screenX - location[0]
            line.setBounds(0, top - location[1], host.width, bottom - location[1])
            line.invalidateSelf()
        }
    }

    fun dismiss() {
        for ((host, line) in hosts) host.overlay.remove(line)
    }

    private class GuideLine(
        private val density: Float,
        private val rightEdge: Boolean,
        private val borderColor: Int,
        private val indicatorColor: Int
    ) : Drawable() {
        var x = 0f
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        override fun draw(canvas: Canvas) {
            val width = 3 * density
            val left = if (rightEdge) x - width else x
            val center = bounds.exactCenterY()
            paint.color = borderColor
            canvas.drawRect(left, bounds.top.toFloat(), left + width, bounds.bottom.toFloat(), paint)
            paint.color = indicatorColor
            paint.alpha = 230
            canvas.drawRoundRect(left, center - 24 * density, left + width, center + 24 * density, width / 2, width / 2, paint)
            paint.alpha = 255
        }

        override fun setAlpha(alpha: Int) { paint.alpha = alpha }
        override fun setColorFilter(colorFilter: ColorFilter?) { paint.colorFilter = colorFilter }
        @Suppress("DEPRECATION")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }

    companion object {
        data class Colors(val border: Int, val indicator: Int)

        fun colors(owner: Activity): Colors {
            val prefs = (owner.applicationContext as NbApplication).prefsRepo.get()
            val borderColor = owner.getColor(when (prefs.getResolvedTheme(owner)) {
                PrefConstants.ThemeValue.DARK -> R.color.segmented_control_border_dark
                PrefConstants.ThemeValue.BLACK -> R.color.segmented_control_border_black
                PrefConstants.ThemeValue.SEPIA -> R.color.segmented_control_border_sepia
                else -> R.color.segmented_control_border_light
            })
            val colors = owner.obtainStyledAttributes(intArrayOf(android.R.attr.textColorSecondary))
            val indicatorColor = colors.getColor(0, borderColor)
            colors.recycle()
            return Colors(borderColor, indicatorColor)
        }

        fun show(owner: Activity, peer: Activity?, top: Int, bottom: Int, rightEdge: Boolean, density: Float): TabletPaneResizeGuide {
            val colors = colors(owner)
            val hosts = listOfNotNull(owner, peer).distinct().map { activity ->
                val host = activity.window.decorView
                val line = GuideLine(density, rightEdge, colors.border, colors.indicator)
                host.overlay.add(line)
                host to line
            }
            return TabletPaneResizeGuide(hosts, top, bottom)
        }
    }
}
