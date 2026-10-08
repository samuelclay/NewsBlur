package com.newsblur.compose

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.newsblur.R
import com.newsblur.util.LanguageSettings

/** Uses the active NewsBlurTheme, including light, dark and black. */
@Composable
fun LanguagePicker(onSelected: (String) -> Unit) {
    val context = LocalContext.current
    var expanded by remember { mutableStateOf(false) }
    val automatic = stringResource(R.string.language_automatic)
    val current = LanguageSettings.selected(context)
    Box {
        TextButton(
            onClick = { expanded = true },
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.onSurface),
        ) {
            Text(stringResource(R.string.language_current, LanguageSettings.names[current] ?: automatic))
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            (linkedMapOf("auto" to automatic) + LanguageSettings.names).forEach { (code, name) ->
                DropdownMenuItem(text = { Text(name) }, onClick = {
                    expanded = false
                    onSelected(code)
                })
            }
        }
    }
}
