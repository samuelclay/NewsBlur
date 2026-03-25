package com.newsblur.compose

import android.graphics.Paint
import android.graphics.RuntimeShader
import android.net.Uri
import android.os.Build
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.autofill.contentType
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dns
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
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
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.window.Dialog
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.design.LoginAuthPalette
import com.newsblur.design.NbThemeVariant
import com.newsblur.design.loginAuthPalette
import com.newsblur.viewModel.LoginRegisterViewModel
import com.newsblur.viewModel.LoginRegisterViewModel.AuthMode
import kotlinx.coroutines.delay
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.withFrameNanos

private val gothamNarrow = FontFamily(Font(R.font.gotham_narrow_book, FontWeight.SemiBold))
private val chronicle = FontFamily(Font(R.font.chronicle_ssm_book))
private val whitney =
    FontFamily(
        Font(R.font.whitney_ssm_book_bas, FontWeight.Normal),
        Font(R.font.whitney_ssm_semi_bold_bas, FontWeight.SemiBold),
    )

internal object LoginScreenTags {
    const val ScrollContent = "login_scroll_content"
    const val AuthPanel = "login_auth_panel"
    const val SubmitButton = "login_submit_button"
    const val CustomServerFooter = "login_custom_server_footer"
    const val CustomServerDialogPanel = "login_custom_server_dialog_panel"
}

internal enum class LoginFieldType {
    Username,
    Password,
    Email,
}

internal fun loginFieldContentType(
    mode: AuthMode,
    fieldType: LoginFieldType,
): ContentType =
    when (fieldType) {
        LoginFieldType.Username ->
            if (mode == AuthMode.SignIn) {
                ContentType.Username + ContentType.EmailAddress
            } else {
                ContentType.NewUsername
            }
        LoginFieldType.Password ->
            if (mode == AuthMode.SignIn) {
                ContentType.Password
            } else {
                ContentType.NewPassword
            }
        LoginFieldType.Email -> ContentType.EmailAddress
    }

@Composable
fun LoginScreen(
    variant: NbThemeVariant,
    viewModel: LoginRegisterViewModel = hiltViewModel(),
    onAuthCompleted: () -> Unit,
    onOpenForgotPassword: () -> Unit,
) {
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val resolvedVariant =
        if (variant == NbThemeVariant.System && androidx.compose.foundation.isSystemInDarkTheme()) {
            NbThemeVariant.Dark
        } else if (variant == NbThemeVariant.System) {
            NbThemeVariant.Light
        } else {
            variant
        }
    val palette = remember(resolvedVariant) { loginAuthPalette(resolvedVariant) }

    val usernameFocusRequester = remember { FocusRequester() }
    val passwordFocusRequester = remember { FocusRequester() }
    val emailFocusRequester = remember { FocusRequester() }

    var username by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var showCustomServerDialog by rememberSaveable { mutableStateOf(false) }
    var customServerValue by rememberSaveable { mutableStateOf(viewModel.getCustomServer().orEmpty()) }

    LaunchedEffect(Unit) {
        delay(180)
        usernameFocusRequester.requestFocus()
    }

    LaunchedEffect(uiState.mode) {
        delay(90)
        when (uiState.mode) {
            AuthMode.SignIn -> usernameFocusRequester.requestFocus()
            AuthMode.SignUp -> usernameFocusRequester.requestFocus()
        }
    }

    LaunchedEffect(uiState.phase) {
        if (uiState.phase == LoginRegisterViewModel.AuthPhase.Authenticated) {
            keyboardController?.hide()
            focusManager.clearFocus(force = true)
            delay(350)
            onAuthCompleted()
        }
    }

    fun submit() {
        keyboardController?.hide()
        focusManager.clearFocus(force = true)
        when (uiState.mode) {
            AuthMode.SignIn -> viewModel.signIn(username.trim(), password)
            AuthMode.SignUp -> viewModel.signUp(username.trim(), password, email.trim())
        }
    }

    LoginScreenContent(
        variant = resolvedVariant,
        palette = palette,
        uiState = uiState,
        username = username,
        password = password,
        email = email,
        customServerValue = customServerValue,
        showCustomServerDialog = showCustomServerDialog,
        onUsernameChange = {
            username = it
            viewModel.clearError()
        },
        onPasswordChange = {
            password = it
            viewModel.clearError()
        },
        onEmailChange = {
            email = it
            viewModel.clearError()
        },
        onSelectMode = { mode ->
            viewModel.clearError()
            if (mode == AuthMode.SignIn) {
                viewModel.showSignIn()
            } else {
                viewModel.showSignUp()
            }
        },
        onSubmit = ::submit,
        onOpenForgotPassword = onOpenForgotPassword,
        onOpenCustomServerDialog = { showCustomServerDialog = true },
        onDismissCustomServerDialog = { showCustomServerDialog = false },
        onSaveCustomServer = { newValue ->
            customServerValue = newValue
            if (newValue.isBlank()) {
                viewModel.clearCustomServer()
            } else {
                viewModel.saveCustomServer(newValue)
            }
            showCustomServerDialog = false
        },
        usernameFocusRequester = usernameFocusRequester,
        passwordFocusRequester = passwordFocusRequester,
        emailFocusRequester = emailFocusRequester,
    )
}

