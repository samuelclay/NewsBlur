//
//  TrainerRegexInput.swift
//  NewsBlur
//
//  Created by David Sinclair on 2025-03-03.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

import SwiftUI

struct TrainerRegexInput: View {
    enum SectionType {
        case title, text, url
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
        }
    }

    // MARK: - Match Type Toggle

    var matchTypeToggle: some View {
        HStack(spacing: 0) {
            Button {
                isRegex = false
            } label: {
                Text("Exact phrase")
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
                Text("Regex")
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
                badge(text: "\u{2713} Valid", style: .valid)
                if let matchResult = storyMatchResult {
                    if matchResult {
                        badge(text: "\u{2713} Matches story", style: .valid)
                    } else {
                        badge(text: "No match in story", style: .noMatch)
                    }
                }
            case .invalid(let error):
                badge(text: "Invalid: \(error)", style: .error)
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

    var storyMatchResult: Bool? {
        guard let story else { return nil }
        guard case .valid = validationResult else { return nil }

        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: trimmed, options: [.caseInsensitive]) else { return nil }

        let textToMatch: String
        switch sectionType {
        case .title:
            textToMatch = story.title
        case .text:
            textToMatch = story.contentHTML
        case .url:
            textToMatch = story.permalink
        }

        let range = NSRange(textToMatch.startIndex..<textToMatch.endIndex, in: textToMatch)
        return regex.firstMatch(in: textToMatch, options: [], range: range) != nil
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
            case .title: return "e.g. \\bbreaking\\b"
            case .text: return "e.g. sponsored|advertisement"
            case .url: return "e.g. /blog/\\d{4}/"
            }
        } else {
            switch sectionType {
            case .title: return "Enter title phrase..."
            case .text: return "Enter text phrase..."
            case .url: return "Enter URL phrase..."
            }
        }
    }

    var headerLabel: String {
        switch sectionType {
        case .title: return isRegex ? "Title Regex" : "Title"
        case .text: return isRegex ? "Text Regex" : "Text"
        case .url: return isRegex ? "URL Regex" : "URL"
        }
    }

    // MARK: - Regex Help

    private var purpleAccent: Color {
        Color(red: 0.482, green: 0.408, blue: 0.933) // #7B68EE
    }

    var regexHelpContent: some View {
        VStack(spacing: 0) {
            Text("Regex Patterns")
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

            Text("All patterns are case-insensitive by default")
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
        }

        pattern = ""
    }

}
