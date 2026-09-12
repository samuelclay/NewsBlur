package com.newsblur.activity

import android.view.View
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreparedReaderEntranceTest {
    @Test
    fun preparationStillDrawsThroughHwuisEightBitAlphaLayer() {
        val surface = mockk<View>(relaxed = true)
        val alpha = slot<Float>()
        every { surface.alpha = capture(alpha) } returns Unit

        prepareReaderSurface(surface)

        // RenderNode.h skips alpha <= 0; RenderNodeDrawable.cpp quantizes alpha to eight bits.
        assertTrue("The article's draw subtree must remain active", alpha.captured > 0f)
        assertTrue("Preparation must survive saveLayerAlpha quantization", (alpha.captured * 255).toInt() >= 1)
        assertTrue("Preparation must leave the titles visually intact", alpha.captured <= 1f / 255f)
    }

    @Test
    fun aPrefetchedPageCannotRevealTheStillEmptyTargetPage() {
        assertFalse(shouldRevealPreparedReader(true, null, "target", "neighbor"))
        assertFalse(shouldRevealPreparedReader(true, "target", "first", "first"))
        assertFalse(shouldRevealPreparedReader(true, null, null, "neighbor"))
    }

    @Test
    fun theSelectedPreparedPageStartsOnlyTheInitialEntrance() {
        assertTrue(shouldRevealPreparedReader(true, null, "target", "target"))
        assertFalse(shouldRevealPreparedReader(false, null, "target", "target"))
    }
}
