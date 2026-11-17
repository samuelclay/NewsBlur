//
//  NewsBlurSocketClient.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

/// A reusable Socket.IO client for NewsBlur real-time features.
/// Supports Ask AI streaming, feed updates, and other real-time events.
///
/// Uses Engine.IO v4 protocol where the server initiates ping/pong:
/// - Server sends "2" (ping) at `pingInterval`
/// - Client responds with "3" (pong)
/// - If no ping within `pingInterval + pingTimeout`, connection is dead
@objc class NewsBlurSocketClient: NSObject {
    @objc static let shared = NewsBlurSocketClient()

    // MARK: - Properties

    /// Serial queue for all mutable state access
    private let queue = DispatchQueue(label: "com.newsblur.socketclient", qos: .utility)

    /// Dedicated delegate queue for URLSession (off main thread)
    private let delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.newsblur.socketclient.delegate"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimeoutTimer: DispatchSourceTimer?
    private var reconnectTimer: DispatchSourceTimer?
    private var reconnectAttempts = 0
    /// NewsBlurSocketClient.swift keeps retrying after a long outage at this interval, since the Mac app
    /// stays connected for as long as it runs.
    private let maximumReconnectDelay: TimeInterval = 60

    /// Incremented on each connection attempt to ignore stale callbacks
    private var connectionGeneration: Int = 0

    private var username: String?
    private var feeds: [String] = []
    private var isConnected = false
    private var isConnecting = false
    /// Set by `connect` and cleared by `disconnect`, so a drop only reconnects a socket someone still wants.
    private var shouldReconnect = false
    private var sid: String?

    /// Server-provided ping settings from Engine.IO open packet
    private var serverPingInterval: TimeInterval = 30.0
    private var serverPingTimeout: TimeInterval = 120.0

    private var eventHandlers: [String: [(Any) -> Void]] = [:]
    /// Handlers that receive every argument of an event. The feed and user channels emit
    /// `(channel, message)`, which `eventHandlers` would cut down to the channel alone.
    private var argumentHandlers: [String: [([Any]) -> Void]] = [:]

    /// Called on the main queue with `true` once Socket.IO accepts the connection and the feed
    /// subscription is sent, and with `false` when an established connection drops or is closed.
    var onConnectionChange: ((Bool) -> Void)?
    private let serverURLProvider: () -> String?

    init(serverURLProvider: @escaping () -> String? = { NewsBlurAppDelegate.shared()?.url }) {
        self.serverURLProvider = serverURLProvider
        super.init()
    }

    private(set) var baseURL = "wss://www.newsblur.com/v3/socket.io/"

    private static func socketBaseURL(serverURL: String?) -> String {
        if let appURL = serverURL,
           !appURL.isEmpty {
            let wsURL = appURL
                .replacingOccurrences(of: "https://", with: "wss://")
                .replacingOccurrences(of: "http://", with: "ws://")
            return "\(wsURL)/v3/socket.io/"
        }
        return "wss://www.newsblur.com/v3/socket.io/"
    }

    // MARK: - Public Methods

