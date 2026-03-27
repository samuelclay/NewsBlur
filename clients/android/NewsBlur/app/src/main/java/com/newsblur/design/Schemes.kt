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

val SepiaColors: ColorScheme =
    lightColorScheme(
        primary = NbSepiaBar,
        onPrimary = NbSepiaText,
        secondary = NbSepiaLink,
        onSecondary = White,
        background = NbSepiaBar,
        onBackground = NbSepiaText,
        surface = NbSepiaSurface,
        onSurface = NbSepiaText,
        outline = NbSepiaBorder,
    )

val DarkColors: ColorScheme =
    darkColorScheme(
        primary = Gray20, // @color/primary.dark #333333
        onPrimary = Gray85,
        secondary = NewsblurBlue,
        onSecondary = Black,
        background = Gray20, // #333333
        onBackground = Gray85,
        surface = Gray30, // #4D4D4D
        onSurface = Gray85,
        outline = Gray20, // #333333
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
