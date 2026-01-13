package com.newsblur.compose

import android.graphics.Bitmap
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.design.LocalNbColors
import com.newsblur.viewModel.LoginRegisterViewModel
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.Error
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SignIn
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SignUp
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SignedIn
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SignedUp
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SigningIn
import com.newsblur.viewModel.LoginRegisterViewModel.UiState.SigningUp
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    viewModel: LoginRegisterViewModel = hiltViewModel(),
    onAuthCompleted: () -> Unit,
    onOpenForgotPassword: () -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current

    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    var username by rememberSaveable { mutableStateOf("") }
    var loginPassword by rememberSaveable { mutableStateOf("") }

    var regPassword by rememberSaveable { mutableStateOf("") }
    var regEmail by rememberSaveable { mutableStateOf("") }

    val initialCustomServer =
        remember {
            viewModel.getCustomServer().orEmpty()
        }
    var customServerEnabled by rememberSaveable { mutableStateOf(initialCustomServer.isNotEmpty()) }
    var customServerValue by rememberSaveable { mutableStateOf(initialCustomServer) }

    LaunchedEffect(uiState) {
        when (val s = uiState) {
            is Error -> {
                val msg = s.message ?: context.getString(R.string.login_message_error)
                Toast
                    .makeText(context, msg, Toast.LENGTH_LONG)
                    .show()
                viewModel.backTo(s.backTo)
            }

            is SignedIn -> {
                delay(1_000)
                onAuthCompleted()
            }

            is SignedUp -> onAuthCompleted

            else -> Unit
        }
    }

    LaunchedEffect(uiState::class) {
        if (uiState is SignIn || uiState is SignUp) {
            focusManager.clearFocus(force = true)
            keyboard?.hide()
        }
    }

    fun applyOrClearCustomServer(): Boolean {
        if (customServerEnabled) {
            val value = customServerValue.trim()
            if (value.isNotEmpty()) {
                if (value.startsWith("https://")) {
                    viewModel.saveCustomServer(value)
                } else {
                    Toast
                        .makeText(context, R.string.login_custom_server_scheme_error, Toast.LENGTH_LONG)
                        .show()
                    return false
                }
            }
        } else {
            customServerValue = ""
            viewModel.clearCustomServer()
        }
        return true
    }

    fun logIn() {
        if (username.isNotBlank() && applyOrClearCustomServer()) {
            viewModel.signIn(username.trim(), loginPassword)
        }
    }

    fun signUp() {
        if (applyOrClearCustomServer()) {
            viewModel.signUp(username.trim(), regPassword, regEmail.trim())
        }
    }

    fun resetCustomServer() {
        customServerEnabled = false
        customServerValue = ""
        viewModel.clearCustomServer()
    }

    Scaffold(
        containerColor = cs.background,
    ) { padding ->
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 20.dp),
        ) {
            Image(
                modifier = Modifier.padding(vertical = 32.dp),
                painter = painterResource(id = R.drawable.logo_newsblur_blur_dark),
                contentDescription = stringResource(R.string.newsblur),
            )
            when (val s = uiState) {
                SignIn -> {
                    Column {
                        SignInForm(
                            username = username,
                            onUsername = { username = it },
                            password = loginPassword,
                            onPassword = { loginPassword = it },
                            onDone = ::logIn,
                        )

                        SignInActions(
                            onSignIn = ::logIn,
                            onSwitchToSignUp = { viewModel.showSignUp() },
                            onForgotPassword = onOpenForgotPassword,
                        )

                        CustomServerSection(
                            enabled = customServerEnabled,
                            onEnabledChange = { customServerEnabled = it },
                            value = customServerValue,
                            onValueChange = { customServerValue = it },
                            onReset = ::resetCustomServer,
                        )
                    }
                }

                SignUp -> {
                    Column {
                        SignUpForm(
                            username = username,
                            onUsername = { username = it },
                            password = regPassword,
                            onPassword = { regPassword = it },
                            email = regEmail,
                            onEmail = { regEmail = it },
                            onDone = ::signUp,
                        )

                        SignUpActions(
                            onSignUp = ::signUp,
                            onSwitchToSignIn = { viewModel.showSignIn() },
                        )

                        CustomServerSection(
                            enabled = customServerEnabled,
                            onEnabledChange = { customServerEnabled = it },
                            value = customServerValue,
                            onValueChange = { customServerValue = it },
                            onReset = ::resetCustomServer,
                        )
                    }
                }

                is SignedIn -> SignedInUi(userImage = s.userImage)
                SigningIn -> AuthInProgress(text = stringResource(R.string.login_logging_in))
                SigningUp -> AuthInProgress(text = stringResource(R.string.registering))
                else -> Unit
            }
        }
    }
}

