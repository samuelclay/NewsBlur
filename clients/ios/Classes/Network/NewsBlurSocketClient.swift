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
@objc class NewsBlurSocketClient: NSObject {
    @objc static let shared = NewsBlurSocketClient()

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private var username: String?
    private var feeds: [String] = []
    private var isConnected = false
    private var isConnecting = false
    private var sid: String? // Socket.IO session ID

    private var eventHandlers: [String: [(Any) -> Void]] = [:]

    private var baseURL: String {
        // Use the app's configured URL (handles both production and dev)
        if let appURL = NewsBlurAppDelegate.shared()?.url,
           !appURL.isEmpty {
            // Convert http(s) to ws(s)
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
        guard !isConnecting && !isConnected else {
            NSLog("NewsBlurSocketClient: Already connected or connecting")
            return
        }

        self.username = username
        self.feeds = feeds
        self.isConnecting = true

        // First, do the HTTP polling handshake to get session ID
        performHandshake { [weak self] success in
            guard let self = self, success else {
                self?.isConnecting = false
                self?.scheduleReconnect()
                return
            }

            self.connectWebSocket()
        }
    }

    /// Disconnect from the server
    @objc func disconnect() {
        NSLog("NewsBlurSocketClient: Disconnecting")
        stopPingTimer()
        stopReconnectTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
        sid = nil
        reconnectAttempts = 0
    }

    /// Subscribe to a specific event
    func subscribe(event: String, handler: @escaping (Any) -> Void) {
        if eventHandlers[event] == nil {
            eventHandlers[event] = []
        }
        eventHandlers[event]?.append(handler)
    }

    /// Unsubscribe from all handlers for an event
    func unsubscribe(event: String) {
        eventHandlers[event] = nil
    }

    /// Check if currently connected
    @objc var connected: Bool {
        return isConnected
    }

    // MARK: - WebSocket Connection
    // Note: NewsBlur socket server only accepts websocket transport (no polling)
    // So we connect directly via WebSocket without HTTP polling handshake

    private func performHandshake(completion: @escaping (Bool) -> Void) {
        // Skip polling handshake - server only accepts websocket transport
        // We'll get the session ID from the WebSocket connection directly
        completion(true)
    }

    private func connectWebSocket() {
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
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300

        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        // Start receiving messages immediately
        receiveMessages()
    }

    // MARK: - Message Handling

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                NSLog("NewsBlurSocketClient: Receive error: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: String) {
        // Engine.IO packet types:
        // 0 - open, 1 - close, 2 - ping, 3 - pong, 4 - message, 5 - upgrade, 6 - noop

        guard !message.isEmpty else { return }

        let firstChar = message.first!

        switch firstChar {
        case "0": // Open - received when WebSocket connects directly
            NSLog("NewsBlurSocketClient: Engine.IO open received")
            // Parse session info from the open packet
            let jsonPart = String(message.dropFirst())
            if let data = jsonPart.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sessionId = json["sid"] as? String {
                self.sid = sessionId
                NSLog("NewsBlurSocketClient: Got session ID: \(sessionId)")
            }
            // Complete connection and send Socket.IO connect
            completeConnection()

        case "2": // Ping
            sendRawMessage("3") // Pong

        case "3": // Pong (response to our ping or probe)
            if message == "3probe" {
                // Complete the upgrade
                sendRawMessage("5") // Upgrade packet
                completeConnection()
            }

        case "4": // Message (Socket.IO packet)
            handleSocketIOMessage(String(message.dropFirst()))

        case "6": // Noop
            break

        default:
            NSLog("NewsBlurSocketClient: Unknown packet: \(message.prefix(50))")
        }
    }

    private func handleSocketIOMessage(_ message: String) {
        // Socket.IO packet types:
        // 0 - connect, 1 - disconnect, 2 - event, 3 - ack, 4 - error

        guard !message.isEmpty else { return }

        let firstChar = message.first!

        switch firstChar {
        case "0": // Connect acknowledgment
            NSLog("NewsBlurSocketClient: Socket.IO connected")
            // Now subscribe to feeds
            subscribeToFeeds()

        case "1": // Disconnect
            NSLog("NewsBlurSocketClient: Socket.IO disconnected")
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
        // Event format: ["event_name", data]
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = json.first as? String else {
            NSLog("NewsBlurSocketClient: Failed to parse event: \(message.prefix(100))")
            return
        }

        let eventData = json.count > 1 ? json[1] : nil

        // Route to handlers
        if let handlers = eventHandlers[eventName] {
            for handler in handlers {
                handler(eventData ?? [:])
            }
        }

        // Also emit to generic event handlers
        if let handlers = eventHandlers["*"] {
            for handler in handlers {
                handler(["event": eventName, "data": eventData ?? [:]])
            }
        }
    }

    private func completeConnection() {
        isConnecting = false
        isConnected = true
        reconnectAttempts = 0
        stopReconnectTimer()
        startPingTimer()
        // Note: receiveMessages() already called from connectWebSocket()

        // Send Socket.IO connect packet
        sendRawMessage("40") // Socket.IO connect to default namespace

        NSLog("NewsBlurSocketClient: WebSocket connected, isConnected=\(isConnected)")
    }

    private func subscribeToFeeds() {
        guard let username = username else { return }

        // Emit subscribe:feeds event
        // Format: 42["subscribe:feeds", [feeds], username]
        let feedsJson = (try? JSONSerialization.data(withJSONObject: feeds)) ?? Data()
        let feedsString = String(data: feedsJson, encoding: .utf8) ?? "[]"

        let message = "42[\"subscribe:feeds\",\(feedsString),\"\(username)\"]"
        sendRawMessage(message)

        NSLog("NewsBlurSocketClient: Subscribed to \(feeds.count) feeds for \(username)")
    }

    // MARK: - Sending Messages

    private func sendRawMessage(_ message: String) {
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                NSLog("NewsBlurSocketClient: Send error: \(error.localizedDescription)")
            }
        }
    }

    /// Emit a Socket.IO event
    func emit(event: String, data: Any) {
        guard isConnected else {
            NSLog("NewsBlurSocketClient: Not connected, cannot emit \(event)")
            return
        }

        var payload: [Any] = [event]
        payload.append(data)

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendRawMessage("42\(jsonString)")
        }
    }

    // MARK: - Connection Management

    private func handleDisconnect() {
        let wasConnected = isConnected
        isConnected = false
        isConnecting = false
        stopPingTimer()

        if wasConnected {
            NSLog("NewsBlurSocketClient: Disconnected, scheduling reconnect")
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            NSLog("NewsBlurSocketClient: Max reconnect attempts reached")
            return
        }

        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0) // Exponential backoff, max 30s

        NSLog("NewsBlurSocketClient: Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let username = self.username else { return }
            self.connect(username: username, feeds: self.feeds)
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Ping/Pong

    private func startPingTimer() {
        stopPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.sendRawMessage("2") // Engine.IO ping
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension NewsBlurSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        NSLog("NewsBlurSocketClient: WebSocket opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("NewsBlurSocketClient: WebSocket closed with code: \(closeCode.rawValue)")
        handleDisconnect()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("NewsBlurSocketClient: Task error: \(error.localizedDescription)")
            handleDisconnect()
        }
    }
}
