package com.newsblur.onboarding

import android.util.Base64
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import com.google.gson.JsonParser
import com.newsblur.BuildConfig
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SubscriptionSyncService
import io.mockk.Runs
import io.mockk.coEvery
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
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
        saved["can_choose_username"] = true
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
        assertNotEquals(true, saved.get<Boolean>("can_choose_username"))
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

    @Test fun test_taken_username_can_return_from_link_to_signup_and_complete_after_recreation() = runTest(dispatcher) {
        mockkObject(SubscriptionSyncService.Companion)
        every { SubscriptionSyncService.schedule(any()) } just Runs
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } answers {
            val values = secondArg<Map<String, String>>()
            requests.add(values.toMap())
            if (values["username"] == "taken-reader") {
                SetupResponse(
                    JsonParser.parseString("""{"link_required":true,"can_choose_username":true,"ticket":"collision-ticket","message":"Connect your existing account"}""").asJsonObject,
                    null,
                )
            } else {
                SetupResponse(JsonParser.parseString("""{"username":"available-reader","created":true}""").asJsonObject, "session-cookie")
            }
        }
        val saved = saved("username")
        val model = model(saved)
        model.updateUsername("taken-reader")
        model.submit(model.state.value.username, "", "")
        advanceUntilIdle()
        assertEquals("link", model.state.value.continuation)
        assertNotNull(model.state.value.error)
        assertEquals(true, saved.get<Boolean>("can_choose_username"))
        model.updatePassword("stale-password")

        model.createNewAccountInstead()

        assertEquals("username", model.state.value.continuation)
        assertEquals("", model.state.value.username)
        assertEquals("", model.state.value.password)
        assertNull(model.state.value.error)
        assertEquals("collision-ticket", saved.get<String>("ticket"))
        assertEquals("provider-verifier", saved.get<String>("verifier"))
        assertEquals("google", saved.get<String>("provider"))
        val restored = SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) })
        val recreated = AccountViewModel(mockk(), api, mockk(), mockk(relaxed = true), prefs, restored)
        assertEquals("username", recreated.state.value.continuation)
        assertEquals("", recreated.state.value.username)
        recreated.updateUsername("available-reader")
        recreated.submit(recreated.state.value.username, recreated.state.value.password, "")
        val finished = recreated.state.first { it.authenticated || it.error != null }
        assertNull(finished.error)
        assertTrue(finished.authenticated)
        assertTrue(finished.setup)
        assertEquals(
            mapOf("username" to "available-reader", "password" to "", "ticket" to "collision-ticket", "verifier" to "provider-verifier"),
            requests.last(),
        )
        verify { prefs.saveLogin("available-reader", "session-cookie") }
        verify { prefs.saveLastAuthProvider("google") }
    }

    @Test fun test_mode_switch_preserves_pending_oauth_for_both_provider_callbacks() = runTest(dispatcher) {
        mockkStatic(Base64::class)
        every { Base64.encodeToString(any(), any()) } returns "pending-verifier"
        coEvery { api.request("/api/social/start", any(), true, any(), any(), any()) } returns
            SetupResponse(JsonParser.parseString("""{"url":"https://provider.example/authorize"}""").asJsonObject, null)
        coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } answers {
            requests.add(secondArg<Map<String, String>>().toMap())
            SetupResponse(JsonParser.parseString("""{"username_required":true,"ticket":"continuation-ticket"}""").asJsonObject, null)
        }
        for (provider in listOf("apple", "google")) {
            val saved = SavedStateHandle()
            val model = model(saved)
            model.social(provider)
            advanceUntilIdle()
            model.browserOpened()
            model.browserUnavailable()
            model.updatePassword("stale-password")
            model.mode()
            assertFalse(model.state.value.signup)
            assertNull(model.state.value.error)
            assertEquals("", model.state.value.password)
            assertEquals("pending-verifier", saved.get<String>("verifier"))
            assertEquals(provider, saved.get<String>("provider"))

            val uri = mockk<Uri>()
            every { uri.scheme } returns if (BuildConfig.APPLICATION_ID.endsWith(".alpha")) "newsblur-auth-android-alpha" else "newsblur-auth-android"
            every { uri.host } returns "complete"
            every { uri.getQueryParameter("error") } returns null
            every { uri.getQueryParameter("ticket") } returns "browser-ticket"
            model.callback(uri)
            advanceUntilIdle()
            assertEquals("username", model.state.value.continuation)
            assertEquals("browser-ticket", requests.last()["ticket"])
            assertEquals("pending-verifier", requests.last()["verifier"])
        }
        assertEquals(2, requests.size)
    }

    @Test fun test_server_required_link_blocks_signup_escape_after_recreation() = runTest(dispatcher) {
        for (flag in listOf("", "\"can_choose_username\":false,")) {
            coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } returns
                SetupResponse(JsonParser.parseString("""{${flag}"link_required":true,"ticket":"required-ticket","message":"Password required"}""").asJsonObject, null)
            val saved = saved("username")
            val model = model(saved)
            model.updateUsername("existing-reader")
            model.connectExistingAccount()
            model.submit("existing-reader", "wrong-password", "")
            advanceUntilIdle()
            assertEquals(false, saved.get<Boolean>("can_choose_username"))
            val recreated = model(SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) }))
            recreated.createNewAccountInstead()
            assertEquals("link", recreated.state.value.continuation)
            assertEquals("existing-reader", recreated.state.value.username)
        }
    }

    @Test fun test_explicit_link_and_server_permitted_link_allow_return_after_recreation() = runTest(dispatcher) {
        for (serverPermission in listOf(false, true)) {
            val saved = saved("username")
            val model = model(saved)
            if (serverPermission) {
                coEvery { api.request("/api/social/complete", any(), true, any(), any(), any()) } returns
                    SetupResponse(JsonParser.parseString("""{"link_required":true,"can_choose_username":true,"ticket":"provider-ticket"}""").asJsonObject, null)
                model.submit("taken-reader", "", "")
                advanceUntilIdle()
            } else {
                model.connectExistingAccount()
            }
            assertEquals(true, saved.get<Boolean>("can_choose_username"))
            val restored = SavedStateHandle(saved.keys().associateWith { saved.get<Any?>(it) })
            val recreated = model(restored)
            recreated.createNewAccountInstead()
            assertEquals("username", recreated.state.value.continuation)
            assertEquals("provider-ticket", restored.get<String>("ticket"))
            assertEquals("provider-verifier", restored.get<String>("verifier"))
        }
    }
}
