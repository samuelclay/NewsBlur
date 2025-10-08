package com.newsblur.compose

import android.widget.Toast
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.newsblur.R
import com.newsblur.network.APIConstants
import com.newsblur.preference.PrefsRepo

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
        prefsRepo: PrefsRepo,
        onStartLoginProgress: (username: String, password: String) -> Unit,
        onStartRegisterProgress: (username: String, password: String, email: String) -> Unit,
        onOpenForgotPassword: () -> Unit
) {
    val cs = MaterialTheme.colorScheme
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current

    var mode by remember { mutableStateOf(LoginMode.Login) }

    var loginUsername by rememberSaveable { mutableStateOf("") }
    var loginPassword by rememberSaveable { mutableStateOf("") }

    var regUsername by rememberSaveable { mutableStateOf("") }
    var regPassword by rememberSaveable { mutableStateOf("") }
    var regEmail by rememberSaveable { mutableStateOf("") }

    val initialCustomServer = remember {
        prefsRepo.getCustomSever().orEmpty()
    }
    var customServerEnabled by rememberSaveable { mutableStateOf(initialCustomServer.isNotEmpty()) }
    var customServerValue by rememberSaveable { mutableStateOf(initialCustomServer) }

    fun setMode(to: LoginMode) {
        if (to != mode) {
            focusManager.clearFocus(force = true)
            keyboard?.hide()
            mode = to
        }
    }

    fun applyOrClearCustomServer(): Boolean {
        if (customServerEnabled) {
            val value = customServerValue.trim()
            if (value.isNotEmpty()) {
                if (value.startsWith("https://")) {
                    APIConstants.setCustomServer(value)
                    prefsRepo.saveCustomServer(value)
                } else {
                    Toast
                            .makeText(context, R.string.login_custom_server_scheme_error, Toast.LENGTH_LONG)
                            .show()
                    return false
                }
            }
        } else {
            customServerValue = ""
            APIConstants.unsetCustomServer()
            prefsRepo.clearCustomServer()
        }
        return true
    }

    fun logIn() {
        if (loginUsername.isNotBlank()) {
            if (!applyOrClearCustomServer()) return
            onStartLoginProgress(loginUsername.trim(), loginPassword)
        }
    }

    fun signUp() {
        if (!applyOrClearCustomServer()) return
        onStartRegisterProgress(regUsername.trim(), regPassword, regEmail.trim())
    }

    fun resetCustomServer() {
        customServerEnabled = false
        customServerValue = ""
        APIConstants.unsetCustomServer()
        prefsRepo.clearCustomServer()
    }

    Scaffold(containerColor = cs.background) { padding ->
        Column(
                modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(horizontal = 20.dp)
        ) {
            Image(modifier = Modifier.padding(vertical = 32.dp),
                    painter = painterResource(id = R.drawable.logo_newsblur_blur_dark),
                    contentDescription = stringResource(R.string.newsblur)
            )

            AnimatedContent(
                    targetState = mode,
                    transitionSpec = {
                        fadeIn(tween(180)) togetherWith fadeOut(tween(120))
                    },
                    label = "auth",
                    modifier = Modifier
                            .fillMaxWidth()
                            .animateContentSize(tween(220))
            ) { state ->
                when (state) {
                    LoginMode.Login -> LoginForm(
                            username = loginUsername,
                            onUsername = { loginUsername = it },
                            password = loginPassword,
                            onPassword = { loginPassword = it },
                            onDone = { logIn() }
                    )

                    LoginMode.Register -> RegisterForm(
                            username = regUsername, onUsername = { regUsername = it },
                            password = regPassword, onPassword = { regPassword = it },
                            email = regEmail, onEmail = { regEmail = it },
                            onDone = { signUp() }
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.End,
            ) {
                if (mode == LoginMode.Register) {
                    Button(
                            onClick = { signUp() },
                            modifier = Modifier.widthIn(min = 120.dp)
                    ) { Text(stringResource(id = R.string.login_registration_register)) }

                    Spacer(Modifier.height(20.dp))

                    TextButton(onClick = { setMode(LoginMode.Login) }) {
                        Text(stringResource(id = R.string.need_to_login))
                    }
                } else {
                    Button(
                            onClick = { logIn() },
                            modifier = Modifier.wrapContentWidth()
                    ) { Text(stringResource(id = R.string.login_button_login)) }

                    Spacer(Modifier.height(20.dp))

                    TextButton(onClick = { setMode(LoginMode.Register) }) {
                        Text(stringResource(id = R.string.login_registration_register))
                    }

                    TextButton(onClick = onOpenForgotPassword) {
                        Text(stringResource(id = R.string.login_forgot_password))
                    }
                }
            }

            if (!customServerEnabled) {
                TextButton(
                        modifier = Modifier.align(Alignment.End),
                        onClick = { customServerEnabled = !customServerEnabled },
                ) {
                    Text(stringResource(id = R.string.login_custom_server))
                }
            }

            Spacer(Modifier.height(24.dp))

            AnimatedVisibility(visible = customServerEnabled) {
                Column {
                    Text(
                            text = stringResource(id = R.string.login_registration_custom_server),
                            style = MaterialTheme.typography.titleMedium
                    )
                    Spacer(Modifier.height(4.dp))
                    OutlinedTextField(
                            modifier = Modifier
                                    .fillMaxWidth()
                                    .height(56.dp),
                            value = customServerValue,
                            onValueChange = { customServerValue = it },
                            label = { Text(stringResource(id = R.string.login_custom_server_hint)) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(
                                    keyboardType = KeyboardType.Uri,
                                    imeAction = ImeAction.Done
                            ),
                            keyboardActions = KeyboardActions(
                                    onDone = {
                                        defaultKeyboardAction(ImeAction.Done)
                                    }
                            ),
                    )
                    Spacer(Modifier.height(6.dp))
                    TextButton(
                            onClick = { resetCustomServer() },
                            modifier = Modifier.align(Alignment.End)
                    ) {
                        Text(stringResource(id = R.string.login_registration_reset_url))
                    }
                }
            }
        }
    }
}

private enum class LoginMode { Login, Register }

@Composable
private fun LoginForm(
        username: String,
        onUsername: (String) -> Unit,
        password: String,
        onPassword: (String) -> Unit,
        onDone: () -> Unit
) {
    Column {
        OutlinedTextField(
                modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                value = username,
                onValueChange = onUsername,
                label = { Text(stringResource(id = R.string.login_username_hint)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Next
                ),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
                modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                value = password,
                onValueChange = onPassword,
                label = { Text(stringResource(id = R.string.login_password_hint)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done
                ),
                keyboardActions = KeyboardActions(onDone = { onDone() })
        )
    }
}

@Composable
private fun RegisterForm(
        username: String,
        onUsername: (String) -> Unit,
        password: String,
        onPassword: (String) -> Unit,
        email: String,
        onEmail: (String) -> Unit,
        onDone: () -> Unit
) {
    Column {
        OutlinedTextField(
                modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                value = username,
                onValueChange = onUsername,
                label = { Text(stringResource(id = R.string.login_username_hint)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Next
                ),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
                modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                value = password,
                onValueChange = onPassword,
                label = { Text(stringResource(id = R.string.login_password_hint)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Next
                ),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
                modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                value = email,
                onValueChange = onEmail,
                label = { Text(stringResource(id = R.string.login_registration_email_hint)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Done
                ),
                keyboardActions = KeyboardActions(onDone = { onDone() }),
        )
    }
}
