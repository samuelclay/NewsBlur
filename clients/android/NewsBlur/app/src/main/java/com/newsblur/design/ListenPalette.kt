package com.newsblur.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.newsblur.util.PrefConstants.ThemeValue

/**
 * ListenPalette.kt holds every Listen color (mini player, Now Playing, voice settings, the story button pill and
 * the follow-along highlight) per theme, so a new theme like Sapia only needs one more branch here.
 */
object ListenPalette {
    data class Colors(
        val sheetBackground: Color,
        val cardBackground: Color,
        val border: Color,
        val textPrimary: Color,
        val textSecondary: Color,
        val barBackground: Color,
        val barBorder: Color,
        val accent: Color,
        val onAccent: Color,
        val progressTrack: Color,
        val previewBackground: Color,
        val previewText: Color,
        val highlightBackground: Color,
        val error: Color,
        val upgradeBackground: Color,
        val onUpgrade: Color,
        val chipSelected: Color,
        val onChipSelected: Color,
        val chipBackground: Color,
        val inputBackground: Color,
    )

    fun colors(theme: ThemeValue): Colors {
        val sheet = ReaderSheetPalette.colors(theme)
        return when (theme) {
            ThemeValue.SEPIA ->
                Colors(
                    sheetBackground = sheet.background,
                    cardBackground = sheet.cardBackground,
                    border = sheet.border,
                    textPrimary = Color(0xFF3C3226),
                    textSecondary = Color(0xFF8B7B6B),
                    barBackground = Color(0xFFFAF5ED),
                    barBorder = Color(0xFFD4C8B8),
                    accent = Color(0xFF6E8F4E),
                    onAccent = Color.White,
                    progressTrack = Color(0xFFE6DACA),
                    previewBackground = Color(0xFFF2E0C0),
                    previewText = Color(0xFF7A4E14),
                    highlightBackground = Color(0xFFF1E2BE),
                    error = Color(ReaderSheetPalette.destructiveArgb(theme)),
                    upgradeBackground = Color(0xFFC98A2E),
                    onUpgrade = Color.White,
                    chipSelected = Color(0xFF6E8F4E),
                    onChipSelected = Color.White,
                    chipBackground = Color(0xFFEFE5D6),
                    inputBackground = sheet.inputBackground,
                )

            ThemeValue.DARK ->
                Colors(
                    sheetBackground = sheet.background,
                    cardBackground = sheet.cardBackground,
                    border = sheet.border,
                    textPrimary = Color(0xFFEDEDED),
                    textSecondary = Color(0xFFA8A8A8),
                    barBackground = Color(0xFF3A3A3A),
                    barBorder = Color(0xFF575757),
                    accent = Color(0xFF8DBA74),
                    onAccent = Color(0xFF1C2416),
                    progressTrack = Color(0xFF575757),
                    previewBackground = Color(0xFF5A4A2A),
                    previewText = Color(0xFFF2D49B),
                    highlightBackground = Color(0xFF5B5536),
                    error = Color(ReaderSheetPalette.destructiveArgb(theme)),
                    upgradeBackground = Color(0xFFD9962F),
                    onUpgrade = Color(0xFF241705),
                    chipSelected = Color(0xFF8DBA74),
                    onChipSelected = Color(0xFF1C2416),
                    chipBackground = Color(0xFF555555),
                    inputBackground = sheet.inputBackground,
                )

            ThemeValue.BLACK ->
                Colors(
                    sheetBackground = sheet.background,
                    cardBackground = sheet.cardBackground,
                    border = sheet.border,
                    textPrimary = Color(0xFFEEEEEE),
                    textSecondary = Color(0xFF9E9E9E),
                    barBackground = Color(0xFF171717),
                    barBorder = Color(0xFF333333),
                    accent = Color(0xFF7FB062),
                    onAccent = Color(0xFF0E1509),
                    // Black's track has to show on the #2A2A2A cards as well as the black sheet.
                    progressTrack = Color(0xFF484848),
                    previewBackground = Color(0xFF3A2F17),
                    previewText = Color(0xFFE8C77F),
                    highlightBackground = Color(0xFF2B2715),
                    error = Color(ReaderSheetPalette.destructiveArgb(theme)),
                    upgradeBackground = Color(0xFFC98A2E),
                    onUpgrade = Color(0xFF1A1004),
                    chipSelected = Color(0xFF7FB062),
                    onChipSelected = Color(0xFF0E1509),
                    chipBackground = Color(0xFF3A3A3A),
                    inputBackground = sheet.inputBackground,
                )

            else ->
                Colors(
                    sheetBackground = sheet.background,
                    cardBackground = sheet.cardBackground,
                    border = sheet.border,
                    textPrimary = Color(0xFF2F3134),
                    textSecondary = Color(0xFF7A7D78),
                    barBackground = Color.White,
                    barBorder = Color(0xFFD0D2CC),
                    accent = Color(0xFF709E5D),
                    onAccent = Color.White,
                    progressTrack = Color(0xFFE3E5DF),
                    previewBackground = Color(0xFFFFF0D6),
                    previewText = Color(0xFF94570A),
                    highlightBackground = Color(0xFFFFF4C7),
                    error = Color(ReaderSheetPalette.destructiveArgb(theme)),
                    upgradeBackground = Color(0xFFD98E2A),
                    onUpgrade = Color.White,
                    chipSelected = Color(0xFF709E5D),
                    onChipSelected = Color.White,
                    chipBackground = Color(0xFFEDEFEA),
                    inputBackground = sheet.inputBackground,
                )
        }
    }

    @JvmStatic fun highlightArgb(theme: ThemeValue): Int =
        colors(
            theme,
        ).highlightBackground.toArgb()

    @JvmStatic fun previewBackgroundArgb(theme: ThemeValue): Int =
        colors(
            theme,
        ).previewBackground.toArgb()

    @JvmStatic fun previewTextArgb(theme: ThemeValue): Int = colors(theme).previewText.toArgb()

    @JvmStatic fun accentArgb(theme: ThemeValue): Int = colors(theme).accent.toArgb()

    /**
     * The follow-along style for the story WebView. The dark and black reading CSS force a background on every
     * span and paragraph, so the highlight is opaque and repeated on descendants to stay one even color.
     */
    @JvmStatic
    fun highlightCss(theme: ThemeValue): String {
        val color = cssColor(colors(theme).highlightBackground)
        return ".NB-story .NB-listen-highlight{background-color:$color !important;border-radius:4px;" +
            "box-shadow:0 0 0 6px $color;transition:background-color .3s ease,box-shadow .3s ease;}" +
            ".NB-story .NB-listen-highlight *{background-color:$color !important;}"
    }

    private fun cssColor(color: Color): String {
        val argb = color.toArgb()
        return String.format("#%06X", argb and 0xFFFFFF)
    }
}
