package com.newsblur.compose

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.newsblur.R
import com.newsblur.design.LocalNbColors
import com.newsblur.util.LanguageSettings

/** LanguagePicker.kt colors its menu from LocalNbColors, so light, sepia, dark and black each get their own surface. */
@Composable
fun LanguagePicker(
    contentColor: Color,
    onSelected: (String) -> Unit,
) {
    val context = LocalContext.current
    val colors = LocalNbColors.current
    var expanded by remember { mutableStateOf(false) }
    val automatic = remember(context) { LanguageSettings.automaticLabel(context) }
    val current = LanguageSettings.selected(context)
    Box {
        TextButton(
            onClick = { expanded = true },
            colors = ButtonDefaults.textButtonColors(contentColor = contentColor),
        ) {
            Text(stringResource(R.string.language_current, LanguageSettings.names[current] ?: automatic))
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            containerColor = colors.barBackground,
        ) {
            LanguageSettings.options(automatic).forEach { (code, name) ->
                DropdownMenuItem(text = { Text(name, color = colors.textDefault) }, onClick = {
                    expanded = false
                    onSelected(code)
                })
            }
        }
    }
}
