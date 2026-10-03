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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
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
import com.newsblur.design.LoginAuthPalettes
import com.newsblur.design.NbThemeVariant

@Composable
fun AccountScreen(
    model: AccountViewModel,
    onAuthenticated: (Boolean) -> Unit,
    onForgot: () -> Unit,
) {
    val state by model.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var username by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    // AccountScreen.kt deliberately keeps passwords out of saved instance state.
    var password by remember { mutableStateOf("") }
    var customServer by rememberSaveable { mutableStateOf(false) }
    val gold = Color(0xFFFBDB9B)
    val palette = LoginAuthPalettes.of(NbThemeVariant.Light)
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
                    Image(painterResource(R.drawable.logo), "NewsBlur", Modifier.padding(top = 16.dp).size(120.dp))
                    Text("NewsBlur", color = Color.White, fontFamily = heading, fontSize = 38.sp)
                    Text(
                        "A personal news reader bringing\npeople together to talk about the world.",
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
                            when (state.continuation) {
                                "link" -> "Connect your account"
                                "username" -> "Choose your username"
                                else -> if (state.signup) "Create an account" else "Welcome back"
                            },
                            color = Color.White,
                            fontFamily = heading,
                            fontSize = 24.sp,
                        )
                        if (state.continuation == null) {
                            listOf("apple", "google").forEach { provider ->
                                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Button(
                                        onClick = {
                                            model.social(provider)
                                        },
                                        enabled = !state.busy,
                                        modifier =
                                            Modifier.fillMaxWidth().height(
                                                50.dp,
                                            ),
                                        colors =
                                            ButtonDefaults.buttonColors(
                                                containerColor = Color.White,
                                                contentColor = Color.Black,
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
                                        )
                                        Text(
                                            "Sign in with ${if (provider == "apple") "Apple" else "Google"}",
                                            Modifier.padding(start = 12.dp),
                                            fontSize = 17.sp,
                                            fontWeight = FontWeight.Medium,
                                        )
                                    }
                                    if (state.lastUsed == provider) LastUsed()
                                }
                            }
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(alpha = .35f))
                                Text("or", color = Color.White.copy(alpha = .65f), fontSize = 12.sp)
                                HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(alpha = .35f))
                            }
                        }
                        if (state.signup &&
                            state.continuation == null
                        ) {
                            AccountField("Email", email, { email = it }, !state.busy, KeyboardType.Email)
                        }
                        AccountField(
                            if (state.signup ||
                                state.continuation == "username"
                            ) {
                                "Username"
                            } else {
                                "Username or email"
                            },
                            username,
                            { username = it },
                            !state.busy,
                        )
                        if (state.continuation !=
                            "username"
                        ) {
                            AccountField("Password", password, { password = it }, !state.busy, KeyboardType.Password)
                        }
                        if (state.continuation == null &&
                            state.lastUsed == "email"
                        ) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { LastUsed() }
                        }
                        state.error?.let { Text(it, color = Color(0xFFFFD699), fontSize = 14.sp) }
                        Button(
                            onClick = { model.submit(username.trim(), password, email.trim()) },
                            enabled =
                                !state.busy && username.isNotBlank() && (state.continuation == "username" || password.isNotEmpty()),
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(
                                        min = 50.dp,
                                    ).background(
                                        Brush.verticalGradient(listOf(Color(0xFFD9A621), Color(0xFFB8890B))),
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
                                    "Continue"
                                } else if (state.signup) {
                                    "Create account"
                                } else {
                                    "Sign in"
                                },
                                fontFamily = heading,
                                fontSize = 17.sp,
                            )
                        }
                        if (state.busy) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
                                Text("Signing in…", Modifier.padding(start = 10.dp), color = Color.White)
                            }
                        }
                        if (state.continuation !=
                            null
                        ) {
                            TextButton(
                                onClick = model::mode,
                                enabled = !state.busy,
                            ) { Text("Use another sign-in method", color = gold) }
                        } else if (!state.signup) {
                            TextButton(onClick = onForgot) { Text("Forgot your password?", color = gold) }
                        }
                    }
                    if (state.continuation ==
                        null
                    ) {
                        TextButton(onClick = model::mode, enabled = !state.busy) {
                            Text(
                                if (state.signup) "Already have an account? Sign in" else "New to NewsBlur? Create an account",
                                color = gold,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                    TextButton(onClick = {
                        customServer = true
                    }, enabled = !state.busy) {
                        Text(
                            if (model.customServer().isBlank()) "Use a custom server" else model.customServer(),
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

@Composable private fun LastUsed() {
    Text(
        "Last used",
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
    keyboard: KeyboardType = KeyboardType.Text,
) {
    BasicTextField(
        value,
        onChange,
        Modifier.fillMaxWidth().background(Color.White.copy(alpha = .12f), RoundedCornerShape(12.dp)).padding(15.dp)
            .semantics { contentDescription = label },
        enabled = enabled,
        singleLine = true,
        textStyle = TextStyle(color = Color.White, fontSize = 16.sp),
        cursorBrush = SolidColor(Color(0xFFFBDB9B)),
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
            if (value.isEmpty()) Text(label, color = Color.White.copy(alpha = .65f), fontSize = 16.sp)
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
