package com.newsblur.util

/** Shared limits for StorySplitView.kt and FeedListDrawer.kt, in the whole window's coordinates. */
object TabletPaneSizing {
    const val DEFAULT_RATIO = 0.4f

    // TabletPaneDivider.kt grows either start-edge list toward the reading direction.
    fun draggedRatio(startRatio: Float, displacementPx: Float, windowWidthPx: Float, isRtl: Boolean): Float =
        startRatio + (if (isRtl) -displacementPx else displacementPx) / windowWidthPx.coerceAtLeast(1f)

    fun storyRange(windowWidthDp: Float): ClosedFloatingPointRange<Float> {
        val minimum = (240f / windowWidthDp.coerceAtLeast(600f)).coerceAtLeast(0.25f)
        val maximum = (1f - 240f / windowWidthDp.coerceAtLeast(600f)).coerceAtMost(0.65f)
        return minimum..maximum
    }

    fun storyRatio(requested: Float, windowWidthDp: Float): Float =
        finiteRatio(requested).coerceIn(storyRange(windowWidthDp))

    fun feedRatio(requested: Float, windowWidthDp: Float): Float =
        finiteRatio(requested).coerceIn(feedRange(windowWidthDp))

    fun feedRange(windowWidthDp: Float): ClosedFloatingPointRange<Float> {
        val width = windowWidthDp.coerceAtLeast(600f)
        return (280f / width).coerceAtLeast(0.2f)..(1f - 240f / width).coerceAtMost(0.7f)
    }

    private fun finiteRatio(value: Float): Float = if (value.isFinite()) value else DEFAULT_RATIO
}
