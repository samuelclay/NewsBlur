//
//  AskAIView.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct AskAIView: View {
    @ObservedObject var viewModel: AskAIViewModel
    var onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.hasAskedQuestion {
                    responseView
                } else {
                    questionSelectorView
                }
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.hasAskedQuestion && !viewModel.conversation.isStreaming {
                        Button("New Question") {
                            viewModel.reset()
                        }
                    }
                }
            }
        }
        .accentColor(Color(UIColor.label))
    }

    // MARK: - Question Selector View

    private var questionSelectorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summarize Section
                summarizeSection

                // Understand Section
                understandSection

                // Custom Question Section
                customQuestionSection

                // Model Selector
                modelSelector

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    private var summarizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summarize", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach([AskAIQuestionType.sentence, .bullets, .paragraph], id: \.self) { type in
                    summarizeButton(type)
                }
            }
        }
    }

    private func summarizeButton(_ type: AskAIQuestionType) -> some View {
        Button(action: {
            viewModel.selectedSummarizeType = type
            viewModel.sendQuestion(type)
        }) {
            VStack(spacing: 4) {
                Image(systemName: summarizeIcon(for: type))
                    .font(.title2)
                Text(type.displayTitle)
                    .font(.subheadline.bold())
                Text(type.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.selectedSummarizeType == type ? viewModel.selectedModel.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func summarizeIcon(for type: AskAIQuestionType) -> String {
        switch type {
        case .sentence: return "minus"
        case .bullets: return "list.bullet"
        case .paragraph: return "text.justify"
        default: return "text.alignleft"
        }
    }

    private var understandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Understand", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach([AskAIQuestionType.context, .people, .arguments, .factcheck], id: \.self) { type in
                    understandButton(type)
                }
            }
        }
    }

    private func understandButton(_ type: AskAIQuestionType) -> some View {
        Button(action: {
            viewModel.sendQuestion(type)
        }) {
            HStack {
                Image(systemName: type.iconName)
                    .frame(width: 24)
                    .foregroundColor(viewModel.selectedModel.color)

                Text(type.displayTitle)
                    .font(.body)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var customQuestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ask a question", systemImage: "questionmark.circle")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                // Voice button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.isRecording ? .red : viewModel.selectedModel.color)
                }
                .disabled(viewModel.isTranscribing)

                // Text input
                TextField("Ask a question...", text: $viewModel.customQuestion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .disabled(viewModel.isRecording || viewModel.isTranscribing)

                // Send button
                if !viewModel.customQuestion.isEmpty {
                    Button(action: {
                        viewModel.sendQuestion(.custom)
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.selectedModel.color)
                    }
                }
            }

            if viewModel.isRecording {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Recording...")
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isTranscribing {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Transcribing...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var modelSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Model")
                .font(.caption)
                .foregroundColor(.secondary)

            Menu {
                ForEach(AskAIProvider.allCases) { model in
                    Button(action: {
                        viewModel.selectedModel = model
                    }) {
                        HStack {
                            Text(model.displayName)
                            if model == viewModel.selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    ModelPill(model: viewModel.selectedModel)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Response View

    private var responseView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Question header
                        questionHeader

                        // Model pill
                        ModelPill(model: viewModel.conversation.model, isLoading: viewModel.conversation.isStreaming)

                        // Error message
                        if let error = viewModel.conversation.error {
                            errorView(error)
                        }

                        // Response text
                        if !viewModel.conversation.responseText.isEmpty {
                            responseText
                        } else if viewModel.conversation.isStreaming {
                            streamingPlaceholder
                        }

                        // Usage message
                        if let usage = viewModel.conversation.usageMessage {
                            usageView(usage)
                        }

                        // Bottom anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: viewModel.conversation.responseText) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Follow-up input
            if viewModel.conversation.isComplete || viewModel.conversation.error != nil {
                followUpInput
            }
        }
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.conversation.questionText)
                .font(.headline)
                .foregroundColor(.primary)

            if !viewModel.conversation.storyTitle.isEmpty {
                Text("About: \(viewModel.conversation.storyTitle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .foregroundColor(.red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }

    private var responseText: some View {
        MarkdownText(viewModel.conversation.responseText)
            .textSelection(.enabled)
    }

    private var streamingPlaceholder: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Thinking...")
                .foregroundColor(.secondary)
        }
    }

    private func usageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text(message)
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }

    private var followUpInput: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                // Voice button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.isRecording ? .red : viewModel.selectedModel.color)
                }

                // Text input
                TextField("Follow up...", text: $viewModel.customQuestion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)

                // Re-ask menu
                Menu {
                    ForEach(AskAIProvider.allCases) { model in
                        Button(action: {
                            viewModel.reaskWithModel(model)
                        }) {
                            HStack {
                                Text("Re-ask with \(model.shortName)")
                                if model == viewModel.selectedModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("Re-ask")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }

                // Send button
                if !viewModel.customQuestion.isEmpty {
                    Button(action: {
                        viewModel.sendFollowUp()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.selectedModel.color)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Model Pill

@available(iOS 15.0, *)
struct ModelPill: View {
    let model: AskAIProvider
    var isLoading: Bool = false
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: model.textColor))
                    .scaleEffect(0.7)
            }

            Text(model.shortName)
                .font(.caption.bold())
                .foregroundColor(isError ? .white : model.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isError ? Color.red : model.color)
        )
        .opacity(isLoading ? 0.8 : 1.0)
        .animation(isLoading ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: isLoading)
    }
}

// MARK: - Markdown Text

@available(iOS 15.0, *)
struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                if paragraph.hasPrefix("# ") {
                    Text(paragraph.dropFirst(2))
                        .font(.title2.bold())
                } else if paragraph.hasPrefix("## ") {
                    Text(paragraph.dropFirst(3))
                        .font(.title3.bold())
                } else if paragraph.hasPrefix("### ") {
                    Text(paragraph.dropFirst(4))
                        .font(.headline)
                } else if paragraph.hasPrefix("- ") || paragraph.hasPrefix("* ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(formatInlineMarkdown(String(paragraph.dropFirst(2))))
                    }
                } else if paragraph.hasPrefix("---") {
                    Divider()
                        .padding(.vertical, 8)
                } else if let numberMatch = paragraph.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    let number = String(paragraph[numberMatch].dropLast())
                    let content = String(paragraph[numberMatch.upperBound...])
                    HStack(alignment: .top, spacing: 8) {
                        Text(number)
                            .foregroundColor(.secondary)
                        Text(formatInlineMarkdown(content))
                    }
                } else {
                    Text(formatInlineMarkdown(paragraph))
                }
            }
        }
    }

    private var paragraphs: [String] {
        text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func formatInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold: **text** or __text__
        let boldPattern = #"\*\*(.+?)\*\*|__(.+?)__"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let range = Range(match.range, in: text),
                   let attrRange = Range(range, in: result) {
                    let content = match.range(at: 1).location != NSNotFound
                        ? nsString.substring(with: match.range(at: 1))
                        : nsString.substring(with: match.range(at: 2))
                    var replacement = AttributedString(content)
                    replacement.font = .body.bold()
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }

        // Italic: *text* or _text_ (not already bold)
        let italicPattern = #"(?<!\*)\*([^*]+)\*(?!\*)|(?<!_)_([^_]+)_(?!_)"#
        if let regex = try? NSRegularExpression(pattern: italicPattern) {
            let nsString = String(result.characters) as NSString
            let matches = regex.matches(in: String(result.characters), range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let range = Range(match.range, in: String(result.characters)),
                   let attrRange = Range(range, in: result) {
                    let content = match.range(at: 1).location != NSNotFound
                        ? nsString.substring(with: match.range(at: 1))
                        : nsString.substring(with: match.range(at: 2))
                    var replacement = AttributedString(content)
                    replacement.font = .body.italic()
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }

        return result
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, *)
struct AskAIView_Previews: PreviewProvider {
    static var previews: some View {
        AskAIView(
            viewModel: AskAIViewModel(story: ["story_hash": "test", "story_title": "Test Story"]),
            onDismiss: {}
        )
    }
}
#endif
