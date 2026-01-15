//
//  AskAIModels.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - AI Provider

enum AskAIProvider: String, CaseIterable, Identifiable {
    case opus = "opus"
    case gpt = "gpt-5.2"
    case gemini = "gemini-3"
    case grok = "grok-4.1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus: return "Anthropic Claude Opus 4.5"
        case .gpt: return "OpenAI GPT 5.2"
        case .gemini: return "Google Gemini 3 Pro"
        case .grok: return "xAI Grok 4.1 Fast"
        }
    }

    var shortName: String {
        switch self {
        case .opus: return "Opus 4.5"
        case .gpt: return "GPT 5.2"
        case .gemini: return "Gemini 3"
        case .grok: return "Grok 4.1"
        }
    }

    var providerName: String {
        switch self {
        case .opus: return "anthropic"
        case .gpt: return "openai"
        case .gemini: return "google"
        case .grok: return "xai"
        }
    }

    var color: Color {
        switch self {
        case .opus: return Color(red: 0.85, green: 0.47, blue: 0.34) // Anthropic coral/tan
        case .gpt: return Color(red: 0.2, green: 0.65, blue: 0.45) // Green
        case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96) // Google blue
        case .grok: return Color(red: 0.1, green: 0.1, blue: 0.1) // Dark/black
        }
    }

    var textColor: Color {
        return .white
    }
}

// MARK: - Question Types

enum AskAIQuestionType: String, CaseIterable, Identifiable {
    // Summarize
    case sentence = "sentence"
    case bullets = "bullets"
    case paragraph = "paragraph"

    // Understand
    case context = "context"
    case people = "people"
    case arguments = "arguments"
    case factcheck = "factcheck"

    // Custom
    case custom = "custom"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .sentence: return "Brief"
        case .bullets: return "Medium"
        case .paragraph: return "Detailed"
        case .context: return "What's the context and background?"
        case .people: return "Identify key people and relationships"
        case .arguments: return "What are the main arguments?"
        case .factcheck: return "Fact check this story"
        case .custom: return "Custom question"
        }
    }

    var subtitle: String {
        switch self {
        case .sentence: return "One sentence"
        case .bullets: return "Bullet points"
        case .paragraph: return "Full paragraph"
        default: return ""
        }
    }

    var iconName: String {
        switch self {
        case .sentence, .bullets, .paragraph: return "text.alignleft"
        case .context: return "globe"
        case .people: return "person.2"
        case .arguments: return "arrow.triangle.branch"
        case .factcheck: return "magnifyingglass"
        case .custom: return "questionmark.circle"
        }
    }

    var isSummarize: Bool {
        switch self {
        case .sentence, .bullets, .paragraph: return true
        default: return false
        }
    }

    /// Full question text shown in the response header
    var questionDescription: String {
        switch self {
        case .sentence: return "Summarize in one sentence"
        case .bullets: return "Summarize in bullet points"
        case .paragraph: return "Give a detailed summary"
        case .context: return "What's the context and background?"
        case .people: return "Identify key people and relationships"
        case .arguments: return "What are the main arguments?"
        case .factcheck: return "Fact check this story"
        case .custom: return "Custom question"
        }
    }
}

// MARK: - Conversation

struct AskAIMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
}

// A completed question-response exchange
struct AskAIResponseBlock: Identifiable {
    let id = UUID()
    let questionText: String
    let model: AskAIProvider
    let responseText: String
    let isFollowUp: Bool
}

struct AskAIConversation {
    var storyHash: String
    var storyTitle: String
    var questionId: String
    var questionText: String
    var requestId: String
    var responseText: String
    var conversationHistory: [AskAIMessage]
    var completedBlocks: [AskAIResponseBlock]  // History of completed responses
    var model: AskAIProvider
    var isStreaming: Bool
    var isComplete: Bool
    var error: String?
    var usageMessage: String?

    init(storyHash: String, storyTitle: String = "") {
        self.storyHash = storyHash
        self.storyTitle = storyTitle
        self.questionId = ""
        self.questionText = ""
        self.requestId = UUID().uuidString
        self.responseText = ""
        self.conversationHistory = []
        self.completedBlocks = []
        self.model = .opus
        self.isStreaming = false
        self.isComplete = false
        self.error = nil
        self.usageMessage = nil
    }
}

// MARK: - API Response

struct AskAIQuestionResponse: Decodable {
    let code: Int
    let message: String?
    let requestId: String?
    let storyHash: String?
    let questionId: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case requestId = "request_id"
        case storyHash = "story_hash"
        case questionId = "question_id"
    }
}

struct AskAITranscribeResponse: Decodable {
    let code: Int
    let text: String?
    let message: String?
}

// MARK: - Socket Events

struct AskAISocketEvent {
    let type: AskAISocketEventType
    let storyHash: String
    let questionId: String
    let requestId: String
    let chunk: String?
    let error: String?
    let message: String?
}

enum AskAISocketEventType: String {
    case start = "ask_ai:start"
    case chunk = "ask_ai:chunk"
    case complete = "ask_ai:complete"
    case usage = "ask_ai:usage"
    case error = "ask_ai:error"
}
