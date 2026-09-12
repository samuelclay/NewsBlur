package com.newsblur.view

import kotlin.math.max
import kotlin.math.min

/** Geometry for the visible rows animated by AnimatedFolderListView.kt. */
internal object FolderListTransition {
    data class Row(
        val id: Long,
        val top: Float,
        val height: Int,
        val alpha: Float = 1f,
        val indicatorRotation: Float? = null,
    )

    data class Motion(
        val before: Row,
        val after: Row,
    )

    fun plan(
        before: List<Row>,
        after: List<Row>,
        viewportBottom: Float,
        anchorBottom: Float,
        expanding: Boolean,
        revealDistance: Float,
    ): List<Motion> {
        val previous = before.associateBy { it.id }
        val current = after.associateBy { it.id }
        val firstIncomingTop = after.firstOrNull { it.id !in previous }?.top ?: viewportBottom
        val followingRowTravel =
            after.firstNotNullOfOrNull { row ->
                previous[row.id]?.let { old -> (row.top - old.top).takeIf { it > 0f } }
            } ?: max(revealDistance, viewportBottom - anchorBottom)

        return after.map { row ->
            val old = previous[row.id]
            val incomingTop =
                if (expanding) {
                    row.top - min(revealDistance, max(0f, row.top - anchorBottom))
                } else {
                    max(viewportBottom, firstIncomingTop) + row.top - firstIncomingTop
                }
            Motion(old ?: row.copy(top = incomingTop, alpha = 0f), row)
        } + before.filter { it.id !in current }.map { row ->
            val destination =
                if (expanding) {
                    row.top + followingRowTravel
                } else {
                    row.top - min(revealDistance, max(0f, row.top - anchorBottom))
                }
            Motion(row, row.copy(top = destination, alpha = 0f))
        }
    }
}
