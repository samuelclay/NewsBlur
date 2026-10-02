package com.newsblur.network

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkInfo
import android.text.TextUtils
import com.newsblur.domain.ValueMultimap
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.Call
import okhttp3.EventListener
import okhttp3.OkHttpClient
import org.junit.Assert.*
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class Test_CancellableGet {
    @Test fun test_timeout_cancels_real_socket_waiting_for_headers_or_body() = runBlocking {
        mockkStatic(TextUtils::class, android.util.Log::class)
        every { TextUtils.isEmpty(any()) } answers { firstArg<CharSequence?>().isNullOrEmpty() }
        every { TextUtils.join(any(), any<Iterable<*>>()) } answers { secondArg<Iterable<*>>().joinToString(firstArg()) }
        every { android.util.Log.w(any(), any<String>()) } returns 0
        try {
            listOf(false, true).forEach { sendPartialBody ->
                ServerSocket(0).use { server ->
                    val requestArrived = CountDownLatch(1)
                    val releaseServer = CountDownLatch(1)
                    val cancelled = CountDownLatch(1)
                    val worker = thread(isDaemon = true) {
                        server.accept().use { socket ->
                            val reader = socket.getInputStream().bufferedReader()
                            while (reader.readLine()?.isNotEmpty() == true) Unit
                            if (sendPartialBody) {
                                socket.getOutputStream().write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n{".toByteArray())
                                socket.getOutputStream().flush()
                            }
                            requestArrived.countDown()
                            releaseServer.await(3, TimeUnit.SECONDS)
                        }
                    }
                    val client = OkHttpClient.Builder().eventListener(object : EventListener() {
                        override fun canceled(call: Call) { cancelled.countDown() }
                    }).build()
                    val network = NetworkClientImpl(onlineContext(), client, "test-agent", mockk<PrefsRepo> { every { getCustomServer() } returns null })
                    try {
                        val started = System.nanoTime()
                        val request = async(Dispatchers.IO) {
                            withTimeoutOrNull(500) { network.getCancellable("http://127.0.0.1:${server.localPort}/feed", ValueMultimap()) }
                        }
                        assertTrue("Real HTTP request must begin", requestArrived.await(2, TimeUnit.SECONDS))
                        assertNull(request.await())
                        assertTrue("Coroutine cancellation must cancel OkHttp", cancelled.await(1, TimeUnit.SECONDS))
                        assertTrue("Network wait must respect the coroutine deadline", TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 2_000)
                    } finally {
                        releaseServer.countDown()
                        worker.join(2_000)
                        client.dispatcher.executorService.shutdown()
                        client.dispatcher.executorService.awaitTermination(2, TimeUnit.SECONDS)
                    }
                }
            }
        } finally {
            unmockkStatic(TextUtils::class, android.util.Log::class)
        }
    }

    private fun onlineContext(): Context {
        val network = mockk<NetworkInfo> { every { isConnected } returns true }
        val manager = mockk<ConnectivityManager> { every { activeNetworkInfo } returns network }
        val preferences = mockk<SharedPreferences> { every { getString(any(), any()) } returns null }
        return mockk {
            every { getSystemService(Context.CONNECTIVITY_SERVICE) } returns manager
            every { getSharedPreferences(any(), any()) } returns preferences
        }
    }
}
