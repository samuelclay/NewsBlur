package com.newsblur.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.newsblur.util.PrefConstants.ThemeValue

enum class NbThemeVariant { Light, Dark, Black, System }

@Composable
fun NewsBlurTheme(
        variant: NbThemeVariant,
        dynamic: Boolean = true, // Android 12+
        content: @Composable () -> Unit
) {
    val context = LocalContext.current
    val dark = when (variant) {
        NbThemeVariant.Light -> false
        NbThemeVariant.Dark, NbThemeVariant.Black -> true
        NbThemeVariant.System -> isSystemInDarkTheme()
    }

    val scheme =
            if (dynamic && android.os.Build.VERSION.SDK_INT >= 31) {
                if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
            } else {
                when (variant) {
                    NbThemeVariant.Light -> LightColors
                    NbThemeVariant.Dark -> DarkColors
                    NbThemeVariant.Black -> BlackColors
                    NbThemeVariant.System -> if (dark) DarkColors else LightColors
                }
            }

    MaterialTheme(
            colorScheme = scheme,
            typography = NbTypography,
            content = content
    )
}

fun ThemeValue.toVariant(): NbThemeVariant = when (this) {
    ThemeValue.LIGHT -> NbThemeVariant.Light
    ThemeValue.DARK -> NbThemeVariant.Dark
    ThemeValue.BLACK -> NbThemeVariant.Black
    ThemeValue.AUTO -> NbThemeVariant.System
}