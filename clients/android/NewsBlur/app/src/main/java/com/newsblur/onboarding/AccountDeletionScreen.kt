package com.newsblur.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.PrefConstants.ThemeValue

@Composable
fun AccountDeletionScreen(
    state: AccountState,
    model: AccountViewModel,
    theme: ThemeValue,
    onClose: () -> Unit,
    onDeleted: () -> Unit,
) {
    var confirmation by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val colors = ReaderSheetPalette.colors(theme)
    val links = LocalUriHandler.current
    Box(Modifier.fillMaxSize().background(colors.background).safeDrawingPadding(), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .widthIn(max = 600.dp)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Delete account", Modifier.weight(1f), color = colors.textPrimary, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                TextButton(onClick = if (state.deleted) onDeleted else onClose) { Text("Done", color = colors.siteLink) }
            }
            Icon(Icons.Outlined.DeleteOutline, null, Modifier.size(42.dp), tint = colors.textSecondary)
            if (state.deleted) {
                Text("Your account has been deleted.", color = colors.textPrimary, fontSize = 20.sp)
                if (state.revocationRequired) {
                    Text(
                        "Disconnect NewsBlur from Sign in with Apple in your Apple Account settings to finish removing its authorization.",
                        color = colors.textSecondary,
                    )
                    TextButton(onClick = {
                        links.openUri("https://support.apple.com/en-us/102571")
                    }) { Text("Apple Account settings", color = colors.siteLink) }
                }
                Button(onClick = onDeleted) { Text("Done") }
            } else {
                Text(
                    "Deleting your account permanently removes your feeds, saved stories, and account data. This cannot be undone.",
                    color = colors.textSecondary,
                )
                if (state.accountLoaded && (state.verified || state.providers.isEmpty())) {
                    if (state.providers.isEmpty()) {
                        OutlinedTextField(
                            password,
                            {
                                password = it
                            },
                            label = {
                                Text("Confirm your password")
                            },
                            visualTransformation = PasswordVisualTransformation(),
                            singleLine = true,
                            keyboardOptions =
                                KeyboardOptions(
                                    keyboardType = KeyboardType.Password,
                                ),
                            enabled = !state.busy,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    Text("Type Delete to permanently delete your account.", color = colors.textPrimary)
                    OutlinedTextField(confirmation, {
                        confirmation = it
                    }, label = { Text("Delete") }, singleLine = true, enabled = !state.busy, modifier = Modifier.fillMaxWidth())
                    Button(
                        onClick = { model.deleteAccount(confirmation, password) },
                        enabled =
                            !state.busy && confirmation == "Delete" && (state.verified || password.isNotEmpty()),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB74444)),
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Permanently delete account") }
                } else if (state.accountLoaded) {
                    state.providers.forEach { provider ->
                        OutlinedButton(onClick = {
                            model.social(provider)
                        }, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) {
                            Text("Verify with ${if (provider == "apple") "Apple" else "Google"}", color = colors.textPrimary)
                        }
                    }
                }
                if (state.busy) CircularProgressIndicator(color = colors.textSecondary)
                state.error?.let {
                    Text(it, color = colors.textPrimary)
                    if (!state.accountLoaded) TextButton(onClick = model::loadAccount) { Text("Try again") }
                }
            }
        }
    }
}
