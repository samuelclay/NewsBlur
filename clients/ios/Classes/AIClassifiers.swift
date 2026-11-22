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

// MARK: - AI credits

/// A month of AI credits, from apps/analyzer/ai_credits.py state(). /reader/feeds sends it as user_profile.ai_credits,
/// and /analyzer/ai_classifier_usage, /profile/usage_billing_history and /profile/save_usage_billing_limit answer with
/// a fresh one. Every paid plan includes credits each month; usage billing keeps filters running past them.
struct AICredits: Equatable {
    /// Why filters aren't scoring stories: a plan without credits, a month's credits used, or the monthly limit hit.
    enum PauseReason: String {
        case plan
        case credits
        case limit
    }

    /// Where the month is headed at the last week's pace.
    struct Forecast: Equatable {
        var credits: Double
        var runsOutOn: Date?
        /// What the month would cost with usage billing, before any limit.
        var overageUSD: Double
    }

    /// What the trainer and AICreditsView.swift tell the reader, checked in this order: a server that counts no
    /// credits, a plan without them, a limit reached, credits used, usage billing, then running low or running.
    enum Status: Equatable {
        case unlimited
        case free
        case pausedAtLimit
        case pausedForCredits
        case usageBilling
        case warning
        case running
    }

    var included: Int
    var used: Double
    var resetsOn: Date?
    var isUnlimited: Bool
    var isBillingAvailable: Bool
    var isUsageBilling: Bool
    var monthlyLimit: Double?
    var overageUSD: Double
    var unbilledUSD: Double
    var minimumChargeUSD: Double
    var immediateChargeUSD: Double
    var pauseReason: PauseReason?
    var isWarning: Bool
    var forecast: Forecast?

    init?(json: Any?) {
        guard let json = json as? [AnyHashable: Any], json["included"] != nil || json["is_unlimited"] != nil else { return nil }
        included = AIClassifierValue.int(json["included"])
        used = AIClassifierValue.double(json["used"]) ?? 0
        resetsOn = AICreditsFormat.parseDay(json["resets_on"])
        isUnlimited = AIClassifierValue.bool(json["is_unlimited"])
        isBillingAvailable = AIClassifierValue.bool(json["is_billing_available"])
        isUsageBilling = AIClassifierValue.bool(json["is_usage_billing"])
        monthlyLimit = AIClassifierValue.double(json["monthly_limit"]).flatMap { $0 > 0 ? $0 : nil }
        overageUSD = AIClassifierValue.double(json["overage_usd"]) ?? 0
        unbilledUSD = AIClassifierValue.double(json["unbilled_usd"]) ?? 0
        minimumChargeUSD = AIClassifierValue.double(json["minimum_charge_usd"]) ?? 1
        immediateChargeUSD = AIClassifierValue.double(json["immediate_charge_usd"]) ?? 10
        pauseReason = (json["pause_reason"] as? String).flatMap(PauseReason.init(rawValue:))
        isWarning = AIClassifierValue.bool(json["is_warning"])
        if let forecast = json["forecast"] as? [AnyHashable: Any] {
            self.forecast = Forecast(credits: AIClassifierValue.double(forecast["credits"]) ?? 0,
                                     runsOutOn: AICreditsFormat.parseDay(forecast["runs_out_on"]),
                                     overageUSD: AIClassifierValue.double(forecast["overage_usd"]) ?? 0)
        } else {
            forecast = nil
        }
    }

    init?(profile: [AnyHashable: Any]?) {
        self.init(json: profile?["ai_credits"])
    }

    /// The signed in account's credits, as /reader/feeds or the last usage fetch left them (AICreditsStore).
    @MainActor static var current: AICredits? {
        AICredits(profile: NewsBlurAppDelegate.shared?.dictUserProfile as? [AnyHashable: Any])
    }

    var status: Status {
        if isUnlimited { return .unlimited }
        switch pauseReason {
        case .plan: return .free
        case .limit: return .pausedAtLimit
        case .credits: return .pausedForCredits
        case nil: break
        }
        if isUsageBilling { return .usageBilling }
        return isWarning ? .warning : .running
    }

    var isPaused: Bool { pauseReason != nil }

    /// The meter's fill: the share of the plan's credits used, full once they're gone.
    var usedFraction: Double {
        guard included > 0 else { return used > 0 ? 1 : 0 }
        return min(1, max(0, used / Double(included)))
    }

