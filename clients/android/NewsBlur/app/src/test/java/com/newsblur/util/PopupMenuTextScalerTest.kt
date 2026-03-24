package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test

class PopupMenuTextScalerTest {
    @Test
    fun menuTextScaleNeverDropsBelowCurrentSize() {
        assertEquals(1f, PopupMenuTextScaler.resolvedTextScale(0.7f), 0.0001f)
        assertEquals(1f, PopupMenuTextScaler.resolvedTextScale(1f), 0.0001f)
    }

    @Test
    fun menuTextScaleTracksLargerUserPreference() {
        assertEquals(1.4f, PopupMenuTextScaler.resolvedTextScale(1.4f), 0.0001f)
        assertEquals(2f, PopupMenuTextScaler.resolvedTextScale(2f), 0.0001f)
    }

    @Test
    fun textSizeUsesResolvedScale() {
        assertEquals(15f, PopupMenuTextScaler.scaledTextSizePx(15f, 0.85f), 0.0001f)
        assertEquals(21f, PopupMenuTextScaler.scaledTextSizePx(15f, 1.4f), 0.0001f)
    }

    @Test
    fun minimumHeightOnlyGrowsSlightlyWithLargerText() {
        assertEquals(20, PopupMenuTextScaler.scaledMinimumHeightPx(20, 0.85f))
        assertEquals(22, PopupMenuTextScaler.scaledMinimumHeightPx(20, 1.5f))
        assertEquals(24, PopupMenuTextScaler.scaledMinimumHeightPx(20, 2f))
    }
}
