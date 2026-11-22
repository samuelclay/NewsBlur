//
//  AICreditsView.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-10-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AuthenticationServices
import SwiftUI

// MARK: - Stripe browser

/// AICreditsView.swift opens Stripe in an in-app browser that closes itself on the newsblur-auth callback.
/// NewsBlurTests replace it so no test ever reaches Stripe.
@MainActor protocol UsageBillingBrowser: AnyObject {
    func open(_ url: URL, callbackScheme: String, completion: @escaping (URL?, Error?) -> Void) -> Bool
}

/// The production browser, following the ASWebAuthenticationSession setup in OnboardingAccountViewController.swift.
@MainActor final class WebAuthenticationUsageBillingBrowser: NSObject, UsageBillingBrowser, ASWebAuthenticationPresentationContextProviding {
    var anchor: () -> UIWindow?
    private var session: ASWebAuthenticationSession?

    init(anchor: @escaping () -> UIWindow?) {
        self.anchor = anchor
    }

    func open(_ url: URL, callbackScheme: String, completion: @escaping (URL?, Error?) -> Void) -> Bool {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.session = nil
                completion(callbackURL, error)
            }
        }
        session.presentationContextProvider = self
        // AICreditsView.swift shares the browser's cookies so Stripe can offer saved payment details.
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        return session.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor() ?? ASPresentationAnchor()
    }
}

// MARK: - Model

/// AICreditsView.swift's state: the month's AI credits, usage billing, its monthly limit and invoices.
@MainActor final class AICreditsModel: ObservableObject {
    enum HistoryState: Equatable {
        case notSetUp
        case loading
        case loaded(UsageBillingHistory)
        case failed
    }

    struct Message: Equatable {
        let text: String
        let isError: Bool
    }

    @Published private(set) var credits: AICredits?
    @Published private(set) var loadFailed = false
    @Published private(set) var historyState: HistoryState = .notSetUp
    @Published var limitText = ""
    @Published private(set) var limitMessage: Message?
    @Published private(set) var isSavingLimit = false
    @Published private(set) var isOpeningStripe = false
    @Published private(set) var stripeMessage: Message?

    let api: AIClassifierAPI
    var browser: UsageBillingBrowser?
    var readCredits: () -> AICredits?
    /// Keeps fresh credits in the profile (AIClassifiers.swift AICreditsStore), so the trainer agrees.
    var storeCredits: ([String: Any]) -> Void
    /// Reloads /reader/feeds so NewsBlurAppDelegate.m's dictUserProfile carries the new billing flags.
    var refreshProfile: () -> Void
    /// Opens PremiumView.swift through NewsBlurAppDelegate.m showPremiumDialog.
    var openUpgrade: () -> Void
    /// The region whose decimal separator the decimal pad types, such as the comma in German and French.
    let locale: Locale

    private var hasEditedLimit = false

