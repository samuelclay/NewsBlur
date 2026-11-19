package com.newsblur.util

import com.newsblur.util.PrefConstants.ThemeValue

/** ThemeAppearance.kt names the Settings Theme row's three choices, the side each ThemeValue sits on. */
enum class ThemeMode { AUTO, LIGHT, DARK }

/**
 * ThemeAppearance.kt maps the iPhone's Theme, Light appearance and Dark appearance rows, and its two-finger
 * theme swipe, onto Android's single stored ThemeValue plus the light and dark variants PrefsRepo.kt remembers.
 */
object ThemeAppearance {
    /** ThemeAppearance.kt: every preference whose change can alter the colors on screen. */
    val preferenceKeys =
        setOf(PrefConstants.THEME, PrefConstants.THEME_LIGHT_VARIANT, PrefConstants.THEME_DARK_VARIANT)

    fun mode(theme: ThemeValue): ThemeMode =
        when (theme) {
            ThemeValue.AUTO -> ThemeMode.AUTO
            ThemeValue.LIGHT, ThemeValue.SEPIA -> ThemeMode.LIGHT
            ThemeValue.DARK, ThemeValue.BLACK -> ThemeMode.DARK
        }

    fun themeFor(
        mode: ThemeMode,
        lightVariant: ThemeValue,
        darkVariant: ThemeValue,
    ): ThemeValue =
        when (mode) {
            ThemeMode.AUTO -> ThemeValue.AUTO
            ThemeMode.LIGHT -> lightVariant
            ThemeMode.DARK -> darkVariant
        }

    /** ThemeAppearance.kt: the other variant on the same side: Light and Warm trade places, as do Gray and Black. */
    fun otherVariant(theme: ThemeValue): ThemeValue =
        when (theme) {
            ThemeValue.LIGHT -> ThemeValue.SEPIA
            ThemeValue.SEPIA -> ThemeValue.LIGHT
            ThemeValue.DARK -> ThemeValue.BLACK
            ThemeValue.BLACK -> ThemeValue.DARK
            ThemeValue.AUTO -> ThemeValue.AUTO
        }

    /**
     * ThemeAppearance.kt ports ThemeManager.m handleThemeGesture: from iOS. On a light or dark side any swipe trades that side's
     * variants. In Auto, fingers moving down the screen go dark and up go light; iOS calls that direction
     * "isUpward", but its behavior, which this keeps, is down = darker. A swipe toward the variant already
     * showing would change nothing, so it flips to the other variant on that side instead.
     */
    fun afterSwipe(
        selected: ThemeValue,
        showing: ThemeValue,
        lightVariant: ThemeValue,
        darkVariant: ThemeValue,
        fingersMovedDown: Boolean,
    ): ThemeValue {
        if (selected != ThemeValue.AUTO) return otherVariant(selected)
        val target = if (fingersMovedDown) darkVariant else lightVariant
        return if (showing == target) otherVariant(target) else target
    }
}