@Composable
private fun SignInForm(
    username: String,
    onUsername: (String) -> Unit,
    password: String,
    onPassword: (String) -> Unit,
    onDone: () -> Unit,
) {
    Column {
        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = username,
            onValueChange = onUsername,
            label = { Text(stringResource(id = R.string.login_username_hint)) },
            singleLine = true,
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next,
                ),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = password,
            onValueChange = onPassword,
            label = { Text(stringResource(id = R.string.login_password_hint)) },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
            keyboardActions = KeyboardActions(onDone = { onDone() }),
        )
    }
}

@Composable
private fun SignUpForm(
    username: String,
    onUsername: (String) -> Unit,
    password: String,
    onPassword: (String) -> Unit,
    email: String,
    onEmail: (String) -> Unit,
    onDone: () -> Unit,
) {
    Column {
        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = username,
            onValueChange = onUsername,
            label = { Text(stringResource(id = R.string.login_username_hint)) },
            singleLine = true,
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next,
                ),
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = password,
            onValueChange = onPassword,
            label = { Text(stringResource(id = R.string.login_password_hint)) },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Next,
                ),
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = email,
            onValueChange = onEmail,
            label = { Text(stringResource(id = R.string.login_registration_email_hint)) },
            singleLine = true,
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Done,
                ),
            keyboardActions = KeyboardActions(onDone = { onDone() }),
        )
    }
}

@Composable
private fun SignInActions(
    onSignIn: () -> Unit,
    onSwitchToSignUp: () -> Unit,
    onForgotPassword: () -> Unit,
) {
    Spacer(Modifier.height(20.dp))
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.End) {
        Button(onClick = onSignIn) {
            Text(stringResource(R.string.login_button_login))
        }
        Spacer(Modifier.height(20.dp))
        TextButton(onClick = onSwitchToSignUp) {
            Text(stringResource(R.string.login_registration_register))
        }
        TextButton(onClick = onForgotPassword) {
            Text(stringResource(R.string.login_forgot_password))
        }
    }
}

@Composable
private fun SignUpActions(
    onSignUp: () -> Unit,
    onSwitchToSignIn: () -> Unit,
) {
    Spacer(Modifier.height(20.dp))
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.End) {
        Button(onClick = onSignUp, modifier = Modifier.widthIn(min = 120.dp)) {
            Text(stringResource(R.string.login_registration_register))
        }
        Spacer(Modifier.height(20.dp))
        TextButton(onClick = onSwitchToSignIn) {
            Text(stringResource(R.string.need_to_login))
        }
    }
}

@Composable
private fun CustomServerSection(
    modifier: Modifier = Modifier,
    enabled: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    value: String,
    onValueChange: (String) -> Unit,
    onReset: () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        if (!enabled) {
            TextButton(
                onClick = { onEnabledChange(true) },
                modifier = Modifier.align(Alignment.End),
            ) {
                Text(stringResource(R.string.login_custom_server))
            }
            return@Column
        }

        Spacer(Modifier.height(20.dp))

        Text(
            text = stringResource(R.string.login_registration_custom_server),
            style = MaterialTheme.typography.titleMedium,
            color = LocalNbColors.current.textDefault,
        )
        Spacer(Modifier.height(4.dp))

        OutlinedTextField(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(62.dp),
            value = value,
            onValueChange = onValueChange,
            label = { Text(stringResource(R.string.login_custom_server_hint)) },
            singleLine = true,
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Uri,
                    imeAction = ImeAction.Done,
                ),
            keyboardActions = KeyboardActions(onDone = { defaultKeyboardAction(ImeAction.Done) }),
        )

        Spacer(Modifier.height(6.dp))
        TextButton(
            onClick = onReset,
            modifier = Modifier.align(Alignment.End),
        ) {
            Text(stringResource(R.string.login_registration_reset_url))
        }
    }
}

@Composable
private fun AuthInProgress(text: String) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.width(16.dp))
        Text(
            color = LocalNbColors.current.textDefault,
            style = MaterialTheme.typography.titleMedium,
            text = text,
        )
    }
}

@Composable
private fun SignedInUi(userImage: Bitmap?) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val avatar = userImage?.asImageBitmap()
        if (avatar != null) {
            Image(
                bitmap = avatar,
                contentDescription = stringResource(R.string.user_profile_picture),
                modifier = Modifier.size(40.dp),
            )
        } else {
            Image(
                painter = painterResource(R.drawable.logo),
                contentDescription = stringResource(R.string.newsblur),
                modifier = Modifier.size(40.dp),
            )
        }
        Spacer(Modifier.width(16.dp))
        Text(
            color = LocalNbColors.current.textDefault,
            style = MaterialTheme.typography.titleMedium,
            text = stringResource(R.string.login_logging_in),
        )
    }
}