    /// Stripe's webhook turns billing on server side, which can land after the checkout returns to the app, so
    /// AICreditsView.swift keeps showing billing as on and re-reads the profile a few times until it agrees.
    private var activationChecksRemaining = 0
    static let activationCheckLimit = 4
    var scheduleActivationCheck: (_ delay: TimeInterval, _ check: @escaping () -> Void) -> Void = { delay, check in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: check)
    }

    init(api: AIClassifierAPI? = nil, browser: UsageBillingBrowser? = nil,
         readCredits: (() -> AICredits?)? = nil,
         storeCredits: (([String: Any]) -> Void)? = nil,
         refreshProfile: (() -> Void)? = nil,
         openUpgrade: (() -> Void)? = nil,
         locale: Locale = .current) {
        let readCredits = readCredits ?? { AICredits.current }
        self.api = api ?? AIClassifierAPI()
        self.browser = browser
        self.readCredits = readCredits
        self.storeCredits = storeCredits ?? { AICreditsStore.save($0) }
        self.refreshProfile = refreshProfile ?? { NewsBlurAppDelegate.shared?.reloadFeedsView(false) }
        self.openUpgrade = openUpgrade ?? { NewsBlurAppDelegate.shared?.showPremiumDialog() }
        self.locale = locale
        credits = readCredits()
        limitText = Self.limitString(credits?.monthlyLimit, locale: locale)
    }

    /// AICreditsView.swift shows the profile's credits right away, then asks the server for this moment's.
    func load() {
        apply(readCredits())
        fetchUsage()
        fetchHistory()
    }

    /// The feed list finished reloading, so the profile's credits may have changed.
    func profileDidRefresh() {
        let fresh = readCredits()
        if activationChecksRemaining > 0, fresh?.isUsageBilling != true {
            activationChecksRemaining -= 1
            scheduleActivationCheck(3) { [weak self] in self?.refreshProfile() }
            return
        }
        activationChecksRemaining = 0
        let wasBilling = credits?.isUsageBilling
        apply(fresh)
        if credits?.isUsageBilling != wasBilling { fetchHistory() }
    }

    func fetchUsage() {
        api.fetchUsage(feedId: nil) { [weak self] usage in
            guard let self else { return }
            guard let usage, let json = usage.creditsJSON else {
                if self.credits == nil { self.loadFailed = true }
                return
            }
            self.loadFailed = false
            self.storeCredits(json)
            let wasBilling = self.credits?.isUsageBilling
            self.apply(usage.credits)
            if self.credits?.isUsageBilling != wasBilling { self.fetchHistory() }
        }
    }

    func fetchHistory() {
        guard credits?.isUsageBilling == true else {
            historyState = .notSetUp
            return
        }
        if case .loaded = historyState {} else { historyState = .loading }
        api.fetchUsageBillingHistory { [weak self] history in
            guard let self else { return }
            guard let history else {
                self.historyState = .failed
                return
            }
            self.historyState = .loaded(history)
        }
    }

    /// Shows fresh credits, keeping the last ones when a fetch failed, and billing on while a checkout that just
    /// finished waits for Stripe's webhook.
    private func apply(_ fresh: AICredits?) {
        guard var fresh else { return }
        if activationChecksRemaining > 0, !fresh.isUsageBilling {
            fresh = fresh.assumingUsageBilling
        }
        credits = fresh
        if !hasEditedLimit { limitText = Self.limitString(fresh.monthlyLimit, locale: locale) }
    }

    // MARK: Monthly limit

    /// The limit is only edited here while UsageBillingFeature.swift lets the app manage usage billing; otherwise
    /// AICreditsView.swift shows it as text.
    var canEditLimit: Bool {
        UsageBillingFeature.isEnabled && credits?.isUsageBilling == true
    }

    func editLimit(_ text: String) {
        let edited = Self.editableLimit(text, locale: locale)
        let changed = edited != limitText
        // Publishing an unchanged value still puts the field back when the filter dropped what was typed.
        limitText = edited
        guard changed else { return }
        hasEditedLimit = true
        limitMessage = nil
    }

    func saveLimit() {
        guard canEditLimit, !isSavingLimit else { return }
        isSavingLimit = true
        limitMessage = nil
        api.saveUsageBillingLimit(Self.serverLimit(limitText, locale: locale)) { [weak self] result in
            guard let self else { return }
            self.isSavingLimit = false
            switch result {
            case .saved(let limit, let creditsJSON):
                self.hasEditedLimit = false
                if let creditsJSON, AICredits(json: creditsJSON) != nil {
                    self.storeCredits(creditsJSON)
                    self.apply(AICredits(json: creditsJSON))
                } else {
                    self.credits?.monthlyLimit = limit
                }
                self.limitText = Self.limitString(limit, locale: self.locale)
                self.limitMessage = Message(text: NBLocalization.text("Saved"), isError: false)
            case .failed(let message):
                self.limitMessage = Message(text: message ?? NBLocalization.text("Couldn't save your monthly limit. Please try again."),
                                            isError: true)
            }
        }
    }

    /// The saved limit as the field shows it: plain digits with the region's decimal separator, so "10,5" in German.
    static func limitString(_ limit: Double?, locale: Locale) -> String {
        guard let limit, limit > 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        let plain = formatter.string(from: NSNumber(value: limit)) ?? ""
        return plain.replacingOccurrences(of: ".", with: decimalSeparator(locale))
    }

    /// AICreditsView.swift keeps whole dollars and cents, like the web's number field. Both "." and the region's
    /// decimal separator start the cents, which show with the region's separator. Anything else, such as a grouping
    /// separator, is dropped, so a German "10,50" stays $10.50 instead of becoming $1,050.
    static func editableLimit(_ text: String, locale: Locale) -> String {
        let separator = decimalSeparator(locale)
        var dollars = ""
        var cents: String?
        for character in text {
            if character == "." || String(character) == separator {
                // The first separator starts the cents and any later one is dropped.
                if cents == nil { cents = "" }
            } else if let digit = asciiDigit(character) {
                if let typedCents = cents {
                    if typedCents.count < 2 { cents = typedCents + digit }
                } else if dollars.count < 6 {
                    dollars += digit
                }
            }
        }
        guard let cents else { return dollars }
        return dollars + separator + cents
    }

    /// The limit for apps/profile/views.py save_usage_billing_limit, which parses it with Python's Decimal and needs
    /// "10.50". A blank field clears the limit, and a lone separator sends "0" so the server rejects it instead.
    static func serverLimit(_ text: String, locale: Locale) -> String {
        let edited = editableLimit(text, locale: locale)
        guard let range = edited.range(of: decimalSeparator(locale)) else { return edited }
        let dollars = edited[..<range.lowerBound].isEmpty ? "0" : String(edited[..<range.lowerBound])
        let cents = edited[range.upperBound...]
        return cents.isEmpty ? dollars : "\(dollars).\(cents)"
    }

    private static func decimalSeparator(_ locale: Locale) -> String {
        locale.decimalSeparator ?? "."
    }

    /// A decimal digit in any script, such as the Arabic-Indic digits some decimal pads type, as an ASCII digit.
    private static func asciiDigit(_ character: Character) -> String? {
        guard character.unicodeScalars.count == 1, character.unicodeScalars.first?.properties.numericType == .decimal,
              let value = character.wholeNumberValue else { return nil }
        return String(value)
    }

    // MARK: Stripe

    /// Readers with usage billing manage it on Stripe, and readers on a paid plan can set it up. Nothing opens Stripe
    /// while UsageBillingFeature.swift holds billing out of the release, on a server that counts no credits, or for a
    /// plan without credits, which AICreditsView.swift points at upgrading instead.
    var stripeAction: UsageBillingStripeAction? {
        guard UsageBillingFeature.isEnabled, let credits, !credits.isUnlimited else { return nil }
        if credits.isUsageBilling { return .manage }
        guard credits.isBillingAvailable, credits.status != .free else { return nil }
        return .setup
    }

    func openStripe() {
        guard let action = stripeAction, !isOpeningStripe else { return }
        isOpeningStripe = true
        stripeMessage = nil
        api.startStripe(action) { [weak self] response in
            guard let self else { return }
            switch response {
            case .open(let url):
                let started = self.browser?.open(url, callbackScheme: UsageBillingCallback.scheme) { [weak self] callbackURL, error in
                    self?.finishStripe(callbackURL: callbackURL, error: error)
                } ?? false
                if !started {
                    self.isOpeningStripe = false
                    self.stripeMessage = Message(text: NBLocalization.text("Couldn't open billing. Please try again."), isError: true)
                }
            case .alreadyActive:
                self.isOpeningStripe = false
                self.refresh()
            case .failed(let message):
                self.isOpeningStripe = false
                self.stripeMessage = Message(text: message ?? NBLocalization.text("Couldn't open billing. Please try again."),
                                             isError: true)
            }
        }
    }

    func finishStripe(callbackURL: URL?, error: Error?) {
        isOpeningStripe = false
        guard let callbackURL, let callback = UsageBillingCallback(url: callbackURL) else {
            // Closing the browser early is a cancel, not an error, but the portal may still have changed things.
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin, error != nil {
                stripeMessage = Message(text: NBLocalization.text("Couldn't open billing. Please try again."), isError: true)
            }
            refresh()
            return
        }
        switch callback {
        case .setupComplete:
            activationChecksRemaining = Self.activationCheckLimit
            credits = credits?.assumingUsageBilling
        case .cancelled, .portalReturn:
            break
        }
        refresh()
    }

    private func refresh() {
        refreshProfile()
        fetchUsage()
        fetchHistory()
    }

    // MARK: Turning billing off

    @Published private(set) var isTurningOff = false

    /// Turning usage billing off is a Stripe action like the others, so it waits on UsageBillingFeature.swift too.
    var canTurnOffBilling: Bool {
        UsageBillingFeature.isEnabled && credits?.isUsageBilling == true
    }

    func turnOffUsageBilling() {
        guard canTurnOffBilling, !isTurningOff else { return }
        isTurningOff = true
        stripeMessage = nil
        api.cancelUsageBilling { [weak self] json in
            guard let self else { return }
            self.isTurningOff = false
            guard let json, let fresh = AICredits(json: json) else {
                self.stripeMessage = Message(text: NBLocalization.text("Couldn't turn off usage billing. Please try again."), isError: true)
                return
            }
            self.activationChecksRemaining = 0
            self.storeCredits(json)
            self.apply(fresh)
            self.fetchHistory()
            self.refreshProfile()
        }
    }
}

