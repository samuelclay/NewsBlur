package com.newsblur.design

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextDirection

val NbTypography = Typography()

/**
 * Type.kt lays out text people wrote (feed titles, story titles, excerpts, links) by its own first
 * strong character, so an English title reads left to right inside an Arabic interface. Compose
 * otherwise lays every string out in the interface direction, which suits translated labels.
 */
fun TextStyle.withContentDirection(): TextStyle = copy(textDirection = TextDirection.Content)
