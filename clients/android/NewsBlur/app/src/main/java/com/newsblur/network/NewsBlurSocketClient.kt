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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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

        // NewsBlurSocketClient.kt: node/unread_counts.coffee emits feed and user events as
        // (channel, message), so realtime handlers get every argument, not just the first.
        private val argumentHandlers = linkedMapOf<String, MutableList<(List<Any?>) -> Unit>>()
        private val _subscribed = MutableStateFlow(false)

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

        /** True once the server has acknowledged `subscribe:feeds` on the current connection. */
        val subscribed: StateFlow<Boolean> = _subscribed.asStateFlow()

        /**
         * Connects as [username], or updates the subscribed feeds on the open connection.
         * Null [feeds] keeps the current subscription, so Ask AI (AskAiViewModel.kt) can make sure
         * the socket is up without replacing the feeds RealtimeUpdates.kt subscribed to.
         */
        fun connect(
            username: String,
            feeds: List<String>? = null,
        ) {
            val generation: Int
            synchronized(lock) {
                if ((isConnected || isConnecting) && this.username == username) {
                    if (feeds == null || this.feeds == feeds) return
                    this.feeds = feeds
                    // A connection still opening subscribes with the new list once Socket.IO connects.
                    if (!isConnected) return
                    generation = -1
                } else {
                    if (this.username != username) this.feeds = emptyList()
                    this.username = username
                    if (feeds != null) this.feeds = feeds
                    isConnecting = true
                    connectionGeneration += 1
                    generation = connectionGeneration
                    tearDownConnectionLocked()
                }
            }
            if (generation == -1) {
                // node/unread_counts.coffee replaces the Redis subscriber on a repeated subscribe:feeds.
                subscribeToFeeds()
                return
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
                connectionGeneration += 1
                tearDownConnectionLocked()
            }
            _subscribed.value = false
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

        /** Like [subscribe], but [handler] receives every event argument, e.g. (channel, message). */
        fun subscribeArguments(
            event: String,
            handler: (List<Any?>) -> Unit,
        ) {
            synchronized(lock) {
                argumentHandlers.getOrPut(event) { mutableListOf() } += handler
            }
        }

        fun unsubscribeArguments(event: String) {
            synchronized(lock) {
                argumentHandlers.remove(event)
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
            val arguments = (1 until payload.length()).map { jsonValueToAny(payload.opt(it)) }
            val (handlers, argHandlers) =
                synchronized(lock) {
                    eventHandlers[eventName]?.toList().orEmpty() to argumentHandlers[eventName]?.toList().orEmpty()
                }
            if (handlers.isEmpty() && argHandlers.isEmpty()) return

            mainHandler.post {
                handlers.forEach { it(arguments.firstOrNull()) }
                argHandlers.forEach { it(arguments) }
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
            _subscribed.value = true
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
            _subscribed.value = false
            if (shouldReconnect) {
                scheduleReconnect()
            }
        }

        private fun scheduleReconnect() {
            reconnectJob?.cancel()
            val reconnectUsername: String
            val delaySeconds: Long
            synchronized(lock) {
                reconnectUsername = this.username ?: return
                reconnectAttempts += 1
                delaySeconds = minOf(reconnectAttempts * 2L, 30L)
            }

            reconnectJob =
                scope.launch {
                    delay(delaySeconds * 1000L)
                    // The stored feed list is kept, including any update made while disconnected.
                    connect(reconnectUsername)
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