@Composable
internal fun LoginScreenContent(
    variant: NbThemeVariant,
    palette: LoginAuthPalette,
    uiState: LoginRegisterViewModel.UiState,
    username: String,
    password: String,
    email: String,
    customServerValue: String,
    showCustomServerDialog: Boolean,
    onUsernameChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onEmailChange: (String) -> Unit,
    onSelectMode: (AuthMode) -> Unit,
    onSubmit: () -> Unit,
    onOpenForgotPassword: () -> Unit,
    onOpenCustomServerDialog: () -> Unit,
    onDismissCustomServerDialog: () -> Unit,
    onSaveCustomServer: (String) -> Unit,
    usernameFocusRequester: FocusRequester? = null,
    passwordFocusRequester: FocusRequester? = null,
    emailFocusRequester: FocusRequester? = null,
    showShaderBackground: Boolean = true,
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    val resolvedVariant =
        if (variant == NbThemeVariant.System && androidx.compose.foundation.isSystemInDarkTheme()) {
            NbThemeVariant.Dark
        } else if (variant == NbThemeVariant.System) {
            NbThemeVariant.Light
        } else {
            variant
        }
    val isSigningIn = uiState.phase == LoginRegisterViewModel.AuthPhase.SigningIn
    val isSigningUp = uiState.phase == LoginRegisterViewModel.AuthPhase.SigningUp
    val isBusy = uiState.phase != LoginRegisterViewModel.AuthPhase.Idle
    val submitButtonLabel =
        when {
            isSigningIn -> context.getString(R.string.login_logging_in)
            isSigningUp -> context.getString(R.string.registering)
            isBusy -> context.getString(R.string.login_logged_in)
            uiState.mode == AuthMode.SignIn -> context.getString(R.string.login_segment_sign_in)
            else -> context.getString(R.string.login_segment_sign_up)
        }
    val canSubmit =
        when (uiState.mode) {
            AuthMode.SignIn -> username.isNotBlank() && password.isNotBlank()
            AuthMode.SignUp -> username.isNotBlank() && password.isNotBlank() && email.isNotBlank()
        }

    Box(
        modifier = Modifier.fillMaxSize(),
    ) {
        if (showShaderBackground && resolvedVariant != NbThemeVariant.Sepia) {
            AndroidShaderBackground(
                palette = palette,
            )
        }

        Box(
            modifier =
                Modifier
                    .matchParentSize()
                    .background(
                        brush =
                            Brush.verticalGradient(
                                colors =
                                    listOf(
                                        palette.gradientTop.copy(alpha = 0.68f),
                                        palette.gradientBottom.copy(alpha = 0.72f),
                                    ),
                            ),
                    ),
        )

        Box(
            modifier =
                Modifier
                    .matchParentSize()
                    .background(
                        brush =
                            Brush.verticalGradient(
                                colors = listOf(palette.scrimTop, Color.Transparent, palette.scrimBottom),
                            ),
                    ),
        )

        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 24.dp)
                    .statusBarsPadding()
                    .navigationBarsPadding()
                    .imePadding()
                    .testTag(LoginScreenTags.ScrollContent),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(48.dp))
            Header(palette = palette)
            Spacer(Modifier.height(28.dp))

            FrostedPanel(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .widthIn(max = 420.dp)
                        .testTag(LoginScreenTags.AuthPanel),
                palette = palette,
                filled = true,
            ) {
                SegmentedControl(
                    mode = uiState.mode,
                    palette = palette,
                    enabled = !isBusy,
                    onSelectMode = onSelectMode,
                )

                Spacer(Modifier.height(18.dp))

                AuthTextField(
                    value = username,
                    onValueChange = onUsernameChange,
                    placeholder =
                        if (uiState.mode == AuthMode.SignIn) {
                            stringResource(R.string.login_username_or_email_hint)
                        } else {
                            stringResource(R.string.login_username_hint)
                        },
                    enabled = !isBusy,
                    palette = palette,
                    focusRequester = usernameFocusRequester,
                    keyboardOptions =
                        KeyboardOptions(
                            keyboardType = KeyboardType.Text,
                            imeAction = ImeAction.Next,
                        ),
                    keyboardActions =
                        KeyboardActions(
                            onNext = { passwordFocusRequester?.requestFocus() },
                        ),
                    contentType = loginFieldContentType(uiState.mode, LoginFieldType.Username),
                )

                Spacer(Modifier.height(12.dp))

                AuthTextField(
                    value = password,
                    onValueChange = onPasswordChange,
                    placeholder = stringResource(R.string.login_password_hint),
                    enabled = !isBusy,
                    palette = palette,
                    focusRequester = passwordFocusRequester,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions =
                        KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = if (uiState.mode == AuthMode.SignIn) ImeAction.Go else ImeAction.Next,
                        ),
                    keyboardActions =
                        KeyboardActions(
                            onGo = {
                                if (canSubmit && !isBusy) onSubmit()
                            },
                            onNext = { emailFocusRequester?.requestFocus() },
                        ),
                    contentType = loginFieldContentType(uiState.mode, LoginFieldType.Password),
                )

                AnimatedVisibility(
                    visible = uiState.mode == AuthMode.SignUp,
                    enter = fadeIn(tween(220)) + expandVertically(tween(260)),
                    exit = fadeOut(tween(150)) + shrinkVertically(tween(180)),
                ) {
                    Column {
                        Spacer(Modifier.height(12.dp))
                        AuthTextField(
                            value = email,
                            onValueChange = onEmailChange,
                            placeholder = stringResource(R.string.login_registration_email_hint),
                            enabled = !isBusy,
                            palette = palette,
                            focusRequester = emailFocusRequester,
                            keyboardOptions =
                                KeyboardOptions(
                                    keyboardType = KeyboardType.Email,
                                    imeAction = ImeAction.Done,
                                ),
                            keyboardActions =
                                KeyboardActions(
                                    onDone = {
                                        if (canSubmit && !isBusy) onSubmit()
                                    },
                                ),
                            contentType = loginFieldContentType(uiState.mode, LoginFieldType.Email),
                        )
                    }
                }

                Spacer(Modifier.height(16.dp))

                Button(
                    onClick = onSubmit,
                    enabled = canSubmit && !isBusy,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag(LoginScreenTags.SubmitButton),
                    shape = RoundedCornerShape(12.dp),
                    colors =
                        ButtonDefaults.buttonColors(
                            containerColor = palette.button,
                            contentColor = palette.buttonText,
                            disabledContainerColor = palette.buttonDisabled,
                            disabledContentColor = palette.buttonText.copy(alpha = 0.75f),
                        ),
                    ) {
                    Text(
                        text = submitButtonLabel,
                        fontFamily = gothamNarrow,
                        fontSize = 18.sp,
                    )
                }

                AnimatedVisibility(visible = uiState.errorMessage != null) {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(top = 12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            text = uiState.errorMessage.orEmpty(),
                            color = palette.error,
                            fontFamily = whitney,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center,
                        )

                        AnimatedVisibility(visible = uiState.mode == AuthMode.SignIn) {
                            TextButton(onClick = onOpenForgotPassword) {
                                Text(
                                    text = stringResource(R.string.login_forgot_password),
                                    color = palette.link,
                                    fontFamily = whitney,
                                )
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(18.dp))

            CustomServerFooter(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .widthIn(max = 420.dp)
                        .testTag(LoginScreenTags.CustomServerFooter),
                palette = palette,
                customServer = customServerValue,
                enabled = !isBusy,
                onClick = onOpenCustomServerDialog,
            )

            Spacer(Modifier.height(28.dp))
        }

        if (showCustomServerDialog) {
            CustomServerDialog(
                palette = palette,
                initialValue = customServerValue,
                onDismiss = onDismissCustomServerDialog,
                onSave = onSaveCustomServer,
            )
        }
    }
}

