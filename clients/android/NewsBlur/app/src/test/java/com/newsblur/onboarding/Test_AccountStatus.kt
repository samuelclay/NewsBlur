package com.newsblur.onboarding

import android.net.Uri
import android.util.Base64
import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.BuildConfig
import com.newsblur.network.AuthApi
import com.newsblur.network.domain.LoginResponse
import com.newsblur.preference.PrefsRepo
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class Test_AccountStatus {
    private val dispatcher = StandardTestDispatcher()
    private val api = mockk<OnboardingApi>()
    private val auth = mockk<AuthApi>()
    private val prefs = mockk<PrefsRepo>(relaxed = true)

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        mockkStatic(Base64::class)
        every { Base64.encodeToString(any(), any()) } returns "verifier"
        every { prefs.lastAuthProvider() } returns "email"
        every { api.account() } returns SetupAccount("https://newsblur.com", null, "generation")
    }

    @After fun tearDown() {
        unmockkAll()
        Dispatchers.resetMain()
    }

    private fun model(saved: SavedStateHandle = SavedStateHandle()) = AccountViewModel(mockk(), api, auth, mockk(), prefs, saved)

    private fun response(json: String) = SetupResponse(JsonParser.parseString(json).asJsonObject, null)

    private fun callback(error: String? = null): Uri = mockk<Uri>().also { uri ->
        every { uri.scheme } returns if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "newsblur-auth-android-alpha" else "newsblur-auth-android"
        every { uri.host } returns "complete"
        every { uri.getQueryParameter("error") } returns error
        every { uri.getQueryParameter("ticket") } returns "browser-ticket"
    }

    @Test fun test_progress_and_error_follow_the_tapped_provider_including_retry() = runTest(dispatcher) {
        val model = model()
        for (provider in listOf("google", "apple")) {
            val pending = CompletableDeferred<SetupResponse?>()
            coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } coAnswers { pending.await() }
            model.social(provider)
            runCurrent()
            try {
                assertTrue(model.state.value.busy)
                assertNull(model.state.value.error)
                assertEquals(provider, model.state.value.activeProvider)
            } finally {
                pending.completeExceptionally(IOException("Provider unavailable"))
                advanceUntilIdle()
            }
            assertFalse(model.state.value.busy)
            assertEquals("Provider unavailable", model.state.value.error)
            assertEquals(provider, model.state.value.activeProvider)
        }
    }

    @Test fun test_email_submission_takes_status_ownership_after_provider_failure() = runTest(dispatcher) {
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } throws IOException("Provider unavailable")
        val model = model()
        model.social("google")
        advanceUntilIdle()
        assertEquals("google", model.state.value.activeProvider)
        val pending = CompletableDeferred<LoginResponse>()
        coEvery { auth.login(any(), any()) } coAnswers { pending.await() }
        model.submit("reader", "password", "")
        runCurrent()
        try {
            assertTrue(model.state.value.busy)
            assertNull(model.state.value.activeProvider)
            assertNull(model.state.value.error)
        } finally {
            pending.completeExceptionally(IOException("Incorrect NewsBlur password"))
        }
        val failed = model.state.first { !it.busy }
        assertEquals("Incorrect NewsBlur password", failed.error)
        assertNull(failed.activeProvider)
    }

    @Test fun test_browser_errors_keep_provider_ownership_across_recreation_and_mode_switch() = runTest(dispatcher) {
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } returns
            response("""{"url":"https://provider.example/authorize"}""")
        val saved = SavedStateHandle()
        val model = model(saved)
        model.social("apple")
        advanceUntilIdle()
        model.browserOpened()
        val recreated = model(SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) }))
        recreated.browserUnavailable()
        assertEquals("apple", recreated.state.value.activeProvider)
        assertNotNull(recreated.state.value.error)
        recreated.mode()
        assertNull(recreated.state.value.activeProvider)
        assertNull(recreated.state.value.error)
        recreated.callback(callback("Apple authorization failed"))
        assertEquals("apple", recreated.state.value.activeProvider)
        assertEquals("Apple authorization failed", recreated.state.value.error)
    }

    @Test fun test_callback_progress_moves_to_form_status_when_link_continuation_arrives() = runTest(dispatcher) {
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } returns
            response("""{"url":"https://provider.example/authorize"}""")
        val pending = CompletableDeferred<SetupResponse?>()
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } coAnswers { pending.await() }
        val model = model()
        model.social("google")
        advanceUntilIdle()
        model.browserOpened()
        model.callback(callback())
        runCurrent()
        try {
            assertTrue(model.state.value.busy)
            assertEquals("google", model.state.value.activeProvider)
        } finally {
            pending.complete(response("""{"link_required":true,"ticket":"link-ticket","message":"Enter your NewsBlur password"}"""))
            advanceUntilIdle()
        }
        assertEquals("link", model.state.value.continuation)
        assertEquals("Enter your NewsBlur password", model.state.value.error)
        assertNull(model.state.value.activeProvider)
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } throws IOException("Incorrect NewsBlur password")
        model.submit("reader", "wrong", "")
        advanceUntilIdle()
        assertEquals("Incorrect NewsBlur password", model.state.value.error)
        assertNull(model.state.value.activeProvider)
    }

    @Test fun test_replayed_callback_after_recreation_preserves_continuation_ticket_and_form_status() = runTest(dispatcher) {
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } returns
            response("""{"url":"https://provider.example/authorize"}""")
        for (continuation in listOf("link", "username")) {
            val requests = mutableListOf<Map<String, String>>()
            coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } answers {
                val values = secondArg<Map<String, String>>()
                requests.add(values.toMap())
                if (requests.size == 1) {
                    response("""{"${continuation}_required":true,"ticket":"continuation-ticket"}""")
                } else if (values["ticket"] == "browser-ticket") {
                    throw IOException("This sign-in ticket has already been used")
                } else {
                    throw IOException("Check your NewsBlur details")
                }
            }
            val saved = SavedStateHandle()
            val model = model(saved)
            model.social("google")
            advanceUntilIdle()
            model.browserOpened()
            model.callback(callback())
            advanceUntilIdle()
            assertEquals(continuation, model.state.value.continuation)

            val restored = SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) })
            val recreated = model(restored)
            recreated.callback(callback())
            advanceUntilIdle()

            assertEquals(continuation, recreated.state.value.continuation)
            assertNull(recreated.state.value.activeProvider)
            assertNull(recreated.state.value.error)
            assertEquals("continuation-ticket", restored.get<String>("ticket"))
            assertEquals(1, requests.size)
            recreated.submit("reader", "password", "")
            advanceUntilIdle()
            assertEquals("continuation-ticket", requests.last()["ticket"])
            assertEquals("Check your NewsBlur details", recreated.state.value.error)
            assertNull(recreated.state.value.activeProvider)
        }
    }

    @Test fun test_restored_continuation_owns_status_even_with_stale_provider_owner() {
        for (continuation in listOf("link", "username")) {
            val saved = SavedStateHandle(mapOf(
                "continuation" to continuation,
                "status_provider" to "google",
                "provider" to "google",
                "ticket" to "continuation-ticket",
            ))
            val model = model(saved)
            assertNull(model.state.value.activeProvider)
            model.browserUnavailable()
            assertNotNull(model.state.value.error)
            assertNull(model.state.value.activeProvider)
            assertEquals(continuation, model.state.value.continuation)
        }
    }
}
