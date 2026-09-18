package com.newsblur.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.newsblur.util.PrefConstants.ThemeValue

object ReaderSheetPalette {
    @JvmStatic fun menuRowHighlightArgb(theme: ThemeValue): Int = when (theme) {
        ThemeValue.DARK -> 0x26FFFFFF
        ThemeValue.BLACK -> 0x30FFFFFF
        ThemeValue.SEPIA -> 0x387D5637
        else -> 0x307A6438
    }

    @JvmStatic fun loadingLowArgb(theme: ThemeValue): Int = when (theme) {
        ThemeValue.DARK -> 0xFF243650.toInt()
        ThemeValue.BLACK -> 0xFF15243A.toInt()
        else -> 0xFFE1EBFF.toInt()
    }

    @JvmStatic fun loadingHighArgb(theme: ThemeValue): Int = when (theme) {
        ThemeValue.BLACK -> 0xFF456DA6.toInt()
        else -> 0xFF5C89C9.toInt()
    }

    data class Colors(
        val background: Color,
        val cardBackground: Color,
        val border: Color,
        val textPrimary: Color,
        val textSecondary: Color,
        val inputBackground: Color,
        val accent: Color = Color(0xFF709E5D),
        val siteFormBackground: Color = background,
        val siteButton: Color = Color(0xFF71879F),
        val siteLink: Color = Color(0xFF5574B2),
        val fresh: Color = Color(0xFF35B963),
        val stale: Color = Color(0xFFDD812B),
    )

    fun colors(theme: ThemeValue): Colors =
        when (theme) {
            ThemeValue.SEPIA ->
                Colors(
                    background = NbSepiaSurface,
                    siteFormBackground = NbSepiaSurfaceAlt,
                    cardBackground = Color(0xFFFAF5ED),
                    border = Color(0xFFD4C8B8),
                    textPrimary = Color(0xFF5C4A3D),
                    textSecondary = Color(0xFF8B7B6B),
                    inputBackground = Color(0xFFFAF5ED),
                )

            ThemeValue.DARK ->
                Colors(
                    background = Gray10,
                    cardBackground = Color(0xFF4A4A4A),
                    border = Color(0xFF5A5A5A),
                    textPrimary = Color(0xFFE0E0E0),
                    textSecondary = Color(0xFFA0A0A0),
                    siteLink = Color(0xFFA3C3ED),
                    inputBackground = Color(0xFF3A3A3A),
                )

            ThemeValue.BLACK ->
                Colors(
                    background = Black,
                    cardBackground = Color(0xFF2A2A2A),
                    border = Color(0xFF404040),
                    textPrimary = Color(0xFFE8E8E8),
                    textSecondary = Color(0xFFB0B0B0),
                    siteLink = Color(0xFFA3C3ED),
                    inputBackground = Color(0xFF222222),
                )

            else ->
                Colors(
                    background = Gray96,
                    siteFormBackground = Color(0xFFEBEDE6),
                    cardBackground = Color.White,
                    border = Color(0xFFD0D2CC),
                    textPrimary = Color(0xFF5E6267),
                    textSecondary = Color(0xFF90928B),
                    inputBackground = Color(0xFFF8F9F6),
                )
        }

    @JvmStatic
    fun backgroundArgb(theme: ThemeValue): Int = colors(theme).background.toArgb()

    @JvmStatic
    fun borderArgb(theme: ThemeValue): Int = colors(theme).border.toArgb()

    @JvmStatic
    fun textPrimaryArgb(theme: ThemeValue): Int = colors(theme).textPrimary.toArgb()

    @JvmStatic
    fun textSecondaryArgb(theme: ThemeValue): Int = colors(theme).textSecondary.toArgb()

    @JvmStatic
    fun inputBackgroundArgb(theme: ThemeValue): Int = colors(theme).inputBackground.toArgb()

    @JvmStatic
    fun accentArgb(theme: ThemeValue): Int = colors(theme).accent.toArgb()
}