extension AICredits {
    /// Credits as they'll be once Stripe's webhook turns usage billing on: filters paused for credits run again.
    var assumingUsageBilling: AICredits {
        var credits = self
        credits.isUsageBilling = true
        if credits.pauseReason == .credits || credits.pauseReason == .plan { credits.pauseReason = nil }
        return credits
    }
}

// MARK: - View

/// AICreditsView.swift: the month's AI credits, how fast they're going, and usage billing past them. Opened from the
/// settings menu and the trainer's AI sections through NewsBlurAppDelegate.m showAICreditsDialogStartingSetup.
struct AICreditsView: View {
    @ObservedObject var model: AICreditsModel
    var onDone: () -> Void
    var openURL: (URL) -> Void

    @State private var confirmsTurningOff = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    creditsCard
                    if showsBillingCard, let credits = model.credits {
                        billingCard(credits)
                    }
                    if model.historyState != .notSetUp {
                        invoicesCard
                    }
                    if let credits = model.credits, credits.status != .free, !credits.isUnlimited {
                        howCreditsWorkCard
                    }
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AICreditsPalette.background.ignoresSafeArea())
        .onAppear { model.load() }
    }

    var header: some View {
        HStack {
            Button(NBLocalization.text("Done"), action: onDone)
                .foregroundColor(AICreditsPalette.link)
            Spacer()
            Text(NBLocalization.text("AI Credits"))
                .font(.headline)
                .foregroundColor(AICreditsPalette.text)
            Spacer()
            // AICreditsView.swift balances the Done button so the title stays centered.
            Button(NBLocalization.text("Done"), action: {}).hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AICreditsPalette.headerBackground)
    }

    // MARK: This month

    var creditsCard: some View {
        card(title: NBLocalization.text("This month")) {
            if let credits = model.credits {
                if credits.status == .free {
                    freeContent
                } else {
                    monthContent(credits)
                }
            } else if model.loadFailed {
                emptyText(NBLocalization.text("Couldn't load your AI credits."))
            } else {
                emptyText(NBLocalization.text("Loading..."))
            }
        }
    }

    var freeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            bodyText(AICredits.freeText)
            primaryButton(NBLocalization.text("Upgrade"), identifier: "ai-credits-upgrade", action: model.openUpgrade)
        }
    }

    func monthContent(_ credits: AICredits) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let usedText = credits.usedText {
                Text(usedText)
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(AICreditsPalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ai-credits-used")
                AICreditsMeter(fraction: credits.usedFraction, fill: AICreditsPalette.meterFill(for: credits), height: 10)
            }
            if let resetText = credits.resetText {
                Text(resetText)
                    .font(.system(size: 13))
                    .foregroundColor(AICreditsPalette.secondaryText)
            }
            if !credits.isPaused {
                let forecast = [credits.forecastText, credits.runsOutText].compactMap { $0 }
                if !forecast.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(forecast, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundColor(credits.status == .warning ? AICreditsPalette.warningText : AICreditsPalette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            if credits.status == .pausedForCredits {
                callout(credits.pausedText)
            } else if credits.status == .pausedAtLimit {
                callout([credits.limitReachedText])
            }
        }
    }

    func callout(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.system(size: 14, weight: index == 0 ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundColor(AICreditsPalette.pausedText)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AICreditsPalette.pausedBackground))
        .padding(.top, 4)
        .accessibilityIdentifier("ai-credits-paused")
    }

    // MARK: Usage billing

    /// Readers with usage billing always see what it costs. Setting it up only shows while the app can open Stripe,
    /// so with UsageBillingFeature.swift off nothing here points anywhere to pay.
    var showsBillingCard: Bool {
        guard let credits = model.credits, !credits.isUnlimited else { return false }
        return credits.isUsageBilling || model.stripeAction == .setup
    }

    func billingCard(_ credits: AICredits) -> some View {
        card(title: NBLocalization.text("Usage billing")) {
            VStack(alignment: .leading, spacing: 14) {
                if credits.isUsageBilling {
                    billingOnContent(credits)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        bodyText(credits.billingOfferText)
                        Text(credits.chargeScheduleText)
                            .font(.system(size: 13))
                            .foregroundColor(AICreditsPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    primaryButton(NBLocalization.text("Set up usage billing"), identifier: "usage-billing-stripe",
                                  isBusy: model.isOpeningStripe, action: model.openStripe)
                }

                if let message = model.stripeMessage {
                    messageText(message)
                }
            }
        }
    }

    func billingOnContent(_ credits: AICredits) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(credits.billingText, id: \.self) { line in
                    bodyText(line)
                }
                if let forecast = credits.forecastOverageText {
                    Text(forecast)
                        .font(.system(size: 13))
                        .foregroundColor(AICreditsPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let fraction = credits.limitFraction, let limit = credits.monthlyLimit {
                VStack(alignment: .leading, spacing: 6) {
                    AICreditsMeter(fraction: fraction, fill: AICreditsPalette.meterFill(for: credits), height: 8)
                    Text(String(format: NBLocalization.text("%1$@ of your %2$@ monthly limit"),
                                AICreditsFormat.money(credits.overageUSD), AICreditsFormat.money(limit)))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundColor(AICreditsPalette.secondaryText)
                }
            }

            if model.stripeAction == .manage {
                secondaryButton(NBLocalization.text("Update card on Stripe"), isBusy: model.isOpeningStripe, action: model.openStripe)
            }

            if model.canEditLimit {
                limitSection
            } else {
                HStack {
                    Text(NBLocalization.text("Monthly limit"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AICreditsPalette.text)
                    Spacer()
                    Text(credits.monthlyLimit.map { AICreditsFormat.money($0) } ?? NBLocalization.text("No limit"))
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundColor(AICreditsPalette.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }

            if model.canTurnOffBilling {
                Button(action: { confirmsTurningOff = true }) {
                    HStack(spacing: 8) {
                        if model.isTurningOff { ProgressView() }
                        Text(NBLocalization.text("Turn off usage billing"))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AICreditsPalette.errorText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(model.isTurningOff)
                .accessibilityIdentifier("usage-billing-turn-off")
                .confirmationDialog(NBLocalization.text("Turn off usage billing?"), isPresented: $confirmsTurningOff,
                                    titleVisibility: .visible) {
                    Button(NBLocalization.text("Turn off usage billing"), role: .destructive, action: model.turnOffUsageBilling)
                    Button(NBLocalization.text("Cancel"), role: .cancel) {}
                } message: {
                    Text(String(format: NBLocalization.text("Your AI filters pause once this month's credits are used. Credits already past your plan's are charged now if they come to at least %@."),
                                credits.minimumChargeText))
                }
            }
        }
    }

    var limitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NBLocalization.text("Monthly limit"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AICreditsPalette.text)

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AICreditsPalette.secondaryText)
                TextField(NBLocalization.text("No limit"), text: Binding(get: { model.limitText }, set: { model.editLimit($0) }))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15).monospacedDigit())
                    .padding(8)
                    .frame(maxWidth: 140)
                    .background(AICreditsPalette.fieldBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AICreditsPalette.fieldBorder, lineWidth: 1))
                    .accessibilityIdentifier("usage-billing-limit")
                Spacer(minLength: 8)
                Button(action: model.saveLimit) {
                    Text(model.isSavingLimit ? NBLocalization.text("Saving...") : NBLocalization.text("Save"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AICreditsPalette.green))
                }
                .buttonStyle(.plain)
                .disabled(model.isSavingLimit)
                .accessibilityIdentifier("usage-billing-save-limit")
            }

            Text(NBLocalization.text("Filters pause when usage billing reaches it. Leave empty for no limit."))
                .font(.system(size: 12))
                .foregroundColor(AICreditsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let message = model.limitMessage {
                messageText(message)
            }
        }
    }

    // MARK: How credits work

    /// What a credit buys and when they come back, from apps/analyzer/ai_credits.py TEXT_STORY_CREDITS and
    /// IMAGE_STORY_CREDITS, so the meter's numbers mean something.
    var howCreditsWorkCard: some View {
        card(title: NBLocalization.text("How credits work")) {
            VStack(alignment: .leading, spacing: 8) {
                bodyText(NBLocalization.text("A credit is about one story through a text filter. An image filter uses about 10 credits a story."))
                Text(NBLocalization.text("Credits reset on the 1st of each month and don't carry over."))
                    .font(.system(size: 13))
                    .foregroundColor(AICreditsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Invoices

    var invoicesCard: some View {
        card(title: NBLocalization.text("Usage invoices")) {
            switch model.historyState {
            case .notSetUp, .loading:
                emptyText(NBLocalization.text("Loading..."))
            case .failed:
                emptyText(NBLocalization.text("Couldn't load your usage invoices."))
            case .loaded(let history):
                if !history.hasInvoices {
                    emptyText(NBLocalization.text("No usage invoices yet."))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if let upcoming = history.upcomingInvoice {
                            invoiceRow(upcoming)
                        }
                        ForEach(Array(history.invoices.enumerated()), id: \.offset) { index, invoice in
                            if index > 0 || history.upcomingInvoice != nil { Divider() }
                            invoiceRow(invoice)
                        }
                    }
                }
            }
        }
    }

    func invoiceRow(_ invoice: UsageBillingHistory.Invoice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(invoice.date.map(AICreditsFormat.invoiceDay) ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(invoice.isUpcoming ? AICreditsPalette.secondaryText : AICreditsPalette.text)
                if invoice.isUpcoming {
                    Text(NBLocalization.text("Upcoming"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AICreditsPalette.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AICreditsPalette.track))
                }
                Spacer(minLength: 8)
                Text(AICreditsFormat.money(invoice.amount))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(AICreditsPalette.text)
                // Stripe's invoice page can take a payment, so it's only linked while the app may open Stripe.
                if UsageBillingFeature.isEnabled, let url = invoice.hostedInvoiceURL {
                    Button(NBLocalization.text("Invoice")) { openURL(url) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AICreditsPalette.link)
                        .buttonStyle(.plain)
                }
            }
            ForEach(Array(invoice.lineItems.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.description)
                        .foregroundColor(AICreditsPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text("\u{00D7}\(NBLocalization.formattedCount(item.quantity))")
                        .foregroundColor(AICreditsPalette.secondaryText)
                    Text(AICreditsFormat.money(item.amount))
                        .foregroundColor(AICreditsPalette.secondaryText)
                }
                .font(.system(size: 12).monospacedDigit())
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: Pieces

    func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(AICreditsPalette.secondaryText)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(AICreditsPalette.card))
        }
    }

    func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(AICreditsPalette.text)
            .fixedSize(horizontal: false, vertical: true)
    }

    func primaryButton(_ title: String, identifier: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(AICreditsPalette.green))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityIdentifier(identifier)
    }

    func secondaryButton(_ title: String, isBusy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(AICreditsPalette.link)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 8).stroke(AICreditsPalette.fieldBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityIdentifier("usage-billing-stripe")
    }

    func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .italic()
            .foregroundColor(AICreditsPalette.secondaryText)
    }

    func messageText(_ message: AICreditsModel.Message) -> some View {
        Text(message.text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(message.isError ? AICreditsPalette.errorText : AICreditsPalette.green)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// AICreditsView.swift's meter, shared with the trainer's AI sections (TrainerAIPromptSection.swift).
struct AICreditsMeter: View {
    let fraction: Double
    let fill: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AICreditsPalette.track)
                Capsule().fill(fill)
                    // A little use still shows, so a meter that has started never looks empty.
                    .frame(width: fraction > 0 ? max(height, geometry.size.width * fraction) : 0)
            }
            // AICreditsView.swift fills the meter from the leading edge, so it runs right to left in Arabic and Hebrew.
            .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// AICreditsView.swift's colors for the Light, Sepia, Medium and Dark themes.
enum AICreditsPalette {
    static var background: Color { Color.themed([0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x111111]) }
    static var headerBackground: Color { Color.themed([0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222]) }
    static var card: Color { Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x222222]) }
    static var text: Color { Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7]) }
    static var secondaryText: Color { Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]) }
    static var link: Color { Color.themed([0x2F6FB3, 0x8A5A1E, 0x8CC4FF, 0x8CC4FF]) }
    static var green: Color { Color.themed([0x5F9B4C, 0x5F9B4C, 0x4E8A3E, 0x4E8A3E]) }
    static var amber: Color { Color.themed([0xE59A2F, 0xD98C24, 0xD9973A, 0xD9973A]) }
    static var red: Color { Color.themed([0xD9534F, 0xC9483F, 0xD8605C, 0xD8605C]) }
    /// Credits past the plan's, billed through usage billing.
    static var accent: Color { Color.themed([0x5A6BD9, 0x6A62B8, 0x8C98F0, 0x8C98F0]) }
    static var track: Color { Color.themed([0xE6E8E3, 0xE8DED0, 0x48484A, 0x333333]) }
    static var warningText: Color { Color.themed([0x8A5A0B, 0x7F5410, 0xF0C87A, 0xF0C87A]) }
    static var pausedText: Color { Color.themed([0x8A1F1F, 0x8A1F1F, 0xFFC2C2, 0xFFC2C2]) }
    static var pausedBackground: Color { Color.themed([0xFDE7E7, 0xF6DCD3, 0x4F2A2A, 0x3D2020]) }
    static var errorText: Color { Color.themed([0xC62828, 0xB0352B, 0xFFA3A5, 0xFFA3A5]) }
    static var fieldBackground: Color { Color.themed([0xFFFFFF, 0xFFFBF5, 0x2C2C2E, 0x1C1C1E]) }
    static var fieldBorder: Color { Color.themed([0xC7C7CC, 0xD4C8B8, 0x555555, 0x444444]) }

    /// The meter's tone over the gray track: green while credits last, amber running low, red paused. Past the plan's
    /// credits on usage billing the bar is simply full and green, amber only near the monthly limit; the summary says
    /// how many went past the plan.
    static func meterFill(for credits: AICredits) -> Color {
        switch credits.status {
        case .pausedForCredits, .pausedAtLimit: return red
        case .warning: return amber
        case .usageBilling: return credits.isNearLimit ? amber : green
        case .running, .free, .unlimited: return green
        }
    }
}

