package com.newsblur.image

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_ImageViewport {
    private fun viewport() = ImageViewport().apply { layout(400f, 800f, 1200f, 800f) }

    @Test fun test_fit_preserves_aspect_ratio_and_does_not_enlarge_small_images() {
        val image = viewport()
        assertEquals(400f, image.fittedWidth, 0.01f)
        assertEquals(266.667f, image.fittedHeight, 0.01f)
        image.layout(400f, 800f, 40f, 20f)
        assertEquals(40f, image.fittedWidth, 0.01f)
        assertEquals(20f, image.fittedHeight, 0.01f)
    }

    @Test fun test_zoom_keeps_the_tapped_point_stationary() {
        val image = viewport()
        image.scaleTo(3f, 100f, 400f)
        assertEquals(200f, image.panX, 0.01f)
        assertEquals(0f, image.panY, 0.01f)
        assertTrue(image.isZoomed)
    }

    @Test fun test_pan_cannot_reveal_blank_space_past_the_image_edges() {
        val image = viewport()
        image.scaleTo(3f, 200f, 400f)
        image.pan(10000f, 10000f)
        assertEquals(400f, image.panX, 0.01f)
        assertEquals(0f, image.panY, 0.01f)
        image.pan(-20000f, -20000f)
        assertEquals(-400f, image.panX, 0.01f)
        assertEquals(0f, image.panY, 0.01f)
    }

    @Test fun test_zooming_back_to_fit_recenters_after_panning() {
        val image = viewport()
        image.scaleTo(5f, 80f, 200f)
        image.pan(-180f, 100f)
        image.scaleTo(1f, 200f, 400f)
        assertFalse(image.isZoomed)
        assertEquals(0f, image.panX, 0f)
        assertEquals(0f, image.panY, 0f)
    }

    @Test fun test_rotation_refits_and_resets_zoom() {
        val image = viewport()
        image.scaleTo(3f, 100f, 400f)
        image.layout(800f, 400f, 1200f, 800f)
        assertEquals(600f, image.fittedWidth, 0f)
        assertEquals(400f, image.fittedHeight, 0f)
        assertFalse(image.isZoomed)
        assertEquals(0f, image.panX, 0f)
    }

    @Test fun test_zoom_bounds() {
        val image = viewport()
        image.scaleTo(1000f, 200f, 400f)
        assertEquals(image.maxZoom, image.zoom, 0f)
        image.scaleTo(0.1f, 200f, 400f)
        assertEquals(1f, image.zoom, 0f)
    }

    @Test fun test_dismiss_in_every_direction_including_diagonal() {
        listOf(100f to 0f, -100f to 0f, 0f to 100f, 0f to -100f, 70f to 70f).forEach { (x, y) ->
            assertTrue(ImageViewport.shouldDismiss(x, y, 0f, 0f))
        }
    }

    @Test fun test_short_drag_returns_but_deliberate_flick_dismisses() {
        assertFalse(ImageViewport.shouldDismiss(20f, 0f, 1000f, 0f))
        assertFalse(ImageViewport.shouldDismiss(50f, 0f, 100f, 0f))
        assertTrue(ImageViewport.shouldDismiss(-30f, 0f, -700f, 0f))
    }
}
