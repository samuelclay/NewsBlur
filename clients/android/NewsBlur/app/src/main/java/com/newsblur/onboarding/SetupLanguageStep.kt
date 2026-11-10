package com.newsblur.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.newsblur.compose.LanguageChooser
import com.newsblur.compose.LanguageChooserGate
import com.newsblur.compose.LanguageChooserPalette
import com.newsblur.util.PrefConstants.ThemeValue

/** SetupLanguageStep.kt is setup's first page: LanguageChooser.kt on a card, where every choice moves on. */
@Composable
fun SetupLanguageStep(
    model: SetupViewModel,
    theme: ThemeValue,
) {
    val context = LocalContext.current
    val detected = remember(context) { LanguageChooserGate.detected(context) }
    val colors = LanguageChooserPalette.setup(theme)
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Box(Modifier.widthIn(max = 720.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(colors.surface)) {
            LanguageChooser(detected, colors, onKeep = model::keepLanguage, onChoose = model::chooseLanguage, scrolls = false)
        }
    }
}
