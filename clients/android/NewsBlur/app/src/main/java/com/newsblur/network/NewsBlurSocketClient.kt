package com.newsblur.network

import android.os.Handler
import android.os.Looper
import com.newsblur.di.ApiOkHttpClient
import com.newsblur.preference.PrefsRepo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NewsBlurSocketClient
    @Inject
    constructor(
        private val prefsRepo: PrefsRepo,
        @ApiOkHttpClient private val okHttpClient: OkHttpClient,
    ) {
        private val lock = Any()
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        private val mainHandler = Handler(Looper.getMainLooper())
        private val eventHandlers = linkedMapOf<String, MutableList<(Any?) -> Unit>>()

        private var webSocket: WebSocket? = null
        private var pingTimeoutJob: Job? = null
        private var reconnectJob: Job? = null

        private var username: String? = null
        private var feeds: List<String> = emptyList()
        private var isConnected = false
        private var isConnecting = false
        private var reconnectAttempts = 0
        private var connectionGeneration = 0
        private var serverPingIntervalMs = 30_000L
        private var serverPingTimeoutMs = 120_000L

        val connected: Boolean
            get() = synchronized(lock) { isConnected }

        fun connect(
            username: String,
            feeds: List<String> = emptyList(),
        ) {
            val generation: Int
            synchronized(lock) {
                if ((isConnected || isConnecting) && this.username == username && this.feeds == feeds) {
                    return
                }
                this.username = username
                this.feeds = feeds
                isConnecting = true
                connectionGeneration += 1
                generation = connectionGeneration
                tearDownConnectionLocked()
            }

            val request = Request.Builder().url(buildSocketUrl()).build()
            webSocket =
                okHttpClient.newWebSocket(
                    request,
                    object : WebSocketListener() {
                        override fun onOpen(
                            webSocket: WebSocket,
                            response: Response,
                        ) = Unit

                        override fun onMessage(
                            webSocket: WebSocket,
                            text: String,
                        ) {
                            if (!isCurrentGeneration(generation)) return
                            handleMessage(text)
                        }

                        override fun onClosing(
                            webSocket: WebSocket,
                            code: Int,
                            reason: String,
                        ) {
                            webSocket.close(code, reason)
                        }

                        override fun onClosed(
                            webSocket: WebSocket,
                            code: Int,
                            reason: String,
                        ) {
                            if (!isCurrentGeneration(generation)) return
                            handleDisconnect()
                        }

                        override fun onFailure(
                            webSocket: WebSocket,
                            t: Throwable,
                            response: Response?,
                        ) {
                            if (!isCurrentGeneration(generation)) return
                            handleDisconnect()
                        }
                    },
                )
        }

        fun disconnect() {
            synchronized(lock) {
                reconnectAttempts = 0
                isConnected = false
                isConnecting = false
                username = null
                feeds = emptyList()
                tearDownConnectionLocked()
            }
        }

        fun subscribe(
            event: String,
            handler: (Any?) -> Unit,
        ) {
            synchronized(lock) {
                val handlers = eventHandlers.getOrPut(event) { mutableListOf() }
                handlers += handler
            }
        }

        fun unsubscribe(event: String) {
            synchronized(lock) {
                eventHandlers.remove(event)
            }
        }

        private fun buildSocketUrl(): String {
            val baseUrl = prefsRepo.getCustomServer()?.takeIf { it.isNotBlank() } ?: "https://newsblur.com"
            val socketBase =
                baseUrl
                    .removeSuffix("/")
                    .replaceFirst("https://", "wss://")
                    .replaceFirst("http://", "ws://")

            return "$socketBase/v3/socket.io/?EIO=4&transport=websocket"
        }

        private fun handleMessage(message: String) {
            if (message.isEmpty()) return

            when (message.first()) {
                '0' -> {
                    parseOpenPacket(message.drop(1))
                    completeConnection()
                }

                '2' -> {
                    sendRawMessage("3")
                    resetPingTimeout()
                }

                '4' -> handleSocketIoPacket(message.drop(1))
                '6' -> Unit
            }
        }

        private fun parseOpenPacket(jsonBody: String) {
            runCatching {
                val packet = JSONObject(jsonBody)
                serverPingIntervalMs = packet.optLong("pingInterval", serverPingIntervalMs)
                serverPingTimeoutMs = packet.optLong("pingTimeout", serverPingTimeoutMs)
            }
        }

        private fun handleSocketIoPacket(message: String) {
            if (message.isEmpty()) return

            when (message.first()) {
                '0' -> subscribeToFeeds()
                '1' -> handleDisconnect()
                '2' -> handleEvent(message.drop(1))
            }
        }

        private fun handleEvent(message: String) {
            val payload = runCatching { JSONArray(message) }.getOrNull() ?: return
            val eventName = payload.optString(0)
            val eventData = if (payload.length() > 1) jsonValueToAny(payload.opt(1)) else null
            val handlers =
                synchronized(lock) {
                    eventHandlers[eventName]?.toList()
                } ?: return

            mainHandler.post {
                handlers.forEach { it(eventData) }
            }
        }

        private fun completeConnection() {
            synchronized(lock) {
                isConnecting = false
                isConnected = true
                reconnectAttempts = 0
            }
            cancelReconnect()
            resetPingTimeout()
            sendRawMessage("40")
        }

        private fun subscribeToFeeds() {
            val currentUsername: String
            val currentFeeds: List<String>
            synchronized(lock) {
                currentUsername = username ?: return
                currentFeeds = feeds
            }

            val payload = JSONArray().apply {
                put("subscribe:feeds")
                put(JSONArray(currentFeeds))
                put(currentUsername)
            }
            sendRawMessage("42$payload")
        }

        private fun resetPingTimeout() {
            pingTimeoutJob?.cancel()
            pingTimeoutJob =
                scope.launch {
                    delay(serverPingIntervalMs + serverPingTimeoutMs)
                    handleDisconnect()
                }
        }

        private fun handleDisconnect() {
            val shouldReconnect: Boolean
            synchronized(lock) {
                shouldReconnect = username != null
                isConnected = false
                isConnecting = false
                tearDownConnectionLocked()
            }
            if (shouldReconnect) {
                scheduleReconnect()
            }
        }

        private fun scheduleReconnect() {
            reconnectJob?.cancel()
            val reconnectUsername: String
            val reconnectFeeds: List<String>
            val delaySeconds: Long
            synchronized(lock) {
                reconnectUsername = this.username ?: return
                reconnectFeeds = this.feeds
                reconnectAttempts += 1
                delaySeconds = minOf(reconnectAttempts * 2L, 30L)
            }

            reconnectJob =
                scope.launch {
                    delay(delaySeconds * 1000L)
                    connect(reconnectUsername, reconnectFeeds)
                }
        }

        private fun cancelReconnect() {
            reconnectJob?.cancel()
            reconnectJob = null
        }

        private fun sendRawMessage(message: String) {
            webSocket?.send(message)
        }

        private fun isCurrentGeneration(generation: Int): Boolean =
            synchronized(lock) {
                generation == connectionGeneration
            }

        private fun tearDownConnectionLocked() {
            pingTimeoutJob?.cancel()
            pingTimeoutJob = null
            reconnectJob?.cancel()
            reconnectJob = null
            webSocket?.cancel()
            webSocket = null
        }

        private fun jsonValueToAny(value: Any?): Any? =
            when (value) {
                null, JSONObject.NULL -> null
                is JSONObject -> {
                    buildMap {
                        val keys = value.keys()
                        while (keys.hasNext()) {
                            val key = keys.next()
                            put(key, jsonValueToAny(value.opt(key)))
                        }
                    }
                }

                is JSONArray -> {
                    buildList {
                        for (index in 0 until value.length()) {
                            add(jsonValueToAny(value.opt(index)))
                        }
                    }
                }

                else -> value
            }
    }
