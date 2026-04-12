package com.newsblur.util

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.widget.TextView
import androidx.annotation.ColorInt
import androidx.annotation.StringRes
import com.newsblur.R
import kotlin.math.roundToInt

object StoryClusterBadgeViewBinder {
    @StringRes
    fun labelRes(clusterTier: String?): Int =
        if (StoryClusterDisplayDecision.normalizeClusterTier(clusterTier) == StoryClusterDisplayDecision.CLUSTER_TIER_TITLE) {
            R.string.story_cluster_badge_match
        } else {
            R.string.story_cluster_badge_related
        }

    fun endAnchorId(
        hasPreview: Boolean,
        previewId: Int,
        dateId: Int,
    ): Int = if (hasPreview) previewId else dateId

    fun bind(
        target: TextView,
        context: Context,
        clusterTier: String?,
        palette: StoryClusterThemeStyle.Palette,
        isRead: Boolean,
    ) {
        val color = StoryClusterThemeStyle.badgeColor(palette, clusterTier, isRead)
        target.text = context.getString(labelRes(clusterTier))
        target.setTextColor(color)
        target.background = background(color, target.resources.displayMetrics.density)
        target.visibility = android.view.View.VISIBLE
    }

    private fun background(
        @ColorInt color: Int,
        density: Float,
    ): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 999f * density
            setColor(Color.TRANSPARENT)
            setStroke(density.roundToInt().coerceAtLeast(1), color)
        }
}
