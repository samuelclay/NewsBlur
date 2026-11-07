//
//  TrainerRegexInput.swift
//  NewsBlur
//
//  Created by David Sinclair on 2025-03-03.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

import SwiftUI

/// TrainerRegexInput.swift runs readers' regex classifiers against story text within a time budget. A valid pattern
/// like (a+)+$ backtracks for minutes on a long story it doesn't match, so each search asks NSRegularExpression for
/// progress callbacks and stops once its budget runs out, reporting that it couldn't tell rather than a wrong answer.
@objcMembers final class TrainerRegexMatcher: NSObject {
    enum Outcome: Equatable {
        case matches
        case noMatch
        /// The search ran past its budget, so whether the pattern matches is unknown.
        case timedOut
    }

    /// For the pattern being typed, which TrainerRegexInput.swift checks off the main thread.
    static let typingBudget: TimeInterval = 0.25
    /// For saved patterns checked on the main thread while the trainer or a story header draws.
    static let drawingBudget: TimeInterval = 0.05
    /// How long typing pauses before TrainerRegexInput.swift checks the pattern against the story.
    static let typingDebounce: TimeInterval = 0.3

    static func outcome(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> Outcome {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var outcome = Outcome.noMatch
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if result != nil {
                outcome = .matches
                stop.pointee = true
            } else if ProcessInfo.processInfo.systemUptime > deadline {
                outcome = .timedOut
                stop.pointee = true
            }
        }
        return outcome
    }

    /// The pattern's outcome, or nil when it isn't a valid regex. Patterns are case insensitive, like the server's.
    static func outcome(of pattern: String, in text: String, budget: TimeInterval) -> Outcome? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return outcome(of: regex, in: text, budget: budget)
    }

    /// Searches on a background queue so a slow pattern never holds up typing.
    static func outcomeOffMainThread(of pattern: String, in text: String,
                                     budget: TimeInterval = typingBudget) async -> Outcome? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: outcome(of: pattern, in: text, budget: budget))
            }
        }
    }

    /// Every match, for StoryDetailObjCViewController.m's story header, or nil when the budget ran out first.
    static func matches(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> [NSTextCheckingResult]? {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var matches: [NSTextCheckingResult] = []
        var timedOut = false
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if let result { matches.append(result) }
            if ProcessInfo.processInfo.systemUptime > deadline {
                timedOut = true
                stop.pointee = true
            }
        }
        return timedOut ? nil : matches
    }

    /// The first match for StoryDetailObjCViewController.m's story header, or nil when there is none in the budget.
    static func firstMatch(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> NSTextCheckingResult? {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var match: NSTextCheckingResult?
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if let result {
                match = result
                stop.pointee = true
            } else if ProcessInfo.processInfo.systemUptime > deadline {
                stop.pointee = true
            }
        }
        return match
    }
}

struct TrainerRegexInput: View {
    enum SectionType {
        case title, text, url, author
    }

    let sectionType: SectionType
    let story: Story?
    let feedId: String?
    let appDelegate: NewsBlurAppDelegate
    let fontBuilder: (String, CGFloat) -> Font
    let cache: StoryCache

    @State private var showingHelp = false
    @FocusState private var isTextFieldFocused: Bool

    @State private var isRegex = false
    @State private var pattern = ""
    /// Whether the pattern matches the story, once the search for the current pattern has finished.
    @State private var storyMatch: TrainerRegexMatcher.Outcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                matchTypeToggle

                if isRegex {
                    Button {
                        isTextFieldFocused = false
                        DispatchQueue.main.async {
                            showingHelp = true
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(purpleAccent)
                            .imageScale(.medium)
                    }
                    .popover(isPresented: $showingHelp) {
                        regexHelpContent
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: $pattern)
                    .font(isRegex ? .system(.body, design: .monospaced) : fontBuilder("WhitneySSm-Medium", 14))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)

                if !pattern.isEmpty {
                    Button {
                        pattern = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                            .foregroundColor(.gray)
                    }
                }
            }

