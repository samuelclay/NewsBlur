package com.newsblur.network

import android.os.Handler
import android.os.Looper
import com.newsblur.preference.PrefsRepo
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import okhttp3.OkHttpClient
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class Test_NewsBlurSocketClientSubscriptions {
    private val prefsRepo = mockk<PrefsRepo>(relaxed = true)
    private val okHttpClient = mockk<OkHttpClient>()
    private val webSocket = mockk<WebSocket>(relaxed = true)
    private val listener = slot<WebSocketListener>()
    private val sent = mutableListOf<String>()

    @Before
    fun setUp() {
        mockkStatic(Looper::class)
        every { Looper.getMainLooper() } returns mockk()
        mockkConstructor(Handler::class)
        every { anyConstructed<Handler>().post(any()) } answers {
            firstArg<Runnable>().run()
            true
        }
        every { prefsRepo.getCustomServer() } returns null
        every { okHttpClient.newWebSocket(any(), capture(listener)) } returns webSocket
        every { webSocket.send(any<String>()) } answers {
            sent += firstArg<String>()
            true
        }
    }

    @After
    fun tearDown() {
        unmockkConstructor(Handler::class)
        unmockkStatic(Looper::class)
    }

    private fun openConnection(client: NewsBlurSocketClient) {
        listener.captured.onMessage(webSocket, """0{"sid":"abc","pingInterval":30000,"pingTimeout":120000}""")
        listener.captured.onMessage(webSocket, "40")
    }

    @Test
    fun test_ask_ai_connect_keeps_the_feeds_realtime_subscribed() {
        val client = NewsBlurSocketClient(prefsRepo, okHttpClient)
        client.connect("sam", listOf("1", "social:7"))
        openConnection(client)

        // AskAiViewModel.kt only makes sure the socket is up.
        client.connect("sam")
        client.connect("sam", listOf("1", "2", "social:7"))

        verify(exactly = 1) { okHttpClient.newWebSocket(any(), any()) }
        assertEquals(
            listOf(
                """42["subscribe:feeds",["1","social:7"],"sam"]""",
                """42["subscribe:feeds",["1","2","social:7"],"sam"]""",
            ),
            sent.filter { it.startsWith("42") },
        )
    }

    @Test
    fun test_feed_and_user_events_reach_handlers_with_channel_and_message() {
        val client = NewsBlurSocketClient(prefsRepo, okHttpClient)
        val received = mutableListOf<List<Any?>>()
        val firstArguments = mutableListOf<Any?>()
        client.subscribeArguments("user:update") { received += it }
        client.subscribe("user:update") { firstArguments += it }
        client.connect("sam", listOf("1"))
        openConnection(client)

        listener.captured.onMessage(webSocket, """42["user:update","sam","story:read:1:abc"]""")

        assertEquals(listOf(listOf("sam", "story:read:1:abc")), received)
        assertEquals(listOf<Any?>("sam"), firstArguments)
    }
}
