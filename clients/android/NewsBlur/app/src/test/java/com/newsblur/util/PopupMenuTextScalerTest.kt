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
        assertEquals(15f, PopupMenuTextScaler.scaledTextSizePx(15f, 1f), 0.0001f)
    }

    @Test
    fun controlHeightOnlyGetsTinyIncreaseAtLargerScales() {
        assertEquals(20, PopupMenuTextScaler.scaledControlHeightPx(20, 1f))
        assertEquals(21, PopupMenuTextScaler.scaledControlHeightPx(20, 1.2f))
        assertEquals(23, PopupMenuTextScaler.scaledControlHeightPx(20, 1.4f))
        assertEquals(26, PopupMenuTextScaler.scaledControlHeightPx(20, 1.8f))
    }

    @Test
    fun controlHeightDpIncreaseTargetsLargerMenuSizes() {
        assertEquals(0f, PopupMenuTextScaler.additionalControlHeightDp(1f), 0.0001f)
        assertEquals(2f, PopupMenuTextScaler.additionalControlHeightDp(1.2f), 0.0001f)
        assertEquals(3f, PopupMenuTextScaler.additionalControlHeightDp(1.4f), 0.0001f)
        assertEquals(6f, PopupMenuTextScaler.additionalControlHeightDp(1.8f), 0.0001f)
    }
}
