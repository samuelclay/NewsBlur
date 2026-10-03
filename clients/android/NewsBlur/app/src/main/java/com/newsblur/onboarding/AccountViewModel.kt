package com.newsblur.onboarding

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.BuildConfig
import com.newsblur.discover.obj
import com.newsblur.discover.string
import com.newsblur.network.APIConstants
import com.newsblur.network.AuthApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SubscriptionSyncService
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.security.MessageDigest
import java.security.SecureRandom
import javax.inject.Inject

data class AccountState(
    val signup: Boolean,
    val busy: Boolean = false,
    val error: String? = null,
    val browserUrl: String? = null,
    val continuation: String? = null,
    val authenticated: Boolean = false,
    val setup: Boolean = false,
    val lastUsed: String? = null,
)

@HiltViewModel
class AccountViewModel
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val api: OnboardingApi,
        private val auth: AuthApi,
        private val user: UserApi,
        private val prefs: PrefsRepo,
        private val saved: SavedStateHandle,
    ) : ViewModel() {
        private val mutable =
            MutableStateFlow(
                AccountState(
                    signup = prefs.lastAuthProvider() == null,
                    lastUsed = prefs.lastAuthProvider(),
                    continuation = saved["continuation"],
                ),
            )
        val state = mutable.asStateFlow()

        fun mode() {
            saved.remove<String>("ticket")
            saved.remove<String>("continuation")
            mutable.update { it.copy(signup = !it.signup, error = null, continuation = null) }
        }

        fun customServer() = prefs.getCustomServer().orEmpty()

        fun server(value: String) {
            if (value.isBlank()) {
                APIConstants.unsetCustomServer()
                prefs.clearCustomServer()
            } else {
                APIConstants.setCustomServer(value)
                prefs.saveCustomServer(value)
            }
            saved.remove<String>("verifier")
            saved.remove<String>("ticket")
            mutable.update { it.copy(continuation = null, error = null) }
        }

        fun submit(
            username: String,
            password: String,
            email: String,
        ) {
            if (state.value.busy) return
            if (state.value.continuation != null) {
                complete(username, password)
                return
            }
            run {
                val signup = state.value.signup
                val created =
                    withContext(Dispatchers.IO) {
                        if (signup) {
                            val response = auth.signup(username, password, email)
                            check(
                                response.authenticated,
                            ) { response.getErrorMessage() ?: "Could not create your account. Please try again." }
                        } else {
                            val response = auth.login(username, password)
                            check(!response.isError) { response.getErrorMessage() ?: "Could not sign in. Please try again." }
                        }
                        signup
                    }
                authenticated(created, "email")
            }
        }

        fun social(provider: String) =
            run {
                val verifier =
                    Base64.encodeToString(
                        ByteArray(32).also { SecureRandom().nextBytes(it) },
                        Base64.NO_WRAP or Base64.URL_SAFE or Base64.NO_PADDING,
                    )
                val challenge = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray()).joinToString("") { "%02x".format(it) }
                saved["verifier"] = verifier
                saved["provider"] = provider
                saved["server"] = api.account().server
                val platform = if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "android-alpha" else "android"
                val json =
                    api
                        .request(
                            "/api/social/start",
                            mapOf("provider" to provider, "challenge" to challenge, "platform" to platform),
                            true,
                        )!!
                        .json
                val url = json.string("url")
                check(url.startsWith("https://")) { "This server needs an update to support $provider sign-in on Android." }
                mutable.update { it.copy(browserUrl = url) }
            }

        fun browserOpened() {
            mutable.update { it.copy(browserUrl = null) }
        }

        fun callback(uri: Uri) {
            val expected = if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "newsblur-auth-android-alpha" else "newsblur-auth-android"
            if (uri.scheme != expected || uri.host != "complete") return
            val verifier: String? = saved["verifier"]
            val server: String? = saved["server"]
            if (verifier.isNullOrBlank() || server != api.account().server) {
                mutable.update { it.copy(error = "Sign-in expired. Please try again.") }
                return
            }
            uri.getQueryParameter("error")?.let { message ->
                mutable.update { it.copy(error = message) }
                return
            }
            val ticket = uri.getQueryParameter("ticket") ?: return
            saved["ticket"] = ticket
            complete("", "")
        }

        private fun complete(
            username: String,
            password: String,
        ) = run {
            val values =
                mapOf(
                    "ticket" to saved.get<String>("ticket").orEmpty(),
                    "verifier" to saved.get<String>("verifier").orEmpty(),
                    "username" to username,
                    "password" to password,
                )
            val response = api.request("/api/social/complete", values, true)!!
            val json = response.json
            val continuation =
                when {
                    json.string("link_required") == "true" -> "link"
                    json.string("username_required") == "true" -> "username"
                    else -> null
                }
            if (continuation != null) {
                saved["ticket"] = json.string("ticket")
                saved["continuation"] = continuation
                mutable.update { it.copy(continuation = continuation, error = json.string("message")) }
            } else {
                val cookie = response.cookie?.substringBefore(';')
                check(!cookie.isNullOrBlank()) { "The server did not return a login session. Please try again." }
                prefs.saveLogin(json.string("username"), cookie)
                authenticated(json.string("created") == "true", saved.get<String>("provider").orEmpty())
                saved.remove<String>("verifier")
                saved.remove<String>("ticket")
                saved.remove<String>("continuation")
            }
        }

        private suspend fun authenticated(
            created: Boolean,
            provider: String,
        ) {
            prefs.saveLastAuthProvider(provider)
            withContext(Dispatchers.IO) {
                user.updateUserProfile()
                SubscriptionSyncService.schedule(context)
            }
            // AccountViewModel.kt checks the server's complete feed map, never a filtered or still-empty local database.
            val empty =
                if (created) {
                    true
                } else if (prefs.hasCompletedOnboarding()) {
                    false
                } else {
                    try {
                        api
                            .request("/reader/feeds", mapOf("include_favicons" to "false"))!!
                            .json
                            .obj("feeds")
                            ?.size() == 0
                    } catch (_: Exception) {
                        false
                    }
                }
            mutable.update { it.copy(authenticated = true, setup = created || empty) }
        }

        private fun run(block: suspend () -> Unit) {
            if (state.value.busy) return
            viewModelScope.launch {
                mutable.update { it.copy(busy = true, error = null) }
                try {
                    block()
                } catch (cancel: CancellationException) {
                    throw cancel
                } catch (e: Exception) {
                    mutable.update {
                        it.copy(
                            error =
                                e.message ?: "Could not connect. Please try again.",
                        )
                    }
                } finally {
                    mutable.update { it.copy(busy = false) }
                }
            }
        }
    }