    /// Usage billing past a monthly limit, from 0 to 1, or nil without a limit.
    var limitFraction: Double? {
        guard isUsageBilling, let monthlyLimit else { return nil }
        return min(1, max(0, overageUSD / monthlyLimit))
    }

    /// With usage billing on, running low means nearing the monthly limit. The server's is_warning also counts the
    /// plan's credits, which usage billing keeps going past, so it would keep the meter amber all month.
    var isNearLimit: Bool {
        (limitFraction ?? 0) >= 0.8
    }

    // MARK: Wording

    /// "12,340 of 10,000 AI credits used", or nil for usage billing without included credits.
    var usedText: String? {
        guard included > 0 else { return nil }
        // AIClassifiers.swift compares whole credits as shown, so 10,000.4 of 10,000 never reads "0 past your plan's".
        let shownUsed = AICreditsFormat.shownCredits(used)
        let plan = AICreditsFormat.credits(Double(included))
        guard shownUsed > Double(included) else {
            return NBLocalization.plural("%2$@ of %3$@ AI credits used", count: included,
                                         arguments: [AICreditsFormat.credits(used), plan])
        }
        return NBLocalization.plural("%2$@ AI credits used, %3$@ past your plan's %4$@", count: included,
                                     arguments: [AICreditsFormat.credits(used),
                                                 AICreditsFormat.credits(shownUsed - Double(included)), plan])
    }

    var resetText: String? {
        resetsOn.map { String(format: NBLocalization.text("Resets %@"), AICreditsFormat.day($0)) }
    }

    /// The day credits come back, for sentences that need one even if the server left it out.
    private var resetDay: String {
        resetsOn.map(AICreditsFormat.day) ?? ""
    }

    static var freeText: String {
        NBLocalization.text("AI filters are saved but only run on Premium. Premium includes 1,000 AI credits a month, Archive 10,000 and Pro 100,000.")
    }

    var runsOutText: String? {
        guard let runsOutOn = forecast?.runsOutOn else { return nil }
        return String(format: NBLocalization.text("At this pace your credits run out around %@."), AICreditsFormat.day(runsOutOn))
    }

    /// The forecast line on AICreditsView.swift: where the month is headed at the last week's pace.
    var forecastText: String? {
        guard let forecast, forecast.credits > 0 else { return nil }
        return NBLocalization.plural("At this pace, this month will use about %2$@ AI credits.",
                                     value: AICreditsFormat.shownCredits(forecast.credits),
                                     display: AICreditsFormat.credits(forecast.credits))
    }

    var pausedText: [String] {
        [String(format: NBLocalization.text("Your AI filters are paused until %@."), resetDay),
         NBLocalization.plural("This month's %@ AI credits are used.", groupedCount: included)]
    }

    var limitReachedText: String {
        String(format: NBLocalization.text("Your AI filters reached your %1$@ monthly limit and are paused until %2$@."),
               AICreditsFormat.money(monthlyLimit ?? 0), resetDay)
    }

    /// What usage billing has cost so far this month, and when it's charged.
    var billingText: [String] {
        var lines: [String]
        if included > 0 {
            lines = [NBLocalization.plural("Usage billing is on. Credits past your %2$@ cost 1¢ per 1,000: %3$@ so far this month.",
                                           count: included,
                                           arguments: [AICreditsFormat.credits(Double(included)), AICreditsFormat.money(overageUSD)])]
        } else {
            lines = [String(format: NBLocalization.text("Usage billing is on. Credits cost 1¢ per 1,000: %@ so far this month."),
                            AICreditsFormat.money(overageUSD))]
        }
        if unbilledUSD > 0 {
            lines.append(String(format: NBLocalization.text("%1$@ is waiting to be charged: at the start of next month if it's at least %2$@, or right away at %3$@."),
                                AICreditsFormat.money(unbilledUSD), minimumChargeText, immediateChargeText))
        }
        return lines
    }

    /// apps/analyzer/ai_credits.py charges usage billing at the start of the month once it comes to this much.
    var minimumChargeText: String { AICreditsFormat.money(minimumChargeUSD, dropsWholeCents: true) }

    /// ...or right away once unbilled credits reach this much.
    var immediateChargeText: String { AICreditsFormat.money(immediateChargeUSD, dropsWholeCents: true) }

    /// How usage billing charges, for a reader deciding whether to set it up.
    var chargeScheduleText: String {
        String(format: NBLocalization.text("Your saved card is charged at the start of the month once it's at least %1$@, or right away at %2$@."),
               minimumChargeText, immediateChargeText)
    }

