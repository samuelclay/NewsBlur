//
//  StoryClassifierScorer.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// StoryClassifierScorer.swift recomputes a loaded story's text, URL and regex classifier scores with the rules in
/// apps/analyzer/models.py, so NewsBlurAppDelegate.m's recalculateIntelligenceScores: shows a classifier change on
/// stories that are already loaded, and a removed classifier stops counting there without waiting for a reload.
@objcMembers final class StoryClassifierScorer: NSObject {
    private struct Classifier {
        let pattern: String
        let score: Int
    }

    private struct RegexSearch: Hashable {
        let classifierKey: String
        let pattern: String
    }

    /// Drops tags and keeps their text and entities, like the server's strip_tags before it matches story content.
    private static let htmlTag = try! NSRegularExpression(pattern: "<[A-Za-z/!?][^>]*>")

    private let isPremium: Bool
    /// apps/reader/views.py scores text classifiers for Premium Archive and Pro, and every regex for Pro only.
    private let canUseTextClassifiers: Bool
    private let isPremiumPro: Bool
    private let classifiersByKey: [String: [Classifier]]
    private var compiledRegexes: [String: NSRegularExpression] = [:]
    private var invalidPatterns: Set<String> = []
    /// A pattern that runs out of time on one story counts as no match on the rest of this pass, so a pattern
    /// that backtracks costs the main thread one TrainerRegexMatcher.drawingBudget rather than one per loaded story.
    private var timedOutSearches: Set<RegexSearch> = []

    init(classifiers: NSDictionary?, isPremium: Bool, isPremiumArchive: Bool, isPremiumPro: Bool) {
        self.isPremium = isPremium
        self.canUseTextClassifiers = isPremiumArchive || isPremiumPro
        self.isPremiumPro = isPremiumPro

        let feedClassifiers = classifiers as? [String: Any] ?? [:]
        var classifiersByKey: [String: [Classifier]] = [:]
        for key in ["texts", "text_regex", "urls", "url_regex", "title_regex", "author_regex"] {
            let entries = feedClassifiers[key] as? [String: Any] ?? [:]
            // A removed classifier stays in the dictionary at 0 until the next reload, and a 0 never changes a score.
            classifiersByKey[key] = entries.compactMap { pattern, value in
                let score = (value as? NSNumber)?.intValue ?? 0
                return score == 0 || pattern.isEmpty ? nil : Classifier(pattern: pattern, score: score)
            }
        }
        self.classifiersByKey = classifiersByKey
    }

    /// The story's text, URL and regex scores, keyed like the server's intelligence dictionary. A story loaded
    /// without its content gets no text or text_regex entry, so the server's scores for those stay.
    func scores(forStory story: NSDictionary) -> [String: Int] {
        let title = Self.string(story["story_title"])
        let authors = Self.string(story["story_authors"])
        let permalink = Self.string(story["story_permalink"])
        let permalinkLowercased = permalink.lowercased()

        var scores = [
            "url": isPremium ? score(for: "urls", in: permalink) { permalinkLowercased.contains($0.lowercased()) } : 0,
            "url_regex": isPremiumPro ? regexScore(for: "url_regex", in: permalink) : 0,
            "title_regex": isPremiumPro ? regexScore(for: "title_regex", in: title) : 0,
            "author_regex": isPremiumPro ? regexScore(for: "author_regex", in: authors) : 0,
        ]

        if let content = story["story_content"] as? String {
            let scoresText = canUseTextClassifiers && !(classifiersByKey["texts"] ?? []).isEmpty
            let scoresTextRegex = isPremiumPro && !(classifiersByKey["text_regex"] ?? []).isEmpty
            // Classifiers match the text a reader sees, so a phrase split by <em> or <a> still matches.
            let visibleText = scoresText || scoresTextRegex ? Self.visibleText(ofHTML: content) : ""
            let visibleTextLowercased = visibleText.lowercased()
            scores["text"] = scoresText
                ? score(for: "texts", in: visibleText) { visibleTextLowercased.contains($0.lowercased()) } : 0
            scores["text_regex"] = scoresTextRegex ? regexScore(for: "text_regex", in: visibleText) : 0
        }

        return scores
    }

    /// The server's rule for one classifier type: a matching super dislike wins outright, then any like, then any
    /// dislike. A story without the text it matches against scores 0.
    private func score(for key: String, in text: String, matches: (String) -> Bool) -> Int {
        guard !text.isEmpty else { return 0 }
        var score = 0
        for classifier in classifiersByKey[key] ?? [] where matches(classifier.pattern) {
            if classifier.score <= -2 {
                return classifier.score
            }
            if classifier.score > 0 {
                score = classifier.score
            } else if score <= 0 {
                score = classifier.score
            }
        }
        return score
    }

    /// Regexes are case insensitive and an invalid or timed-out one doesn't match, like the server's safe_regex_match.
    private func regexScore(for key: String, in text: String) -> Int {
        score(for: key, in: text) { pattern in
            let search = RegexSearch(classifierKey: key, pattern: pattern)
            guard !timedOutSearches.contains(search), let regex = regex(for: pattern) else { return false }
            switch TrainerRegexMatcher.outcome(of: regex, in: text, budget: TrainerRegexMatcher.drawingBudget) {
            case .matches:
                return true
            case .noMatch:
                return false
            case .timedOut:
                timedOutSearches.insert(search)
                return false
            }
        }
    }

    private func regex(for pattern: String) -> NSRegularExpression? {
        if let regex = compiledRegexes[pattern] {
            return regex
        }
        guard !invalidPatterns.contains(pattern),
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            invalidPatterns.insert(pattern)
            return nil
        }
        compiledRegexes[pattern] = regex
        return regex
    }

    private static func visibleText(ofHTML html: String) -> String {
        htmlTag.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "")
    }

    private static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }
}
