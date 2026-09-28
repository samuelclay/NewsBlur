package com.newsblur.util

import com.newsblur.util.PrefConstants.ThemeValue

/** GestureThemeStyle.kt centralizes swipe contrast for all supported themes. */
object GestureThemeStyle {
    data class Palette(
        val background: Int,
        val foreground: Int,
    )

    fun palette(theme: ThemeValue): Palette =
        when (theme) {
            ThemeValue.DARK -> Palette(0xff4b6073.toInt(), 0xffeeeeee.toInt())
            ThemeValue.BLACK -> Palette(0xff283e52.toInt(), 0xffeeeeee.toInt())
            ThemeValue.SEPIA -> Palette(0xffd4c4ab.toInt(), 0xff40382d.toInt())
            else -> Palette(0xffc5cfdc.toInt(), 0xff303840.toInt())
        }
}
