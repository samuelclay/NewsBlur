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
    private let streamingTimeoutDuration: TimeInterval = 20.0

    // Voice recorder
    let voiceRecorder = VoiceRecorder()

    // Store story for re-initialization
    let story: [String: Any]

    // MARK: - Initialization

    init(story: [String: Any]) {
        self.story = story
        let storyHash = story["story_hash"] as? String ?? ""
        let storyTitle = ((story["story_title"] as? String ?? "") as NSString).decodingHTMLEntities() ?? ""

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
            conversation.questionText = type.questionDescription
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

        // Reset for new response (responseText is empty after handleComplete saves to completedBlocks)
        conversation.isStreaming = true
        conversation.isComplete = false
        conversation.requestId = UUID().uuidString
        conversation.questionText = customQuestion
        conversation.questionId = "custom"
        conversation.model = selectedModel  // Use the currently selected model
        customQuestion = ""

        // Save model preference
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "askAIModel")

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
        let storyHash = conversation.storyHash
        let storyTitle = conversation.storyTitle
        conversation = AskAIConversation(storyHash: storyHash, storyTitle: storyTitle)
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
        let baseURL = appDelegate.url ?? "https://www.newsblur.com"
        guard let url = URL(string: "\(baseURL)/ask-ai/question") else {
            conversation.error = "Invalid URL"
            conversation.isStreaming = false
            return
        }

        NSLog("AskAI: Sending request to \(url)")
        NSLog("AskAI: Socket connected: \(NewsBlurSocketClient.shared.connected)")

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
                    NSLog("AskAI: Request error: \(error.localizedDescription)")
                    self.conversation.error = error.localizedDescription
                    self.conversation.isStreaming = false
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    NSLog("AskAI: Response status: \(httpResponse.statusCode)")
                }

                guard let data = data else {
                    NSLog("AskAI: No response data")
                    self.conversation.error = "No response data"
                    self.conversation.isStreaming = false
                    return
                }

                if let responseStr = String(data: data, encoding: .utf8) {
                    NSLog("AskAI: Response body: \(responseStr.prefix(500))")
                }

                do {
                    let response = try JSONDecoder().decode(AskAIQuestionResponse.self, from: data)
                    NSLog("AskAI: Parsed response code: \(response.code)")

                    if response.code != 1 {
                        self.conversation.error = response.message ?? "Request failed"
                        self.conversation.isStreaming = false
                    }
                    // Success - wait for socket events
                } catch {
                    NSLog("AskAI: Parse error: \(error)")
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
        NSLog("AskAI: Received start event: \(data)")
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            NSLog("AskAI: Start event ignored - mismatched hash/requestId")
            return
        }

        NSLog("AskAI: Start event matched, beginning streaming")
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

        NSLog("AskAI: Received chunk: \(chunk.prefix(50))...")
        // Clear any timeout error since content is arriving
        if conversation.error != nil {
            conversation.error = nil
            conversation.isStreaming = true
        }

        // Append chunk to response
        conversation.responseText += chunk

        // Reset streaming timeout
        startStreamingTimeout()
    }

    private func handleComplete(_ data: Any) {
        NSLog("AskAI: Received complete event")
        guard let dict = data as? [String: Any],
              let storyHash = dict["story_hash"] as? String,
              let requestId = dict["request_id"] as? String,
              storyHash == conversation.storyHash,
              requestId == conversation.requestId else {
            return
        }

        NSLog("AskAI: Stream complete")
        timeoutTimer?.invalidate()

        let responseText = conversation.responseText
        let questionText = conversation.questionText

        // Save completed response to history
        let isFollowUp = !conversation.completedBlocks.isEmpty
        let block = AskAIResponseBlock(
            questionText: conversation.questionText,
            model: conversation.model,
            responseText: conversation.responseText,
            isFollowUp: isFollowUp
        )
        conversation.completedBlocks.append(block)

        // Preserve conversation context for follow-ups
        if !questionText.isEmpty {
            conversation.conversationHistory.append(
                AskAIMessage(role: "user", content: questionText)
            )
        }
        if !responseText.isEmpty {
            conversation.conversationHistory.append(
                AskAIMessage(role: "assistant", content: responseText)
            )
        }

        // Clear current response (it's now in completedBlocks)
        conversation.responseText = ""
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

                // If we have received content, treat as successful even without complete event
                if !self.conversation.responseText.isEmpty {
                    NSLog("AskAI: Stream timeout but content received, completing gracefully")
                    let responseText = self.conversation.responseText
                    let questionText = self.conversation.questionText
                    // Save completed response to history
                    let isFollowUp = !self.conversation.completedBlocks.isEmpty
                    let block = AskAIResponseBlock(
                        questionText: self.conversation.questionText,
                        model: self.conversation.model,
                        responseText: self.conversation.responseText,
                        isFollowUp: isFollowUp
                    )
                    self.conversation.completedBlocks.append(block)
                    if !questionText.isEmpty {
                        self.conversation.conversationHistory.append(
                            AskAIMessage(role: "user", content: questionText)
                        )
                    }
                    if !responseText.isEmpty {
                        self.conversation.conversationHistory.append(
                            AskAIMessage(role: "assistant", content: responseText)
                        )
                    }
                    self.conversation.responseText = ""
                    self.conversation.isStreaming = false
                    self.conversation.isComplete = true
                } else {
                    self.conversation.error = "Stream interrupted"
                    self.conversation.isStreaming = false
                }
            }
        }
    }
}
