//
//  AskAIView.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Theme Observer for SwiftUI

@available(iOS 15.0, *)
class AskAIThemeObserver: ObservableObject {
    @Published var themeVersion: Int = 0

    private var observers: [NSObjectProtocol] = []

    init() {
        // Observe UserDefaults changes for theme-related keys
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.themeVersion += 1
        }
        observers.append(observer)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - NewsBlur Design Colors (Theme-aware)
@available(iOS 15.0, *)
private struct NewsBlurColors {
    // Theme-aware colors: returns appropriate color based on current NewsBlur theme
    // Themes: Light, Sepia, Medium (gray), Dark (black)

    static var background: Color {
        // Light: #EAECE6, Sepia: #F5E6D3, Medium: #3D3D3D, Dark: #1A1A1A
        themedColor(light: 0xEAECE6, sepia: 0xF3E2CB, medium: 0x3D3D3D, dark: 0x1A1A1A)
    }

    static var cardBackground: Color {
        // Light: white, Sepia: #FDF8F0, Medium: #4A4A4A, Dark: #2A2A2A
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x4A4A4A, dark: 0x2A2A2A)
    }

    static var cardHover: Color {
        // Light: #ECEEEA, Sepia: #F0E8DC, Medium: #555555, Dark: #333333
        themedColor(light: 0xECEEEA, sepia: 0xF0E8DC, medium: 0x555555, dark: 0x333333)
    }

    static var border: Color {
        // Light: #D0D2CC, Sepia: #D4C8B8, Medium: #5A5A5A, Dark: #404040
        themedColor(light: 0xD0D2CC, sepia: 0xD4C8B8, medium: 0x5A5A5A, dark: 0x404040)
    }

    static var textPrimary: Color {
        // Light: #5E6267, Sepia: #5C4A3D, Medium: #E0E0E0, Dark: #E8E8E8
        themedColor(light: 0x5E6267, sepia: 0x5C4A3D, medium: 0xE0E0E0, dark: 0xE8E8E8)
    }

    static var textSecondary: Color {
        // Light: #90928B, Sepia: #8B7B6B, Medium: #A0A0A0, Dark: #B0B0B0
        themedColor(light: 0x90928B, sepia: 0x8B7B6B, medium: 0xA0A0A0, dark: 0xB0B0B0)
    }

    static var inputBackground: Color {
        // Light: #F8F9F6, Sepia: #FAF5ED, Medium: #3A3A3A, Dark: #222222
        themedColor(light: 0xF8F9F6, sepia: 0xFAF5ED, medium: 0x3A3A3A, dark: 0x222222)
    }

    static let accent = Color(red: 0.439, green: 0.620, blue: 0.365)  // NewsBlur green #709E5D

    // Helper to create themed color from hex values for Light, Sepia, Medium, Dark
    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            // Default to light theme if no theme manager
            return Color(
                red: Double((light >> 16) & 0xFF) / 255.0,
                green: Double((light >> 8) & 0xFF) / 255.0,
                blue: Double(light & 0xFF) / 255.0
            )
        }

        let hex: Int

        // Use effectiveTheme which resolves "auto" to the actual visual theme
        let effectiveTheme = themeManager.effectiveTheme

        if effectiveTheme == ThemeStyleMedium || effectiveTheme == "medium" {
            hex = medium
        } else if effectiveTheme == ThemeStyleDark || effectiveTheme == "dark" {
            hex = dark
        } else if effectiveTheme == ThemeStyleSepia || effectiveTheme == "sepia" {
            hex = sepia
        } else {
            hex = light
        }

        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

