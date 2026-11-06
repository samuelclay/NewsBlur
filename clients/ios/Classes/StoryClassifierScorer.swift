//
//  StoryClassifierScorer.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// StoryClassifierScorer.swift recomputes a loaded story's title, author, tag, text, URL and regex classifier scores
/// with the rules in apps/analyzer/models.py, so NewsBlurAppDelegate.m's recalculateIntelligenceScores: shows a
/// classifier change on stories that are already loaded, and a removed classifier stops counting there without
/// waiting for a reload.
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

    /// One recalculation's time for matching text and regex classifiers, which runs on the main thread over every
    /// loaded story. Once it's spent, the rest of the stories keep the server's text and regex scores and count as
    /// uncertain, so StoryScoreRefresher.swift asks the server for them.
    static let passBudget: TimeInterval = 0.1

    /// Drops tags and keeps their text and entities, like the server's strip_tags before it matches story content.
    private static let htmlTag = try! NSRegularExpression(pattern: "<[A-Za-z/!?][^>]*>")

    private let isPremium: Bool
    /// apps/reader/views.py scores text classifiers for Premium Archive and Pro, and every regex for Pro only.
    private let canUseTextClassifiers: Bool
    private let isPremiumPro: Bool
    private let classifiersByKey: [String: [Classifier]]
    /// Each title classifier lowercased once for the whole pass, the way classifier_title_matches compares it.
    private let lowercasedTitlePatterns: [String: [Unicode.Scalar]]
    private var compiledRegexes: [String: NSRegularExpression] = [:]
    private var invalidPatterns: Set<String> = []
    /// A pattern that runs out of time on one story isn't searched again this pass, so a pattern that backtracks
    /// costs the main thread one TrainerRegexMatcher.drawingBudget rather than one per loaded story. The server
    /// gives each search twice that, so the app can't tell whether it matches and keeps the server's score.
    private var timedOutSearches: Set<RegexSearch> = []

    private let budget: TimeInterval
    private let clock: () -> TimeInterval
    private let started: TimeInterval
    private let textCache: StoryVisibleTextCache
    /// The stories this pass left a text, URL or regex score on as the server sent it, because the app couldn't tell
    /// what it is now. StoryScoreRefresher.swift asks the server for them.
    private(set) var uncertainStoryHashes: Set<String> = []

    convenience init(classifiers: NSDictionary?, isPremium: Bool, isPremiumArchive: Bool, isPremiumPro: Bool) {
        self.init(classifiers: classifiers, isPremium: isPremium, isPremiumArchive: isPremiumArchive,
                  isPremiumPro: isPremiumPro, budget: StoryClassifierScorer.passBudget,
                  clock: StoryClassifierScorer.threadTime, textCache: .shared)
    }

    /// NewsBlurTests pass their own budget, clock and cache.
    @nonobjc init(classifiers: NSDictionary?, isPremium: Bool, isPremiumArchive: Bool, isPremiumPro: Bool,
                  budget: TimeInterval, clock: @escaping () -> TimeInterval, textCache: StoryVisibleTextCache) {
        self.isPremium = isPremium
        self.canUseTextClassifiers = isPremiumArchive || isPremiumPro
        self.isPremiumPro = isPremiumPro
        self.budget = budget
        self.clock = clock
        self.started = clock()
        self.textCache = textCache

        let feedClassifiers = classifiers as? [String: Any] ?? [:]
        var classifiersByKey: [String: [Classifier]] = [:]
        for key in ["titles", "authors", "tags", "texts", "text_regex", "urls", "url_regex", "title_regex", "author_regex"] {
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
        lowercasedTitlePatterns = Dictionary(uniqueKeysWithValues: (classifiersByKey["titles"] ?? []).map { classifier in
            (classifier.pattern, ClassifierTextMatching.pythonLowercased(classifier.pattern))
        })
    }

    /// The story's title, author, tag, text, URL and regex scores, keyed like the server's intelligence dictionary.
    /// A score the app can't work out is left out so the server's stays: text and text_regex on a story loaded
    /// without its content, any score that rests on a pattern the app couldn't search or that may hide another
    /// score, and text and regex scores once the pass's budget is spent. Leaving out a score that may have changed
    /// adds the story to uncertainStoryHashes.
    func scores(forStory story: NSDictionary) -> [String: Int] {
        let title = Self.string(story["story_title"])
        let authors = Self.string(story["story_authors"])
        let tags = (story["story_tags"] as? [Any] ?? []).compactMap { $0 as? String }
        let permalink = Self.string(story["story_permalink"])
        let permalinkLowercased = permalink.lowercased()

        var scores: [String: Int?] = [:]
        // Titles, authors and tags score for every account. ClassifierTextMatching compares them the way
        // apps/analyzer/models.py does, so a match the server wouldn't make never shows.
        let lowercasedTitle = (classifiersByKey["titles"] ?? []).isEmpty ? [] : ClassifierTextMatching.pythonLowercased(title)
        scores["title"] = score(for: "titles", in: title) { pattern in
            ClassifierTextMatching.titleMatches(lowercasedTitle: lowercasedTitle,
                                                lowercasedClassifier: self.lowercasedTitlePatterns[pattern] ?? [])
        }
        scores["author"] = score(for: "authors", in: authors) { ClassifierTextMatching.isSameText($0, authors) }
        scores["tags"] = tags.isEmpty ? 0 : score(for: "tags") { pattern in
            tags.contains { ClassifierTextMatching.isSameText($0, pattern) }
        }
        scores["url"] = isPremium ? score(for: "urls", in: permalink) { permalinkLowercased.contains($0.lowercased()) } : 0
        scores["url_regex"] = isPremiumPro ? regexScore(for: "url_regex", in: permalink) : 0
        scores["title_regex"] = isPremiumPro ? regexScore(for: "title_regex", in: title) : 0
        scores["author_regex"] = isPremiumPro ? regexScore(for: "author_regex", in: authors) : 0

        let scoresText = canUseTextClassifiers && !(classifiersByKey["texts"] ?? []).isEmpty
        let scoresTextRegex = isPremiumPro && !(classifiersByKey["text_regex"] ?? []).isEmpty
        if let content = story["story_content"] as? NSString {
            // Classifiers match the text a reader sees, so a phrase split by <em> or <a> still matches.
            let visibleText = scoresText || scoresTextRegex ? self.visibleText(of: content, storyHash: story["story_hash"]) : nil
            scores["text"] = scoresText ? visibleText.flatMap { visible in
                score(for: "texts", in: visible.text) { pattern in
                    self.isOverBudget ? nil : visible.lowercased.contains(pattern.lowercased())
                }
            } : 0
            scores["text_regex"] = scoresTextRegex ? visibleText.flatMap { regexScore(for: "text_regex", in: $0.text) } : 0
        } else {
            // Without the content there's nothing to match again, so the server's text scores stay. They may be out
            // of date when a classifier could score them, or when the server's score came from one since removed.
            let intelligence = story["intelligence"] as? [String: Any] ?? [:]
            let textMayHaveChanged = scoresText || (canUseTextClassifiers && Self.int(intelligence["text"]) != 0)
            let textRegexMayHaveChanged = scoresTextRegex || (isPremiumPro && Self.int(intelligence["text_regex"]) != 0)
            if textMayHaveChanged || textRegexMayHaveChanged {
                noteUncertain(story)
            }
        }

        if scores.values.contains(where: { $0 == nil }) {
            noteUncertain(story)
        }
        return scores.compactMapValues { $0 }
    }

    /// The server's rule for one classifier type: a matching super dislike wins outright, then any like, then any
    /// dislike. A story without the text it matches against scores 0. The score is uncertain when `matches` answers
    /// nil because the app can't tell, or when a matching pattern may hide another score. Then only a super dislike
    /// that certainly matches settles it; otherwise this returns nil so the server's score stays.
    private func score(for key: String, in text: String, matches: (String) -> Bool?) -> Int? {
        guard !text.isEmpty else { return 0 }
        return score(for: key, matches: matches)
    }

    private func score(for key: String, matches: (String) -> Bool?) -> Int? {
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
    /// patterns Python's re compiles, and some of those, like a (?P<name>...) group, aren't valid ICU. A search gets
    /// whatever is left of the pass's budget when that's less than TrainerRegexMatcher.drawingBudget.
    private func regexScore(for key: String, in text: String) -> Int? {
        score(for: key, in: text) { pattern in
            let search = RegexSearch(classifierKey: key, pattern: pattern)
            let remaining = remainingBudget
            guard remaining > 0, !timedOutSearches.contains(search), let regex = regex(for: pattern) else { return nil }
            switch TrainerRegexMatcher.outcome(of: regex, in: text, budget: min(TrainerRegexMatcher.drawingBudget, remaining)) {
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

    // MARK: Budget

    private var remainingBudget: TimeInterval {
        budget - (clock() - started)
    }

    private var isOverBudget: Bool {
        remainingBudget <= 0
    }

    /// The calling thread's own running time, so a stall while the main thread isn't running doesn't spend the budget.
    static func threadTime() -> TimeInterval {
        var time = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        return TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000
    }

    // MARK: Story text

    /// The story's text without its HTML, from StoryVisibleTextCache when an earlier pass stripped the same content,
    /// or nil once the pass has spent its budget.
    private func visibleText(of content: NSString, storyHash: Any?) -> StoryVisibleTextCache.Text? {
        guard !isOverBudget else { return nil }
        let hash = storyHash as? String
        if let hash, let cached = textCache.text(forStoryHash: hash, content: content) {
            return cached
        }
        let stripped = Self.htmlTag.stringByReplacingMatches(in: content as String, range: NSRange(location: 0, length: content.length),
                                                             withTemplate: "")
        let text = StoryVisibleTextCache.Text(text: stripped, lowercased: stripped.lowercased())
        if let hash {
            textCache.store(text, forStoryHash: hash, content: content)
        }
        return text
    }

    private func noteUncertain(_ story: NSDictionary) {
        if let hash = story["story_hash"] as? String {
            uncertainStoryHashes.insert(hash)
        }
    }

    private static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    private static func int(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? 0
    }
}

/// StoryClassifierScorer.swift matches title, author and tag classifiers the way apps/analyzer/models.py does. Python
/// compares code points, so these compare Unicode scalars, never Swift's characters or canonically equivalent text.
enum ClassifierTextMatching {
    /// classifier_title_matches: case insensitive, and a classifier that starts with a word character must match at
    /// the start of a word, so "apple" matches "Apple launch" but not "Pineapple prices".
    static func titleMatches(_ storyTitle: String, classifier: String) -> Bool {
        titleMatches(lowercasedTitle: pythonLowercased(storyTitle), lowercasedClassifier: pythonLowercased(classifier))
    }

    static func titleMatches(lowercasedTitle title: [Unicode.Scalar], lowercasedClassifier classifier: [Unicode.Scalar]) -> Bool {
        guard let first = classifier.first, !title.isEmpty else { return false }
        let mustStartAWord = isWordCharacter(first)
        var start = 0
        while let index = firstIndex(of: classifier, in: title, from: start) {
            if !mustStartAWord || index == 0 || !isWordCharacter(title[index - 1]) {
                return true
            }
            start = index + 1
        }
        return false
    }

    /// apply_classifier_authors and apply_classifier_tags need the exact text, the way Python's == and `in` compare
    /// strings: no other case, no part of a longer name, and no accent written another way.
    static func isSameText(_ text: String, _ other: String) -> Bool {
        text.unicodeScalars.elementsEqual(other.unicodeScalars)
    }

    /// _is_unicode_word_character: an underscore, a letter or number the way Python's isalnum counts them, or a
    /// combining mark.
    static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "_" {
            return true
        }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark:
            return true
        default:
            return scalar.properties.numericType != nil
        }
    }

    /// Python's str.lower(): each code point's full lowercase mapping, so İ becomes i and a combining dot, and a
    /// capital sigma that ends a word becomes ς.
    static func pythonLowercased(_ text: String) -> [Unicode.Scalar] {
        let scalars = Array(text.unicodeScalars)
        var lowercased: [Unicode.Scalar] = []
        lowercased.reserveCapacity(scalars.count)
        for (index, scalar) in scalars.enumerated() {
            if scalar.isASCII {
                lowercased.append(("A"..."Z").contains(scalar) ? Unicode.Scalar(UInt8(scalar.value + 32)) : scalar)
            } else if scalar == "\u{03A3}" {
                lowercased.append(isFinalSigma(at: index, in: scalars) ? "\u{03C2}" : "\u{03C3}")
            } else {
                lowercased.append(contentsOf: scalar.properties.lowercaseMapping.unicodeScalars)
            }
        }
        return lowercased
    }

    /// Python's handle_capital_sigma: a cased letter comes before the sigma and none after it, skipping case
    /// ignorable ones like apostrophes and accents.
    private static func isFinalSigma(at index: Int, in scalars: [Unicode.Scalar]) -> Bool {
        guard let before = scalars[..<index].last(where: { !$0.properties.isCaseIgnorable }),
              before.properties.isCased else { return false }
        let after = scalars[(index + 1)...].first { !$0.properties.isCaseIgnorable }
        return !(after?.properties.isCased ?? false)
    }

    /// Python's str.find on code points.
    private static func firstIndex(of needle: [Unicode.Scalar], in haystack: [Unicode.Scalar], from start: Int) -> Int? {
        guard !needle.isEmpty, start <= haystack.count - needle.count else { return nil }
        for index in start...(haystack.count - needle.count) where haystack[index] == needle[0] {
            if haystack[index..<(index + needle.count)].elementsEqual(needle) {
                return index
            }
        }
        return nil
    }
}

/// StoryClassifierScorer.swift keeps each story's text without its HTML, and that text lowercased, by story hash, so
/// the recalculation after every classifier save doesn't strip the same stories again. An entry is only used for the
/// content it was made from.
final class StoryVisibleTextCache {
    struct Text: Equatable {
        let text: String
        let lowercased: String
    }

    private final class Entry {
        let content: NSString
        let text: Text

        init(content: NSString, text: Text) {
            self.content = content
            self.text = text
        }
    }

    static let shared = StoryVisibleTextCache()

    private let cache = NSCache<NSString, Entry>()

    init() {
        // About 32 MB of UTF-16 text, a few hundred long stories; NSCache also lets go under memory pressure.
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    /// The story's stripped text, if it was cached for this same content. Rescored stories keep their content
    /// object, so the check is usually a pointer comparison.
    func text(forStoryHash storyHash: String, content: NSString) -> Text? {
        guard let entry = cache.object(forKey: storyHash as NSString),
              entry.content === content || entry.content.isEqual(content) else { return nil }
        return entry.text
    }

    func store(_ text: Text, forStoryHash storyHash: String, content: NSString) {
        let cost = (content.length + text.text.utf16.count + text.lowercased.utf16.count) * 2
        cache.setObject(Entry(content: content, text: text), forKey: storyHash as NSString, cost: cost)
    }
}