    /// The forecast's cost past the plan's credits, when there is one.
    var forecastOverageText: String? {
        guard let overage = forecast?.overageUSD, overage > 0 else { return nil }
        return String(format: NBLocalization.text("About %@ this month at your pace."), AICreditsFormat.money(overage))
    }

    /// How usage billing works, offered while credits run low or are used up.
    var billingOfferText: String {
        ([NBLocalization.text("Past your credits, filters keep running at 1¢ per 1,000 credits.")] + [forecastOverageText].compactMap { $0 })
            .joined(separator: " ")
    }

    var turnOnBillingDetail: String {
        guard let overage = forecast?.overageUSD, overage > 0 else {
            return NBLocalization.text("1¢ per 1,000 credits past your plan's")
        }
        return String(format: NBLocalization.text("1¢ per 1,000 credits past your plan's, about %@ this month"),
                      AICreditsFormat.money(overage))
    }

    var waitText: String {
        String(format: NBLocalization.text("or wait until %@"), resetDay)
    }

    var limitSummaryText: String? {
        guard let monthlyLimit else { return nil }
        return String(format: NBLocalization.text("Monthly limit: %@"), AICreditsFormat.money(monthlyLimit))
    }
}

/// AIClassifiers.swift formats credits, dollars and the server's calendar days in the interface language.
enum AICreditsFormat {
    /// Whole credits, grouped like the interface language, such as "12,340".
    static func credits(_ value: Double) -> String {
        NBLocalization.formattedCount(Int(shownCredits(value)))
    }

    /// The whole number credits(_:) shows, so a plural form and a comparison agree with what the reader reads.
    static func shownCredits(_ value: Double) -> Double {
        value.rounded()
    }

    /// Dollars as the web shows them. The minimum charge reads "$1" rather than "$1.00".
    static func money(_ amount: Double, dropsWholeCents: Bool = false) -> String {
        if dropsWholeCents, amount == amount.rounded() {
            return String(format: "$%.0f", locale: Locale(identifier: "en_US_POSIX"), amount)
        }
        return String(format: "$%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
    }

    /// A short month and day, like "Dec 1".
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = NBLocalization.formattingLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        // AIClassifiers.swift parses the server's YYYY-MM-DD days in UTC, so they print in UTC too.
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    /// An invoice date, like "Nov 1, 2026".
    static func invoiceDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = NBLocalization.formattingLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("MMMdyyyy")
        return formatter.string(from: date)
    }