@Composable
private fun AndroidShaderBackground(
    palette: LoginAuthPalette,
) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

    val shader = remember { RuntimeShader(LOGIN_SHADER_SOURCE) }
    val nativePaint = remember { Paint() }
    val elapsedTime by produceState(initialValue = 0f) {
        var start = 0L
        while (true) {
            withFrameNanos { frameTime ->
                if (start == 0L) start = frameTime
                value = (frameTime - start) / 1_000_000_000f
            }
        }
    }

    Canvas(modifier = Modifier.fillMaxSize()) {
        shader.setFloatUniform("u_resolution", size.width, size.height)
        shader.setFloatUniform("u_time", elapsedTime)
        shader.setFloatUniform("u_base", palette.shader.base.red, palette.shader.base.green, palette.shader.base.blue)
        shader.setFloatUniform("u_mid", palette.shader.mid.red, palette.shader.mid.green, palette.shader.mid.blue)
        shader.setFloatUniform("u_light", palette.shader.light.red, palette.shader.light.green, palette.shader.light.blue)
        shader.setFloatUniform("u_gold", palette.shader.gold.red, palette.shader.gold.green, palette.shader.gold.blue)
        shader.setFloatUniform(
            "u_soft_gold",
            palette.shader.softGold.red,
            palette.shader.softGold.green,
            palette.shader.softGold.blue,
        )
        nativePaint.shader = shader

        drawIntoCanvas { canvas ->
            canvas.nativeCanvas.drawRect(0f, 0f, size.width, size.height, nativePaint)
        }
    }
}

