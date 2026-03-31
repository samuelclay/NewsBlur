package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test

class StoryHeaderPillAppearanceResolverTest {
    @Test
    fun keeps_expanded_spacing_when_label_is_visible() {
        val appearance =
            StoryHeaderPillAppearanceResolver.resolve(
                true,
                18,
                7,
                18,
                7,
                6,
                8,
            )

        assertEquals(18, appearance.paddingStart())
        assertEquals(18, appearance.paddingEnd())
        assertEquals(6, appearance.iconPadding())
    }

    @Test
    fun collapses_to_compact_spacing_when_label_is_hidden() {
        val appearance =
            StoryHeaderPillAppearanceResolver.resolve(
                false,
                18,
                7,
                18,
                7,
                6,
                8,
            )

        assertEquals(8, appearance.paddingStart())
        assertEquals(8, appearance.paddingEnd())
        assertEquals(7, appearance.paddingTop())
        assertEquals(7, appearance.paddingBottom())
        assertEquals(0, appearance.iconPadding())
    }
}
