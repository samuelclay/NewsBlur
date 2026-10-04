package com.newsblur.onboarding

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.BuildConfig
import com.newsblur.discover.string
import com.newsblur.network.APIConstants
import com.newsblur.network.AuthApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SubscriptionSyncService
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.security.SecureRandom
import javax.inject.Inject

data class AccountState(
    val signup: Boolean,
    val busy: Boolean = false,
    val error: String? = null,
    val browserUrl: String? = null,
    val continuation: String? = null,
    val canChooseUsername: Boolean = false,
    val username: String = "",
    val password: String = "",
    val authenticated: Boolean = false,
    val setup: Boolean = false,
    val lastUsed: String? = null,
    val deleting: Boolean = false,
    val providers: List<String> = emptyList(),
    val accountLoaded: Boolean = false,
    val verified: Boolean = false,
    val deleted: Boolean = false,
    val revocationRequired: Boolean = false,
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
                    canChooseUsername = saved.get<Boolean>("can_choose_username") == true,
                    username = saved.get<String>("username").orEmpty(),
                    deleting = saved.get<Boolean>("manage_account") == true,
                ),
            )
        val state = mutable.asStateFlow()

        private val owner = api.account()

        init {
            if (state.value.deleting) loadAccount()
        }

        fun loadAccount() =
            run {
                val json = api.request("/api/social/account", account = owner)!!.json
                val providers = json.getAsJsonArray("providers").map { it.asString }
                mutable.update { it.copy(accountLoaded = true, providers = if ("apple" in providers) listOf("apple") else providers) }
            }

        fun deleteAccount(
            confirm: String,
            password: String,
        ) = run {
            check(confirm == "Delete") { "Type Delete to confirm." }
            val social = state.value.providers.isNotEmpty()
            val values =
                if (social) {
                    mapOf("confirm" to confirm, "delete_token" to saved.get<String>("delete_token").orEmpty())
                } else {
                    mapOf(
                        "confirm" to confirm,
                        "password" to password,
                    )
                }
            val path = if (social) "/api/social/delete_account" else "/api/social/delete_password_account"
            val json = api.request(path, values, true, owner)!!.json
            mutable.update { it.copy(deleted = true, revocationRequired = json.string("apple_revocation_required") == "true") }
            saved.remove<String>("delete_token")
        }

        fun mode() {
            if (state.value.busy) return
            if (state.value.continuation != null) resetContinuation()
            mutable.update { it.copy(signup = !it.signup, password = "", error = null) }
        }

        fun updateUsername(value: String) {
            saved["username"] = value
            mutable.update { it.copy(username = value) }
        }

        // AccountViewModel.kt keeps passwords only in memory, never in SavedStateHandle.
        fun updatePassword(value: String) {
            mutable.update { it.copy(password = value) }
        }

        fun connectExistingAccount() {
            if (state.value.busy || state.value.continuation != "username") return
            saved["continuation"] = "link"
            saved["can_choose_username"] = true
            mutable.update { it.copy(continuation = "link", canChooseUsername = true, password = "", error = null) }
        }

        fun createNewAccountInstead() {
            if (state.value.busy || state.value.continuation != "link" || !state.value.canChooseUsername) return
            saved["continuation"] = "username"
            saved["username"] = ""
            mutable.update { it.copy(continuation = "username", username = "", password = "", error = null) }
        }

        private fun resetContinuation() {
            saved.remove<String>("verifier")
            saved.remove<String>("ticket")
            saved.remove<String>("continuation")
            saved.remove<Boolean>("can_choose_username")
            mutable.update { it.copy(error = null, continuation = null, canChooseUsername = false, password = "", browserUrl = null) }
        }

        fun customServer() = prefs.getCustomServer().orEmpty()

        fun theme() = prefs.getResolvedTheme(context)

        fun server(value: String) {
            if (value.isBlank()) {
                APIConstants.unsetCustomServer()
                prefs.clearCustomServer()
            } else {
                APIConstants.setCustomServer(value)
                prefs.saveCustomServer(value)
            }
            resetContinuation()
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
                resetContinuation()
                updateUsername("")
                val verifier =
                    Base64.encodeToString(
                        ByteArray(32).also { SecureRandom().nextBytes(it) },
                        Base64.NO_WRAP or Base64.URL_SAFE or Base64.NO_PADDING,
                    )
                val challenge = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray()).joinToString("") { "%02x".format(it) }
                saved["verifier"] = verifier
                saved["provider"] = provider
                saved["server"] = api.account().server
                saved["login_generation"] = api.account().generation
                val platform = if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "android-alpha" else "android"
                val json =
                    api
                        .request(
                            "/api/social/start",
                            mapOf(
                                "provider" to provider,
                                "challenge" to challenge,
                                "platform" to platform,
                                "purpose" to if (state.value.deleting) "delete_account" else "signin",
                            ),
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

        fun browserUnavailable() {
            mutable.update { it.copy(error = "Install a web browser to continue with Apple or Google.") }
        }

        fun callback(uri: Uri) {
            val expected = if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "newsblur-auth-android-alpha" else "newsblur-auth-android"
            if (uri.scheme != expected || uri.host != "complete") return
            val verifier: String? = saved["verifier"]
            val server: String? = saved["server"]
            if (verifier.isNullOrBlank() ||
                server != api.account().server ||
                saved.get<String>("login_generation") != api.account().generation
            ) {
                mutable.update { it.copy(error = "Sign-in expired. Please try again.") }
                return
            }
            uri.getQueryParameter("error")?.let { message ->
                mutable.update { it.copy(error = message) }
                return
            }
            val ticket = uri.getQueryParameter("ticket") ?: return
            saved["ticket"] = ticket
            viewModelScope.launch {
                state.first { !it.busy }
                complete("", "")
            }
        }

        private fun complete(
            username: String,
            password: String,
        ) = run {
            val values =
                mutableMapOf(
                    "ticket" to saved.get<String>("ticket").orEmpty(),
                    "verifier" to saved.get<String>("verifier").orEmpty(),
                    "username" to username,
                    "password" to if (state.value.continuation == "username") "" else password,
                )
            if (state.value.continuation == "link") values["action"] = "link"
            val response = api.request("/api/social/complete", values, true)!!
            val json = response.json
            if (state.value.deleting) {
                val token = json.string("delete_token")
                check(token.isNotBlank()) { "Account verification expired. Please try again." }
                saved["delete_token"] = token
                mutable.update { it.copy(verified = true) }
                return@run
            }
            val continuation =
                when {
                    json.string("link_required") == "true" -> "link"
                    json.string("username_required") == "true" -> "username"
                    else -> null
                }
            if (continuation != null) {
                val canChooseUsername = json.string("can_choose_username") == "true"
                saved["ticket"] = json.string("ticket")
                saved["continuation"] = continuation
                saved["can_choose_username"] = canChooseUsername
                mutable.update {
                    it.copy(
                        continuation = continuation,
                        canChooseUsername = canChooseUsername,
                        error = json.string("message"),
                        password = if (continuation != it.continuation) "" else it.password,
                    )
                }
            } else {
                val cookie = response.cookie
                check(!cookie.isNullOrBlank()) { "The server did not return a login session. Please try again." }
                prefs.saveLogin(json.string("username"), cookie)
                authenticated(json.string("created") == "true", saved.get<String>("provider").orEmpty())
                saved.remove<String>("verifier")
                saved.remove<String>("ticket")
                saved.remove<String>("continuation")
                saved.remove<Boolean>("can_choose_username")
                mutable.update { it.copy(canChooseUsername = false) }
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
                        hasEmptySubscriptions(api.request("/reader/feeds", mapOf("include_favicons" to "false"))!!.json)
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
