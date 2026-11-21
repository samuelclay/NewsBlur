package com.newsblur.design

import com.newsblur.util.PrefConstants.ThemeValue

/**
 * Colors for the trainer's natural language classifier sections (fragment/AiClassifierSections.kt),
 * one set per theme. The light values follow media/css/reader/reader.css and the dark ones
 * media/css/reader/darkmode.css. A new theme only needs a new branch in colors().
 */
object AiClassifierPalette {
    data class Colors(
        val focusBackground: Int,
        val focusText: Int,
        val hiddenBackground: Int,
        val hiddenText: Int,
        val neutralBackground: Int,
        val neutralText: Int,
        val badgeBackground: Int,
        // AiClassifierSections.kt's banner for saved AI filters on an account without Premium Archive.
        val archiveBannerBackground: Int,
        val archiveBannerBorder: Int,
        val archiveBannerText: Int,
        val archiveBannerLink: Int,
        val matchBackground: Int,
        val matchText: Int,
        val matchBorder: Int,
        val noMatchBackground: Int,
        val noMatchText: Int,
        val noMatchBorder: Int,
        val errorBackground: Int,
        val errorText: Int,
        val errorBorder: Int,
        val scopeActive: Int,
        val scopeInactive: Int,
        val accent: Int = 0xFF709E5D.toInt(),
        val accentText: Int = 0xFFFFFFFF.toInt(),
    )

    private val light =
        Colors(
            focusBackground = 0xFFE3F0DB.toInt(),
            focusText = 0xFF2E7D32.toInt(),
            hiddenBackground = 0xFFF8E1E1.toInt(),
            hiddenText = 0xFFA90103.toInt(),
            neutralBackground = 0xFFEDEEEA.toInt(),
            neutralText = 0xFF707070.toInt(),
            badgeBackground = 0x1A000000,
            archiveBannerBackground = 0xFFF4EEFC.toInt(),
            archiveBannerBorder = 0xFFD5C2F2.toInt(),
            archiveBannerText = 0xFF4E3482.toInt(),
            archiveBannerLink = 0xFF6B3FBF.toInt(),
            matchBackground = 0xFFE8F5E9.toInt(),
            matchText = 0xFF2E7D32.toInt(),
            matchBorder = 0xFFA5D6A7.toInt(),
            noMatchBackground = 0xFFFCE4EC.toInt(),
            noMatchText = 0xFFB71C1C.toInt(),
            noMatchBorder = 0xFFEF9A9A.toInt(),
            errorBackground = 0xFFFFF3E0.toInt(),
            errorText = 0xFFE65100.toInt(),
            errorBorder = 0xFFFFCC80.toInt(),
            scopeActive = 0xFF4A7BC0.toInt(),
            scopeInactive = 0xFFB0B2AC.toInt(),
        )

    private val sepia =
        light.copy(
            neutralBackground = 0xFFEDE4D6.toInt(),
            neutralText = 0xFF7A6A5A.toInt(),
            scopeInactive = 0xFFB9AC9A.toInt(),
            archiveBannerBackground = 0xFFF3EAF2.toInt(),
            archiveBannerBorder = 0xFFD8C4D6.toInt(),
        )

    private val dark =
        Colors(
            focusBackground = 0xFF1A2E1A.toInt(),
            focusText = 0xFF7ECE72.toInt(),
            hiddenBackground = 0xFF2E1A1A.toInt(),
            hiddenText = 0xFFE87272.toInt(),
            neutralBackground = 0xFF3A3A3C.toInt(),
            neutralText = 0xFFB0B0B0.toInt(),
            badgeBackground = 0x26FFFFFF,
            archiveBannerBackground = 0xFF2A2238.toInt(),
            archiveBannerBorder = 0xFF4E3D6E.toInt(),
            archiveBannerText = 0xFFD9C8F5.toInt(),
            archiveBannerLink = 0xFFB794F6.toInt(),
            matchBackground = 0xFF1A2E1A.toInt(),
            matchText = 0xFF66BB6A.toInt(),
            matchBorder = 0xFF2E7D32.toInt(),
            noMatchBackground = 0xFF2E1A1A.toInt(),
            noMatchText = 0xFFEF9A9A.toInt(),
            noMatchBorder = 0xFF6D3A3A.toInt(),
            errorBackground = 0xFF3A2A1A.toInt(),
            errorText = 0xFFE6A040.toInt(),
            errorBorder = 0xFF7A5A2A.toInt(),
            scopeActive = 0xFF8FB4E8.toInt(),
            scopeInactive = 0xFF6A6A6E.toInt(),
        )

    private val black =
        dark.copy(
            neutralBackground = 0xFF262626.toInt(),
            archiveBannerBackground = 0xFF1C1626.toInt(),
            archiveBannerBorder = 0xFF3E3158.toInt(),
        )

    @JvmStatic
    fun colors(theme: ThemeValue): Colors =
        when (theme) {
            ThemeValue.SEPIA -> sepia
            ThemeValue.DARK -> dark
            ThemeValue.BLACK -> black
            else -> light
        }
}
