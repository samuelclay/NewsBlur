package com.newsblur.viewModel

import android.content.Context
import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.network.APIConstants
import com.newsblur.network.AuthApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.UIUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LoginRegisterViewModel
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val userApi: UserApi,
        private val authApi: AuthApi,
        private val prefsRepo: PrefsRepo,
    ) : ViewModel() {
        private val _uiState = MutableStateFlow<UiState>(UiState.SignIn)
        val uiState = _uiState.asStateFlow()

        fun signIn(
            username: String,
            password: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(UiState.SigningIn)
                val response = authApi.login(username, password)
                if (!response.isError) {
                    userApi.updateUserProfile()
                    val roundedUserImage =
                        prefsRepo.getUserImage(context)?.let { userImage ->
                            UIUtils.clipAndRound(userImage, true, false)
                        }
                    _uiState.emit(UiState.SignedIn(roundedUserImage))
                } else {
                    val message = response.getErrorMessage()
                    _uiState.emit(UiState.Error(message, BackTo.SignIn))
                }
            }
        }

        fun signUp(
            username: String,
            password: String,
            email: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(UiState.SigningUp)
                val response = authApi.signup(username, password, email)
                if (response.authenticated) {
                    _uiState.emit(UiState.SignedUp)
                } else {
                    val message = response.getErrorMessage()
                    _uiState.emit(UiState.Error(message, BackTo.SignUp))
                }
            }
        }

        fun showSignIn() {
            _uiState.value = UiState.SignIn
        }

        fun showSignUp() {
            _uiState.value = UiState.SignUp
        }

        fun getCustomServer() = prefsRepo.getCustomSever()

        fun saveCustomServer(value: String) {
            APIConstants.setCustomServer(value)
            prefsRepo.saveCustomServer(value)
        }

        fun clearCustomServer() {
            APIConstants.unsetCustomServer()
            prefsRepo.clearCustomServer()
        }

        fun backTo(backTo: BackTo) {
            val state =
                when (backTo) {
                    BackTo.SignIn -> UiState.SignIn
                    BackTo.SignUp -> UiState.SignUp
                }
            _uiState.value = state
        }

        sealed interface UiState {
            object SignIn : UiState

            object SignUp : UiState

            object SigningIn : UiState

            object SigningUp : UiState

            data class SignedIn(
                val userImage: Bitmap? = null,
            ) : UiState

            object SignedUp : UiState

            data class Error(
                val message: String? = null,
                val backTo: BackTo,
            ) : UiState
        }

        enum class BackTo { SignIn, SignUp }
    }