            if !pattern.isEmpty {
                if isRegex {
                    validationBadges
                }

                HStack(spacing: 8) {
                    Button {
                        saveClassifier()
                    } label: {
                        TrainerCapsule(score: .none, header: headerLabel, value: pattern, isRegex: isRegex)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding([.top], 12)
        .padding([.bottom], 8)
        .onAppear {
            syncFromCache()
        }
        .onChange(of: isRegex) { newValue in
            syncToCache()
        }
        .onChange(of: pattern) { newValue in
            syncToCache()
        }
        .task(id: storyMatchRequest) {
            await checkStoryMatch(storyMatchRequest)
        }
    }

    // MARK: - Story Match

    /// What TrainerRegexInput.swift searches the story for, so a new pattern cancels the search for the last one.
    struct StoryMatchRequest: Hashable {
        let pattern: String
        let text: String
    }

    var storyMatchRequest: StoryMatchRequest? {
        guard isRegex, let story else { return nil }
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return StoryMatchRequest(pattern: trimmed, text: Self.matchText(for: sectionType, in: story))
    }

    static func matchText(for sectionType: SectionType, in story: Story) -> String {
        switch sectionType {
        case .title: return story.title
        case .text: return story.contentHTML
        case .url: return story.permalink
        case .author: return story.author
        }
    }

    /// Waits for typing to pause, then searches off the main thread. A result for an older pattern never shows.
    private func checkStoryMatch(_ request: StoryMatchRequest?) async {
        storyMatch = nil
        guard let request else { return }
        try? await Task.sleep(nanoseconds: UInt64(TrainerRegexMatcher.typingDebounce * 1_000_000_000))
        guard !Task.isCancelled else { return }
        let outcome = await TrainerRegexMatcher.outcomeOffMainThread(of: request.pattern, in: request.text)
        guard !Task.isCancelled else { return }
        storyMatch = outcome
    }

    // MARK: - Cache Sync

    private func syncFromCache() {
        switch sectionType {
        case .title:
            isRegex = cache.titleIsRegex
            pattern = cache.titlePattern
        case .text:
            isRegex = cache.textIsRegex
            pattern = cache.textPattern
        case .url:
            isRegex = cache.urlIsRegex
            pattern = cache.urlPattern
        case .author:
            isRegex = cache.authorIsRegex
            pattern = cache.authorPattern
        }
    }

    private func syncToCache() {
        switch sectionType {
        case .title:
            cache.titleIsRegex = isRegex
            cache.titlePattern = pattern
        case .text:
            cache.textIsRegex = isRegex
            cache.textPattern = pattern
        case .url:
            cache.urlIsRegex = isRegex
            cache.urlPattern = pattern
        case .author:
            cache.authorIsRegex = isRegex
            cache.authorPattern = pattern
        }
    }

    // MARK: - Match Type Toggle

    var matchTypeToggle: some View {
        HStack(spacing: 0) {
            Button {
                isRegex = false
            } label: {
                Text(NBLocalization.text("Exact phrase"))
                    .font(fontBuilder("WhitneySSm-Medium", 11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(!isRegex ? Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x3A3A3C]) : Color.clear)
                    .foregroundColor(!isRegex ? Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0]) : Color.themed([0x666666, 0x8B7B6B, 0x999999, 0x999999]))
                    .cornerRadius(4)
            }
            .buttonStyle(BorderlessButtonStyle())

            Button {
                isRegex = true
            } label: {
                Text(NBLocalization.text("Regex"))
                    .font(fontBuilder("WhitneySSm-Medium", 11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(isRegex ? Color(red: 0.482, green: 0.408, blue: 0.933) : Color.clear) // #7B68EE
                    .foregroundColor(isRegex ? .white : Color.themed([0x666666, 0x8B7B6B, 0x999999, 0x999999]))
                    .cornerRadius(4)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(2)
        .background(Color.themed([0xE8E8E8, 0xE0D8C8, 0x2C2C2E, 0x2C2C2E]))
        .cornerRadius(6)
    }

    // MARK: - Validation

    var validationBadges: some View {
        HStack(spacing: 6) {
            switch validationResult {
            case .valid:
                badge(text: "\u{2713} " + NBLocalization.text("Valid"), style: .valid)
                switch storyMatch {
                case .matches:
                    badge(text: "\u{2713} " + NBLocalization.text("Matches story"), style: .valid)
                case .noMatch:
                    badge(text: NBLocalization.text("No match in story"), style: .noMatch)
                case .timedOut:
                    badge(text: NBLocalization.text("Couldn't check story"), style: .noMatch)
                case nil:
                    EmptyView()
                }
            case .invalid(let error):
                badge(text: String(format: NBLocalization.text("Invalid: %@"), error), style: .error)
            case .empty:
                EmptyView()
            }
        }
    }

    enum ValidationResult {
        case valid
        case invalid(String)
        case empty
    }

    var validationResult: ValidationResult {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }

        do {
            _ = try NSRegularExpression(pattern: trimmed, options: [.caseInsensitive])
            return .valid
        } catch {
            let message = error.localizedDescription
                .replacingOccurrences(of: "The value \".*\" is invalid\\.", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return .invalid(message.isEmpty ? "Invalid pattern" : message)
        }
    }

    enum BadgeStyle {
        case valid, noMatch, error
    }

    @ViewBuilder
    func badge(text: String, style: BadgeStyle) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(badgeBackground(style))
            .foregroundColor(badgeForeground(style))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(badgeBorder(style), lineWidth: 1)
            )
            .cornerRadius(10)
    }

    func badgeBackground(_ style: BadgeStyle) -> Color {
        switch style {
        case .valid: return Color(red: 0.91, green: 0.96, blue: 0.91) // #E8F5E9
        case .noMatch: return Color(red: 0.96, green: 0.96, blue: 0.96) // #F5F5F5
        case .error: return Color(red: 1.0, green: 0.92, blue: 0.93) // #FFEBEE
        }
    }

    func badgeForeground(_ style: BadgeStyle) -> Color {
        switch style {
        case .valid: return Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32
        case .noMatch: return Color(red: 0.46, green: 0.46, blue: 0.46) // #757575
        case .error: return Color(red: 0.78, green: 0.16, blue: 0.16) // #C62828
        }
    }

    func badgeBorder(_ style: BadgeStyle) -> Color {
        switch style {
        case .valid: return Color(red: 0.65, green: 0.84, blue: 0.65) // #A5D6A7
        case .noMatch: return Color(red: 0.88, green: 0.88, blue: 0.88) // #E0E0E0
        case .error: return Color(red: 0.94, green: 0.60, blue: 0.60) // #EF9A9A
        }
    }

    // MARK: - Placeholders & Labels

    var placeholder: String {
        if isRegex {
            switch sectionType {
            case .title: return String(format: NBLocalization.text("e.g. %@"), "\\bbreaking\\b")
            case .text: return String(format: NBLocalization.text("e.g. %@"), "sponsored|advertisement")
            case .url: return String(format: NBLocalization.text("e.g. %@"), "/blog/\\d{4}/")
            case .author: return String(format: NBLocalization.text("e.g. %@"), "^Sam|smith")
            }
        } else {
            switch sectionType {
            case .title: return NBLocalization.text("Enter title phrase...")
            case .text: return NBLocalization.text("Enter text phrase...")
            case .url: return NBLocalization.text("Enter URL phrase...")
            case .author: return NBLocalization.text("Enter author phrase...")
            }
        }
    }

    var headerLabel: String {
        switch sectionType {
        case .title: return isRegex ? "Title Regex" : "Title"
        case .text: return isRegex ? "Text Regex" : "Text"
        case .url: return isRegex ? "URL Regex" : "URL"
        case .author: return isRegex ? "Author Regex" : "Author"
        }
    }

    // MARK: - Regex Help

    private var purpleAccent: Color {
        Color(red: 0.482, green: 0.408, blue: 0.933) // #7B68EE
    }

    var regexHelpContent: some View {
        VStack(spacing: 0) {
            Text(NBLocalization.text("Regex Patterns"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(purpleAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                regexHelpCard("Word Matching", examples: [
                    ("\\bcat\\b", "Whole word"),
                    ("cat|dog", "Either word"),
                    ("\\bthe cat\\b", "Exact phrase"),
                ])

                regexHelpCard("Position", examples: [
                    ("^Breaking", "Starts with"),
                    ("update$", "Ends with"),
                    ("breaking.*news", "Words in order"),
                ])

                regexHelpCard("Patterns", examples: [
                    ("\\d+", "Numbers"),
                    ("\\$\\d+", "Dollar amounts"),
                    ("#\\w+", "Hashtags"),
                ])

                regexHelpCard("Advanced", examples: [
                    ("^(?!.*sponsor)", "Exclude word"),
                    ("\\d{4}", "Exactly 4 digits"),
                    ("[A-Z]{2,}", "Acronyms"),
                ])
            }
            .padding(.horizontal, 20)

            Spacer()

            Text(NBLocalization.text("All patterns are case-insensitive by default"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 340, minHeight: 360)
    }

    @ViewBuilder
    func regexHelpCard(_ title: String, examples: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(purpleAccent)
                .tracking(0.8)

            ForEach(examples, id: \.0) { pattern, description in
                VStack(alignment: .leading, spacing: 1) {
                    Text(pattern)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(red: 0.353, green: 0.312, blue: 0.812))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(purpleAccent.opacity(0.1))
                        .cornerRadius(4)

                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(purpleAccent.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Save

    func saveClassifier() {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if isRegex {
            if case .invalid = validationResult { return }
        }

        switch sectionType {
        case .title:
            if isRegex {
                appDelegate.toggleTitleRegexClassifier(trimmed, feedId: feedId)
            } else {
                appDelegate.toggleTitleClassifier(trimmed, feedId: feedId, score: 0)
            }
        case .text:
            if isRegex {
                appDelegate.toggleTextRegexClassifier(trimmed, feedId: feedId)
            } else {
                appDelegate.toggleTextClassifier(trimmed, feedId: feedId)
            }
        case .url:
            if isRegex {
                appDelegate.toggleUrlRegexClassifier(trimmed, feedId: feedId)
            } else {
                appDelegate.toggleUrlClassifier(trimmed, feedId: feedId)
            }
        case .author:
            if isRegex {
                appDelegate.toggleAuthorRegexClassifier(trimmed, feedId: feedId)
            } else {
                appDelegate.toggleAuthorClassifier(trimmed, feedId: feedId)
            }
        }

        pattern = ""
    }

}
