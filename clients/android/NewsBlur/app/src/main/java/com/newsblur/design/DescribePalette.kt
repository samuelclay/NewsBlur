package com.newsblur.design

import androidx.compose.ui.graphics.Color
import com.newsblur.util.PrefConstants.ThemeValue

/**
 * DescribePalette.kt holds every color the Describe tab adds on top of ReaderSheetPalette (score pills, source
 * badges, the phase stepper, sub-query chips, the active history card and the sparkle accent) per theme, so a
 * new theme like Sapia only needs one more branch here.
 */
object DescribePalette {
    data class Colors(
        val scoreHigh: Color,
        val onScoreHigh: Color,
        val scoreMedium: Color,
        val onScoreMedium: Color,
        val scoreLow: Color,
        val onScoreLow: Color,
        val pending: Color,
        val onPending: Color,
        val sourceWeb: Color,
        val onSourceWeb: Color,
        val sourceIndex: Color,
        val onSourceIndex: Color,
        val stepDone: Color,
        val stepCurrent: Color,
        val stepPending: Color,
        val chip: Color,
        val onChip: Color,
        val historyActive: Color,
        val historyActiveBorder: Color,
        val sparkle: Color,
        val upgradeButton: Color,
        val onUpgradeButton: Color,
    )

    fun colors(theme: ThemeValue): Colors =
        when (theme) {
            ThemeValue.SEPIA ->
                Colors(
                    scoreHigh = Color(0xFFDCEBD0),
                    onScoreHigh = Color(0xFF2E6B2A),
                    scoreMedium = Color(0xFFF6E3B8),
                    onScoreMedium = Color(0xFF8A5A10),
                    scoreLow = Color(0xFFEDE3D4),
                    onScoreLow = Color(0xFF7A6A5A),
                    pending = Color(0xFFEFE6D8),
                    onPending = Color(0xFF8B7B6B),
                    sourceWeb = Color(0xFFE0E6EE),
                    onSourceWeb = Color(0xFF3F5E86),
                    sourceIndex = Color(0xFFF8E6CC),
                    onSourceIndex = Color(0xFFA35A12),
                    stepDone = Color(0xFF6E8F4E),
                    stepCurrent = Color(0xFF5574B2),
                    stepPending = Color(0xFFD4C8B8),
                    chip = Color(0xFFEFE5D6),
                    onChip = Color(0xFF5C4A3D),
                    historyActive = Color(0xFFEBE1D0),
                    historyActiveBorder = Color(0xFF5574B2),
                    sparkle = Color(0xFFC98A2E),
                    upgradeButton = Color(0xFFC98A2E),
                    onUpgradeButton = Color.White,
                )

            ThemeValue.DARK ->
                Colors(
                    scoreHigh = Color(0xFF2B4A31),
                    onScoreHigh = Color(0xFFA8E2B4),
                    scoreMedium = Color(0xFF4E3F16),
                    onScoreMedium = Color(0xFFF2D27E),
                    scoreLow = Color(0xFF3E3E3E),
                    onScoreLow = Color(0xFFC4C4C4),
                    pending = Color(0xFF3B404A),
                    onPending = Color(0xFFBFC6D2),
                    sourceWeb = Color(0xFF2B3A52),
                    onSourceWeb = Color(0xFFA3C3ED),
                    sourceIndex = Color(0xFF4A3420),
                    onSourceIndex = Color(0xFFF0B07A),
                    stepDone = Color(0xFF8DBA74),
                    stepCurrent = Color(0xFFA3C3ED),
                    stepPending = Color(0xFF5A5A5A),
                    chip = Color(0xFF3A3A3A),
                    onChip = Color(0xFFD8D8D8),
                    historyActive = Color(0xFF34435A),
                    historyActiveBorder = Color(0xFFA3C3ED),
                    sparkle = Color(0xFFE0B35A),
                    upgradeButton = Color(0xFFD9962F),
                    onUpgradeButton = Color(0xFF241705),
                )

            ThemeValue.BLACK ->
                Colors(
                    scoreHigh = Color(0xFF203A26),
                    onScoreHigh = Color(0xFFA8E2B4),
                    scoreMedium = Color(0xFF3F3212),
                    onScoreMedium = Color(0xFFF2D27E),
                    // DescribePalette.kt: the black card is 0xFF2A2A2A, so these chips sit a few steps lighter to stay visible.
                    scoreLow = Color(0xFF404040),
                    onScoreLow = Color(0xFFC4C4C4),
                    pending = Color(0xFF3A3F48),
                    onPending = Color(0xFFBFC6D2),
                    sourceWeb = Color(0xFF1F2C40),
                    onSourceWeb = Color(0xFFA3C3ED),
                    sourceIndex = Color(0xFF3C2A18),
                    onSourceIndex = Color(0xFFF0B07A),
                    stepDone = Color(0xFF8DBA74),
                    stepCurrent = Color(0xFFA3C3ED),
                    stepPending = Color(0xFF474747),
                    chip = Color(0xFF3C3C3C),
                    onChip = Color(0xFFE0E0E0),
                    historyActive = Color(0xFF26344A),
                    historyActiveBorder = Color(0xFFA3C3ED),
                    sparkle = Color(0xFFE0B35A),
                    upgradeButton = Color(0xFFD9962F),
                    onUpgradeButton = Color(0xFF241705),
                )

            else ->
                Colors(
                    scoreHigh = Color(0xFFDDF3E0),
                    onScoreHigh = Color(0xFF1F7A3A),
                    scoreMedium = Color(0xFFFCEBC8),
                    onScoreMedium = Color(0xFF8A5A00),
                    scoreLow = Color(0xFFECEDEA),
                    onScoreLow = Color(0xFF6B6E66),
                    pending = Color(0xFFEDEFF3),
                    onPending = Color(0xFF6B7280),
                    sourceWeb = Color(0xFFE3EDFB),
                    onSourceWeb = Color(0xFF2F5E9E),
                    sourceIndex = Color(0xFFFFF0DE),
                    onSourceIndex = Color(0xFFA35A12),
                    stepDone = Color(0xFF4C9A5A),
                    stepCurrent = Color(0xFF5574B2),
                    stepPending = Color(0xFFC9CCC6),
                    chip = Color(0xFFF0F1ED),
                    onChip = Color(0xFF5E6267),
                    historyActive = Color(0xFFE9F0FA),
                    historyActiveBorder = Color(0xFF5574B2),
                    sparkle = Color(0xFFD9962F),
                    upgradeButton = Color(0xFF709E5D),
                    onUpgradeButton = Color.White,
                )
        }
}
