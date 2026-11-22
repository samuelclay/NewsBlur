package com.newsblur.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * The AI credit meter's bar: how much of the month's credits are used, as a rounded fill over a
 * rounded track. fragment/AiClassifierSections.kt, activity/AiCreditsActivity.kt and the Premium
 * screen color it from design/AiClassifierPalette.kt and fill it from util/AiCreditsStatus.kt.
 */
class AiCreditsBarView
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
    ) : View(context, attrs) {
        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val rect = RectF()
        private var fraction = 0f

        init {
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        fun bind(
            fraction: Float,
            trackColor: Int,
            fillColor: Int,
        ) {
            this.fraction = fraction.coerceIn(0f, 1f)
            trackPaint.color = trackColor
            fillPaint.color = fillColor
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val radius = height / 2f
            rect.set(0f, 0f, width.toFloat(), height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, trackPaint)
            if (fraction <= 0f) return
            // A sliver of use still shows as a dot rather than vanishing.
            val fillWidth = maxOf(width * fraction, height.toFloat())
            val isRtl = layoutDirection == LAYOUT_DIRECTION_RTL
            if (isRtl) rect.set(width - fillWidth, 0f, width.toFloat(), height.toFloat()) else rect.set(0f, 0f, fillWidth, height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, fillPaint)
        }
    }
