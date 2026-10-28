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

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
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
    let costEstimate: AIClassifierCostEstimate?

    init(outcome: Outcome, costEstimate: AIClassifierCostEstimate?) {
        self.outcome = outcome
        self.costEstimate = costEstimate
    }

    init(json: [String: Any]) {
        if AIClassifierValue.int(json["code"]) == 0, json["classification"] != nil {
            let imageMatches = (json["image_results"] as? [Any] ?? []).map { AIClassifierValue.int($0) == 1 }
            outcome = .classified(matches: AIClassifierValue.int(json["classification"]) != 0, imageMatches: imageMatches)
        } else {
            outcome = .failed(message: json["message"] as? String)
        }
        costEstimate = AIClassifierCostEstimate(json: json["cost_estimate"] as? [String: Any])
    }
}

// MARK: - Cost estimates

/// Average AI costs per story from /classifier/ai_classifier_usage or a prompt test's cost_estimate.
struct AIClassifierCostEstimate: Equatable {
    let averageCostPerText: Double
    let averageCostPerImage: Double

    init(averageCostPerText: Double, averageCostPerImage: Double) {
        self.averageCostPerText = averageCostPerText
        self.averageCostPerImage = averageCostPerImage
    }

    init?(json: [String: Any]?) {
        guard let json, json["avg_cost_per_text"] != nil || json["avg_cost_per_image"] != nil else { return nil }
        averageCostPerText = AIClassifierValue.double(json["avg_cost_per_text"]) ?? 0
        averageCostPerImage = AIClassifierValue.double(json["avg_cost_per_image"]) ?? 0
    }

    func costPerRun(for kind: PromptClassifierKind) -> Double {
        kind == .image ? averageCostPerImage : averageCostPerText
    }
}

/// /classifier/ai_classifier_usage in apps/analyzer/views.py.
struct AIClassifierUsage: Equatable {
    let canUseAI: Bool
    let estimate: AIClassifierCostEstimate?
    let isLimitReached: Bool

    init(json: [String: Any]) {
        canUseAI = AIClassifierValue.bool(json["can_use_ai"])
        estimate = canUseAI ? AIClassifierCostEstimate(json: json) : nil
        isLimitReached = AIClassifierValue.bool(json["is_limit_reached"])
    }
}

/// One active filter counted in a section's cost estimate, with the stories it would score each month.
struct AIClassifierCostFilter: Equatable {
    let scope: ClassifierScope
    let storiesPerMonth: Int
}

/// The cost row under each trainer AI section, computed the way reader_classifier.js _render_section_cost does.
struct AIClassifierSectionCost: Equatable {
    let monthly: String
    let daily: String
    let breakdown: String
}

enum AIClassifierCostFormatter {
    /// reader_classifier.js _format_cost keeps tiny per-story costs readable.
    static func format(_ amount: Double) -> String {
        if amount == 0 { return "$0.00" }
        if amount < 0.005 { return String(format: "$%.4f", locale: Locale(identifier: "en_US_POSIX"), amount) }
        if amount < 0.10 { return String(format: "$%.3f", locale: Locale(identifier: "en_US_POSIX"), amount) }
        return String(format: "$%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
    }

    static func sectionCost(kind: PromptClassifierKind, costPerRun: Double, feedStoriesPerMonth: Int,
                            filters: [AIClassifierCostFilter]) -> AIClassifierSectionCost? {
        let totalStories = filters.reduce(0) { $0 + $1.storiesPerMonth }
        guard feedStoriesPerMonth > 0 || totalStories > 0 else { return nil }

        // Filters that are all feed scoped still cost one run per story on this site.
        let effectiveStories = totalStories > 0 ? totalStories : feedStoriesPerMonth
        let monthly = filters.isEmpty ? 0 : Double(effectiveStories) * costPerRun
        let costPerStory = String(format: NBLocalization.text("%@/story"), format(costPerRun))

        let breakdown: String
        let scopes = orderedScopes(in: filters)
        if filters.isEmpty || scopes == [.feed] {
            breakdown = [storiesPerMonth(feedStoriesPerMonth), filterCount(filters.count, kind: kind), costPerStory]
                .joined(separator: " \u{00D7} ")
        } else {
            let parts = scopes.map { scope -> String in
                let scoped = filters.filter { $0.scope == scope }
                let count = NBLocalization.formattedCount(scoped.count)
                let stories = storiesPerMonth(scoped.first?.storiesPerMonth ?? 0)
                switch scope {
                case .feed: return String(format: NBLocalization.text("%1$@ on this site (%2$@)"), count, stories)
                case .folder: return String(format: NBLocalization.text("%1$@ on folder (%2$@)"), count, stories)
                case .global: return String(format: NBLocalization.text("%1$@ on all sites (%2$@)"), count, stories)
                }
            }
            breakdown = parts.joined(separator: " + ") + " \u{00D7} " + costPerStory
        }

        return AIClassifierSectionCost(monthly: format(monthly), daily: format(monthly / 30), breakdown: breakdown)
    }

    private static func orderedScopes(in filters: [AIClassifierCostFilter]) -> [ClassifierScope] {
        var scopes: [ClassifierScope] = []
        for filter in filters where !scopes.contains(filter.scope) {
            scopes.append(filter.scope)
        }
        return scopes
    }

    private static func storiesPerMonth(_ stories: Int) -> String {
        NBLocalization.plural("%@ stories/mo", groupedCount: stories)
    }

    private static func filterCount(_ count: Int, kind: PromptClassifierKind) -> String {
        kind == .image
            ? NBLocalization.plural("%@ image filters", groupedCount: count)
            : NBLocalization.plural("%@ content filters", groupedCount: count)
    }
}

/// AIClassifiers.swift sums stories_last_month across the feeds a prompt's scope covers, like
/// reader_classifier.js _stories_for_scope.
struct AIClassifierStoryVolumes {
    let storiesForFeed: (String) -> Int
    let storiesForFolder: (String) -> Int
    let storiesForAllSites: () -> Int

