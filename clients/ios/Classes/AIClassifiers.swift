//
//  AIClassifiers.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-10-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

// MARK: - Story header pills

/// AIClassifiers.swift builds the story header pills that show which natural language prompts matched a story,
/// mirroring the web template in media/js/newsblur/views/story_detail_view.js. StoryDetailObjCViewController.m
/// places them after the URL match, and storyDetailView.js routes a tap to the story trainer.
@objcMembers final class StoryAIClassifierPills: NSObject {
    static func headerHTML(for promptClassifiers: Any?) -> String {
        guard let entries = promptClassifiers as? [Any] else { return "" }
        let pills = entries.compactMap(pillHTML(for:))
        guard !pills.isEmpty else { return "" }
        return "<div class=\"NB-story-ai-classifiers\">\(pills.joined())</div>"
    }

    private static func pillHTML(for entry: Any) -> String? {
        guard let classifier = entry as? [String: Any],
              let prompt = classifier["prompt"] as? String,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        // AIClassifiers.swift only shows prompts whose result moved the story; the server sends 1 or -1.
        let score = AIClassifierValue.int(classifier["score"])
        guard score != 0 else { return nil }
        let includesImages = AIClassifierValue.bool(classifier["include_images"])
        let label = includesImages ? NBLocalization.text("Image Filter") : NBLocalization.text("Content Filter")
        return "<a href=\"http://ios.newsblur.com/train\" class=\"NB-story-ai-classifier NB-score-\(score)\" "
            + "data-prompt-type=\"\(includesImages ? "image" : "content")\">"
            + "<span class=\"NB-story-ai-classifier-label\">\(escapeHTML(label))</span>: "
            + "<span class=\"NB-story-ai-classifier-prompt\" dir=\"auto\">\(escapeHTML(prompt))</span></a>"
    }

    /// AIClassifiers.swift escapes prompt text for HTML. A backslash becomes an entity too, because
    /// StoryDetailObjCViewController.m's refreshHeader embeds the header inside a JavaScript string.
    static func escapeHTML(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            case "\\": escaped += "&#92;"
            case "\n", "\r": escaped += " "
            default: escaped.append(character)
            }
        }
        return escaped
    }
}

// MARK: - JSON values

/// AIClassifiers.swift reads loosely typed JSON from the NewsBlur API, where booleans and numbers can
/// arrive as NSNumber, Bool, Int or numeric strings.
enum AIClassifierValue {
    static func bool(_ value: Any?) -> Bool {
        switch value {
        case let number as NSNumber: return number.boolValue
        case let string as String: return ["1", "true", "yes"].contains(string.lowercased())
        default: return false
        }
    }

    static func int(_ value: Any?) -> Int {
        switch value {
        case let number as NSNumber: return number.intValue
        case let string as String: return Int(string) ?? 0
        default: return 0
        }
    }
}

// MARK: - Prompt classifiers

/// The two kinds of natural language classifiers in the trainer, matching the web's content and image
/// filter sections in media/js/newsblur/reader/reader_classifier.js.
enum PromptClassifierKind: String, CaseIterable {
    case content
    case image

    var includesImages: Bool { self == .image }

    /// The key in a feed's classifiers dictionary from /reader/feed or /classifier/<feed_id>.
    var classifiersKey: String { self == .image ? "image_prompts" : "prompts" }

    /// The classifier type that /classifier/save prefixes with like_, dislike_ and remove_.
    var saveType: String { self == .image ? "image_prompt" : "prompt" }
}

/// AIClassifiers.swift turns a prompt classifier change into the /classifier/save parameters that
/// apps/analyzer/views.py save_classifier reads (like_prompt, remove_dislike_image_prompt and so on).
@objcMembers final class PromptClassifierSave: NSObject {
    /// The trainer cycles a saved prompt like the other classifier rows: like, then dislike, then removed.
    static func nextScore(afterTapping score: Int) -> Int {
        score > 0 ? -1 : score < 0 ? 0 : 1
    }

    /// The thumbs down button turns a dislike off, or anything else into a dislike.
    static func nextScore(afterTappingDislike score: Int) -> Int {
        score < 0 ? 0 : -1
    }

    static func parameters(prompt: String, feedId: String, score: Int, previousScore: Int,
                           includeImages: Bool, scope: String?, folderName: String?) -> [String: Any]? {
        let type = includeImages ? "image_prompt" : "prompt"
        let key: String
        if score > 0 {
            key = "like_\(type)"
        } else if score < 0 {
            key = "dislike_\(type)"
        } else if previousScore > 0 {
            key = "remove_like_\(type)"
        } else if previousScore < 0 {
            key = "remove_dislike_\(type)"
        } else {
            return nil
        }

        var parameters: [String: Any] = [key: prompt, "feed_id": feedId]
        if let scope, scope != ClassifierScope.feed.rawValue {
            parameters["scope"] = scope
            if scope == ClassifierScope.folder.rawValue, let folderName, !folderName.isEmpty {
                parameters["folder_name"] = folderName
            }
        }
        return parameters
    }
}

