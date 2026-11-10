package com.newsblur.util

import androidx.window.embedding.EmbeddingAnimationParams.AnimationSpec
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_TabletResizeAnimations {
    @Test
    fun test_drag_does_not_animate_stale_frames_but_navigation_still_animates() {
        val params = StorySplitView.resizeAnimationParams(true, 7)
        assertEquals(AnimationSpec.JUMP_CUT, params.changeAnimation)
        assertEquals(AnimationSpec.DEFAULT, params.openAnimation)
        assertEquals(AnimationSpec.DEFAULT, params.closeAnimation)
        assertEquals(
            AnimationSpec.DEFAULT,
            StorySplitView.resizeAnimationParams(false, 7).changeAnimation
        )
    }

    @Test
    fun test_older_extensions_keep_supported_animation_defaults() {
        assertEquals(
            AnimationSpec.DEFAULT,
            StorySplitView.resizeAnimationParams(true, 6).changeAnimation
        )
    }
}