    /// Connect to the NewsBlur Socket.IO server
    @objc func connect(username: String, feeds: [String]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isConnecting && !self.isConnected else {
                NSLog("NewsBlurSocketClient: Already connected or connecting")
                return
            }

            self.username = username
            self.feeds = feeds
            self.shouldReconnect = true
            self.cancelReconnectTimer()
            self.isConnecting = true
            self.connectionGeneration += 1
            let generation = self.connectionGeneration
            // NewsBlurSocketClient.swift reads UIApplication-backed configuration on main without blocking either queue.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let endpoint = Self.socketBaseURL(serverURL: self.serverURLProvider())
                self.queue.async { [weak self] in
                    guard let self, self.isConnecting, self.connectionGeneration == generation else { return }
                    self.baseURL = endpoint
                    self.connectWebSocket()
                }
            }
        }
    }

    /// Disconnect from the server
    @objc func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            NSLog("NewsBlurSocketClient: Disconnecting")
            let wasConnected = self.isConnected
            self.shouldReconnect = false
            self.connectionGeneration += 1
            self.cancelReconnectTimer()
            self.tearDownConnection()
            self.isConnected = false
            self.isConnecting = false
            self.reconnectAttempts = 0
            if wasConnected { self.notifyConnectionChange(false) }
        }
    }

    /// Replace the feeds this connection listens to. A live connection resubscribes in place, since the
    /// server swaps its Redis subscriber on every `subscribe:feeds`, and a later reconnect uses the new list.
    func updateFeeds(_ feeds: [String]) {
        queue.async { [weak self] in
            guard let self, feeds != self.feeds else { return }
            self.feeds = feeds
            if self.isConnected { self.subscribeToFeeds() }
        }
    }

    /// Run one raw Engine.IO frame through the parser, as the receive loop does. NewsBlurTests use it.
    func receive(frame: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.handleMessage(frame, generation: self.connectionGeneration)
        }
    }

    /// Subscribe to every argument of an event, such as `user:update`'s channel and message.
    func subscribeArguments(event: String, handler: @escaping ([Any]) -> Void) {
        queue.async { [weak self] in
            self?.argumentHandlers[event, default: []].append(handler)
        }
    }

    /// Subscribe to a specific event
    func subscribe(event: String, handler: @escaping (Any) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.eventHandlers[event] == nil {
                self.eventHandlers[event] = []
            }
            self.eventHandlers[event]?.append(handler)
        }
    }

    /// Unsubscribe from all handlers for an event
    func unsubscribe(event: String) {
        queue.async { [weak self] in
            self?.eventHandlers[event] = nil
        }
    }

    /// Check if currently connected
    @objc var connected: Bool {
        return queue.sync { isConnected }
    }

    // MARK: - Connection Lifecycle

    /// Tear down the current connection, invalidating the URLSession
    /// Must be called on self.queue
    private func tearDownConnection() {
        cancelPingTimeoutTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        sid = nil
    }

    func connectWebSocket() {
        // Must be called on self.queue
        // Tear down any existing connection first
        tearDownConnection()

        connectionGeneration += 1
        let generation = connectionGeneration

        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket")
        ]

        guard let url = urlComponents.url else {
            NSLog("NewsBlurSocketClient: Invalid WebSocket URL")
            isConnecting = false
            return
        }

        NSLog("NewsBlurSocketClient: Connecting to \(url)")

        let configuration = URLSessionConfiguration.default
        // The server pings every 30 seconds, so a request timeout only fires on a connection that went quiet.
        configuration.timeoutIntervalForRequest = 120
        // A WebSocket task is one resource for as long as it stays open. A 5 minute limit here dropped every
        // connection after 5 minutes, and RealtimeUpdates.swift then recounted every feed to catch up.
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60

        session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        receiveMessages(generation: generation)
    }

    // MARK: - Message Handling

    private func receiveMessages(generation: Int) {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            self.queue.async {
                // Ignore callbacks from stale connections
                guard generation == self.connectionGeneration else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text, generation: generation)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text, generation: generation)
                        }
                    @unknown default:
                        break
                    }
                    // Continue receiving
                    self.receiveMessages(generation: generation)

                case .failure(let error):
                    NSLog("NewsBlurSocketClient: Receive error: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: String, generation: Int) {
        // Must be called on self.queue
        guard !message.isEmpty, generation == connectionGeneration else { return }

        // Engine.IO v4 packet types:
        // 0 - open, 1 - close, 2 - ping (server→client), 3 - pong, 4 - message, 6 - noop
        let firstChar = message.first!

        switch firstChar {
        case "0": // Engine.IO open
            NSLog("NewsBlurSocketClient: Engine.IO open received")
            let jsonPart = String(message.dropFirst())
            if let data = jsonPart.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                sid = json["sid"] as? String
                if let interval = json["pingInterval"] as? Int {
                    serverPingInterval = TimeInterval(interval) / 1000.0
                }
                if let timeout = json["pingTimeout"] as? Int {
                    serverPingTimeout = TimeInterval(timeout) / 1000.0
                }
                NSLog("NewsBlurSocketClient: Got session ID: \(sid ?? "nil"), pingInterval: \(serverPingInterval)s, pingTimeout: \(serverPingTimeout)s")
            }
            completeConnection()

        case "2": // Server ping → respond with pong
            sendRawMessage("3")
            resetPingTimeoutTimer()

        case "3": // Pong
            break

        case "4": // Socket.IO message
            handleSocketIOMessage(String(message.dropFirst()))

        case "6": // Noop
            break

        default:
            NSLog("NewsBlurSocketClient: Unknown packet: \(message.prefix(50))")
        }
    }

    private func handleSocketIOMessage(_ message: String) {
        // Must be called on self.queue
        // Socket.IO packet types: 0 - connect, 1 - disconnect, 2 - event, 3 - ack, 4 - error
        guard !message.isEmpty else { return }

        let firstChar = message.first!

        switch firstChar {
        case "0": // Connect acknowledgment
            NSLog("NewsBlurSocketClient: Socket.IO connected")
            subscribeToFeeds()
            notifyConnectionChange(true)

        case "1": // Disconnect
            NSLog("NewsBlurSocketClient: Socket.IO disconnected by server")
            handleDisconnect()

        case "2": // Event
            handleEvent(String(message.dropFirst()))

        case "4": // Error
            NSLog("NewsBlurSocketClient: Socket.IO error: \(message)")

        default:
            NSLog("NewsBlurSocketClient: Unknown Socket.IO packet: \(message.prefix(50))")
        }
    }

    private func handleEvent(_ message: String) {
        // Must be called on self.queue
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = json.first as? String else {
            NSLog("NewsBlurSocketClient: Failed to parse event: \(message.prefix(100))")
            return
        }

        let eventData = json.count > 1 ? json[1] : nil
        let handlers = eventHandlers[eventName]
        let wildcardHandlers = eventHandlers["*"]
        let eventArgumentHandlers = argumentHandlers[eventName]
        let arguments = Array(json.dropFirst())

        if let eventArgumentHandlers {
            DispatchQueue.main.async {
                for handler in eventArgumentHandlers {
                    handler(arguments)
                }
            }
        }

        // Dispatch event handlers on main queue for UI safety
        if let handlers = handlers {
            DispatchQueue.main.async {
                for handler in handlers {
                    handler(eventData ?? [:])
                }
            }
        }

        if let wildcardHandlers = wildcardHandlers {
            DispatchQueue.main.async {
                for handler in wildcardHandlers {
                    handler(["event": eventName, "data": eventData ?? [:]])
                }
            }
        }
    }

    private func completeConnection() {
        // Must be called on self.queue
        isConnecting = false
        isConnected = true
        reconnectAttempts = 0
        cancelReconnectTimer()

        // Start monitoring for server pings
        resetPingTimeoutTimer()

        // Send Socket.IO connect packet
        sendRawMessage("40")

        NSLog("NewsBlurSocketClient: WebSocket connected, isConnected=\(isConnected)")
    }

    private func subscribeToFeeds() {
        // Must be called on self.queue
        guard let username = username else { return }

        let payload: [Any] = ["subscribe:feeds", feeds, username]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let message = String(data: data, encoding: .utf8) else { return }
        sendRawMessage("42\(message)")

        NSLog("NewsBlurSocketClient: Subscribed to \(feeds.count) feeds for \(username)")
    }

    private func notifyConnectionChange(_ connected: Bool) {
        // Must be called on self.queue
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(connected)
        }
    }

    // MARK: - Sending Messages

    private func sendRawMessage(_ message: String) {
        // Can be called from self.queue; the send is async
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                NSLog("NewsBlurSocketClient: Send error: \(error.localizedDescription)")
            }
        }
    }

    /// Emit a Socket.IO event
    func emit(event: String, data: Any) {
        queue.async { [weak self] in
            guard let self = self, self.isConnected else {
                NSLog("NewsBlurSocketClient: Not connected, cannot emit \(event)")
                return
            }

            var payload: [Any] = [event]
            payload.append(data)

            if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self.sendRawMessage("42\(jsonString)")
            }
        }
    }

    // MARK: - Connection Management

    private func handleDisconnect() {
        // Must be called on self.queue
        let wasConnected = isConnected
        isConnected = false
        isConnecting = false
        tearDownConnection()

        if wasConnected {
            NSLog("NewsBlurSocketClient: Disconnected, scheduling reconnect")
            notifyConnectionChange(false)
            if shouldReconnect { scheduleReconnect() }
        } else if shouldReconnect && reconnectTimer == nil {
            // NewsBlurSocketClient.swift retries a connection that failed before it opened, which a dropped
            // network causes after the Mac app's earlier connection was already lost.
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        // Must be called on self.queue
        reconnectAttempts += 1
        let backoff = min(Double(reconnectAttempts) * 2.0, maximumReconnectDelay)
        // Spread the retries so every client doesn't return the moment the socket server comes back.
        let delay = backoff * Double.random(in: 0.75...1.25)

        NSLog("NewsBlurSocketClient: Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        cancelReconnectTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.shouldReconnect else { return }
            self.reconnectTimer = nil
            self.isConnecting = true
            self.isConnected = false
            self.connectWebSocket()
        }
        timer.resume()
        reconnectTimer = timer
    }

    private func cancelReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    // MARK: - Ping Timeout Monitoring

    /// Reset the ping timeout timer. If no server ping arrives within
    /// `pingInterval + pingTimeout`, the connection is considered dead.
    private func resetPingTimeoutTimer() {
        // Must be called on self.queue
        cancelPingTimeoutTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + serverPingInterval + serverPingTimeout)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            NSLog("NewsBlurSocketClient: Ping timeout - no server ping received in \(self.serverPingInterval + self.serverPingTimeout)s")
            self.handleDisconnect()
        }
        timer.resume()
        pingTimeoutTimer = timer
    }

    private func cancelPingTimeoutTimer() {
        pingTimeoutTimer?.cancel()
        pingTimeoutTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension NewsBlurSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        NSLog("NewsBlurSocketClient: WebSocket opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            // Ignore callbacks from stale sessions
            guard session === self.session, webSocketTask === self.webSocketTask else {
                NSLog("NewsBlurSocketClient: Ignoring close from stale session")
                return
            }
            NSLog("NewsBlurSocketClient: WebSocket closed with code: \(closeCode.rawValue)")
            self.handleDisconnect()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            guard session === self.session else {
                NSLog("NewsBlurSocketClient: Ignoring error from stale session")
                return
            }
            NSLog("NewsBlurSocketClient: Task error: \(error.localizedDescription)")
            self.handleDisconnect()
        }
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        #if DEBUG
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        #endif
        completionHandler(.performDefaultHandling, nil)
    }
}
