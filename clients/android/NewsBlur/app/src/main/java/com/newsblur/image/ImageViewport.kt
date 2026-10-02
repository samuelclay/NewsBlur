package com.newsblur.image

import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** ImageViewport.kt keeps zoom, pan bounds, and dismissal thresholds independent of touch delivery. */
class ImageViewport {
    var width = 0f
        private set
    var height = 0f
        private set
    var fittedWidth = 0f
        private set
    var fittedHeight = 0f
        private set
    var maxZoom = 4f
        private set
    var zoom = 1f
        private set
    var panX = 0f
        private set
    var panY = 0f
        private set
    val isZoomed get() = zoom > 1.01f

    fun layout(
        width: Float,
        height: Float,
        imageWidth: Float,
        imageHeight: Float,
    ) {
        this.width = width
        this.height = height
        val fit = min(1f, min(width / imageWidth.coerceAtLeast(1f), height / imageHeight.coerceAtLeast(1f)))
        fittedWidth = imageWidth * fit
        fittedHeight = imageHeight * fit
        maxZoom = max(4f, min(12f, 2f / fit.coerceAtLeast(0.001f)))
        reset()
    }

    fun reset() {
        zoom = 1f
        panX = 0f
        panY = 0f
    }

    fun scaleTo(
        value: Float,
        focusX: Float,
        focusY: Float,
    ) {
        val next = value.coerceIn(1f, maxZoom)
        val ratio = next / zoom
        panX = (panX + width / 2 - focusX) * ratio + focusX - width / 2
        panY = (panY + height / 2 - focusY) * ratio + focusY - height / 2
        zoom = next
        clampPan()
    }

    fun pan(
        dx: Float,
        dy: Float,
    ) {
        panX += dx
        panY += dy
        clampPan()
    }

    private fun clampPan() {
        val xLimit = max(0f, (fittedWidth * zoom - width) / 2)
        val yLimit = max(0f, (fittedHeight * zoom - height) / 2)
        panX = panX.coerceIn(-xLimit, xLimit)
        panY = panY.coerceIn(-yLimit, yLimit)
    }

    companion object {
        fun shouldDismiss(
            dxDp: Float,
            dyDp: Float,
            vxDp: Float,
            vyDp: Float,
        ): Boolean {
            val distance = hypot(dxDp, dyDp)
            return distance > 90 || (distance > 25 && hypot(vxDp, vyDp) > 650)
        }
    }
}
