package com.newsblur.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import com.newsblur.design.AiClassifierPalette
import com.newsblur.network.domain.AiCredits
import com.newsblur.util.AiCreditsStage
import com.newsblur.util.AiCreditsStatus

/**
 * The AI credit meter's bar: how much of the month's credits are used, as a rounded fill over a
 * rounded track. With usage billing past the plan's credits it splits in two, the plan's share in
 * the usual fill and the billed rest in the AI accent, or red once the monthly limit pauses them.
 * fragment/AiClassifierSections.kt, activity/AiCreditsActivity.kt and the Premium screen bind it
 * from util/AiCreditsStatus.kt with design/AiClassifierPalette.kt's colors.
 */
class AiCreditsBarView
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
    ) : View(context, attrs) {
        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val pastPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val rect = RectF()
        private var fraction = 0f

        // The plan's share of a split bar, or null for one color.
        private var planShare: Float? = null

        init {
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        fun bind(
            credits: AiCredits,
            colors: AiClassifierPalette.Colors,
        ) {
            trackPaint.color = colors.meterTrack
            planShare = AiCreditsStatus.planShare(credits)
            if (planShare != null) {
                fraction = 1f
                fillPaint.color = colors.meterFill
                pastPaint.color = if (AiCreditsStatus.stage(credits) == AiCreditsStage.PAUSED_LIMIT) colors.meterPaused else colors.meterPast
            } else {
                fraction = AiCreditsStatus.meterFraction(credits)
                fillPaint.color = colors.meterColor(AiCreditsStatus.meterLevel(credits))
            }
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val radius = height / 2f
            val isRtl = layoutDirection == LAYOUT_DIRECTION_RTL
            rect.set(0f, 0f, width.toFloat(), height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, trackPaint)
            val share = planShare
            if (share != null) {
                // The billed credits fill the whole bar, then the plan's share covers its start,
                // cut square where the billed part begins.
                canvas.drawRoundRect(rect, radius, radius, pastPaint)
                val shareWidth = width * share
                canvas.save()
                val shareStart = if (isRtl) width - shareWidth else 0f
                canvas.clipRect(shareStart, 0f, shareStart + shareWidth, height.toFloat())
                canvas.drawRoundRect(rect, radius, radius, fillPaint)
                canvas.restore()
                return
            }
            if (fraction <= 0f) return
            // A sliver of use still shows as a dot rather than vanishing.
            val fillWidth = maxOf(width * fraction, height.toFloat())
            if (isRtl) rect.set(width - fillWidth, 0f, width.toFloat(), height.toFloat()) else rect.set(0f, 0f, fillWidth, height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, fillPaint)
        }
    }
