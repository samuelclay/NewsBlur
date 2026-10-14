package com.newsblur.onboarding

import android.content.Context
import android.content.SharedPreferences
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.LanguageSettings
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException

class OnboardingApiTest {
    private fun api(
        status: Int,
        body: String,
        contentType: String,
        onRequest: (Request) -> Unit = {},
    ): OnboardingApi {
        val prefs = mockk<PrefsRepo>()
        every { prefs.getCustomServer() } returns null
        every { prefs.getCookie() } returns null
        every { prefs.getUniqueLoginKey() } returns null
        val client = OkHttpClient.Builder().addInterceptor { chain ->
            onRequest(chain.request())
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1)
                .code(status).message("Fixture")
                .body(body.toResponseBody(contentType.toMediaType())).build()
        }.build()
        val languagePrefs = mockk<SharedPreferences>()
        every { languagePrefs.getString(LanguageSettings.KEY, "auto") } returns "fr"
        val context = mockk<Context>()
        every { context.getSharedPreferences(PrefConstants.PREFERENCES, 0) } returns languagePrefs
        return OnboardingApi(client, prefs, context)
    }

    @Test fun requestsCarryTheAppLanguage() = runTest {
        // OnboardingApiTest.kt checks that social sign-in and setup errors come back in the language the app shows.
        var acceptLanguage: String? = null
        api(200, """{"code":1}""", "application/json", onRequest = { acceptLanguage = it.header("Accept-Language") })
            .request("/api/social/account")
        assertEquals("fr", acceptLanguage)
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
