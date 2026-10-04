package com.newsblur.onboarding

import android.util.Base64
import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.preference.PrefsRepo
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class Test_AccountSocialLink {
    private val dispatcher = StandardTestDispatcher()
    private val api = mockk<OnboardingApi>()
    private val prefs = mockk<PrefsRepo>(relaxed = true)
    private val requests = mutableListOf<Map<String, String>>()

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        every { prefs.lastAuthProvider() } returns null
        every { api.account() } returns SetupAccount("https://newsblur.com", null, "generation")
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } answers {
            requests.add(secondArg<Map<String, String>>().toMap())
            throw IOException("Incorrect NewsBlur password")
        }
    }

    @After fun tearDown() {
        unmockkAll()
        Dispatchers.resetMain()
    }

    private fun saved(mode: String = "link") = SavedStateHandle(
        mapOf("continuation" to mode, "ticket" to "provider-ticket", "verifier" to "provider-verifier", "provider" to "google"),
    )

    private fun model(saved: SavedStateHandle) = AccountViewModel(mockk(), api, mockk(), mockk(), prefs, saved)

    @Test fun test_same_email_link_sends_explicit_action_and_newsblur_credentials() = runTest(dispatcher) {
        val model = model(saved())
        model.submit("reader@example.com", "newsblur-password", "")
        advanceUntilIdle()
        assertEquals(
            mapOf("action" to "link", "username" to "reader@example.com", "password" to "newsblur-password",
                "ticket" to "provider-ticket", "verifier" to "provider-verifier"),
            requests.single(),
        )
    }

    @Test fun test_failed_link_retries_with_same_ticket_and_new_credentials() = runTest(dispatcher) {
        val saved = saved()
        val model = model(saved)
        model.submit("reader", "wrong", "")
        advanceUntilIdle()
        assertEquals("Incorrect NewsBlur password", model.state.value.error)
        assertEquals("link", model.state.value.continuation)
        model.submit("other@example.com", "corrected", "")
        advanceUntilIdle()
        assertEquals(2, requests.size)
        assertTrue(requests.all { it["action"] == "link" && it["ticket"] == "provider-ticket" && it["verifier"] == "provider-verifier" })
        assertEquals("other@example.com", requests.last()["username"])
        assertEquals("corrected", requests.last()["password"])
        assertEquals("provider-ticket", saved.get<String>("ticket"))
    }

    @Test fun test_username_signup_does_not_request_linking() = runTest(dispatcher) {
        model(saved("username")).submit("newreader", "", "")
        advanceUntilIdle()
        assertNull(requests.single()["action"])
        assertEquals("newreader", requests.single()["username"])
    }

    @Test fun test_new_provider_attempt_discards_old_link_continuation_even_if_start_fails() = runTest(dispatcher) {
        mockkStatic(Base64::class)
        every { Base64.encodeToString(any(), any()) } returns "new-verifier"
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } throws IOException("Offline")
        val saved = saved()
        val model = model(saved)
        model.updateUsername("previous-reader")
        model.updatePassword("previous-password")
        model.social("apple")
        advanceUntilIdle()
        assertNull(model.state.value.continuation)
        assertNull(saved.get<String>("continuation"))
        assertNull(saved.get<String>("ticket"))
        assertEquals("new-verifier", saved.get<String>("verifier"))
        assertEquals("apple", saved.get<String>("provider"))
        assertEquals("", model.state.value.username)
        assertEquals("", model.state.value.password)
    }

    @Test fun test_switch_to_existing_account_preserves_identity_and_clears_stale_fields() = runTest(dispatcher) {
        val saved = saved("username")
        val model = model(saved)
        model.updateUsername("existingreader")
        model.updatePassword("stale-password")
        model.submit("existingreader", "", "")
        advanceUntilIdle()
        assertNotNull(model.state.value.error)

        model.connectExistingAccount()

        assertEquals("link", model.state.value.continuation)
        assertEquals("existingreader", model.state.value.username)
        assertEquals("", model.state.value.password)
        assertNull(model.state.value.error)
        assertEquals("provider-ticket", saved.get<String>("ticket"))
        assertEquals("provider-verifier", saved.get<String>("verifier"))
        model.submit(model.state.value.username, "newsblur-password", "")
        advanceUntilIdle()
        assertEquals("link", requests.last()["action"])
    }

    @Test fun test_recreation_restores_link_and_username_but_never_password() = runTest(dispatcher) {
        val saved = saved("username")
        val model = model(saved)
        model.updateUsername("different@example.com")
        model.connectExistingAccount()
        model.updatePassword("secret")
        val recreated = model(SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) }))

        assertEquals("link", recreated.state.value.continuation)
        assertEquals("different@example.com", recreated.state.value.username)
        assertEquals("", recreated.state.value.password)
        recreated.submit(recreated.state.value.username, "reentered-password", "")
        advanceUntilIdle()
        assertEquals("link", requests.single()["action"])
        assertEquals("provider-verifier", requests.single()["verifier"])
    }

    @Test fun test_link_retry_uses_replacement_ticket_from_server() = runTest(dispatcher) {
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } answers {
            requests.add(secondArg<Map<String, String>>().toMap())
            SetupResponse(JsonParser.parseString("""{"link_required":true,"ticket":"retry-ticket","message":"Try again"}""").asJsonObject, null)
        }
        val model = model(saved())
        model.submit("existing", "wrong", "")
        advanceUntilIdle()
        model.submit("existing", "retry", "")
        advanceUntilIdle()
        assertEquals("retry-ticket", requests.last()["ticket"])
        assertEquals("link", requests.last()["action"])
        assertEquals("provider-verifier", requests.last()["verifier"])
    }

    @Test fun test_leaving_continuation_clears_saved_mode_and_password() {
        val saved = saved()
        val model = model(saved)
        model.updatePassword("secret")
        model.mode()
        assertEquals("", model.state.value.password)
        assertNull(saved.get<String>("ticket"))
        assertNull(saved.get<String>("verifier"))
        assertNull(model(saved).state.value.continuation)
    }
}