    /// The server sends days as YYYY-MM-DD, which AIClassifiers.swift keeps as that calendar day.
    static func parseDay(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

extension NBLocalization {
    /// AIClassifiers.swift picks a plural form for a count with decimals, such as 0.4 credits, and shows the count
    /// as %2$@, formatted by the caller. Foundation's plural rules read the fraction, so French says "0,4 crédit".
    static func plural(_ source: String, value: Double, display: String) -> String {
        String(format: text(source), locale: Locale(identifier: resolvedLanguage), arguments: [NSNumber(value: value), display])
    }

    /// AIClassifiers.swift picks a plural form for count (%1$@) in a message with several other values (%2$@ on).
    static func plural(_ source: String, count: Int, arguments: [String]) -> String {
        String(format: text(source), locale: Locale(identifier: resolvedLanguage),
               arguments: [NSNumber(value: count)] + arguments.map { $0 as CVarArg })
    }
}

/// What a trainer AI section says about the reader's credits (TrainerAIPromptSection.swift), for each Status.
struct AICreditsNotice: Equatable {
    enum Tone: Equatable {
        case normal
        case warning
        case paused
        case upgrade
    }

    enum Action: Equatable {
        /// PremiumView.swift, through NewsBlurAppDelegate.m showPremiumDialog.
        case upgrade
        /// AICreditsView.swift, starting Stripe checkout for usage billing.
        case setUpBilling
        /// AICreditsView.swift, with the billing portal and the monthly limit.
        case manageBilling
        /// AICreditsView.swift, from the meter.
        case openCredits
    }

    /// The month's meter: the share of the plan's credits used (full past them) and its summary. The AI credits
    /// screen it opens says when credits reset.
    struct Meter: Equatable {
        let fraction: Double
        let usedText: String
    }

    struct ActionButton: Equatable {
        let title: String
        let detail: String?
        let action: Action
    }

    let tone: Tone
    let meter: Meter?
    let messages: [String]
    let button: ActionButton?
    let footnote: String?

    /// offersBilling is UsageBillingFeature.swift's switch. While it's off the notice never offers Stripe or points
    /// anywhere to pay: a paused reader learns when filters run again and nothing more, and a reader who turned usage
    /// billing on elsewhere sees what it has cost and their limit.
    static func make(_ credits: AICredits, offersBilling: Bool) -> AICreditsNotice? {
        let offersSetup = offersBilling && credits.isBillingAvailable && !credits.isUsageBilling
        let meter = credits.usedText.map { Meter(fraction: credits.usedFraction, usedText: $0) }
        switch credits.status {
        case .unlimited:
            return nil
        case .free:
            return AICreditsNotice(tone: .upgrade, meter: nil, messages: [AICredits.freeText],
                                   button: ActionButton(title: NBLocalization.text("Upgrade"), detail: nil, action: .upgrade),
                                   footnote: nil)
        case .running:
            return AICreditsNotice(tone: .normal, meter: meter, messages: [], button: nil, footnote: nil)
        case .warning:
            let button = offersSetup
                ? ActionButton(title: NBLocalization.text("Keep filters running"), detail: credits.billingOfferText, action: .setUpBilling)
                : nil
            return AICreditsNotice(tone: .warning, meter: meter, messages: [credits.runsOutText].compactMap { $0 },
                                   button: button, footnote: nil)
        case .pausedForCredits:
            let button = offersSetup
                ? ActionButton(title: NBLocalization.text("Turn on usage billing"), detail: credits.turnOnBillingDetail, action: .setUpBilling)
                : nil
            return AICreditsNotice(tone: .paused, meter: meter, messages: credits.pausedText, button: button,
                                   footnote: offersSetup ? credits.waitText : nil)
        case .usageBilling:
            let messages = credits.billingText + (offersBilling ? [] : [credits.limitSummaryText].compactMap { $0 })
            let button = offersBilling ? ActionButton(title: NBLocalization.text("Manage billing"), detail: nil, action: .manageBilling) : nil
            return AICreditsNotice(tone: credits.isNearLimit ? .warning : .normal, meter: meter, messages: messages,
                                   button: button, footnote: nil)
        case .pausedAtLimit:
            let button = offersBilling ? ActionButton(title: NBLocalization.text("Change limit"), detail: nil, action: .manageBilling) : nil
            return AICreditsNotice(tone: .paused, meter: meter, messages: [credits.limitReachedText], button: button, footnote: nil)
        }
    }
}

/// /analyzer/ai_classifier_usage in apps/analyzer/views.py: this month's credits, and about how many a text or image
/// filter on one site spends a month.
struct AIClassifierUsage: Equatable {
    let credits: AICredits?
    /// The raw ai_credits, which AICreditsStore keeps in the profile.
    let creditsJSON: [String: Any]?
    let textCreditsPerMonth: Double
    let imageCreditsPerMonth: Double

    init(json: [String: Any]) {
        creditsJSON = json["ai_credits"] as? [String: Any]
        credits = AICredits(json: creditsJSON)
        textCreditsPerMonth = AIClassifierValue.double(json["text_credits_per_month"]) ?? 0
        imageCreditsPerMonth = AIClassifierValue.double(json["image_credits_per_month"]) ?? 0
    }

    func creditsPerMonth(for kind: PromptClassifierKind) -> Double {
        kind == .image ? imageCreditsPerMonth : textCreditsPerMonth
    }

    static func == (lhs: AIClassifierUsage, rhs: AIClassifierUsage) -> Bool {
        lhs.credits == rhs.credits && lhs.textCreditsPerMonth == rhs.textCreditsPerMonth
            && lhs.imageCreditsPerMonth == rhs.imageCreditsPerMonth
    }

    /// "A text filter on this site uses about 1,400 credits a month", or that it uses less than one for a site that
    /// published next to nothing last month. Like every credit number, the estimate rounds to a whole credit first.
    static func estimateText(_ credits: Double, kind: PromptClassifierKind) -> String {
        let shown = AICreditsFormat.shownCredits(credits)
        guard shown >= 1 else {
            return kind == .image
                ? NBLocalization.text("An image filter on this site uses less than one credit a month")
                : NBLocalization.text("A text filter on this site uses less than one credit a month")
        }
        let display = AICreditsFormat.credits(shown)
        return kind == .image
            ? NBLocalization.plural("An image filter on this site uses about %2$@ credits a month", value: shown, display: display)
            : NBLocalization.plural("A text filter on this site uses about %2$@ credits a month", value: shown, display: display)
    }
}

/// AIClassifiers.swift keeps the freshest ai_credits in NewsBlurAppDelegate.m's dictUserProfile, so the trainer, the
/// AI credits screen and the settings menu agree between /reader/feeds reloads.
enum AICreditsStore {
    @MainActor static func save(_ json: [String: Any]) {
        guard let appDelegate = NewsBlurAppDelegate.shared, let profile = appDelegate.dictUserProfile else { return }
        var updated = profile
        updated["ai_credits"] = json
        appDelegate.dictUserProfile = updated
    }
}

// MARK: - Usage billing

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

        var isUpcoming: Bool { status == "draft" || status == "upcoming" }
    }

