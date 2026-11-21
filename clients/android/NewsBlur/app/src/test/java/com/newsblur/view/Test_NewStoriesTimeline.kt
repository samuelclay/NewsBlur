package com.newsblur.view

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_NewStoriesTimeline {
    // New stories join in date order, so an old row can sit between two new ones. At every frame each row's visible
    // part must start exactly where the row above it ends: a gap flashes the background, an overlap draws one story
    // over another.
    @Test
    fun test_rowsStayTouchingFromTheTopEdgeWhileTheListIsPushedDown() {
        val heights = floatArrayOf(120f, 64f, 96f, 80f)
        val isNew = booleanArrayOf(true, false, true, false)
        val total = NewStoriesTimeline.totalMs(2)
        var elapsed = 0f
        while (elapsed <= total) {
            val progress = rowProgress(isNew, elapsed)
            val offsets = NewStoriesTimeline.pushOffsets(heights, progress)
            var edge = 0f
            var finalTop = 0f
            heights.indices.forEach { row ->
                val hidden = heights[row] * (1f - progress[row])
                assertEquals("row $row at ${elapsed}ms", edge, finalTop - offsets[row] + hidden, 0.01f)
                edge = finalTop + heights[row] - offsets[row]
                finalTop += heights[row]
            }
            elapsed += 5f
        }
    }

    // The rows that were on screen must start exactly where they were and end at their new places.
    @Test
    fun test_oldRowsStartWhereTheyWereAndEndPushedByEveryNewRowAboveThem() {
        val heights = floatArrayOf(120f, 64f, 96f, 80f)
        val isNew = booleanArrayOf(true, false, true, false)
        val start = NewStoriesTimeline.pushOffsets(heights, rowProgress(isNew, 0f))
        val end = NewStoriesTimeline.pushOffsets(heights, rowProgress(isNew, NewStoriesTimeline.totalMs(2)))

        assertEquals(120f, start[1], 0.01f)
        assertEquals(216f, start[3], 0.01f)
        end.forEach { assertEquals(0f, it, 0.01f) }
    }

    private fun rowProgress(
        isNew: BooleanArray,
        elapsedMs: Float,
    ): FloatArray {
        val newRows = isNew.indices.filter { isNew[it] }
        val newProgress = NewStoriesTimeline.rowProgress(newRows.size, elapsedMs)
        val progress = FloatArray(isNew.size) { 1f }
        newRows.forEachIndexed { rank, row -> progress[row] = newProgress[rank] }
        return progress
    }

    // Sam chose a cascade that starts with the bottom-most new story, and a dozen stories mustn't take seconds.
    @Test
    fun test_bottomRowDropsFirstAndLongCascadesStayShort() {
        val early = NewStoriesTimeline.rowProgress(4, 40f)
        assertTrue(early.last() > 0f)
        assertEquals(0f, early.first(), 0f)

        assertTrue(NewStoriesTimeline.totalMs(30) <= NewStoriesTimeline.DURATION_MS + NewStoriesTimeline.MAX_CASCADE_MS)
    }
}
