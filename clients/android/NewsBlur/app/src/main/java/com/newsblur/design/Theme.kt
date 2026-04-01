package com.newsblur.design

import android.content.Context
import android.content.res.Configuration
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue

enum class NbThemeVariant { Light, Sepia, Dark, Black, System }

@Composable
fun NewsBlurTheme(
    variant: NbThemeVariant,
    dynamic: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    // Resolve System variant to the user's preferred light/dark variant
    val resolved = if (variant == NbThemeVariant.System) {
        resolveSystemVariant(context)
    } else {
        variant
    }
    val dark = resolved == NbThemeVariant.Dark || resolved == NbThemeVariant.Black

    val scheme =
        if (dynamic && android.os.Build.VERSION.SDK_INT >= 31 && resolved != NbThemeVariant.Sepia) {
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        } else {
            when (resolved) {
                NbThemeVariant.Sepia -> SepiaColors
                NbThemeVariant.Dark -> DarkColors
                NbThemeVariant.Black -> BlackColors
                else -> LightColors
            }
        }

    ProvideNbExtendedColors(resolved) {
        MaterialTheme(
            colorScheme = scheme,
            typography = NbTypography,
            content = content,
        )
    }
}

private fun resolveSystemVariant(context: Context): NbThemeVariant {
    val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
    val nightFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return if (nightFlags == Configuration.UI_MODE_NIGHT_YES) {
        when (prefs.getString(PrefConstants.THEME_DARK_VARIANT, ThemeValue.DARK.name)) {
            ThemeValue.BLACK.name -> NbThemeVariant.Black
            else -> NbThemeVariant.Dark
        }
    } else {
        when (prefs.getString(PrefConstants.THEME_LIGHT_VARIANT, ThemeValue.LIGHT.name)) {
            ThemeValue.SEPIA.name -> NbThemeVariant.Sepia
            else -> NbThemeVariant.Light
        }
    }
}

fun ThemeValue.toVariant(): NbThemeVariant =
    when (this) {
        ThemeValue.LIGHT -> NbThemeVariant.Light
        ThemeValue.SEPIA -> NbThemeVariant.Sepia
        ThemeValue.DARK -> NbThemeVariant.Dark
        ThemeValue.BLACK -> NbThemeVariant.Black
        ThemeValue.AUTO -> NbThemeVariant.System
    }