    func stories(scope: ClassifierScope, folderName: String, feedId: String?) -> Int {
        switch scope {
        case .global: return storiesForAllSites()
        case .folder: return folderName.isEmpty ? 0 : storiesForFolder(folderName)
        case .feed: return feedId.map(storiesForFeed) ?? 0
        }
    }

    @MainActor static func live(appDelegate: NewsBlurAppDelegate?) -> AIClassifierStoryVolumes {
        func feedStories(_ feedId: String) -> Int {
            let feed = (appDelegate?.dictActiveFeeds?[feedId] ?? appDelegate?.dictFeeds?[feedId]) as? AnyDictionary
            return AIClassifierValue.int(feed?["stories_last_month"])
        }
        return AIClassifierStoryVolumes(
            storiesForFeed: feedStories,
            storiesForFolder: { folderName in
                guard let appDelegate, let folders = appDelegate.dictFolders as? [String: Any] else { return 0 }
                // NewsBlurAppDelegate.m stores folders by full path ("Tech ▸ Swift"); classifier scopes use the last name.
                let roots = folders.keys.filter { appDelegate.extractFolderName($0) == folderName }
                var feedIds = Set<String>()
                for (path, feeds) in folders where roots.contains(where: { path == $0 || path.hasPrefix($0 + " ▸ ") }) {
                    for feedId in feeds as? [Any] ?? [] { feedIds.insert("\(feedId)") }
                }
                return feedIds.reduce(0) { $0 + feedStories($1) }
            },
            storiesForAllSites: {
                guard let feeds = appDelegate?.dictFeeds as? [AnyHashable: Any] else { return 0 }
                return feeds.values.reduce(0) { $0 + AIClassifierValue.int(($1 as? AnyDictionary)?["stories_last_month"]) }
            }
        )
    }
}

// MARK: - Usage billing

/// The usage billing flags in the user_profile from /reader/feeds (apps/profile/models.py canonical).
struct UsageBillingStatus: Equatable {
    var isUsageBilling: Bool
    var isSelfHostedAI: Bool
    var canUseAIClassifiers: Bool
    var usageBillingLimit: Double?

    init(isUsageBilling: Bool, isSelfHostedAI: Bool, canUseAIClassifiers: Bool, usageBillingLimit: Double?) {
        self.isUsageBilling = isUsageBilling
        self.isSelfHostedAI = isSelfHostedAI
        self.canUseAIClassifiers = canUseAIClassifiers
        self.usageBillingLimit = usageBillingLimit
    }

    init(profile: [AnyHashable: Any]?) {
        isUsageBilling = AIClassifierValue.bool(profile?["is_usage_billing"])
        isSelfHostedAI = AIClassifierValue.bool(profile?["is_self_hosted_ai"])
        if profile?["can_use_ai_classifiers"] != nil {
            canUseAIClassifiers = AIClassifierValue.bool(profile?["can_use_ai_classifiers"])
        } else {
            canUseAIClassifiers = isUsageBilling || isSelfHostedAI
        }
        usageBillingLimit = AIClassifierValue.double(profile?["usage_billing_limit"])
    }

