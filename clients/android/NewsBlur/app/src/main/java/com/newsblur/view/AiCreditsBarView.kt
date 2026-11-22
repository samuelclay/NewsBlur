package com.newsblur.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import com.newsblur.design.AiClassifierPalette
import com.newsblur.network.domain.AiCredits
import com.newsblur.util.AiCreditsStatus

/**
 * The AI credit meter's bar: how much of the month's credits are used, as a rounded fill over a
 * light gray track, green while credits last, amber near the end and red when filters pause.
 * Past the plan's credits with usage billing it's simply full, and the meter's text says how far
 * past. fragment/AiClassifierSections.kt, activity/AiCreditsActivity.kt and the Premium screen
 * bind it from util/AiCreditsStatus.kt with design/AiClassifierPalette.kt's colors.
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
            credits: AiCredits,
            colors: AiClassifierPalette.Colors,
        ) {
            trackPaint.color = colors.meterTrack
            fillPaint.color = colors.meterColor(AiCreditsStatus.meterLevel(credits))
            fraction = AiCreditsStatus.meterFraction(credits)
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
