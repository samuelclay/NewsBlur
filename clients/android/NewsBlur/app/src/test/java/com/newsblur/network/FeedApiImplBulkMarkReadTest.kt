package com.newsblur.network

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkInfo
import android.text.TextUtils
import com.google.gson.Gson
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class FeedApiImplBulkMarkReadTest {
    @Test
    fun bulkMarkReadPostsAllFeedIdsWithoutRetrying() =
        runTest {
            mockkStatic(TextUtils::class)
            every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
            mockkStatic(android.util.Log::class)
            every { android.util.Log.e(any(), any<String>()) } returns 0
            every { android.util.Log.i(any(), any<String>()) } returns 0
            every { android.util.Log.isLoggable(any(), any()) } returns false
            val attempts = AtomicInteger()
            val readTimeouts = mutableListOf<Int>()
            val requestBodies = mutableListOf<String>()
            val client =
                OkHttpClient
                    .Builder()
                    .addInterceptor { chain ->
                        readTimeouts += chain.readTimeoutMillis()
                        requestBodies += chain.request().body!!.utf8()
                        val attempt = attempts.incrementAndGet()
                        Response
                            .Builder()
                            .request(chain.request())
                            .protocol(okhttp3.Protocol.HTTP_1_1)
                            .code(if (attempt == 1) 500 else 200)
                            .message(if (attempt == 1) "Server error" else "OK")
                            .body("{}".toResponseBody("application/json".toMediaType()))
                            .build()
                    }.build()
            val networkClient = NetworkClientImpl(onlineContext(), client, "test-agent", prefsRepo())
            val feedApi = FeedApiImpl(Gson(), networkClient)

            feedApi.markFeedsAsRead(FeedSet.folder("test", setOf("11", "22", "33")), null, null)

            assertEquals("A bulk read mutation must make one HTTP attempt", 1, attempts.get())
            assertEquals("A bulk read mutation must allow the server two minutes to finish", 120_000, readTimeouts.single())
            val requestBody = requestBodies.single()
            assertTrue(requestBody.contains("feed_id=11"))
            assertTrue(requestBody.contains("feed_id=22"))
            assertTrue(requestBody.contains("feed_id=33"))
        }

    @Test
    fun concurrentIdenticalBulkMarkReadCallsShareOneHttpRequest() =
        runBlocking {
            mockkStatic(TextUtils::class)
            every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
            mockkStatic(android.util.Log::class)
            every { android.util.Log.e(any(), any<String>()) } returns 0
            every { android.util.Log.i(any(), any<String>()) } returns 0
            every { android.util.Log.isLoggable(any(), any()) } returns false
            val attempts = AtomicInteger()
            val firstRequestStarted = CountDownLatch(1)
            val secondRequestStarted = CountDownLatch(1)
            val releaseFirstRequest = CountDownLatch(1)
            val client =
                OkHttpClient
                    .Builder()
                    .addInterceptor { chain ->
                        if (attempts.incrementAndGet() == 1) {
                            firstRequestStarted.countDown()
                            releaseFirstRequest.await(5, TimeUnit.SECONDS)
                        } else {
                            secondRequestStarted.countDown()
                        }
                        Response
                            .Builder()
                            .request(chain.request())
                            .protocol(okhttp3.Protocol.HTTP_1_1)
                            .code(200)
                            .message("OK")
                            .body("{}".toResponseBody("application/json".toMediaType()))
                            .build()
                    }.build()
            val networkClient = NetworkClientImpl(onlineContext(), client, "test-agent", prefsRepo())
            val feedApi = FeedApiImpl(Gson(), networkClient)
            val feedSet = FeedSet.folder("test", setOf("11", "22", "33"))

            val first = async(Dispatchers.IO) { feedApi.markFeedsAsRead(feedSet, null, null) }
            assertTrue(firstRequestStarted.await(5, TimeUnit.SECONDS))
            val second = async(Dispatchers.IO) { feedApi.markFeedsAsRead(feedSet, null, null) }

            try {
                assertFalse(
                    "An overlapping sync must join the in-flight bulk mutation",
                    secondRequestStarted.await(500, TimeUnit.MILLISECONDS),
                )
            } finally {
                releaseFirstRequest.countDown()
            }
            awaitAll(first, second)
            assertEquals(1, attempts.get())
        }

    private fun onlineContext(): Context {
        val networkInfo = mockk<NetworkInfo>()
        every { networkInfo.isConnected } returns true
        val connectivityManager = mockk<ConnectivityManager>()
        every { connectivityManager.activeNetworkInfo } returns networkInfo
        val sharedPreferences = mockk<SharedPreferences>()
        every { sharedPreferences.getString(any(), any()) } returns null
        return mockk {
            every { getSystemService(Context.CONNECTIVITY_SERVICE) } returns connectivityManager
            every { getSharedPreferences(any(), any()) } returns sharedPreferences
        }
    }

    private fun prefsRepo(): PrefsRepo =
        mockk {
            every { getCustomServer() } returns null
        }

    private fun okhttp3.RequestBody.utf8(): String =
        okio.Buffer().also { writeTo(it) }.readUtf8()
}