    @MainActor static var current: UsageBillingStatus {
        UsageBillingStatus(profile: NewsBlurAppDelegate.shared?.dictUserProfile as? [AnyHashable: Any])
    }

    /// The account billing status line, from reader_account.js.
    var statusText: String {
        if isUsageBilling {
            return NBLocalization.text("Usage-based billing is enabled for natural language classifiers.")
        } else if isSelfHostedAI {
            return NBLocalization.text("Natural language classifiers are using your instance's API keys.")
        } else {
            return NBLocalization.text("Set up usage-based billing to use natural language content and image filters.")
        }
    }
}

/// /profile/usage_billing_history in apps/profile/views.py.
struct UsageBillingHistory: Equatable {
    struct LineItem: Equatable {
        let description: String
        let quantity: Int
        let amount: Double
    }

    struct Invoice: Equatable {
        let date: Date?
        let amount: Double
        let status: String
        let hostedInvoiceURL: URL?
        let lineItems: [LineItem]

        var isScheduled: Bool { status == "draft" || status == "upcoming" }
    }

    let invoices: [Invoice]
    let upcomingInvoice: Invoice?
    let currentCycleSpend: Double
    let usageBillingLimit: Double?
    let isLimitReached: Bool
    let cycleStart: Date?
    let cycleEnd: Date?

    init(json: [String: Any]) {
        invoices = (json["invoices"] as? [[String: Any]] ?? []).map { Self.invoice(from: $0, amountKey: "amount_paid") }
        upcomingInvoice = (json["upcoming_invoice"] as? [String: Any]).map { Self.invoice(from: $0, amountKey: "amount") }
        currentCycleSpend = AIClassifierValue.double(json["current_cycle_spend"]) ?? 0
        usageBillingLimit = AIClassifierValue.double(json["usage_billing_limit"])
        isLimitReached = AIClassifierValue.bool(json["is_limit_reached"])
        cycleStart = (json["cycle_start"] as? String).flatMap(Self.day)
        cycleEnd = (json["cycle_end"] as? String).flatMap(Self.day)
    }

    /// The limit progress bar's fill from 0 to 1, or nil when no limit is set.
    var limitProgress: Double? {
        guard let usageBillingLimit, usageBillingLimit > 0 else { return nil }
        return min(1, currentCycleSpend / usageBillingLimit)
    }

    /// reader_account.js warns past 80% of the limit.
    var isNearLimit: Bool { (limitProgress ?? 0) > 0.8 }

    var hasInvoices: Bool { !invoices.isEmpty || upcomingInvoice != nil }

    private static func invoice(from json: [String: Any], amountKey: String) -> Invoice {
        Invoice(date: (json["date"] as? String).flatMap(day),
                amount: AIClassifierValue.double(json[amountKey]) ?? AIClassifierValue.double(json["amount"]) ?? 0,
                status: json["status"] as? String ?? "",
                hostedInvoiceURL: (json["hosted_invoice_url"] as? String).flatMap(URL.init(string:)),
                lineItems: (json["line_items"] as? [[String: Any]] ?? []).map {
                    LineItem(description: $0["description"] as? String ?? "",
                             quantity: AIClassifierValue.int($0["quantity"]),
                             amount: AIClassifierValue.double($0["amount"]) ?? 0)
                })
    }