    let invoices: [Invoice]
    let upcomingInvoice: Invoice?
    let credits: AICredits?
    let creditsJSON: [String: Any]?

    init(json: [String: Any]) {
        invoices = (json["invoices"] as? [[String: Any]] ?? []).map { Self.invoice(from: $0, amountKey: "amount_paid") }
        upcomingInvoice = (json["upcoming_invoice"] as? [String: Any]).map { Self.invoice(from: $0, amountKey: "amount") }
        creditsJSON = json["ai_credits"] as? [String: Any]
        credits = AICredits(json: creditsJSON)
    }

    var hasInvoices: Bool { !invoices.isEmpty || upcomingInvoice != nil }

    static func == (lhs: UsageBillingHistory, rhs: UsageBillingHistory) -> Bool {
        lhs.invoices == rhs.invoices && lhs.upcomingInvoice == rhs.upcomingInvoice && lhs.credits == rhs.credits
    }

    private static func invoice(from json: [String: Any], amountKey: String) -> Invoice {
        Invoice(date: AICreditsFormat.parseDay(json["date"]),
                amount: AIClassifierValue.double(json[amountKey]) ?? AIClassifierValue.double(json["amount"]) ?? 0,
                status: json["status"] as? String ?? "",
                hostedInvoiceURL: (json["hosted_invoice_url"] as? String).flatMap(URL.init(string:)),
                lineItems: (json["line_items"] as? [[String: Any]] ?? []).map {
                    LineItem(description: $0["description"] as? String ?? "",
                             quantity: AIClassifierValue.int($0["quantity"]),
                             amount: AIClassifierValue.double($0["amount"]) ?? 0)
                })
    }
}

/// The result of /profile/save_usage_billing_limit, which answers code 1 on success.
enum UsageBillingLimitSaveResult: Equatable {
    case saved(limit: Double?, creditsJSON: [String: Any]?)
    case failed(message: String?)

    init(json: [String: Any]) {
        if AIClassifierValue.int(json["code"]) == 1 {
            self = .saved(limit: AIClassifierValue.double(json["limit"]), creditsJSON: json["ai_credits"] as? [String: Any])
        } else {
            self = .failed(message: json["message"] as? String)
        }
    }

    static func == (lhs: UsageBillingLimitSaveResult, rhs: UsageBillingLimitSaveResult) -> Bool {
        switch (lhs, rhs) {
        case let (.saved(left, leftCredits), .saved(right, rightCredits)):
            return left == right && AICredits(json: leftCredits) == AICredits(json: rightCredits)
        case let (.failed(left), .failed(right)):
            return left == right
        default:
            return false
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

/// Stripe returns the in-app browser to newsblur-auth://usage-billing?status=... (apps/profile/views.py
/// usage_billing_app_return).
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

/// AIClassifiers.swift sends AI classifier, credit and usage billing requests through this seam so tests can answer
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

/// The AI classifier, credit and usage billing endpoints the trainer and AICreditsView.swift call.
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

    /// This month's credits, with estimates for a site's filters when feedId names one.
    func fetchUsage(feedId: String?, completion: @escaping (AIClassifierUsage?) -> Void) {
        transport.get("/analyzer/ai_classifier_usage", parameters: ["feed_id": Self.numericFeedId(feedId)]) { result in
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

    /// /profile/cancel_usage_billing turns usage billing off and answers with the credits that leaves, or nil when the
    /// request fails.
    func cancelUsageBilling(completion: @escaping ([String: Any]?) -> Void) {
        transport.post("/profile/cancel_usage_billing", parameters: [:]) { result in
            guard case .success(let json) = result, AIClassifierValue.int(json["code"]) == 0,
                  let credits = json["ai_credits"] as? [String: Any] else {
                completion(nil)
                return
            }
            completion(credits)
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
