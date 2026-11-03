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
        /// apps/analyzer/models.py get_classifiers_for_user keeps one score per pattern, so when the pattern is also
        /// trained for a folder or all sites, its scope metadata lists it and the score shown may hide this site's
        /// classifier for the same pattern with another score. The server scores both.
        let mayHideAnotherScore: Bool
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
    /// A pattern that runs out of time on one story isn't searched again this pass, so a pattern that backtracks
    /// costs the main thread one TrainerRegexMatcher.drawingBudget rather than one per loaded story. The server
    /// gives each search twice that, so the app can't tell whether it matches and keeps the server's score.
    private var timedOutSearches: Set<RegexSearch> = []

    init(classifiers: NSDictionary?, isPremium: Bool, isPremiumArchive: Bool, isPremiumPro: Bool) {
        self.isPremium = isPremium
        self.canUseTextClassifiers = isPremiumArchive || isPremiumPro
        self.isPremiumPro = isPremiumPro

        let feedClassifiers = classifiers as? [String: Any] ?? [:]
        var classifiersByKey: [String: [Classifier]] = [:]
        for key in ["texts", "text_regex", "urls", "url_regex", "title_regex", "author_regex"] {
            let entries = feedClassifiers[key] as? [String: Any] ?? [:]
            let scopes = feedClassifiers[ClassifierScopeResolver.metadataKey(for: key)] as? [String: Any] ?? [:]
            // A removed classifier stays in the dictionary at 0 until the next reload. A 0 never changes a score,
            // unless it may hide another classifier for the same pattern that the server still scores.
            classifiersByKey[key] = entries.compactMap { pattern, value in
                let score = (value as? NSNumber)?.intValue ?? 0
                let mayHideAnotherScore = scopes[pattern] != nil
                guard !pattern.isEmpty, score != 0 || mayHideAnotherScore else { return nil }
                return Classifier(pattern: pattern, score: score, mayHideAnotherScore: mayHideAnotherScore)
            }
        }
        self.classifiersByKey = classifiersByKey
    }

    /// The story's text, URL and regex scores, keyed like the server's intelligence dictionary. A score the app
    /// can't work out is left out so the server's stays: text and text_regex on a story loaded without its content,
    /// and any score that rests on a pattern the app couldn't search.
    func scores(forStory story: NSDictionary) -> [String: Int] {
        let title = Self.string(story["story_title"])
        let authors = Self.string(story["story_authors"])
        let permalink = Self.string(story["story_permalink"])
        let permalinkLowercased = permalink.lowercased()

        var scores: [String: Int] = [:]
        scores["url"] = isPremium ? score(for: "urls", in: permalink) { permalinkLowercased.contains($0.lowercased()) } : 0
        scores["url_regex"] = isPremiumPro ? regexScore(for: "url_regex", in: permalink) : 0
        scores["title_regex"] = isPremiumPro ? regexScore(for: "title_regex", in: title) : 0
        scores["author_regex"] = isPremiumPro ? regexScore(for: "author_regex", in: authors) : 0

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
    /// dislike. A story without the text it matches against scores 0. The score is uncertain when `matches` answers
    /// nil because the app can't tell, or when a matching pattern may hide another score. Then only a super dislike
    /// that certainly matches settles it; otherwise this returns nil so the server's score stays.
    private func score(for key: String, in text: String, matches: (String) -> Bool?) -> Int? {
        guard !text.isEmpty else { return 0 }
        var score = 0
        var isCertain = true
        for classifier in classifiersByKey[key] ?? [] {
            // Once the score is uncertain, only a super dislike can still settle it, so skip searching the rest.
            if !isCertain && classifier.score > -2 {
                continue
            }
            guard let matched = matches(classifier.pattern) else {
                isCertain = false
                continue
            }
            guard matched else { continue }
            if classifier.score <= -2 {
                return classifier.score
            }
            if classifier.mayHideAnotherScore {
                isCertain = false
            } else if classifier.score > 0 {
                score = classifier.score
            } else if score <= 0 {
                score = classifier.score
            }
        }
        return isCertain ? score : nil
    }

    /// Regexes are case insensitive, like the server's safe_regex_match. The app can't tell whether a pattern matches
    /// when the search runs out of time, or when NSRegularExpression rejects it: apps/analyzer/views.py only saves
    /// patterns Python's re compiles, and some of those, like a (?P<name>...) group, aren't valid ICU.
    private func regexScore(for key: String, in text: String) -> Int? {
        score(for: key, in: text) { pattern in
            let search = RegexSearch(classifierKey: key, pattern: pattern)
            guard !timedOutSearches.contains(search), let regex = regex(for: pattern) else { return nil }
            switch TrainerRegexMatcher.outcome(of: regex, in: text, budget: TrainerRegexMatcher.drawingBudget) {
            case .matches:
                return true
            case .noMatch:
                return false
            case .timedOut:
                timedOutSearches.insert(search)
                return nil
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
