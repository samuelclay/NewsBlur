package com.newsblur.onboarding

import androidx.compose.ui.graphics.Color
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.PrefConstants.ThemeValue

// SetupPalette.kt centralizes the iOS DiscoverColors.swift mapping, including sepia and Android's black variant.
object SetupPalette {
    fun colors(theme: ThemeValue): ReaderSheetPalette.Colors {
        val base = ReaderSheetPalette.colors(theme)
        return when (theme) {
            ThemeValue.DARK -> base.copy(background = Color(0xFF3D3D3D), inputBackground = Color(0xFF555555))
            ThemeValue.BLACK -> base.copy(background = Color(0xFF1A1A1A), inputBackground = Color(0xFF333333))
            ThemeValue.SEPIA -> base.copy(background = Color(0xFFF3E2CB))
            else -> base.copy(background = Color(0xFFEAECE6), textSecondary = Color(0xFF697168), inputBackground = Color.White)
        }.copy(accent = Color(0xFF42752E))
    }
}
