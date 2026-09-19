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
        // AnimatedFolderListView.kt cannot retain its old scroll offset when collapse shortens the list.
        // Rows at or above the heading reveal the resulting viewport shift; newly exposed upper rows
        // must enter from above, rather than crossing the saved tags from the bottom of the viewport.
        val anchor = before.filter { it.top + it.height <= anchorBottom && it.id in current }.maxByOrNull { it.top }
        val clampShift = if (!expanding && anchor != null) max(0f, current.getValue(anchor.id).top - anchor.top) else 0f
        val firstSharedTop = after.filter { row -> previous[row.id]?.let { it.top + it.height <= anchorBottom } == true }
            .minOfOrNull { it.top } ?: viewportBottom
        fun entersFromAbove(row: Row) = clampShift > 0f && row.top < firstSharedTop
        val firstIncomingTop = after.firstOrNull { it.id !in previous && !entersFromAbove(it) }?.top ?: viewportBottom
        val followingRowTravel =
            after.firstNotNullOfOrNull { row ->
                previous[row.id]?.let { old -> (row.top - old.top).takeIf { it > 0f } }
            } ?: max(revealDistance, viewportBottom - anchorBottom)

        return after.map { row ->
            val old = previous[row.id]
            val incomingTop =
                if (entersFromAbove(row)) {
                    row.top - clampShift
                } else if (expanding) {
                    row.top - min(revealDistance, max(0f, row.top - anchorBottom))
                } else {
                    max(viewportBottom, firstIncomingTop) + row.top - firstIncomingTop
                }
            Motion(old ?: row.copy(top = incomingTop, alpha = if (entersFromAbove(row)) 1f else 0f), row)
        } + before.filter { it.id !in current }.map { row ->
            val destination =
                if (clampShift > 0f) {
                    row.top + clampShift
                } else if (expanding) {
                    row.top + followingRowTravel
                } else {
                    row.top - min(revealDistance, max(0f, row.top - anchorBottom))
                }
            Motion(row, row.copy(top = destination, alpha = 0f))
        }
    }
}