@available(iOS 15.0, *)
struct AskAIView: View {
    @ObservedObject var viewModel: AskAIViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var shouldAutoScroll: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasAskedQuestion {
                responseView
            } else {
                questionSelectorView
            }
        }
        .background(NewsBlurColors.background)
        .id(themeObserver.themeVersion) // Force re-render when theme changes
    }

    // MARK: - Question Selector View

    private var questionSelectorView: some View {
        VStack(spacing: 0) {
            // Summarize Section
            summarizeSection

            // Understand Section
            understandSection

            // Custom Question Section
            customQuestionSection

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
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
            .padding(.vertical, 16)

            // Segmented control for Brief/Medium/Detailed
            HStack(spacing: 8) {
                ForEach([AskAIQuestionType.sentence, .bullets, .paragraph], id: \.self) { type in
                    summarizeButton(type)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .padding(.leading, 28) // Align with text after icon
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(NewsBlurColors.cardBackground)
    }

    private func summarizeButton(_ type: AskAIQuestionType) -> some View {
        Button(action: {
            viewModel.selectedSummarizeType = type
            viewModel.sendQuestion(type)
        }) {
            VStack(spacing: 6) {
                // Icon with consistent height
                summarizeIconView(for: type)
                    .frame(height: 20)

                VStack(spacing: 2) {
                    Text(type.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(NewsBlurColors.textPrimary)

                    Text(type.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(NewsBlurColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(NewsBlurColors.cardBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(NewsBlurColors.border, lineWidth: 1)
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
            // Header row
            HStack(spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 16))
                    .foregroundColor(NewsBlurColors.textSecondary)
                    .frame(width: 18, height: 18)

                Text("Understand")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(NewsBlurColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(NewsBlurColors.background)

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
                    .font(.system(size: 14))
                    .foregroundColor(NewsBlurColors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
                    .foregroundColor(NewsBlurColors.textPrimary)
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
                    .onSubmit {
                        if !viewModel.customQuestion.isEmpty {
                            viewModel.sendQuestion(.custom)
                        }
                    }

                // Ask button with model selector
                askButtonMenu
            }
            .padding(12)
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
        HStack(spacing: 8) {
            // Model selector (always enabled, to the left of Ask)
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
                HStack(spacing: 6) {
                    Text(viewModel.selectedModel.shortName)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(viewModel.selectedModel.textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(viewModel.selectedModel.color)
                )
            }

            // Ask button
            Button(action: {
                if !viewModel.customQuestion.isEmpty {
                    viewModel.sendQuestion(.custom)
                }
            }) {
                Text("Ask")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewModel.customQuestion.isEmpty ? NewsBlurColors.textSecondary : NewsBlurColors.accent)
                    .cornerRadius(4)
            }
            .disabled(viewModel.customQuestion.isEmpty)
        }
    }

    // MARK: - Response View

    private var responseView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Display all completed response blocks
                        ForEach(Array(viewModel.conversation.completedBlocks.enumerated()), id: \.element.id) { index, block in
                            completedBlockView(block, index: index)
                        }

                        // Current streaming response (if any)
                        if viewModel.conversation.isStreaming || !viewModel.conversation.responseText.isEmpty {
                            currentStreamingView
                        }

                        // Error message
                        if let error = viewModel.conversation.error {
                            errorView(error)
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
                // Detect user scroll interaction to disable auto-scroll
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            // User is manually scrolling, disable auto-scroll
                            if shouldAutoScroll {
                                shouldAutoScroll = false
                            }
                        }
                )
                .onChange(of: viewModel.conversation.responseText) { newValue in
                    // Only auto-scroll during streaming if user hasn't scrolled away
                    if viewModel.conversation.isStreaming && shouldAutoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.conversation.isStreaming) { isStreaming in
                    // Only re-enable auto-scroll and scroll to bottom when streaming STARTS (new question)
                    // Never force scroll when streaming stops - respect user's scroll position
                    if isStreaming {
                        shouldAutoScroll = true
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .background(NewsBlurColors.background)

            // Follow-up input - show when complete, error, or not streaming (graceful timeout)
            if viewModel.conversation.isComplete || viewModel.conversation.error != nil || (!viewModel.conversation.isStreaming && !viewModel.conversation.responseText.isEmpty) {
                followUpInput
            }
        }
    }

    private func completedBlockView(_ block: AskAIResponseBlock, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question header (show story title only on first block)
            if block.isFollowUp {
                followUpQuestionHeader(block.questionText)
            } else {
                questionHeaderView(block.questionText, showStoryTitle: true)
            }

            // Model pill (right-justified) - show if first block or model changed
            let previousModel = index > 0 ? viewModel.conversation.completedBlocks[index - 1].model : nil
            if index == 0 || block.model != previousModel {
                HStack {
                    Spacer()
                    ModelPill(model: block.model, isLoading: false)
                }
            }

            // Response text
            MarkdownText(block.responseText)
                .textSelection(.enabled)
        }
    }

    private var currentStreamingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // If this is a follow-up (there are completed blocks), show the question
            if !viewModel.conversation.completedBlocks.isEmpty {
                followUpQuestionHeader(viewModel.conversation.questionText)
            } else {
                questionHeaderView(viewModel.conversation.questionText, showStoryTitle: true)
            }

            // Model pill - show if first or model changed from last completed block
            let lastModel = viewModel.conversation.completedBlocks.last?.model
            if lastModel == nil || viewModel.conversation.model != lastModel {
                HStack {
                    Spacer()
                    ModelPill(model: viewModel.conversation.model, isLoading: viewModel.conversation.isStreaming)
                }
            } else if viewModel.conversation.isStreaming {
                // Show pulsing pill while streaming even if same model
                HStack {
                    Spacer()
                    ModelPill(model: viewModel.conversation.model, isLoading: true)
                }
            }

            // Response text
            if !viewModel.conversation.responseText.isEmpty {
                MarkdownText(viewModel.conversation.responseText)
                    .textSelection(.enabled)
            }
        }
    }

    private func followUpQuestionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12))
                .foregroundColor(NewsBlurColors.textSecondary)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(NewsBlurColors.textPrimary)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(NewsBlurColors.cardBackground.opacity(0.7))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(NewsBlurColors.border.opacity(0.5), lineWidth: 1)
        )
    }

    private func questionHeaderView(_ text: String, showStoryTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(NewsBlurColors.textPrimary)

            if showStoryTitle && !viewModel.conversation.storyTitle.isEmpty {
                Text(viewModel.conversation.storyTitle)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundColor(NewsBlurColors.textSecondary)
                    .lineLimit(2)
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
        let isRateLimitError = error.contains("limit") || error.contains("used all") || error.contains("reached")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(isRateLimitError ? .orange : .red)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(isRateLimitError ? NewsBlurColors.textPrimary : .red)
            }

            // Show upgrade button for rate-limited non-archive users
            if isRateLimitError && !NewsBlurAppDelegate.shared()!.isPremiumArchive {
                Button(action: {
                    openPremiumDialog()
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("Upgrade to Premium Archive")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.accent)
                    .cornerRadius(6)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isRateLimitError ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }


    private func usageView(_ message: String) -> some View {
        let isRateLimitError = message.contains("limit") || message.contains("used all") || message.contains("reached")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isRateLimitError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundColor(isRateLimitError ? .orange : NewsBlurColors.accent)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(NewsBlurColors.textPrimary)
            }

            // Show upgrade button for rate-limited non-archive users
            if isRateLimitError && !NewsBlurAppDelegate.shared()!.isPremiumArchive {
                Button(action: {
                    openPremiumDialog()
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("Upgrade to Premium Archive")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.accent)
                    .cornerRadius(6)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isRateLimitError ? Color.orange.opacity(0.1) : NewsBlurColors.accent.opacity(0.1))
        .cornerRadius(6)
    }

    private func openPremiumDialog() {
        if let appDelegate = NewsBlurAppDelegate.shared() {
            appDelegate.showPremiumDialogForArchive()
        }
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
                    .foregroundColor(NewsBlurColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NewsBlurColors.cardBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(NewsBlurColors.border, lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .onSubmit {
                        if !viewModel.customQuestion.isEmpty {
                            viewModel.sendFollowUp()
                        }
                    }

                // Model selector with native iOS picker style
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
                    HStack(spacing: 6) {
                        Text(viewModel.selectedModel.shortName)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(viewModel.selectedModel.textColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(viewModel.selectedModel.color)
                    )
                }

                // Re-ask button (when no text) or Send button (when text)
                if viewModel.customQuestion.isEmpty {
                    Button(action: {
                        viewModel.reaskWithModel(viewModel.selectedModel)
                    }) {
                        Text("Re-ask")
                            .font(.system(size: 13))
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
                } else {
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

    // Theme-aware text color
    private var textColor: Color {
        guard let themeManager = ThemeManager.shared else {
            return Color(red: 0.369, green: 0.384, blue: 0.404) // #5E6267 default
        }

        // Use effectiveTheme which resolves "auto" to the actual visual theme
        let effectiveTheme = themeManager.effectiveTheme

        if effectiveTheme == ThemeStyleMedium || effectiveTheme == "medium" {
            return Color(red: 0.88, green: 0.88, blue: 0.88) // #E0E0E0
        } else if effectiveTheme == ThemeStyleDark || effectiveTheme == "dark" {
            return Color(red: 0.91, green: 0.91, blue: 0.91) // #E8E8E8
        } else if effectiveTheme == ThemeStyleSepia || effectiveTheme == "sepia" {
            return Color(red: 0.36, green: 0.29, blue: 0.24) // #5C4A3D
        } else {
            return Color(red: 0.369, green: 0.384, blue: 0.404) // #5E6267
        }
    }

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
