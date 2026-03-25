package com.newsblur.compose

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.newsblur.design.NbThemeVariant
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.loginAuthPalette
import com.newsblur.viewModel.LoginRegisterViewModel
import com.newsblur.viewModel.LoginRegisterViewModel.AuthMode
import com.newsblur.viewModel.LoginRegisterViewModel.AuthPhase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LoginScreenTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun signingInState_showsInlineStatusOnDisabledSubmitButton() {
        setLoginContent(
            uiState =
                LoginRegisterViewModel.UiState(
                    mode = AuthMode.SignIn,
                    phase = AuthPhase.SigningIn,
                ),
            username = "samuel",
            password = "correct horse battery staple",
        )

        composeRule
            .onNodeWithTag(LoginScreenTags.SubmitButton)
            .assertIsNotEnabled()
            .assertTextEquals(composeRule.activity.getString(com.newsblur.R.string.login_logging_in))
    }

    @Test
    fun signInFields_exposeAutofillContentTypes() {
        setLoginContent(
            uiState = LoginRegisterViewModel.UiState(mode = AuthMode.SignIn),
            username = "",
            password = "",
        )

        composeRule.waitForIdle()

        val textFields = composeRule.onAllNodes(hasSetTextAction(), useUnmergedTree = true).fetchSemanticsNodes()

        assertTrue("Expected username and password fields", textFields.size >= 2)
        assertEquals(
            setOf("username", "emailAddress"),
            textFields[0].contentHintSet(),
        )
        assertEquals(
            setOf("password"),
            textFields[1].contentHintSet(),
        )
    }

    @Test
    fun customServerFooter_staysBelowAuthPanelInScrollFlow() {
        setLoginContent(
            uiState = LoginRegisterViewModel.UiState(),
            username = "samuel",
            password = "password",
        )

        composeRule.waitForIdle()

        val authPanelNode =
            composeRule
                .onNodeWithTag(LoginScreenTags.AuthPanel)
                .fetchSemanticsNode()
        val footerNode =
            composeRule
                .onNodeWithTag(LoginScreenTags.CustomServerFooter)
                .fetchSemanticsNode()

        assertTrue(
            "Expected auth panel to live inside the login scroll content",
            hasAncestorWithTag(authPanelNode, LoginScreenTags.ScrollContent),
        )
        assertTrue(
            "Expected custom server footer to live inside the login scroll content",
            hasAncestorWithTag(footerNode, LoginScreenTags.ScrollContent),
        )
    }

    @Test
    fun customServerDialog_wrapsContentInsteadOfFillingScreenHeight() {
        val hostHeight = 900.dp
        setLoginContent(
            uiState = LoginRegisterViewModel.UiState(),
            username = "",
            password = "",
            showCustomServerDialog = true,
            height = hostHeight,
        )

        composeRule.waitForIdle()

        val dialogHeight =
            composeRule
                .onNodeWithTag(LoginScreenTags.CustomServerDialogPanel)
                .fetchSemanticsNode()
                .boundsInRoot
                .height
        val hostHeightPx =
            with(composeRule.density) {
                hostHeight.toPx()
            }

        assertTrue(
            "Expected custom server dialog to be content-sized, but dialogHeight=$dialogHeight hostHeight=$hostHeightPx",
            dialogHeight < hostHeightPx * 0.8f,
        )
    }

    private fun setLoginContent(
        uiState: LoginRegisterViewModel.UiState,
        username: String,
        password: String,
        email: String = "",
        customServerValue: String = "",
        showCustomServerDialog: Boolean = false,
        height: Dp = 900.dp,
    ) {
        composeRule.setContent {
            NewsBlurTheme(variant = NbThemeVariant.Light, dynamic = false) {
                Box(modifier = Modifier.size(width = 393.dp, height = height)) {
                    LoginScreenContent(
                        variant = NbThemeVariant.Light,
                        palette = loginAuthPalette(NbThemeVariant.Light),
                        uiState = uiState,
                        username = username,
                        password = password,
                        email = email,
                        customServerValue = customServerValue,
                        showCustomServerDialog = showCustomServerDialog,
                        onUsernameChange = {},
                        onPasswordChange = {},
                        onEmailChange = {},
                        onSelectMode = {},
                        onSubmit = {},
                        onOpenForgotPassword = {},
                        onOpenCustomServerDialog = {},
                        onDismissCustomServerDialog = {},
                        onSaveCustomServer = {},
                        showShaderBackground = false,
                    )
                }
            }
        }
    }

    private fun hasAncestorWithTag(
        node: SemanticsNode,
        tag: String,
    ): Boolean =
        generateSequence(node.parent) { it.parent }.any { ancestor ->
            ancestor.config.contains(SemanticsProperties.TestTag) &&
                ancestor.config[SemanticsProperties.TestTag] == tag
        }

    private fun SemanticsNode.contentHintSet(): Set<String>? =
        if (config.contains(SemanticsProperties.ContentType)) {
            @Suppress("UNCHECKED_CAST")
            config[SemanticsProperties.ContentType]
                ?.let { contentType ->
                    val hintsField = contentType.javaClass.getDeclaredField("androidAutofillHints")
                    hintsField.isAccessible = true
                    hintsField.get(contentType) as Set<String>
                }
        } else {
            null
        }
}
