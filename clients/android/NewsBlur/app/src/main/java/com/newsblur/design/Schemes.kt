package com.newsblur.design

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme

val LightColors: ColorScheme =
    lightColorScheme(
        primary = NbGreenGray91,
        onPrimary = Gray20,
        secondary = NewsblurBlue,
        onSecondary = White,
        background = Gray96,
        onBackground = Gray20,
        surface = White,
        onSurface = Gray20,
        outline = Gray90,
    )

val DarkColors: ColorScheme =
    darkColorScheme(
        primary = Gray13, // @color/primary.dark
        onPrimary = Gray85,
        secondary = NewsblurBlue,
        onSecondary = Black,
        background = Gray07,
        onBackground = Gray85,
        surface = Gray10,
        onSurface = Gray85,
        outline = Gray10,
    )

// AMOLED “Black”
val BlackColors: ColorScheme =
    darkColorScheme(
        primary = Black, // @color/primary.black
        onPrimary = Gray85,
        secondary = NewsblurBlue,
        onSecondary = Black,
        background = Black,
        onBackground = Gray85,
        surface = Gray07,
        onSurface = Gray85,
        outline = Gray10,
    )
