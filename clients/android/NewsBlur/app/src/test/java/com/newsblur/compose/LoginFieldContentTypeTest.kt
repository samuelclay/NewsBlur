package com.newsblur.compose

import com.newsblur.viewModel.LoginRegisterViewModel.AuthMode
import org.junit.Assert.assertEquals
import org.junit.Test

class LoginFieldContentTypeTest {
    @Test
    fun signInUsernameField_acceptsUsernameAndEmailAutofill() {
        assertEquals(
            setOf("username", "emailAddress"),
            loginFieldContentType(AuthMode.SignIn, LoginFieldType.Username).contentHintSet(),
        )
    }

    @Test
    fun signInPasswordField_usesPasswordAutofill() {
        assertEquals(
            setOf("password"),
            loginFieldContentType(AuthMode.SignIn, LoginFieldType.Password).contentHintSet(),
        )
    }

    @Test
    fun signUpFields_useAccountCreationAutofillHints() {
        assertEquals(
            setOf("newUsername"),
            loginFieldContentType(AuthMode.SignUp, LoginFieldType.Username).contentHintSet(),
        )
        assertEquals(
            setOf("newPassword"),
            loginFieldContentType(AuthMode.SignUp, LoginFieldType.Password).contentHintSet(),
        )
        assertEquals(
            setOf("emailAddress"),
            loginFieldContentType(AuthMode.SignUp, LoginFieldType.Email).contentHintSet(),
        )
    }

    private fun Any.contentHintSet(): Set<String> {
        val hintsField = javaClass.getDeclaredField("androidAutofillHints")
        hintsField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return hintsField.get(this) as Set<String>
    }
}
