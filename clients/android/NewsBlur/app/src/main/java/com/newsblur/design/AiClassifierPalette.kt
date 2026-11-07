package com.newsblur.design

import com.newsblur.util.PrefConstants.ThemeValue

/**
 * Colors for the trainer's natural language classifier sections (fragment/AiClassifierSections.kt)
 * and the usage billing screen (activity/UsageBillingActivity.kt), one set per theme. The light
 * values follow media/css/reader/reader.css and the dark ones media/css/reader/darkmode.css.
 * A new theme only needs a new branch in colors().
 */
object AiClassifierPalette {
    data class Colors(
        val screenBackground: Int,
        val cardBackground: Int,
        val cardBorder: Int,
        val textPrimary: Int,
        val textSecondary: Int,
        val inputBackground: Int,
        val focusBackground: Int,
        val focusText: Int,
        val hiddenBackground: Int,
        val hiddenText: Int,
        val neutralBackground: Int,
        val neutralText: Int,
        val badgeBackground: Int,
        val costBackground: Int,
        val costBorder: Int,
        val billingBannerBackground: Int,
        val billingBannerBorder: Int,
        val billingBannerText: Int,
        val billingBannerLink: Int,
        val limitBannerBackground: Int,
        val limitBannerBorder: Int,
        val limitBannerText: Int,
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
        val progressTrack: Int,
        val progressFill: Int,
        val progressWarning: Int,
        val progressLimit: Int,
        // The AI Filter level of the trainer's scoring legend (util/UIUtils.java setupIntelExplainer),
        // in the content filter's blue like media/css/reader/reader.css NB-explainer-level-ai.
        val legendBackground: Int = 0x184A90D9,
        val legendText: Int = 0xFF2F6FB3.toInt(),
        val legendIcon: Int = 0xFF4A90D9.toInt(),
        val accent: Int = 0xFF709E5D.toInt(),
        val accentText: Int = 0xFFFFFFFF.toInt(),
    )

    private val light =
        Colors(
            screenBackground = 0xFFF4F4F2.toInt(),
            cardBackground = 0xFFFFFFFF.toInt(),
            cardBorder = 0xFFD0D2CC.toInt(),
            textPrimary = 0xFF404040.toInt(),
            textSecondary = 0xFF808080.toInt(),
            inputBackground = 0xFFF8F9F6.toInt(),
            focusBackground = 0xFFE3F0DB.toInt(),
            focusText = 0xFF2E7D32.toInt(),
            hiddenBackground = 0xFFF8E1E1.toInt(),
            hiddenText = 0xFFA90103.toInt(),
            neutralBackground = 0xFFEDEEEA.toInt(),
            neutralText = 0xFF707070.toInt(),
            badgeBackground = 0x1A000000,
            costBackground = 0xFFF5F7F9.toInt(),
            costBorder = 0xFFE2E5E9.toInt(),
            billingBannerBackground = 0xFFFFF8E1.toInt(),
            billingBannerBorder = 0xFFFFC107.toInt(),
            billingBannerText = 0xFF6D5A00.toInt(),
            billingBannerLink = 0xFF8A6D00.toInt(),
            limitBannerBackground = 0xFFFFEBEE.toInt(),
            limitBannerBorder = 0xFFEF9A9A.toInt(),
            limitBannerText = 0xFFC62828.toInt(),
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
            progressTrack = 0xFFE6E8E3.toInt(),
            progressFill = 0xFF709E5D.toInt(),
            progressWarning = 0xFFE0A030.toInt(),
            progressLimit = 0xFFC62828.toInt(),
        )

    private val sepia =
        light.copy(
            screenBackground = 0xFFF3EDE2.toInt(),
            cardBackground = 0xFFFAF5ED.toInt(),
            cardBorder = 0xFFD4C8B8.toInt(),
            textPrimary = 0xFF5C4A3D.toInt(),
            textSecondary = 0xFF8B7B6B.toInt(),
            inputBackground = 0xFFFFFBF4.toInt(),
            neutralBackground = 0xFFEDE4D6.toInt(),
            neutralText = 0xFF7A6A5A.toInt(),
            costBackground = 0xFFF3EBDF.toInt(),
            costBorder = 0xFFDCCFBD.toInt(),
            scopeInactive = 0xFFB9AC9A.toInt(),
            progressTrack = 0xFFE6DCCB.toInt(),
        )

    private val dark =
        Colors(
            screenBackground = 0xFF1C1C1E.toInt(),
            cardBackground = 0xFF2C2C2E.toInt(),
            cardBorder = 0xFF48484A.toInt(),
            textPrimary = 0xFFE0E0E0.toInt(),
            textSecondary = 0xFFA0A0A0.toInt(),
            inputBackground = 0xFF3A3A3A.toInt(),
            focusBackground = 0xFF1A2E1A.toInt(),
            focusText = 0xFF7ECE72.toInt(),
            hiddenBackground = 0xFF2E1A1A.toInt(),
            hiddenText = 0xFFE87272.toInt(),
            neutralBackground = 0xFF3A3A3C.toInt(),
            neutralText = 0xFFB0B0B0.toInt(),
            badgeBackground = 0x26FFFFFF,
            costBackground = 0xFF2A2C2E.toInt(),
            costBorder = 0xFF3A3C3E.toInt(),
            billingBannerBackground = 0xFF2A2510.toInt(),
            billingBannerBorder = 0xFF6D5A00.toInt(),
            billingBannerText = 0xFFE6C84A.toInt(),
            billingBannerLink = 0xFFFFC107.toInt(),
            limitBannerBackground = 0xFF2E1A1A.toInt(),
            limitBannerBorder = 0xFF6D3A3A.toInt(),
            limitBannerText = 0xFFEF9A9A.toInt(),
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
            progressTrack = 0xFF3A3A3C.toInt(),
            progressFill = 0xFF7ECE72.toInt(),
            progressWarning = 0xFFE6A040.toInt(),
            progressLimit = 0xFFEF5350.toInt(),
            legendBackground = 0x404A90D9,
            legendText = 0xFF7FB2E5.toInt(),
            legendIcon = 0xFF5B9FD9.toInt(),
        )

    private val black =
        dark.copy(
            screenBackground = 0xFF000000.toInt(),
            cardBackground = 0xFF161616.toInt(),
            cardBorder = 0xFF333333.toInt(),
            textPrimary = 0xFFE8E8E8.toInt(),
            textSecondary = 0xFFB0B0B0.toInt(),
            inputBackground = 0xFF222222.toInt(),
            neutralBackground = 0xFF262626.toInt(),
            costBackground = 0xFF1C1C1C.toInt(),
            costBorder = 0xFF333333.toInt(),
            progressTrack = 0xFF2A2A2A.toInt(),
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
