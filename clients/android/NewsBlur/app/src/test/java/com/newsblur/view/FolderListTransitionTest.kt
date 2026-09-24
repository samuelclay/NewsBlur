package com.newsblur.view

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FolderListTransitionTest {
    private fun row(id: Long, top: Float, alpha: Float = 1f) =
        FolderListTransition.Row(id, top, 50, alpha)

    @Test
    fun expansionKeepsHeadingAnchoredAndMovesFollowingRowsByTheirActualDistance() {
        val motions =
            plan(
                listOf(row(1, 100f), row(2, 150f), row(3, 200f)),
                listOf(row(1, 100f), row(4, 150f), row(5, 200f), row(2, 250f), row(3, 300f)),
            ).associateBy { it.after.id }

        assertEquals(100f, motions.getValue(1).before.top, 0f)
        assertEquals(100f, motions.getValue(1).after.top, 0f)
        assertEquals(150f, motions.getValue(2).before.top, 0f)
        assertEquals(250f, motions.getValue(2).after.top, 0f)
        assertEquals(0f, motions.getValue(4).before.alpha, 0f)
    }

    @Test
    fun collapseRevealsPreviouslyOffscreenRowsFromTheBottomInOrder() {
        val motions =
            plan(
                listOf(row(1, 100f), row(2, 150f), row(3, 200f)),
                listOf(row(1, 100f), row(4, 150f), row(5, 200f)),
                expanding = false,
            ).associateBy { it.after.id }

        assertEquals(600f, motions.getValue(4).before.top, 0f)
        assertEquals(650f, motions.getValue(5).before.top, 0f)
        assertEquals(0f, motions.getValue(2).after.alpha, 0f)
        assertEquals(1f, motions.getValue(4).after.alpha, 0f)
    }

    @Test
    fun rowsPushedOutsideTheViewportByALargeSectionContinueMovingDown() {
        val motions =
            plan(
                listOf(row(1, 100f), row(2, 150f)),
                listOf(row(1, 100f), row(3, 150f), row(4, 200f)),
            )
        val leaving = motions.single { it.after.id == 2L }
        assertTrue(leaving.after.top >= 600f)
    }

    @Test
    fun reversingStartsAtCurrentPresentationInsteadOfThePreviousDestination() {
        val current = listOf(row(1, 100f), row(2, 177f, 0.43f), row(3, 325f))
        val motions = plan(current, listOf(row(1, 100f), row(3, 150f)), expanding = false)
        assertEquals(current[2], motions.single { it.after.id == 3L }.before)
        assertEquals(current[1], motions.single { it.after.id == 2L }.before)
    }

    @Test
    fun identityMatchingDoesNotDependOnAdapterPositionOrVisibleRowOrder() {
        val motions =
            plan(
                listOf(row(1, 100f), row(2, 150f), row(3, 200f)),
                listOf(row(1, 100f), row(3, 150f)),
                expanding = false,
            )
        assertEquals(200f, motions.single { it.after.id == 3L }.before.top, 0f)
        assertEquals(150f, motions.single { it.after.id == 3L }.after.top, 0f)
    }

    @Test
    fun bottomClampedCollapseBringsNewUpperRowsFromAboveTheViewport() {
        val motions = bottomClampedCollapse().associateBy { it.after.id }
        val heading = motions.getValue(6)
        val viewportShift = heading.after.top - heading.before.top

        for (id in 101L..106L) {
            val incoming = motions.getValue(id)
            assertEquals(incoming.after.top - viewportShift, incoming.before.top, 0f)
            assertEquals("Rows exposed by scrolling are already opaque", 1f, incoming.before.alpha, 0f)
        }
    }

    @Test
    fun bottomClampedCollapseNeverLeavesABlackGapAboveTheHeading() {
        val motions = bottomClampedCollapse()
        val heading = motions.single { it.after.id == 6L }
        for (progress in listOf(0f, 0.25f, 0.5f, 0.75f, 1f)) {
            val headingBottom = heading.before.top + (heading.after.top - heading.before.top) * progress + heading.after.height
            val opaqueRows = motions.filter { it.before.alpha == 1f && it.after.alpha == 1f }
                .map { motion ->
                    val top = motion.before.top + (motion.after.top - motion.before.top) * progress
                    top to top + motion.after.height
                }.sortedBy { it.first }
            var coveredTo = 0f
            for ((top, bottom) in opaqueRows) {
                if (bottom <= 0f || top >= headingBottom) continue
                assertTrue("FolderListTransition.kt exposed a gap at $coveredTo while progress=$progress", top <= coveredTo)
                coveredTo = maxOf(coveredTo, bottom)
            }
            assertTrue("Opaque rows must reach the heading at progress=$progress", coveredTo >= headingBottom)
        }
    }

    @Test
    fun bottomClampedCollapseKeepsOutgoingTagsBelowTheMovingHeading() {
        val motions = bottomClampedCollapse()
        val heading = motions.single { it.after.id == 6L }
        val viewportShift = heading.after.top - heading.before.top
        for (outgoing in motions.filter { it.after.id in 7L..12L }) {
            assertEquals("Saved tags must travel with the heading instead of crossing incoming folders",
                viewportShift, outgoing.after.top - outgoing.before.top, 0f)
            assertEquals(0f, outgoing.after.alpha, 0f)
        }
    }

    private fun bottomClampedCollapse(): List<FolderListTransition.Motion> {
        // AnimatedFolderListView.kt's Saved Stories heading moves from 250px to 550px
        // when collapse removes the rows that had allowed the old viewport offset.
        val before = (1L..12L).mapIndexed { index, id -> row(id, index * 50f) }
        val after = (101L..106L).mapIndexed { index, id -> row(id, index * 50f) } +
            (1L..6L).mapIndexed { index, id -> row(id, 300f + index * 50f) }
        return FolderListTransition.plan(before, after, 600f, 300f, false, 24f)
    }

    private fun plan(
        before: List<FolderListTransition.Row>,
        after: List<FolderListTransition.Row>,
        expanding: Boolean = true,
    ) = FolderListTransition.plan(before, after, 600f, 150f, expanding, 24f)
}
