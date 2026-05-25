package com.newsblur.util

import com.newsblur.util.EdgeToEdgeUtil.HorizontalMargins
import com.newsblur.util.EdgeToEdgeUtil.updatedHorizontalMargins
import org.junit.Assert.assertEquals
import org.junit.Test

class EdgeToEdgeUtilTest {
    @Test
    fun horizontalMarginsClearAfterReturningFromLandscapeNavigationBar() {
        val leftNavMargins =
            updatedHorizontalMargins(
                currentLeft = 72,
                currentRight = 0,
                navBarLeft = 0,
                navBarRight = 0,
            )
        val rightNavMargins =
            updatedHorizontalMargins(
                currentLeft = 0,
                currentRight = 72,
                navBarLeft = 0,
                navBarRight = 0,
            )

        assertEquals(HorizontalMargins(left = 0, right = 0), leftNavMargins)
        assertEquals(HorizontalMargins(left = 0, right = 0), rightNavMargins)
    }

    @Test
    fun horizontalMarginsFollowLandscapeNavigationBarSide() {
        assertEquals(
            HorizontalMargins(left = 72, right = 0),
            updatedHorizontalMargins(
                currentLeft = 0,
                currentRight = 0,
                navBarLeft = 72,
                navBarRight = 0,
            ),
        )

        assertEquals(
            HorizontalMargins(left = 0, right = 72),
            updatedHorizontalMargins(
                currentLeft = 0,
                currentRight = 0,
                navBarLeft = 0,
                navBarRight = 72,
            ),
        )
    }
}
