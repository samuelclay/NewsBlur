package com.newsblur.view

import kotlin.math.abs

/** RowSwipeDecision.kt locks vertical intent for the entire touch sequence. */
internal class RowSwipeDecision(
    private val slop: Float,
) {
    var dragging = false
        private set
    private var rejected = false

    fun begin() {
        dragging = false
        rejected = false
    }

    fun move(
        dx: Float,
        dy: Float,
        enabled: Boolean,
    ): Boolean {
        if (rejected) return false
        if (!dragging) {
            if (abs(dy) > slop && abs(dy) >= abs(dx)) {
                cancel()
                return false
            }
            if (abs(dx) <= slop || abs(dx) < abs(dy) * 1.5f) return false
            if (!enabled) {
                cancel()
                return false
            }
            dragging = true
        }
        return true
    }

    fun finish(
        offset: Float,
        width: Int,
        enabled: Boolean,
    ): Boolean {
        val commit = dragging && !rejected && width > 0 && enabled && abs(offset) >= width * .2f
        cancel()
        return commit
    }

    fun cancel() {
        dragging = false
        rejected = true
    }
}