/// A saved natural language prompt as the trainer shows it.
struct PromptClassifier: Identifiable, Equatable {
    let prompt: String
    let kind: PromptClassifierKind
    let score: Int
    let scope: ClassifierScope
    let folderName: String

    var id: String { "\(kind.rawValue):\(prompt)" }

    /// Reads the saved prompts and their scopes from a feed's classifiers dictionary.
    static func saved(in classifiers: AnyDictionary?, kind: PromptClassifierKind) -> [PromptClassifier] {
        guard let prompts = classifiers?[kind.classifiersKey] as? AnyDictionary else { return [] }
        return prompts.compactMap { key, value -> PromptClassifier? in
            guard let prompt = key as? String else { return nil }
            let info = ClassifierScopeResolver.resolveInfo(from: classifiers, classifierKey: kind.classifiersKey, name: prompt)
            return PromptClassifier(prompt: prompt, kind: kind, score: AIClassifierValue.int(value),
                                    scope: info.scope, folderName: info.folderName)
        }
        .sorted { $0.prompt.localizedCaseInsensitiveCompare($1.prompt) == .orderedAscending }
    }
}

// MARK: - Prompt tests

/// The outcome of /classifier/test_prompt in apps/analyzer/views.py.
struct PromptTestResult: Equatable {
    enum Outcome: Equatable {
        /// `matches` is true when the story (text mode) or any image (image mode) matched.
        case classified(matches: Bool, imageMatches: [Bool])
        case failed(message: String?)
    }

    let outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    init(json: [String: Any]) {
        if AIClassifierValue.int(json["code"]) == 0, json["classification"] != nil {
            let imageMatches = (json["image_results"] as? [Any] ?? []).map { AIClassifierValue.int($0) == 1 }
            outcome = .classified(matches: AIClassifierValue.int(json["classification"]) != 0, imageMatches: imageMatches)
        } else {
            outcome = .failed(message: json["message"] as? String)
        }
    }
}

// MARK: - Networking

/// AIClassifiers.swift sends AI classifier requests through this seam so tests can answer them without the
/// network. Paths are relative to the account's NewsBlur host.
@MainActor protocol AIClassifierTransport: AnyObject {
    func post(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void)
}

/// The production transport, which uses NewsBlurAppDelegate's authenticated AFNetworking session.
@MainActor final class AppDelegateAIClassifierTransport: AIClassifierTransport {
    func post(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let appDelegate = NewsBlurAppDelegate.shared, let host = appDelegate.url else {
            completion(.failure(URLError(.notConnectedToInternet)))
            return
        }
        appDelegate.post("\(host)\(path)", parameters: parameters, success: { _, response in
            completion(.success(response as? [String: Any] ?? [:]))
        }, failure: { _, error in
            completion(.failure(error ?? URLError(.unknown)))
        })
    }
}

/// The AI classifier endpoints the trainer calls.
@MainActor final class AIClassifierAPI {
    /// NewsBlurTests replace this to answer requests with fixtures.
    static var makeTransport: () -> AIClassifierTransport = { AppDelegateAIClassifierTransport() }

    let transport: AIClassifierTransport

    init(transport: AIClassifierTransport? = nil) {
        self.transport = transport ?? Self.makeTransport()
    }

    /// Each prompt test runs a real AI request on the server, so callers only send one on a tap. Every account can
    /// test a prompt, including those whose saved filters don't score stories.
    func testPrompt(_ prompt: String, kind: PromptClassifierKind, storyHash: String, feedId: String,
                    classifierType: String, completion: @escaping (PromptTestResult) -> Void) {
        let parameters: [String: Any] = [
            "prompt": prompt,
            "story_hash": storyHash,
            "include_images": kind.includesImages ? "true" : "false",
            "classifier_type": classifierType,
            "feed_id": Self.numericFeedId(feedId),
        ]
        transport.post("/classifier/test_prompt", parameters: parameters) { result in
            switch result {
            case .success(let json): completion(PromptTestResult(json: json))
            case .failure: completion(PromptTestResult(outcome: .failed(message: nil)))
            }
        }
    }

    /// apps/analyzer/views.py parses feed_id as an integer, so social and river ids become 0.
    static func numericFeedId(_ feedId: String) -> String {
        Int(feedId) != nil ? feedId : "0"
    }
}
