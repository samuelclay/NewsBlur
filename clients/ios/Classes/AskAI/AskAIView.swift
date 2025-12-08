//
//  AskAIView.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - NewsBlur Design Colors
@available(iOS 15.0, *)
private struct NewsBlurColors {
    static let background = Color(red: 0.918, green: 0.925, blue: 0.902)  // #EAECE6
    static let cardBackground = Color.white
    static let cardHover = Color(red: 0.925, green: 0.933, blue: 0.918)  // #ECEEEA
    static let border = Color(red: 0.816, green: 0.824, blue: 0.800)  // #D0D2CC
    static let textPrimary = Color(red: 0.369, green: 0.384, blue: 0.404)  // #5E6267
    static let textSecondary = Color(red: 0.565, green: 0.573, blue: 0.545)  // #90928B
    static let inputBackground = Color(red: 0.973, green: 0.976, blue: 0.965)  // #F8F9F6
    static let accent = Color(red: 0.439, green: 0.620, blue: 0.365)  // NewsBlur green #709E5D
}

@available(iOS 15.0, *)
struct AskAIView: View {
    @ObservedObject var viewModel: AskAIViewModel
    var onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasAskedQuestion {
                responseView
            } else {
                questionSelectorView
            }
        }
        .background(NewsBlurColors.background)
    }

    // MARK: - Question Selector View

    private var questionSelectorView: some View {
        VStack(spacing: 0) {
            // Summarize Section
            summarizeSection

            // Understand Section
            understandSection

            Spacer(minLength: 0)

            // Custom Question Section
            customQuestionSection
        }
        .background(NewsBlurColors.background)
    }

    private var summarizeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16))
                    .foregroundColor(NewsBlurColors.textSecondary)
                    .frame(width: 18, height: 18)

                Text("Summarize")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(NewsBlurColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            // Segmented control for Brief/Medium/Detailed
            HStack(spacing: 8) {
                ForEach([AskAIQuestionType.sentence, .bullets, .paragraph], id: \.self) { type in
                    summarizeButton(type)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .padding(.leading, 28) // Align with text after icon
            .background(NewsBlurColors.inputBackground)
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(NewsBlurColors.cardBackground)
    }

    private func summarizeButton(_ type: AskAIQuestionType) -> some View {
        Button(action: {
            viewModel.selectedSummarizeType = type
            viewModel.sendQuestion(type)
        }) {
            VStack(spacing: 4) {
                // Icon with consistent height
                summarizeIconView(for: type)
                    .frame(height: 20)

                VStack(spacing: 2) {
                    Text(type.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(NewsBlurColors.textPrimary)

                    Text(type.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(NewsBlurColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(NewsBlurColors.cardBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(viewModel.selectedSummarizeType == type ? NewsBlurColors.accent : NewsBlurColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func summarizeIconView(for type: AskAIQuestionType) -> some View {
        switch type {
        case .sentence:
            // Single line - custom drawn for consistent size
            RoundedRectangle(cornerRadius: 1)
                .fill(NewsBlurColors.textSecondary)
                .frame(width: 16, height: 2)
        case .bullets:
            Image(systemName: "list.bullet")
                .font(.system(size: 16))
                .foregroundColor(NewsBlurColors.textSecondary)
        case .paragraph:
            Image(systemName: "text.alignleft")
                .font(.system(size: 16))
                .foregroundColor(NewsBlurColors.textSecondary)
        default:
            Image(systemName: "text.alignleft")
                .font(.system(size: 16))
                .foregroundColor(NewsBlurColors.textSecondary)
        }
    }

    private var understandSection: some View {
        VStack(spacing: 0) {
            ForEach([AskAIQuestionType.context, .people, .arguments, .factcheck], id: \.self) { type in
                understandButton(type)
            }
        }
    }

    private func understandButton(_ type: AskAIQuestionType) -> some View {
        Button(action: {
            viewModel.sendQuestion(type)
        }) {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(NewsBlurColors.textSecondary)
                    .frame(width: 18, height: 18)

                Text(type.displayTitle)
                    .font(.system(size: 13))
                    .foregroundColor(NewsBlurColors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(NewsBlurColors.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var customQuestionSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Voice button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.isRecording ? .red : NewsBlurColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(viewModel.isRecording ? Color.red.opacity(0.1) : NewsBlurColors.cardBackground)
                        )
                        .overlay(
                            Circle()
                                .stroke(NewsBlurColors.border, lineWidth: 1)
                        )
                }
                .disabled(viewModel.isTranscribing)

                // Text input
                TextField("Ask a question...", text: $viewModel.customQuestion)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.cardBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(NewsBlurColors.border, lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .disabled(viewModel.isRecording || viewModel.isTranscribing)

                // Ask button with model selector
                askButtonMenu
            }
            .padding(10)
            .background(NewsBlurColors.inputBackground)

            if viewModel.isRecording || viewModel.isTranscribing {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: NewsBlurColors.accent))
                        .scaleEffect(0.8)
                    Text(viewModel.isRecording ? "Recording..." : "Transcribing...")
                        .font(.system(size: 12))
                        .foregroundColor(NewsBlurColors.textSecondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(NewsBlurColors.inputBackground)
            }
        }
    }

    private var askButtonMenu: some View {
        Menu {
            ForEach(AskAIProvider.allCases) { model in
                Button(action: {
                    viewModel.selectedModel = model
                    if !viewModel.customQuestion.isEmpty {
                        viewModel.sendQuestion(.custom)
                    }
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
            HStack(spacing: 0) {
                Text("Ask")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewModel.customQuestion.isEmpty ? NewsBlurColors.textSecondary : NewsBlurColors.accent)

                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(viewModel.customQuestion.isEmpty ? NewsBlurColors.textSecondary : NewsBlurColors.accent)
            }
            .cornerRadius(4)
        }
        .disabled(viewModel.customQuestion.isEmpty)
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
            .background(NewsBlurColors.background)

            // Follow-up input
            if viewModel.conversation.isComplete || viewModel.conversation.error != nil {
                followUpInput
            }
        }
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.conversation.questionText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(NewsBlurColors.textPrimary)

            if !viewModel.conversation.storyTitle.isEmpty {
                Text("About: \(viewModel.conversation.storyTitle)")
                    .font(.system(size: 12))
                    .foregroundColor(NewsBlurColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NewsBlurColors.cardBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(NewsBlurColors.border, lineWidth: 1)
        )
    }

    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }

    private var responseText: some View {
        MarkdownText(viewModel.conversation.responseText)
            .textSelection(.enabled)
    }

    private var streamingPlaceholder: some View {
        // Empty view - the pulsing model pill indicates loading state
        EmptyView()
    }

    private func usageView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(NewsBlurColors.accent)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(NewsBlurColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NewsBlurColors.accent.opacity(0.1))
        .cornerRadius(6)
    }

    private var followUpInput: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NewsBlurColors.border)
                .frame(height: 1)

            HStack(spacing: 8) {
                // Voice button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.isRecording ? .red : NewsBlurColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(viewModel.isRecording ? Color.red.opacity(0.1) : NewsBlurColors.cardBackground)
                        )
                        .overlay(
                            Circle()
                                .stroke(NewsBlurColors.border, lineWidth: 1)
                        )
                }

                // Text input
                TextField("Follow up...", text: $viewModel.customQuestion)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.cardBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(NewsBlurColors.border, lineWidth: 1)
                    )
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
                    HStack(spacing: 4) {
                        Text("Re-ask")
                            .font(.system(size: 13))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(NewsBlurColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.cardBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(NewsBlurColors.border, lineWidth: 1)
                    )
                }

                // Send button
                if !viewModel.customQuestion.isEmpty {
                    Button(action: {
                        viewModel.sendFollowUp()
                    }) {
                        Text("Send")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(NewsBlurColors.accent)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(10)
            .background(NewsBlurColors.inputBackground)
        }
    }
}

// MARK: - Model Pill

@available(iOS 15.0, *)
struct ModelPill: View {
    let model: AskAIProvider
    var isLoading: Bool = false
    var isError: Bool = false

    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(model.shortName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isError ? .white : model.textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isError ? Color.red : model.color)
                .opacity(isLoading ? (isPulsing ? 0.6 : 1.0) : 1.0)
        )
        .onAppear {
            if isLoading {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isLoading) { loading in
            if loading {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - Markdown Text

@available(iOS 15.0, *)
struct MarkdownText: View {
    let text: String

    private let bodyFont = Font.system(size: 15, weight: .regular, design: .default)
    private let headingFont = Font.system(size: 18, weight: .semibold, design: .default)
    private let subheadingFont = Font.system(size: 16, weight: .semibold, design: .default)
    private let bulletColor = Color(red: 0.439, green: 0.620, blue: 0.365) // NewsBlur green
    private let textColor = Color(red: 0.369, green: 0.384, blue: 0.404)

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphView(paragraph, index: index)
            }
        }
    }

    @ViewBuilder
    private func paragraphView(_ paragraph: String, index: Int) -> some View {
        if paragraph.hasPrefix("# ") {
            // H1 Heading
            Text(formatInlineMarkdown(String(paragraph.dropFirst(2))))
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(textColor)
                .padding(.top, index > 0 ? 8 : 0)
        } else if paragraph.hasPrefix("## ") {
            // H2 Heading
            Text(formatInlineMarkdown(String(paragraph.dropFirst(3))))
                .font(headingFont)
                .foregroundColor(textColor)
                .padding(.top, index > 0 ? 6 : 0)
        } else if paragraph.hasPrefix("### ") {
            // H3 Heading
            Text(formatInlineMarkdown(String(paragraph.dropFirst(4))))
                .font(subheadingFont)
                .foregroundColor(textColor)
                .padding(.top, index > 0 ? 4 : 0)
        } else if paragraph.hasPrefix("- ") || paragraph.hasPrefix("* ") {
            // Bullet point with proper hanging indent
            bulletPointView(String(paragraph.dropFirst(2)))
        } else if paragraph.hasPrefix("---") {
            // Horizontal rule
            Rectangle()
                .fill(Color(red: 0.816, green: 0.824, blue: 0.800))
                .frame(height: 1)
                .padding(.vertical, 8)
        } else if let numberMatch = paragraph.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            // Numbered list
            let number = String(paragraph[numberMatch].dropLast())
            let content = String(paragraph[numberMatch.upperBound...])
            numberedListView(number: number, content: content)
        } else {
            // Regular paragraph
            Text(formatInlineMarkdown(paragraph))
                .font(bodyFont)
                .foregroundColor(textColor)
                .lineSpacing(4)
        }
    }

    private func bulletPointView(_ content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("•")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(bulletColor)
                .frame(width: 20, alignment: .leading)

            Text(formatInlineMarkdown(content))
                .font(bodyFont)
                .foregroundColor(textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
    }

    private func numberedListView(number: String, content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(number)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(bulletColor)
                .frame(width: 24, alignment: .trailing)
                .padding(.trailing, 6)

            Text(formatInlineMarkdown(content))
                .font(bodyFont)
                .foregroundColor(textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
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
                    replacement.font = .system(size: 15, weight: .semibold)
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
                    replacement.font = .system(size: 15).italic()
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
