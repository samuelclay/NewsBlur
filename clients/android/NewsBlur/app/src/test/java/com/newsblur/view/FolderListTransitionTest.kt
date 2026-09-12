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

    private fun plan(
        before: List<FolderListTransition.Row>,
        after: List<FolderListTransition.Row>,
        expanding: Boolean = true,
    ) = FolderListTransition.plan(before, after, 600f, 150f, expanding, 24f)
}