    /// The server sends dates as YYYY-MM-DD in UTC, which AIClassifiers.swift keeps as that calendar day.
    static func day(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

/// The result of /profile/save_usage_billing_limit, which answers code 1 on success.
enum UsageBillingLimitSaveResult: Equatable {
    case saved(limit: Double?)
    case failed(message: String?)

    init(json: [String: Any]) {
        if AIClassifierValue.int(json["code"]) == 1 {
            self = .saved(limit: AIClassifierValue.double(json["limit"]))
        } else {
            self = .failed(message: json["message"] as? String)
        }
    }
}

/// Opening Stripe from the app: /profile/setup_usage_billing/ and /profile/manage_usage_billing/ with
/// platform=ios answer with a Stripe URL as JSON instead of redirecting (apps/profile/views.py).
enum UsageBillingStripeAction: String {
    case setup
    case manage

    var path: String { self == .setup ? "/profile/setup_usage_billing/" : "/profile/manage_usage_billing/" }
}

enum UsageBillingStripeResponse: Equatable {
    case open(URL)
    case alreadyActive
    case failed(message: String?)

    init(json: [String: Any]) {
        if AIClassifierValue.int(json["code"]) == 0 {
            if AIClassifierValue.bool(json["already_active"]) {
                self = .alreadyActive
            } else if let address = json["url"] as? String, let url = URL(string: address),
                      let scheme = url.scheme?.lowercased(), scheme == "https" {
                self = .open(url)
            } else {
                self = .failed(message: json["message"] as? String)
            }
        } else {
            self = .failed(message: json["message"] as? String)
        }
    }
}

/// Stripe returns the in-app browser to newsblur-auth://usage-billing?status=... (apps/profile/views.py).
enum UsageBillingCallback: Equatable {
    static let scheme = "newsblur-auth"

    case setupComplete
    case cancelled
    case portalReturn

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, url.host?.lowercased() == "usage-billing" else { return nil }
        let status = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "status" })?.value
        switch status {
        case "setup_complete": self = .setupComplete
        case "cancelled": self = .cancelled
        case "portal_return": self = .portalReturn
        default: return nil
        }
    }
}

// MARK: - Networking

/// AIClassifiers.swift sends AI classifier and usage billing requests through this seam so tests can answer
/// them without the network. Paths are relative to the account's NewsBlur host.
@MainActor protocol AIClassifierTransport: AnyObject {
    func get(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void)
    func post(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void)
}

/// The production transport, which uses NewsBlurAppDelegate's authenticated AFNetworking session.
@MainActor final class AppDelegateAIClassifierTransport: AIClassifierTransport {
    func get(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let appDelegate = NewsBlurAppDelegate.shared, let host = appDelegate.url else {
            completion(.failure(URLError(.notConnectedToInternet)))
            return
        }
        appDelegate.get("\(host)\(path)", parameters: parameters, success: { _, response in
            completion(.success(response as? [String: Any] ?? [:]))
        }, failure: { _, error in
            completion(.failure(error ?? URLError(.unknown)))
        })
    }

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

/// The AI classifier endpoints the trainer and the usage billing screen call.
@MainActor final class AIClassifierAPI {
    /// NewsBlurTests replace this to answer requests with fixtures.
    static var makeTransport: () -> AIClassifierTransport = { AppDelegateAIClassifierTransport() }

    let transport: AIClassifierTransport

    init(transport: AIClassifierTransport? = nil) {
        self.transport = transport ?? Self.makeTransport()
    }

    /// Each prompt test runs a real AI request that the reader pays for, so callers only send one on a tap.
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
            case .failure: completion(PromptTestResult(outcome: .failed(message: nil), costEstimate: nil))
            }
        }
    }

    func fetchUsage(feedId: String?, completion: @escaping (AIClassifierUsage?) -> Void) {
        transport.get("/classifier/ai_classifier_usage", parameters: ["feed_id": Self.numericFeedId(feedId)]) { result in
            if case .success(let json) = result { completion(AIClassifierUsage(json: json)) } else { completion(nil) }
        }
    }

    func fetchUsageBillingHistory(completion: @escaping (UsageBillingHistory?) -> Void) {
        transport.get("/profile/usage_billing_history", parameters: [:]) { result in
            if case .success(let json) = result { completion(UsageBillingHistory(json: json)) } else { completion(nil) }
        }
    }

    /// A blank limit clears it.
    func saveUsageBillingLimit(_ limit: String, completion: @escaping (UsageBillingLimitSaveResult) -> Void) {
        let trimmed = limit.trimmingCharacters(in: .whitespacesAndNewlines)
        transport.post("/profile/save_usage_billing_limit", parameters: ["limit": trimmed]) { result in
            switch result {
            case .success(let json): completion(UsageBillingLimitSaveResult(json: json))
            case .failure: completion(.failed(message: nil))
            }
        }
    }

    func startStripe(_ action: UsageBillingStripeAction, completion: @escaping (UsageBillingStripeResponse) -> Void) {
        transport.post(action.path, parameters: ["platform": "ios"]) { result in
            switch result {
            case .success(let json): completion(UsageBillingStripeResponse(json: json))
            case .failure: completion(.failed(message: nil))
            }
        }
    }

    /// apps/analyzer/views.py parses feed_id as an integer, so social and river ids become 0.
    static func numericFeedId(_ feedId: String?) -> String {
        guard let feedId, Int(feedId) != nil else { return "0" }
        return feedId
    }
}
