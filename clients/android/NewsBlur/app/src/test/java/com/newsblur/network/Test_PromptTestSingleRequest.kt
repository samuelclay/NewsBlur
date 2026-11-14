package com.newsblur.network

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkInfo
import android.text.TextUtils
import com.google.gson.Gson
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.io.InputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

// Test_PromptTestSingleRequest.kt: apps/analyzer/views.py test_prompt_classifier bills every run,
// so ClassifierApiImpl.kt sends one request per tap even when the run times out or its response
// is lost, either of which can happen after the server already billed. A local socket server
// counts the requests; nothing reaches NewsBlur.
class Test_PromptTestSingleRequest {
    private val server = ServerSocket(0)
    private val requests = AtomicInteger()
    private val release = CountDownLatch(1)
    private val readTimeouts = mutableListOf<Int>()

    @Before
    fun setUp() {
        mockkStatic(TextUtils::class, android.util.Log::class)
        every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
        every { android.util.Log.e(any(), any<String>()) } returns 0
        every { android.util.Log.e(any(), any<String>(), any()) } returns 0
        every { android.util.Log.i(any(), any<String>()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0
        every { android.util.Log.d(any(), any<String>()) } returns 0
        every { android.util.Log.getStackTraceString(any()) } returns ""
        every { android.util.Log.isLoggable(any(), any()) } returns false
    }

    @After
    fun tearDown() {
        release.countDown()
        server.close()
        APIConstants.unsetCustomServer()
        unmockkStatic(TextUtils::class, android.util.Log::class)
    }

    /** Accepts every connection, reads one request and then [answer]s it on its own thread. */
    private fun serve(answer: (Socket) -> Unit) {
        thread(isDaemon = true) {
            while (!server.isClosed) {
                val socket = runCatching { server.accept() }.getOrNull() ?: break
                thread(isDaemon = true) {
                    socket.use {
                        readRequest(it.getInputStream())
                        requests.incrementAndGet()
                        answer(it)
                    }
                }
            }
        }
    }

    // [callTimeoutMillis] stands in for the 120 second read timeout, which a test can't wait out.
    private fun classifierApi(callTimeoutMillis: Long = 0): ClassifierApiImpl {
        val client =
            OkHttpClient
                .Builder()
                .callTimeout(callTimeoutMillis, TimeUnit.MILLISECONDS)
                .addNetworkInterceptor { chain ->
                    synchronized(readTimeouts) { readTimeouts += chain.readTimeoutMillis() }
                    chain.proceed(chain.request())
                }.build()
        val prefsRepo = mockk<PrefsRepo> { every { getCustomServer() } returns null }
        APIConstants.setCustomServer("http://127.0.0.1:${server.localPort}")
        return ClassifierApiImpl(Gson(), NetworkClientImpl(onlineContext(), client, "test-agent", prefsRepo))
    }

    private val request = PromptTestRequest("Charts", "1:a", "1", includeImages = true, hidden = false)

    @Test
    fun test_a_timed_out_prompt_test_is_sent_once() =
        runBlocking {
            serve { release.await(10, TimeUnit.SECONDS) }

            val result = classifierApi(callTimeoutMillis = 500).testPrompt(request)

            assertFalse(result.isSuccess)
            assertEquals("A timed out run may have billed, so it is never sent again", 1, requests.get())
            assertEquals(
                "Image tests get the two minutes config/gunicorn_conf.py allows",
                listOf(ClassifierApiImpl.PROMPT_TEST_TIMEOUT_SECONDS.toInt() * 1000),
                readTimeouts,
            )
        }

    @Test
    fun test_a_prompt_test_whose_response_is_lost_is_sent_once() =
        runBlocking {
            // The socket closes without a response, like a connection dropped mid-classification.
            serve { }

            val result = classifierApi().testPrompt(request)

            assertFalse(result.isSuccess)
            assertEquals(1, requests.get())
        }

    @Test
    fun test_a_gateway_timeout_is_not_retried() =
        runBlocking {
            // HAProxy answers 504 after 30 seconds while gunicorn keeps classifying, and billing.
            serve { it.getOutputStream().write("HTTP/1.1 504 Gateway Timeout\r\nContent-Length: 0\r\n\r\n".toByteArray()) }

            val result = classifierApi().testPrompt(request)

            assertFalse(result.isSuccess)
            assertEquals(1, requests.get())
        }

    // Reads the headers and the form body the request's Content-Length announces.
    private fun readRequest(input: InputStream) {
        val headers = StringBuilder()
        while (!headers.endsWith("\r\n\r\n")) {
            val byte = input.read()
            if (byte < 0) return
            headers.append(byte.toChar())
        }
        val length =
            headers
                .lines()
                .firstOrNull { it.startsWith("Content-Length:", ignoreCase = true) }
                ?.substringAfter(":")
                ?.trim()
                ?.toInt() ?: 0
        repeat(length) { input.read() }
    }

    private fun onlineContext(): Context {
        val networkInfo = mockk<NetworkInfo> { every { isConnected } returns true }
        val connectivityManager = mockk<ConnectivityManager> { every { activeNetworkInfo } returns networkInfo }
        val sharedPreferences = mockk<SharedPreferences>()
        every { sharedPreferences.getString(any(), any()) } returns null
        every { sharedPreferences.getString("language", "auto") } returns "en"
        return mockk {
            every { getSystemService(Context.CONNECTIVITY_SERVICE) } returns connectivityManager
            every { getSharedPreferences(any(), any()) } returns sharedPreferences
        }
    }
}
