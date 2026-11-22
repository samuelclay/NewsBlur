package com.newsblur.design

import com.newsblur.util.AiCreditsMeterLevel
import com.newsblur.util.PrefConstants.ThemeValue

/**
 * Colors for the trainer's natural language classifier sections (fragment/AiClassifierSections.kt),
 * their AI credit meter and notices, the AI credits screen (activity/AiCreditsActivity.kt) and the
 * Premium screen's AI credits card, one set per theme. The light values follow
 * media/css/reader/reader.css and the dark ones media/css/reader/darkmode.css. A new theme only
 * needs a new branch in colors().
 */
object AiClassifierPalette {
    data class Colors(
        // AiCreditsActivity.kt's screen and cards.
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
        // A free account's notice that AI filters only run on a paid plan, leading to the upgrade screen.
        val upgradeBackground: Int,
        val upgradeBorder: Int,
        val upgradeText: Int,
        // Most of the month's credits are used.
        val warningBackground: Int,
        val warningBorder: Int,
        val warningText: Int,
        // Filters are paused until the 1st.
        val pausedBackground: Int,
        val pausedBorder: Int,
        val pausedText: Int,
        // Usage billing is on and filters run past the credits.
        val billingBackground: Int,
        val billingBorder: Int,
        val billingText: Int,
        // view/AiCreditsBarView.kt: the track, and the fill for each AiCreditsMeterLevel.
        val meterTrack: Int,
        val meterFill: Int,
        val meterWarning: Int,
        val meterPaused: Int,
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
    ) {
        fun meterColor(level: AiCreditsMeterLevel): Int =
            when (level) {
                AiCreditsMeterLevel.NORMAL -> meterFill
                AiCreditsMeterLevel.WARNING -> meterWarning
                AiCreditsMeterLevel.PAUSED -> meterPaused
            }
    }

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
            upgradeBackground = 0xFFF4EEFC.toInt(),
            upgradeBorder = 0xFFD5C2F2.toInt(),
            upgradeText = 0xFF4E3482.toInt(),
            warningBackground = 0xFFFFF8E1.toInt(),
            warningBorder = 0xFFFFC107.toInt(),
            warningText = 0xFF6D5A00.toInt(),
            pausedBackground = 0xFFFFEBEE.toInt(),
            pausedBorder = 0xFFEF9A9A.toInt(),
            pausedText = 0xFFB71C1C.toInt(),
            billingBackground = 0xFFEEF3FA.toInt(),
            billingBorder = 0xFFC9D8EE.toInt(),
            billingText = 0xFF2F5A8F.toInt(),
            meterTrack = 0xFFE6E8E3.toInt(),
            meterFill = 0xFF709E5D.toInt(),
            meterWarning = 0xFFE0A030.toInt(),
            meterPaused = 0xFFC62828.toInt(),
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
            screenBackground = 0xFFF3EDE2.toInt(),
            cardBackground = 0xFFFAF5ED.toInt(),
            cardBorder = 0xFFD4C8B8.toInt(),
            textPrimary = 0xFF5C4A3D.toInt(),
            textSecondary = 0xFF8B7B6B.toInt(),
            inputBackground = 0xFFFFFBF4.toInt(),
            neutralBackground = 0xFFEDE4D6.toInt(),
            neutralText = 0xFF7A6A5A.toInt(),
            scopeInactive = 0xFFB9AC9A.toInt(),
            upgradeBackground = 0xFFF3EAF2.toInt(),
            upgradeBorder = 0xFFD8C4D6.toInt(),
            billingBackground = 0xFFEEEFEF.toInt(),
            billingBorder = 0xFFCFD3D6.toInt(),
            meterTrack = 0xFFE6DCCB.toInt(),
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
            upgradeBackground = 0xFF2A2238.toInt(),
            upgradeBorder = 0xFF4E3D6E.toInt(),
            upgradeText = 0xFFD9C8F5.toInt(),
            warningBackground = 0xFF2A2510.toInt(),
            warningBorder = 0xFF6D5A00.toInt(),
            warningText = 0xFFE6C84A.toInt(),
            pausedBackground = 0xFF2E1A1A.toInt(),
            pausedBorder = 0xFF6D3A3A.toInt(),
            pausedText = 0xFFEF9A9A.toInt(),
            billingBackground = 0xFF1A2433.toInt(),
            billingBorder = 0xFF2E4366.toInt(),
            billingText = 0xFFA9C4EC.toInt(),
            // Lighter than the trainer's and the credits screen's cards, so the empty part of the meter shows.
            meterTrack = 0xFF56565A.toInt(),
            meterFill = 0xFF7ECE72.toInt(),
            meterWarning = 0xFFE6A040.toInt(),
            meterPaused = 0xFFEF5350.toInt(),
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
            screenBackground = 0xFF000000.toInt(),
            cardBackground = 0xFF161616.toInt(),
            cardBorder = 0xFF333333.toInt(),
            textPrimary = 0xFFE8E8E8.toInt(),
            textSecondary = 0xFFB0B0B0.toInt(),
            inputBackground = 0xFF222222.toInt(),
            neutralBackground = 0xFF262626.toInt(),
            upgradeBackground = 0xFF1C1626.toInt(),
            upgradeBorder = 0xFF3E3158.toInt(),
            warningBackground = 0xFF1F1B0A.toInt(),
            pausedBackground = 0xFF221313.toInt(),
            billingBackground = 0xFF121A26.toInt(),
            billingBorder = 0xFF26385A.toInt(),
            meterTrack = 0xFF3A3A3C.toInt(),
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