@Composable
private fun Header(palette: LoginAuthPalette) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier =
                Modifier
                    .size(122.dp)
                    .shadow(28.dp, CircleShape, ambientColor = palette.logoGlow, spotColor = palette.logoGlow)
                    .clip(CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                painter = painterResource(id = R.drawable.logo),
                contentDescription = stringResource(R.string.description_login_logo),
                modifier = Modifier.size(116.dp),
                contentScale = ContentScale.Fit,
            )
        }

        Spacer(Modifier.height(14.dp))
        Text(
            text = stringResource(R.string.newsblur),
            color = palette.title,
            fontFamily = gothamNarrow,
            fontWeight = FontWeight.SemiBold,
            fontSize = 38.sp,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.login_tagline),
            color = palette.tagline,
            fontFamily = chronicle,
            fontStyle = FontStyle.Italic,
            fontSize = 18.sp,
            lineHeight = 25.sp,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun FrostedPanel(
    modifier: Modifier = Modifier,
    palette: LoginAuthPalette,
    filled: Boolean = true,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(24.dp)
    Box(
        modifier =
            modifier
                .clip(shape)
                .then(
                    if (filled) {
                        Modifier.background(
                            brush =
                                Brush.verticalGradient(
                                    colors = listOf(palette.cardTop, palette.cardBottom),
                                ),
                        )
                    } else {
                        Modifier
                    },
                )
                .border(1.dp, palette.cardBorder, shape),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp, vertical = 24.dp),
            content = content,
        )
    }
}

@Composable
private fun SegmentedControl(
    mode: AuthMode,
    palette: LoginAuthPalette,
    enabled: Boolean,
    onSelectMode: (AuthMode) -> Unit,
) {
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .border(1.dp, palette.segmentBorder, RoundedCornerShape(12.dp)),
    ) {
        val pillWidth = (maxWidth - 4.dp) / 2
        val pillOffset by animateDpAsState(
            targetValue = if (mode == AuthMode.SignIn) 2.dp else pillWidth + 2.dp,
            animationSpec = tween(durationMillis = 260),
            label = "loginSegmentOffset",
        )

        Box(
            modifier =
                Modifier
                    .offset(x = pillOffset, y = 2.dp)
                    .width(pillWidth)
                    .height(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(
                        brush =
                            Brush.verticalGradient(
                                colors = listOf(palette.segmentPillTop, palette.segmentPillBottom),
                            ),
                    )
                    .border(1.dp, palette.segmentBorder, RoundedCornerShape(10.dp)),
        )

        Row(modifier = Modifier.fillMaxSize()) {
            SegmentButton(
                modifier = Modifier.weight(1f),
                selected = mode == AuthMode.SignIn,
                text = stringResource(R.string.login_segment_sign_in),
                palette = palette,
                enabled = enabled,
                onClick = { onSelectMode(AuthMode.SignIn) },
            )
            SegmentButton(
                modifier = Modifier.weight(1f),
                selected = mode == AuthMode.SignUp,
                text = stringResource(R.string.login_segment_sign_up),
                palette = palette,
                enabled = enabled,
                onClick = { onSelectMode(AuthMode.SignUp) },
            )
        }
    }
}

