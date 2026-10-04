package com.newsblur.onboarding

import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException

class OnboardingApiTest {
    private fun api(status: Int, body: String, contentType: String): OnboardingApi {
        val prefs = mockk<PrefsRepo>()
        every { prefs.getCustomServer() } returns null
        every { prefs.getCookie() } returns null
        every { prefs.getUniqueLoginKey() } returns null
        val client = OkHttpClient.Builder().addInterceptor { chain ->
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1)
                .code(status).message("Fixture")
                .body(body.toResponseBody(contentType.toMediaType())).build()
        }.build()
        return OnboardingApi(client, prefs)
    }

    @Test fun missingSocialEndpointExplainsThatSignInIsUnavailable() = runTest {
        // OnboardingApiTest.kt reproduces production's HTML 404 for both provider buttons.
        for (provider in listOf("apple", "google")) {
            try {
                api(404, "<html><body>Not found</body></html>", "text/html")
                    .request("/api/social/start", mapOf("provider" to provider), post = true)
                fail("An undeployed social endpoint must not succeed")
            } catch (error: IOException) {
                assertEquals(
                    "Apple and Google sign-in are not available on this server yet. Please sign in with your NewsBlur username and password.",
                    error.message,
                )
            }
        }
    }

    @Test fun providerConfigurationErrorIsPreserved() = runTest {
        val message = "Google sign-in is not configured on this server yet."
        try {
            api(503, """{"code":-1,"message":"$message"}""", "application/json")
                .request("/api/social/start", mapOf("provider" to "google"), post = true)
            fail("A provider configuration error must not succeed")
        } catch (error: IOException) {
            assertEquals(message, error.message)
        }
    }

    @Test fun structuredSocialNotFoundErrorIsPreserved() = runTest {
        val message = "This sign-in provider is not supported."
        try {
            api(404, """{"code":-1,"message":"$message"}""", "application/json")
                .request("/api/social/start", mapOf("provider" to "google"), post = true)
            fail("A structured server error must not succeed")
        } catch (error: IOException) {
            assertEquals(message, error.message)
        }
    }

    @Test fun otherUnreadableErrorsDoNotClaimSocialSignInIsUnavailable() = runTest {
        for ((path, status) in listOf("/api/social/start" to 500, "/api/login" to 404)) {
            try {
                api(status, "<html><body>Server error</body></html>", "text/html")
                    .request(path, post = true)
                fail("An unreadable server error must not succeed")
            } catch (error: IOException) {
                assertEquals("The server returned an unreadable response. Please try again.", error.message)
            }
        }
    }
}
