package com.newsblur.network

import android.content.ContentValues
import android.content.Context
import com.newsblur.di.ApiOkHttpClient
import com.newsblur.domain.ValueMultimap
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import com.newsblur.util.NetworkUtils
import com.newsblur.util.PrefConstants
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.tls.HandshakeCertificates
import java.io.ByteArrayInputStream
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import kotlin.math.pow
import kotlin.math.roundToInt

class NetworkClientImpl(
    private val context: Context,
    @param:ApiOkHttpClient
    private val client: OkHttpClient,
    private val prefsRepo: PrefsRepo,
    initialUserAgent: String,
) : NetworkClient {
    private var customUserAgent: String = initialUserAgent

    @Volatile
    private var selfHostedClient: OkHttpClient? = null

    @Volatile
    private var selfHostedHost: String? = null

    @Volatile
    private var selfHostedPemHash: Int? = null

    init {
        APIConstants.setCustomServer(prefsRepo.getCustomServer())
    }

    override suspend fun get(urlString: String): APIResponse {
        var response: APIResponse
        var tryCount = 0
        do {
            backoffSleep(tryCount++)
            response = getSingle(urlString)
        } while ((response.isError) && (tryCount < AppConstants.MAX_API_TRIES))
        return response
    }

    override suspend fun get(
        urlString: String,
        values: ContentValues,
    ): APIResponse = get(urlString + "?" + builderGetParametersString(values))

    override suspend fun get(
        urlString: String,
        valueMap: ValueMultimap,
    ): APIResponse = get(urlString + "?" + valueMap.getParameterString())

    override suspend fun post(
        urlString: String,
        formBody: RequestBody,
    ): APIResponse {
        var response: APIResponse
        var tryCount = 0
        do {
            backoffSleep(tryCount++)
            response = postSingle(urlString, formBody)
        } while ((response.isError) && (tryCount < AppConstants.MAX_API_TRIES))
        return response
    }

    override suspend fun post(
        urlString: String,
        values: ContentValues,
    ): APIResponse {
        val formEncodingBuilder = FormBody.Builder()
        for (entry in values.valueSet()) {
            formEncodingBuilder.add(entry.key, entry.value as String)
        }
        return post(urlString, formEncodingBuilder.build())
    }

    override suspend fun post(
        urlString: String,
        valueMap: ValueMultimap,
    ): APIResponse = post(urlString, valueMap.asFormEncodedRequestBody())

    override fun updateCustomUserAgent(customUserAgent: String) {
        this.customUserAgent = customUserAgent
    }

    override fun addCookieHeader(requestBuilder: Request.Builder) {
        val preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0)
        val cookie = preferences.getString(PrefConstants.PREF_COOKIE, null)
        if (cookie != null) {
            requestBuilder.header("Cookie", cookie)
        }
    }

    override fun builderGetParametersString(values: ContentValues): String {
        val parameters = mutableListOf<String>()
        for (entry in values.valueSet()) {
            val builder = StringBuilder()
            builder.append(entry.key)
            builder.append("=")
            builder.append(NetworkUtils.encodeURL(entry.value as String))
            parameters.add(builder.toString())
        }
        return parameters.joinToString("&")
    }

    private fun getSingle(urlString: String): APIResponse {
        if (!NetworkUtils.isOnline(context)) {
            return APIResponse()
        }

        val requestBuilder = Request.Builder().url(urlString)
        addCookieHeader(requestBuilder)
        requestBuilder.header("User-Agent", customUserAgent)

        val chosenClient = clientForUrl(urlString)
        return APIResponse(chosenClient, requestBuilder.build())
    }

    private fun postSingle(
        urlString: String,
        formBody: RequestBody,
    ): APIResponse {
        if (!NetworkUtils.isOnline(context)) {
            return APIResponse()
        }

        if (AppConstants.VERBOSE_LOG_NET) {
            Log.d(this.javaClass.name, "API POST $urlString")
            var body = ""
            try {
                val buffer = okio.Buffer()
                formBody.writeTo(buffer)
                body = buffer.readUtf8()
            } catch (_: Exception) {
                // this is debug code, do not raise
            }
            android.util.Log.d(this.javaClass.name, "post body: $body")
        }

        val requestBuilder = Request.Builder().url(urlString)
        addCookieHeader(requestBuilder)
        requestBuilder.post(formBody)

        val chosenClient = clientForUrl(urlString)
        return APIResponse(chosenClient, requestBuilder.build())
    }

    /**
     * Pause for the sake of exponential retry-backoff as apropriate before the Nth call as counted
     * by the zero-indexed tryCount.
     */
    private fun backoffSleep(tryCount: Int) {
        if (tryCount == 0) return
        Log.i(this.javaClass.name, "API call failed, pausing before retry number $tryCount")
        try {
            // simply double the base sleep time for each subsequent try
            val factor = 2.0.pow(tryCount.toDouble()).roundToInt()
            Thread.sleep(AppConstants.API_BACKOFF_BASE_MILLIS * factor)
        } catch (_: InterruptedException) {
            Log.w(this.javaClass.name, "Abandoning API backoff due to interrupt.")
        }
    }

    private fun parsePemCert(pem: String): X509Certificate {
        val clean =
            pem
                .replace("-----BEGIN CERTIFICATE-----", "")
                .replace("-----END CERTIFICATE-----", "")
                .replace("\\s".toRegex(), "")
        val decoded = android.util.Base64.decode(clean, android.util.Base64.DEFAULT)
        val cf = CertificateFactory.getInstance("X.509")
        return cf.generateCertificate(ByteArrayInputStream(decoded)) as X509Certificate
    }

    fun buildClientWithCustomCa(
        base: OkHttpClient,
        customCaPem: String,
    ): OkHttpClient {
        val cert = parsePemCert(customCaPem)

        val handshakeCertificates =
            HandshakeCertificates
                .Builder()
                .addPlatformTrustedCertificates()
                .addTrustedCertificate(cert)
                .build()

        return base
            .newBuilder()
            .sslSocketFactory(
                handshakeCertificates.sslSocketFactory(),
                handshakeCertificates.trustManager,
            ).build()
    }

    private fun clientForUrl(urlString: String): OkHttpClient {
        val url = urlString.toHttpUrlOrNull() ?: return client

        val customServer = prefsRepo.getCustomServer()?.toHttpUrlOrNull()
        val customHost = customServer?.host ?: return client
        if (url.host != customHost) return client

        val pem = prefsRepo.getCustomServerCaPem()
        if (pem.isNullOrBlank()) return client

        val pemHash = pem.hashCode()
        val cached = selfHostedClient
        if (cached != null && selfHostedHost == customHost && selfHostedPemHash == pemHash) {
            return cached
        }

        return try {
            val built = buildClientWithCustomCa(client, pem)
            selfHostedHost = customHost
            selfHostedPemHash = pemHash
            selfHostedClient = built
            built
        } catch (_: Exception) {
            // Fail safe: return default; the request will fail with normal TLS error instead of crashing
            client
        }
    }
}
