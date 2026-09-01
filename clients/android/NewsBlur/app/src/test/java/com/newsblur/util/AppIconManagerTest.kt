package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppIconManagerTest {
    @Test
    fun appIconFlavors_matchIosChooserOrder() {
        assertEquals(
            listOf(
                "sunrise-gold",
                "meadow-sage",
                "atlantic-blue",
                "coral-rose",
                "ruby-red",
                "ember-orange",
                "teal-mint",
                "lavender-iris",
                "slate-gray",
                "sepia-cocoa",
                "arctic-cyan",
                "plum-berry",
            ),
            AppIconManager.flavors.map { it.id },
        )
    }

    @Test
    fun appIconFlavors_haveLightAndDarkOptions() {
        AppIconManager.flavors.forEach { flavor ->
            assertEquals(2, flavor.options.size)
            assertEquals(listOf("Light", "Dark"), flavor.options.map { it.appearance })
            assertTrue(flavor.options.all { it.flavor == flavor.title })
            assertTrue(flavor.options.all { it.previewRes != 0 })
            assertTrue(flavor.launcherIconRes != 0)
        }
    }
}