@Composable
private fun SegmentButton(
    modifier: Modifier = Modifier,
    selected: Boolean,
    text: String,
    palette: LoginAuthPalette,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier =
            modifier
                .fillMaxHeight()
                .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color =
                if (selected) {
                    if (enabled) palette.segmentSelectedText else palette.segmentSelectedText.copy(alpha = 0.72f)
                } else {
                    if (enabled) palette.segmentUnselectedText else palette.segmentUnselectedText.copy(alpha = 0.72f)
                },
            textAlign = TextAlign.Center,
            fontFamily = gothamNarrow,
            fontSize = 15.sp,
        )
    }
}

@Composable
private fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    enabled: Boolean,
    palette: LoginAuthPalette,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    contentType: ContentType? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val borderColor by animateColorAsState(
        targetValue = if (isFocused) palette.fieldFocusBorder else palette.fieldBorder,
        animationSpec = tween(durationMillis = 180),
        label = "authFieldBorder",
    )
    val shape = RoundedCornerShape(12.dp)

    Box(
        modifier =
            modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(shape)
                .background(
                    if (isFocused) {
                        palette.fieldBackground.copy(alpha = 0.10f)
                    } else {
                        Color.Transparent
                    },
                )
                .border(1.dp, borderColor, shape),
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier =
                Modifier
                    .fillMaxSize()
                    .then(if (contentType != null) Modifier.contentType(contentType) else Modifier)
                    .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier),
            singleLine = true,
            textStyle =
                TextStyle(
                    color = if (enabled) palette.fieldText else palette.fieldText.copy(alpha = 0.78f),
                    fontFamily = whitney,
                    fontSize = 16.sp,
                ),
            enabled = enabled,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            visualTransformation = visualTransformation,
            cursorBrush = SolidColor(palette.fieldCursor),
            interactionSource = interactionSource,
            decorationBox = { innerTextField ->
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(horizontal = 16.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            color = if (enabled) palette.fieldPlaceholder else palette.fieldPlaceholder.copy(alpha = 0.72f),
                            fontFamily = whitney,
                            fontSize = 16.sp,
                        )
                    }
                    innerTextField()
                }
            },
        )
    }
}

@Composable
private fun CustomServerFooter(
    modifier: Modifier = Modifier,
    palette: LoginAuthPalette,
    customServer: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val host = remember(customServer) { customServerHost(customServer) }
    val label =
        if (host == null) {
            stringResource(R.string.login_custom_server)
        } else {
            stringResource(R.string.login_custom_server_active, host)
        }
    val subtitle =
        if (host == null) {
            stringResource(R.string.login_custom_server_subtitle)
        } else {
            stringResource(R.string.login_custom_server_edit)
        }

    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .widthIn(max = 420.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(palette.footerBackground)
                .border(1.dp, palette.footerBorder, RoundedCornerShape(18.dp))
                .clickable(enabled = enabled, onClick = onClick)
                .padding(horizontal = 18.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Rounded.Dns,
            contentDescription = null,
            tint = if (enabled) palette.footerText else palette.footerText.copy(alpha = 0.7f),
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                color = if (enabled) palette.footerText else palette.footerText.copy(alpha = 0.7f),
                fontFamily = gothamNarrow,
                fontSize = 15.sp,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = subtitle,
                color = if (enabled) palette.footerSubtext else palette.footerSubtext.copy(alpha = 0.7f),
                fontFamily = whitney,
                fontSize = 13.sp,
            )
        }
    }
}