// MARK: - Controller

/// AICreditsView.swift's controller, presented as a sheet by NewsBlurAppDelegate.m showAICreditsDialogStartingSetup.
@objc final class AICreditsViewController: UIViewController {
    let model: AICreditsModel
    /// The trainer's Keep filters running and Turn on usage billing go straight on to Stripe checkout.
    private let startsSetup: Bool
    private var didStartSetup = false
    private var feedsObserver: NSObjectProtocol?

    init(model: AICreditsModel? = nil, startingSetup: Bool = false) {
        self.model = model ?? AICreditsModel()
        startsSetup = startingSetup
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        model = AICreditsModel()
        startsSetup = false
        super.init(coder: coder)
    }

    deinit {
        if let feedsObserver { NotificationCenter.default.removeObserver(feedsObserver) }
    }

    /// FeedsObjCViewController.m lists AI Credits in the settings menu for plans that include them and for readers
    /// with usage billing. A server that counts no credits has nothing to show.
    @objc static func showsMenuItem(userProfile: [AnyHashable: Any]?) -> Bool {
        guard let credits = AICredits(profile: userProfile), !credits.isUnlimited else { return false }
        return credits.included > 0 || credits.isUsageBilling
    }

    /// A sheet ready to present, sized like the Premium screen in NewsBlurAppDelegate.m.
    @objc static func makePresentable(startingSetup: Bool) -> UIViewController {
        let controller = AICreditsViewController(startingSetup: startingSetup)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 12
        }
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if model.browser == nil {
            model.browser = WebAuthenticationUsageBillingBrowser { [weak self] in self?.view.window }
        }
        let hosting = UIHostingController(rootView: AICreditsView(
            model: model,
            onDone: { [weak self] in self?.dismiss(animated: true) },
            openURL: { UIApplication.shared.open($0) }
        ))
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)
        view.backgroundColor = UIColor(AICreditsPalette.background)

        // FeedsObjCViewController.m posts this after /reader/feeds refreshes dictUserProfile.
        feedsObserver = NotificationCenter.default.addObserver(forName: Notification.Name("FinishedLoadingFeedsNotification"),
                                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.profileDidRefresh() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ASWebAuthenticationSession needs this sheet on screen to present over it.
        guard startsSetup, !didStartSetup else { return }
        didStartSetup = true
        if model.stripeAction == .setup { model.openStripe() }
    }
}
