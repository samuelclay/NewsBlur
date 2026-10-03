package com.newsblur.onboarding

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.newsblur.di.ApiOkHttpClient
import com.newsblur.discover.number
import com.newsblur.discover.string
import com.newsblur.preference.PrefsRepo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import javax.inject.Inject

// OnboardingApi.kt captures the account and server before work is queued, so a later login cannot receive it.
data class SetupAccount(
    val server: String,
    val cookie: String?,
    val generation: String?,
)

data class SetupResponse(
    val json: JsonObject,
    val cookie: String?,
)

class OnboardingApi
    @Inject
    constructor(
        @ApiOkHttpClient client: OkHttpClient,
        private val prefs: PrefsRepo,
    ) {
        private val client = client.newBuilder().retryOnConnectionFailure(false).build()

        fun account() =
            SetupAccount(
                prefs.getCustomServer()?.takeIf {
                    it.isNotBlank()
                } ?: "https://newsblur.com",
                prefs.getCookie(),
                prefs.getUniqueLoginKey(),
            )

        fun isCurrent(account: SetupAccount) = account == account()

        suspend fun request(
            path: String,
            values: Map<String, String> = emptyMap(),
            post: Boolean = false,
            account: SetupAccount = account(),
            body: RequestBody? = null,
            allowMissing: Boolean = false,
        ): SetupResponse? =
            withContext(Dispatchers.IO) {
                check(isCurrent(account)) { "Your account changed. Reopen setup to continue." }
                val url = (account.server.trimEnd('/') + path).toHttpUrl().newBuilder()
                if (!post) values.forEach { (key, value) -> url.addQueryParameter(key, value) }
                val request =
                    Request
                        .Builder()
                        .url(url.build())
                        .header("User-Agent", "NewsBlur Android")
                        .header("Cache-Control", "no-cache")
                account.cookie?.let { request.header("Cookie", it) }
                if (post) request.post(body ?: FormBody.Builder().apply { values.forEach { (k, v) -> add(k, v) } }.build())
                client.newCall(request.build()).execute().use { response ->
                    if (allowMissing &&
                        (
                            response.code == 404 ||
                                (
                                    !post &&
                                        response.isSuccessful &&
                                        response
                                            .header(
                                                "Content-Type",
                                            ).orEmpty()
                                            .contains("text/html")
                                )
                        )
                    ) {
                        return@withContext null
                    }
                    val json =
                        try {
                            JsonParser.parseString(response.body?.string()).asJsonObject
                        } catch (_: Exception) {
                            throw IOException("The server returned an unreadable response. Please try again.")
                        }
                    val continuation = json.string("link_required") == "true" || json.string("username_required") == "true"
                    if ((!response.isSuccessful || json.number("code") < 0) && !continuation) {
                        throw IOException(
                            json.string("message").ifBlank {
                                json.get("errors")?.toString()?.filter { it != '[' && it != ']' && it != '"' }
                                    ?: "The request failed. Please try again."
                            },
                        )
                    }
                    check(isCurrent(account)) { "Your account changed. Reopen setup to continue." }
                    SetupResponse(
                        json,
                        response
                            .headers("Set-Cookie")
                            .map { it.substringBefore(';') }
                            .joinToString("; ")
                            .takeIf { it.isNotBlank() },
                    )
                }
            }

        suspend fun thumbnail(address: String): android.graphics.Bitmap? =
            withContext(Dispatchers.IO) {
                val url = address.takeIf { it.startsWith("https://") || it.startsWith("http://") } ?: return@withContext null
                // OnboardingApi.kt never sends account cookies to external artwork hosts.
                client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                    if (!response.isSuccessful) return@withContext null
                    val body = response.body ?: return@withContext null
                    if (body.contentLength() > 2_000_000) return@withContext null
                    val output = java.io.ByteArrayOutputStream()
                    val input = body.byteStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > 2_000_000) return@withContext null
                        output.write(buffer, 0, count)
                    }
                    val data = output.toByteArray()
                    OnboardingCatalog.bitmap(android.util.Base64.encodeToString(data, android.util.Base64.NO_WRAP))
                }
            }

        suspend fun import(
            data: ByteArray,
            account: SetupAccount,
        ): JsonObject {
            val body =
                MultipartBody
                    .Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("file", "subscriptions.opml", data.toRequestBody())
                    .build()
            return request("/import/opml_upload", post = true, body = body, account = account)!!.json
        }
    }