@Composable
private fun CustomServerDialog(
    palette: LoginAuthPalette,
    initialValue: String,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    val context = LocalContext.current
    val keyboardController = LocalSoftwareKeyboardController.current
    var value by rememberSaveable(initialValue) { mutableStateOf(initialValue) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }

    fun saveServer() {
        val normalized = value.trim().trimEnd('/')
        error =
            when {
                normalized.isBlank() -> null
                !normalized.startsWith("https://") -> context.getString(R.string.login_custom_server_scheme_error)
                Uri.parse(normalized).host.isNullOrBlank() -> context.getString(R.string.login_custom_server_invalid)
                else -> null
            }

        if (error == null) {
            keyboardController?.hide()
            onSave(normalized)
        }
    }

    Dialog(onDismissRequest = onDismiss) {
        FrostedPanel(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp)
                    .testTag(LoginScreenTags.CustomServerDialogPanel),
            palette = palette,
        ) {
            Text(
                text = stringResource(R.string.login_custom_server_dialog_title),
                color = palette.title,
                fontFamily = gothamNarrow,
                fontSize = 24.sp,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.login_custom_server_dialog_body),
                color = palette.footerSubtext,
                fontFamily = whitney,
                fontSize = 14.sp,
                lineHeight = 20.sp,
            )
            Spacer(Modifier.height(16.dp))
            AuthTextField(
                value = value,
                onValueChange = {
                    value = it
                    error = null
                },
                placeholder = stringResource(R.string.login_custom_server_hint),
                enabled = true,
                palette = palette,
                keyboardOptions =
                    KeyboardOptions(
                        keyboardType = KeyboardType.Uri,
                        imeAction = ImeAction.Done,
                    ),
                keyboardActions =
                    KeyboardActions(
                        onDone = { saveServer() },
                    ),
            )

            AnimatedVisibility(visible = error != null) {
                Text(
                    text = error.orEmpty(),
                    modifier = Modifier.padding(top = 12.dp),
                    color = palette.error,
                    fontFamily = whitney,
                    fontSize = 14.sp,
                )
            }

            if (initialValue.isNotBlank()) {
                TextButton(
                    onClick = {
                        value = ""
                        error = null
                        keyboardController?.hide()
                        onSave("")
                    },
                    modifier = Modifier.align(Alignment.End),
                ) {
                    Text(
                        text = stringResource(R.string.login_registration_reset_url),
                        color = palette.link,
                        fontFamily = whitney,
                    )
                }
            } else {
                Spacer(Modifier.height(12.dp))
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onDismiss) {
                    Text(
                        text = stringResource(R.string.alert_dialog_cancel),
                        color = palette.footerSubtext,
                        fontFamily = whitney,
                    )
                }
                Spacer(Modifier.height(0.dp))
                Button(
                    onClick = ::saveServer,
                    shape = RoundedCornerShape(12.dp),
                    colors =
                        ButtonDefaults.buttonColors(
                            containerColor = palette.button,
                            contentColor = palette.buttonText,
                        ),
                ) {
                    Text(
                        text = stringResource(R.string.alert_dialog_done),
                        fontFamily = gothamNarrow,
                        fontSize = 16.sp,
                    )
                }
            }
        }
    }
}

private fun customServerHost(value: String): String? {
    if (value.isBlank()) return null
    return Uri.parse(value).host ?: value.removePrefix("https://")
}

// Keep Android aligned with the iOS Metal and web WebGL login background wave shader.
private const val LOGIN_SHADER_SOURCE =
    """
    uniform float2 u_resolution;
    uniform float u_time;
    uniform float3 u_base;
    uniform float3 u_mid;
    uniform float3 u_light;
    uniform float3 u_gold;
    uniform float3 u_soft_gold;

    half4 main(float2 fragCoord) {
        float2 uv = fragCoord / u_resolution;
        float3 bg = mix(u_mid, u_base, smoothstep(0.0, 1.0, uv.y));
        float time = u_time * 0.4;

        float d1 = uv.x * 0.6 + uv.y * 0.4;
        float d2 = uv.x * 0.4 - uv.y * 0.6;
        float d3 = uv.x * 0.8 + uv.y * 0.2;

        float w1 = sin(d1 * 8.0 + time * 0.5 + sin(uv.y * 4.0 + time * 0.3) * 0.8);
        float ridge1 = exp(-w1 * w1 * 2.5) * 0.35;

        float w2 = sin(d2 * 6.0 + time * 0.7 + cos(uv.x * 3.0 - time * 0.5) * 0.6);
        float ridge2 = exp(-w2 * w2 * 3.0) * 0.2;

        float w3 = sin(d3 * 14.0 - time * 0.9 + sin(d1 * 5.0 + time * 0.4) * 0.4);
        float ridge3 = exp(-w3 * w3 * 4.0) * 0.12;

        float w4 = sin(d1 * 3.0 + time * 0.25);
        float glow = w4 * w4 * 0.15;

        float3 color = bg;
        color += u_light * ridge1;
        color += u_gold * 0.7 * ridge2;
        color += u_soft_gold * 0.4 * ridge3;
        color += u_mid * glow;

        return half4(color, 1.0);
    }
    """
