package com.newsblur.viewModel

import android.content.Context
import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.network.APIConstants
import com.newsblur.network.AuthApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SubscriptionSyncService
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
        private val _uiState = MutableStateFlow(UiState())
        val uiState = _uiState.asStateFlow()

        fun signIn(
            username: String,
            password: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(
                    _uiState.value.copy(
                        errorMessage = null,
                        phase = AuthPhase.SigningIn,
                    ),
                )
                val response = authApi.login(username, password)
                if (!response.isError) {
                    userApi.updateUserProfile()
                    val roundedUserImage =
                        prefsRepo.getUserImage(context)?.let { userImage ->
                            UIUtils.clipAndRound(userImage, true, false)
                        }
                    SubscriptionSyncService.schedule(context)
                    _uiState.emit(
                        _uiState.value.copy(
                            phase = AuthPhase.Authenticated,
                            userImage = roundedUserImage,
                        ),
                    )
                } else {
                    val message = response.getErrorMessage()
                    _uiState.emit(
                        _uiState.value.copy(
                            mode = AuthMode.SignIn,
                            phase = AuthPhase.Idle,
                            errorMessage = message,
                            userImage = null,
                        ),
                    )
                }
            }
        }

        fun signUp(
            username: String,
            password: String,
            email: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(
                    _uiState.value.copy(
                        errorMessage = null,
                        phase = AuthPhase.SigningUp,
                    ),
                )
                val response = authApi.signup(username, password, email)
                if (response.authenticated) {
                    userApi.updateUserProfile()
                    val roundedUserImage =
                        prefsRepo.getUserImage(context)?.let { userImage ->
                            UIUtils.clipAndRound(userImage, true, false)
                        }
                    SubscriptionSyncService.schedule(context)
                    _uiState.emit(
                        _uiState.value.copy(
                            phase = AuthPhase.Authenticated,
                            userImage = roundedUserImage,
                        ),
                    )
                } else {
                    val message = response.getErrorMessage()
                    _uiState.emit(
                        _uiState.value.copy(
                            mode = AuthMode.SignUp,
                            phase = AuthPhase.Idle,
                            errorMessage = message,
                            userImage = null,
                        ),
                    )
                }
            }
        }

        fun showSignIn() {
            _uiState.value =
                _uiState.value.copy(
                    mode = AuthMode.SignIn,
                    phase = AuthPhase.Idle,
                    errorMessage = null,
                )
        }

        fun showSignUp() {
            _uiState.value =
                _uiState.value.copy(
                    mode = AuthMode.SignUp,
                    phase = AuthPhase.Idle,
                    errorMessage = null,
                )
        }

        fun getCustomServer() = prefsRepo.getCustomServer()

        fun saveCustomServer(value: String) {
            APIConstants.setCustomServer(value)
            prefsRepo.saveCustomServer(value)
        }

        fun clearCustomServer() {
            APIConstants.unsetCustomServer()
            prefsRepo.clearCustomServer()
        }

        fun clearError() {
            _uiState.value = _uiState.value.copy(errorMessage = null)
        }

        data class UiState(
            val mode: AuthMode = AuthMode.SignIn,
            val phase: AuthPhase = AuthPhase.Idle,
            val errorMessage: String? = null,
            val userImage: Bitmap? = null,
        )

        enum class AuthMode { SignIn, SignUp }

        enum class AuthPhase { Idle, SigningIn, SigningUp, Authenticated }
    }
