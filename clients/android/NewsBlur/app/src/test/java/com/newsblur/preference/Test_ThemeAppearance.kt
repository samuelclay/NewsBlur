package com.newsblur.preference

import android.content.SharedPreferences
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.PrefConstants.ThemeValue.AUTO
import com.newsblur.util.PrefConstants.ThemeValue.BLACK
import com.newsblur.util.PrefConstants.ThemeValue.DARK
import com.newsblur.util.PrefConstants.ThemeValue.LIGHT
import com.newsblur.util.PrefConstants.ThemeValue.SEPIA
import com.newsblur.util.ThemeAppearance
import com.newsblur.util.ThemeMode
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class Test_ThemeAppearance {
    private val values = mutableMapOf<String, Any>()
    private val editor =
        mockk<SharedPreferences.Editor>(relaxed = true).apply {
            every { putString(any(), any()) } answers {
                values[firstArg()] = secondArg<String>()
                this@apply
            }
            every { putBoolean(any(), any()) } answers {
                values[firstArg()] = secondArg<Boolean>()
                this@apply
            }
        }
    private val preferences =
        mockk<SharedPreferences> {
            every { getString(any(), any()) } answers { values[firstArg()] as? String ?: secondArg() }
            every { getBoolean(any(), any()) } answers { values[firstArg()] as? Boolean ?: secondArg() }
            every { edit() } returns editor
        }
    private val repo = PrefsRepo(preferences, mockk(relaxed = true))

    private fun saved(
        theme: ThemeValue,
        light: ThemeValue = LIGHT,
        dark: ThemeValue = DARK,
    ) {
        values[PrefConstants.THEME] = theme.name
        values[PrefConstants.THEME_LIGHT_VARIANT] = light.name
        values[PrefConstants.THEME_DARK_VARIANT] = dark.name
    }

    private val theme get() = values[PrefConstants.THEME]
    private val lightVariant get() = values[PrefConstants.THEME_LIGHT_VARIANT]
    private val darkVariant get() = values[PrefConstants.THEME_DARK_VARIANT]

    // Test_ThemeAppearance.kt protects the Theme row's value: a mapping that only knew LIGHT and DARK
    // would show Warm and Black readers as Auto, or as nothing at all.
    @Test fun test_theme_row_groups_every_variant_under_its_side() {
        assertEquals(ThemeMode.AUTO, ThemeAppearance.mode(AUTO))
        assertEquals(ThemeMode.LIGHT, ThemeAppearance.mode(LIGHT))
        assertEquals(ThemeMode.LIGHT, ThemeAppearance.mode(SEPIA))
        assertEquals(ThemeMode.DARK, ThemeAppearance.mode(DARK))
        assertEquals(ThemeMode.DARK, ThemeAppearance.mode(BLACK))
    }

    // Test_ThemeAppearance.kt: choosing Light or Dark returns to the variant the reader last used there, so a Warm reader who
    // tries Dark and comes back is still Warm. A fresh install's Dark stays Gray (DARK), as before this
    // row existed, rather than adopting iOS's Black default.
    @Test fun test_choosing_light_or_dark_restores_the_saved_variant() {
        saved(AUTO, light = SEPIA, dark = BLACK)
        repo.setThemeMode(ThemeMode.LIGHT)
        assertEquals(SEPIA.name, theme)
        repo.setThemeMode(ThemeMode.DARK)
        assertEquals(BLACK.name, theme)
        assertEquals(SEPIA.name, lightVariant)

        values.clear()
        repo.setThemeMode(ThemeMode.DARK)
        assertEquals(DARK.name, theme)
        repo.setThemeMode(ThemeMode.LIGHT)
        assertEquals(LIGHT.name, theme)
    }

    @Test fun test_choosing_auto_keeps_both_saved_variants() {
        saved(BLACK, light = SEPIA, dark = BLACK)
        repo.setThemeMode(ThemeMode.AUTO)
        assertEquals(AUTO.name, theme)
        assertEquals(SEPIA, repo.getThemeLightVariant())
        assertEquals(BLACK, repo.getThemeDarkVariant())
    }

    @Test fun test_choosing_a_variant_on_the_current_side_switches_to_it() {
        saved(LIGHT)
        repo.setThemeVariant(SEPIA)
        assertEquals(SEPIA.name, theme)
        assertEquals(SEPIA.name, lightVariant)

        saved(BLACK, dark = BLACK)
        repo.setThemeVariant(DARK)
        assertEquals(DARK.name, theme)
        assertEquals(DARK.name, darkVariant)
    }

    // Test_ThemeAppearance.kt: picking Black while reading in Light must not plunge the app into Black; it only decides what Dark means.
    @Test fun test_choosing_a_variant_for_the_other_side_only_remembers_it() {
        saved(LIGHT, light = LIGHT, dark = DARK)
        repo.setThemeVariant(BLACK)
        assertEquals(LIGHT.name, theme)
        assertEquals(BLACK.name, darkVariant)
        repo.setThemeMode(ThemeMode.DARK)
        assertEquals(BLACK.name, theme)

        saved(DARK)
        repo.setThemeVariant(SEPIA)
        assertEquals(DARK.name, theme)
        assertEquals(SEPIA, repo.getThemeLightVariant())
    }

    @Test fun test_choosing_a_variant_in_auto_stays_auto() {
        saved(AUTO)
        repo.setThemeVariant(SEPIA)
        repo.setThemeVariant(BLACK)
        assertEquals(AUTO.name, theme)
        assertEquals(SEPIA.name, lightVariant)
        assertEquals(BLACK.name, darkVariant)
    }

    // Test_ThemeAppearance.kt: a swipe on the light side only trades Light for Warm, whichever way the fingers move.
    @Test fun test_swipe_on_the_light_side_flips_between_light_and_warm() {
        for (down in listOf(true, false)) {
            saved(LIGHT, dark = BLACK)
            assertEquals(SEPIA, repo.themeAfterSwipe(showing = LIGHT, fingersMovedDown = down))
            saved(SEPIA, light = SEPIA, dark = BLACK)
            assertEquals(LIGHT, repo.themeAfterSwipe(showing = SEPIA, fingersMovedDown = down))
        }
    }

    @Test fun test_swipe_on_the_dark_side_flips_between_gray_and_black() {
        for (down in listOf(true, false)) {
            saved(DARK, light = SEPIA)
            assertEquals(BLACK, repo.themeAfterSwipe(showing = DARK, fingersMovedDown = down))
            saved(BLACK, light = SEPIA, dark = BLACK)
            assertEquals(DARK, repo.themeAfterSwipe(showing = BLACK, fingersMovedDown = down))
        }
    }

    // Test_ThemeAppearance.kt: iOS's handleThemeGesture: names fingers moving down "isUpward" and goes darker; the port keeps the
    // behavior, not the name: fingers moving down go dark, up go light.
    @Test fun test_auto_swipe_down_goes_to_the_saved_dark_variant_and_up_to_the_light_one() {
        saved(AUTO, light = SEPIA, dark = BLACK)
        assertEquals(BLACK, repo.themeAfterSwipe(showing = SEPIA, fingersMovedDown = true))
        assertEquals(SEPIA, repo.themeAfterSwipe(showing = BLACK, fingersMovedDown = false))
    }

    // Test_ThemeAppearance.kt: in Auto the swipe toward the side already on screen would change nothing, so it flips that side's variant.
    @Test fun test_auto_swipe_toward_the_showing_variant_flips_to_the_other_one() {
        saved(AUTO, light = LIGHT, dark = BLACK)
        assertEquals(DARK, repo.themeAfterSwipe(showing = BLACK, fingersMovedDown = true))
        assertEquals(SEPIA, repo.themeAfterSwipe(showing = LIGHT, fingersMovedDown = false))
    }

    @Test fun test_swipe_is_on_until_turned_off() {
        saved(LIGHT)
        assertEquals(SEPIA, repo.themeAfterSwipe(showing = LIGHT, fingersMovedDown = true))
        values[PrefConstants.THEME_GESTURE] = false
        assertNull(repo.themeAfterSwipe(showing = LIGHT, fingersMovedDown = true))
        saved(AUTO)
        assertNull(repo.themeAfterSwipe(showing = LIGHT, fingersMovedDown = false))
    }
}
