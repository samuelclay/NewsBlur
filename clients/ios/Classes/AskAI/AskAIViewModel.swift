//
//  AskAIViewModel.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AskAIViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversation: AskAIConversation
    @Published var selectedModel: AskAIProvider = .opus
    @Published var selectedSummarizeType: AskAIQuestionType = .bullets
    @Published var customQuestion: String = ""
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var showModelPicker: Bool = false
    @Published var hasAskedQuestion: Bool = false

    // MARK: - Private Properties

    private let appDelegate = NewsBlurAppDelegate.shared()!
    private var socketSubscribed = false
    private var timeoutTimer: Timer?
    private let timeoutDuration: TimeInterval = 15.0
    private let streamingTimeoutDuration: TimeInterval = 10.0

    // Voice recorder
    let voiceRecorder = VoiceRecorder()

    // MARK: - Initialization

    init(story: [String: Any]) {
        let storyHash = story["story_hash"] as? String ?? ""
        let storyTitle = story["story_title"] as? String ?? ""

        self.conversation = AskAIConversation(storyHash: storyHash, storyTitle: storyTitle)

        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: "askAIModel"),
           let model = AskAIProvider(rawValue: savedModel) {
            self.selectedModel = model
        }

        setupSocketHandlers()
        setupVoiceRecorderCallbacks()
    }

    deinit {
        // Note: deinit runs outside MainActor, so we need to unsubscribe synchronously
        // This is safe because socket unsubscription doesn't require MainActor
        let socket = NewsBlurSocketClient.shared
        socket.unsubscribe(event: "ask_ai:start")
        socket.unsubscribe(event: "ask_ai:chunk")
        socket.unsubscribe(event: "ask_ai:complete")
        socket.unsubscribe(event: "ask_ai:usage")
        socket.unsubscribe(event: "ask_ai:error")
    }

    // MARK: - Socket Setup

    private func setupSocketHandlers() {
        guard !socketSubscribed else { return }

        let socket = NewsBlurSocketClient.shared

        socket.subscribe(event: "ask_ai:start") { [weak self] data in
            Task { @MainActor in
                self?.handleStart(data)
            }
        }

        socket.subscribe(event: "ask_ai:chunk") { [weak self] data in
            Task { @MainActor in
                self?.handleChunk(data)
            }
        }

        socket.subscribe(event: "ask_ai:complete") { [weak self] data in
            Task { @MainActor in
                self?.handleComplete(data)
            }
        }

        socket.subscribe(event: "ask_ai:usage") { [weak self] data in
            Task { @MainActor in
                self?.handleUsage(data)
            }
        }

        socket.subscribe(event: "ask_ai:error") { [weak self] data in
            Task { @MainActor in
                self?.handleError(data)
            }
        }

        socketSubscribed = true
    }

    private func unsubscribeFromSocket() {
        guard socketSubscribed else { return }

        let socket = NewsBlurSocketClient.shared
        socket.unsubscribe(event: "ask_ai:start")
        socket.unsubscribe(event: "ask_ai:chunk")
        socket.unsubscribe(event: "ask_ai:complete")
        socket.unsubscribe(event: "ask_ai:usage")
        socket.unsubscribe(event: "ask_ai:error")

        socketSubscribed = false
    }

    // MARK: - Voice Recorder Setup

    private func setupVoiceRecorderCallbacks() {
        voiceRecorder.onTranscriptionComplete = { [weak self] text in
            Task { @MainActor in
                self?.customQuestion = text
                self?.isRecording = false
                self?.isTranscribing = false

                // Auto-submit if we have text
                if !text.isEmpty {
                    self?.sendQuestion(.custom)
                }
            }
        }

        voiceRecorder.onTranscriptionError = { [weak self] error in
            Task { @MainActor in
                self?.isRecording = false
                self?.isTranscribing = false
                self?.conversation.error = error
            }
        }

        voiceRecorder.onRecordingStateChange = { [weak self] isRecording in
            Task { @MainActor in
                self?.isRecording = isRecording
            }
        }
    }

    // MARK: - Public Methods

    func sendQuestion(_ type: AskAIQuestionType) {
        // Reset state
        conversation.error = nil
        conversation.usageMessage = nil
        conversation.responseText = ""
        conversation.isStreaming = true
        conversation.isComplete = false
        conversation.requestId = UUID().uuidString
        conversation.model = selectedModel
        hasAskedQuestion = true

        // Set question info
        if type == .custom {
            conversation.questionId = "custom"
            conversation.questionText = customQuestion
        } else {
            conversation.questionId = type.rawValue
            conversation.questionText = type.displayTitle
        }

        // Start timeout
        startTimeout()

        // Save model preference
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "askAIModel")

        // Make API request
        sendQuestionRequest()
    }

    func sendFollowUp() {
        guard !customQuestion.isEmpty else { return }

        // Add current response to history
        if !conversation.responseText.isEmpty {
            conversation.conversationHistory.append(
                AskAIMessage(role: "assistant", content: conversation.responseText)
            )
        }

        // Add user's follow-up to history
        conversation.conversationHistory.append(
            AskAIMessage(role: "user", content: customQuestion)
        )

        // Reset for new response
        conversation.responseText = ""
        conversation.isStreaming = true
        conversation.isComplete = false
        conversation.requestId = UUID().uuidString
        conversation.questionText = customQuestion
        conversation.questionId = "custom"
        customQuestion = ""

        startTimeout()
        sendQuestionRequest()
    }

    func reaskWithModel(_ model: AskAIProvider) {
        selectedModel = model
        conversation.model = model
        conversation.responseText = ""
        conversation.isStreaming = true
        conversation.isComplete = false
        conversation.requestId = UUID().uuidString

        // Save model preference
        UserDefaults.standard.set(model.rawValue, forKey: "askAIModel")

        startTimeout()
        sendQuestionRequest()
    }

    func cancelRequest() {
        timeoutTimer?.invalidate()
        conversation.isStreaming = false
    }

    func reset() {
        conversation = AskAIConversation(storyHash: conversation.storyHash, storyTitle: conversation.storyTitle)
        customQuestion = ""
        hasAskedQuestion = false
    }

    // MARK: - Voice Recording

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        Task {
            let hasPermission = await voiceRecorder.requestPermissions()
            if hasPermission {
                voiceRecorder.startRecording()
                isRecording = true
            } else {
                conversation.error = "Microphone permission denied"
            }
        }
    }

    func stopRecording() {
        isTranscribing = true
        voiceRecorder.stopRecording()
    }

    // MARK: - Private Methods

    private func sendQuestionRequest() {
        guard let url = URL(string: "\(appDelegate.url ?? "https://www.newsblur.com")/ask-ai/question") else {
            conversation.error = "Invalid URL"
            conversation.isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build parameters
        var params: [String: String] = [
            "story_hash": conversation.storyHash,
            "question_id": conversation.questionId,
            "model": selectedModel.rawValue,
            "request_id": conversation.requestId
        ]

        if conversation.questionId == "custom" {
            params["custom_question"] = conversation.questionText
        }

        if !conversation.conversationHistory.isEmpty {
            let historyData = conversation.conversationHistory.map { ["role": $0.role, "content": $0.content] }
            if let jsonData = try? JSONSerialization.data(withJSONObject: historyData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                params["conversation_history"] = jsonString
            }
        }

        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        // Add cookies for authentication
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    self.conversation.error = error.localizedDescription
                    self.conversation.isStreaming = false
                    return
                }

                guard let data = data else {
                    self.conversation.error = "No response data"
                    self.conversation.isStreaming = false
                    return
                }

                do {
                    let response = try JSONDecoder().decode(AskAIQuestionResponse.self, from: data)

                    if response.code != 1 {
                        self.conversation.error = response.message ?? "Request failed"
                        self.conversation.isStreaming = false
                    }
                    // Success - wait for socket events
                } catch {
                    // Try to parse error message
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        self.conversation.error = message
                    } else {
                        self.conversation.error = "Failed to parse response"
                    }
                    self.conversation.isStreaming = false
                }
            }
        }.resume()
    }

    // MARK: - Socket Event Handlers

    private func handleStart(_ data: Any) {
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        // Reset timeout for streaming
        startStreamingTimeout()
        conversation.error = nil
    }

    private func handleChunk(_ data: Any) {
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              let chunk = dict["chunk"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        // Append chunk to response
        conversation.responseText += chunk

        // Reset streaming timeout
        startStreamingTimeout()
    }

    private func handleComplete(_ data: Any) {
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        timeoutTimer?.invalidate()
        conversation.isStreaming = false
        conversation.isComplete = true
    }

    private func handleUsage(_ data: Any) {
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              let message = dict["message"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        conversation.usageMessage = message
    }

    private func handleError(_ data: Any) {
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              let error = dict["error"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        timeoutTimer?.invalidate()
        conversation.error = error
        conversation.isStreaming = false
    }

    // MARK: - Timeout Handling

    private func startTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.conversation.isStreaming, self.conversation.responseText.isEmpty else { return }
                self.conversation.error = "Request timed out"
                self.conversation.isStreaming = false
            }
        }
    }

    private func startStreamingTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: streamingTimeoutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.conversation.isStreaming else { return }
                self.conversation.error = "Stream interrupted"
                self.conversation.isStreaming = false
            }
        }
    }
}
