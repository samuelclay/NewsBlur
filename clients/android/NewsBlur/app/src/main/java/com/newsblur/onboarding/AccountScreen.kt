package com.newsblur.onboarding

import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.compose.AndroidShaderBackground
import com.newsblur.compose.CustomServerDialog
import com.newsblur.compose.LanguagePicker
import com.newsblur.design.LoginAuthPalette
import com.newsblur.design.LoginAuthPalettes
import com.newsblur.design.toVariant
import com.newsblur.util.LanguageSettings

@Composable
fun AccountScreen(
    model: AccountViewModel,
    onAuthenticated: (Boolean) -> Unit,
    onForgot: () -> Unit,
) {
    val context = LocalContext.current
    val state by model.state.collectAsStateWithLifecycle()
    var email by rememberSaveable { mutableStateOf("") }
    var customServer by rememberSaveable { mutableStateOf(false) }
    val palette = LoginAuthPalettes.of(model.theme().toVariant())
    val gold = palette.link
    val heading = FontFamily(Font(R.font.gotham_narrow_book))
    LaunchedEffect(state.authenticated) { if (state.authenticated) onAuthenticated(state.setup) }
    SocialBrowserEffect(model, state)
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(palette.gradientTop, palette.gradientBottom)))) {
        AndroidShaderBackground(palette)
        BoxWithConstraints(Modifier.fillMaxSize().safeDrawingPadding().imePadding()) {
            val height = maxHeight
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                Column(
                    Modifier
                        .widthIn(max = 520.dp)
                        .fillMaxWidth()
                        .heightIn(min = height)
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
                ) {
                    LanguagePicker(contentColor = palette.link) { language ->
                        LanguageSettings.select(context, language, pending = true)
                    }
                    Image(painterResource(R.drawable.logo), stringResource(R.string.newsblur), Modifier.padding(top = 16.dp).size(120.dp))
                    Text(stringResource(R.string.newsblur), color = Color.White, fontFamily = heading, fontSize = 38.sp)
                    Text(stringResource(R.string.onboarding_a_personal_news_reader_bringing_npeople_together_to_talk_about_th),
                        color = gold,
                        fontSize = 16.sp,
                        lineHeight = 23.sp,
                        fontFamily = FontFamily(Font(R.font.chronicle_ssm_book)),
                        fontStyle = FontStyle.Italic,
                        textAlign = TextAlign.Center,
                    )
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .background(
                                Color.White.copy(alpha = .12f),
                                RoundedCornerShape(20.dp),
                            ).border(.5.dp, Color.White.copy(alpha = .15f), RoundedCornerShape(20.dp))
                            .padding(22.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Text(
                            stringResource(
                                when (state.continuation) {
                                    "link" -> R.string.onboarding_connect_your_account
                                    "username" -> R.string.onboarding_choose_your_username
                                    else -> if (state.signup) R.string.onboarding_create_an_account else R.string.onboarding_welcome_back
                                },
                            ),
                            color = Color.White,
                            fontFamily = heading,
                            fontSize = 24.sp,
                        )
                        if (state.continuation == null) {
                            listOf("apple", "google").forEach { provider ->
                                val providerName = if (provider == "apple") "Apple" else "Google"
                                val signingInDescription = stringResource(R.string.onboarding_signing_in_with_provider, providerName)
                                val signingIn = state.busy && state.activeProvider == provider
                                val providerAlpha = if (state.busy && !signingIn) .38f else 1f
                                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Button(
                                        onClick = {
                                            model.social(provider)
                                        },
                                        enabled = !state.busy,
                                        modifier =
                                            Modifier.fillMaxWidth().height(
                                                50.dp,
                                            ).semantics {
                                                liveRegion = LiveRegionMode.Polite
                                                if (signingIn) stateDescription = signingInDescription
                                            },
                                        colors =
                                            ButtonDefaults.buttonColors(
                                                containerColor = Color.White,
                                                contentColor = Color.Black,
                                                disabledContainerColor = Color.White,
                                                disabledContentColor = Color.Black.copy(alpha = providerAlpha),
                                            ),
                                        shape = RoundedCornerShape(7.dp),
                                    ) {
                                        Image(
                                            painterResource(
                                                if (provider ==
                                                    "apple"
                                                ) {
                                                    R.drawable.apple_signin
                                                } else {
                                                    R.drawable.google_signin
                                                },
                                            ),
                                            null,
                                            Modifier.size(20.dp),
                                            alpha = providerAlpha,
                                        )
                                        Text(
                                            if (signingIn) {
                                                stringResource(R.string.onboarding_signing_in)
                                            } else {
                                                stringResource(R.string.onboarding_sign_in_with_provider, providerName)
                                            },
                                            Modifier.padding(start = 12.dp),
                                            fontSize = 17.sp,
                                            fontWeight = FontWeight.Medium,
                                        )
                                        if (signingIn) {
                                            CircularProgressIndicator(
                                                Modifier.padding(start = 12.dp).size(18.dp),
                                                color = LocalContentColor.current,
                                                strokeWidth = 2.dp,
                                            )
                                        }
                                    }
                                    if (state.activeProvider == provider) {
                                        state.error?.let { AccountError(it, palette) }
                                    }
                                    if (state.lastUsed == provider) LastUsed()
                                }
                            }
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(alpha = .35f))
                                Text(stringResource(R.string.onboarding_or), color = Color.White.copy(alpha = .65f), fontSize = 12.sp)
                                HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(alpha = .35f))
                            }
                        }
                        if (state.signup &&
                            state.continuation == null
                        ) {
                            AccountField(stringResource(R.string.onboarding_email), email, { email = it }, !state.busy, palette, KeyboardType.Email)
                        }
                        if (state.continuation == "link") {
                            Text(stringResource(R.string.onboarding_enter_your_existing_newsblur_username_or_email_and_newsblur_passw),
                                color = palette.fieldText,
                                fontSize = 14.sp,
                            )
                        }
                        AccountField(
                            if (state.continuation == "username" ||
                                (state.signup && state.continuation == null)
                            ) {
                                stringResource(R.string.onboarding_username)
                            } else {
                                stringResource(R.string.onboarding_username_or_email)
                            },
                            state.username,
                            model::updateUsername,
                            !state.busy,
                            palette,
                        )
                        if (state.continuation !=
                            "username"
                        ) {
                            AccountField(
                                stringResource(R.string.onboarding_password),
                                state.password,
                                model::updatePassword,
                                !state.busy,
                                palette,
                                KeyboardType.Password,
                            )
                        }
                        if (state.continuation == null &&
                            state.lastUsed == "email"
                        ) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { LastUsed() }
                        }
                        Button(
                            onClick = { model.submit(state.username.trim(), state.password, email.trim()) },
                            enabled =
                                !state.busy && state.username.isNotBlank() && (state.continuation == "username" || state.password.isNotEmpty()),
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(
                                        min = 50.dp,
                                    ).background(
                                        Brush.verticalGradient(listOf(palette.button, palette.buttonPressed)),
                                        RoundedCornerShape(12.dp),
                                    ),
                            colors =
                                ButtonDefaults.buttonColors(
                                    containerColor = Color.Transparent,
                                    disabledContainerColor = Color.Transparent,
                                    contentColor = Color.White,
                                ),
                            shape = RoundedCornerShape(12.dp),
                        ) {
                            Text(
                                if (state.continuation !=
                                    null
                                ) {
                                    stringResource(R.string.onboarding_continue)
                                } else if (state.signup) {
                                    stringResource(R.string.onboarding_create_account)
                                } else {
                                    stringResource(R.string.onboarding_sign_in)
                                },
                                fontFamily = heading,
                                fontSize = 17.sp,
                            )
                        }
                        if (state.continuation != null || state.activeProvider == null) {
                            state.error?.let { AccountError(it, palette) }
                            if (state.busy) {
                                Row(
                                    Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite },
                                    horizontalArrangement = Arrangement.Center,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    CircularProgressIndicator(Modifier.size(20.dp), color = palette.fieldText, strokeWidth = 2.dp)
                                    Text(stringResource(R.string.onboarding_signing_in), Modifier.padding(start = 10.dp), color = palette.fieldText)
                                }
                            }
                        }
                        if (state.continuation == "username") {
                            TextButton(
                                onClick = model::connectExistingAccount,
                                enabled = !state.busy,
                            ) {
                                Text(stringResource(R.string.onboarding_connect_an_existing_account), color = palette.link)
                            }
                        } else if (state.continuation == "link" && state.canChooseUsername) {
                            TextButton(
                                onClick = model::createNewAccountInstead,
                                enabled = !state.busy,
                            ) {
                                Text(stringResource(R.string.onboarding_create_a_new_account_instead), color = palette.link)
                            }
                        }
                        if (state.continuation !=
                            null
                        ) {
                            TextButton(
                                onClick = model::mode,
                                enabled = !state.busy,
                            ) { Text(stringResource(R.string.onboarding_use_another_sign_in_method), color = gold) }
                        } else if (!state.signup) {
                            TextButton(onClick = onForgot) { Text(stringResource(R.string.onboarding_forgot_your_password), color = gold) }
                        }
                    }
                    if (state.continuation ==
                        null
                    ) {
                        TextButton(onClick = model::mode, enabled = !state.busy) {
                            Text(
                                stringResource(
                                    if (state.signup) {
                                        R.string.onboarding_already_have_an_account_sign_in
                                    } else {
                                        R.string.onboarding_new_to_newsblur_create_an_account
                                    },
                                ),
                                color = gold,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                    TextButton(onClick = {
                        customServer = true
                    }, enabled = !state.busy) {
                        Text(
                            model.customServer().ifBlank { stringResource(R.string.onboarding_use_a_custom_server) },
                            color = Color.White.copy(alpha = .7f),
                            fontSize = 12.sp,
                        )
                    }
                }
            }
        }
    }
    if (customServer) {
        CustomServerDialog(palette, model.customServer(), { customServer = false }) {
            model.server(it)
            customServer = false
        }
    }
}

@Composable private fun AccountError(message: String, palette: LoginAuthPalette) {
    if (message.isNotBlank()) {
        Text(
            message,
            Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite },
            color = palette.error,
            fontSize = 14.sp,
        )
    }
}

@Composable private fun LastUsed() {
    Text(stringResource(R.string.onboarding_last_used),
        Modifier.background(Color.White.copy(alpha = .15f), RoundedCornerShape(20.dp)).padding(horizontal = 8.dp, vertical = 3.dp),
        color = Color.White,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable private fun AccountField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    enabled: Boolean,
    palette: LoginAuthPalette,
    keyboard: KeyboardType = KeyboardType.Text,
) {
    BasicTextField(
        value,
        onChange,
        Modifier.fillMaxWidth().background(palette.fieldBackground, RoundedCornerShape(12.dp)).padding(15.dp)
            .semantics { contentDescription = label },
        enabled = enabled,
        singleLine = true,
        textStyle = TextStyle(color = palette.fieldText, fontSize = 16.sp),
        cursorBrush = SolidColor(palette.fieldCursor),
        keyboardOptions = KeyboardOptions(keyboardType = keyboard, autoCorrectEnabled = false, imeAction = ImeAction.Next),
        visualTransformation =
            if (keyboard ==
                KeyboardType.Password
            ) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
        decorationBox = { inner ->
            if (value.isEmpty()) Text(label, color = palette.fieldPlaceholder, fontSize = 16.sp)
            inner()
        },
    )
}

// AccountScreen.kt shares browser handoff with deletion without rendering a login form underneath it.
@Composable
fun SocialBrowserEffect(
    model: AccountViewModel,
    state: AccountState,
) {
    val context = LocalContext.current
    LaunchedEffect(state.browserUrl) {
        state.browserUrl?.let { url ->
            model.browserOpened()
            try {
                CustomTabsIntent.Builder().build().launchUrl(context, url.toUri())
            } catch (_: android.content.ActivityNotFoundException) {
                model.browserUnavailable()
            }
        }
    }
}
