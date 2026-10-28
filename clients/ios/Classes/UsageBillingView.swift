//
//  UsageBillingView.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-10-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AuthenticationServices
import SwiftUI

// MARK: - Stripe browser

/// UsageBillingView.swift opens Stripe in an in-app browser that closes itself on the newsblur-auth callback.
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
        // UsageBillingView.swift shares the browser's cookies so Stripe can offer saved payment details.
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        return session.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor() ?? ASPresentationAnchor()
    }
}

// MARK: - Model

/// UsageBillingView.swift's state for the web account's "Natural language classifier billing" and
/// "Usage billing history" sections (media/js/newsblur/reader/reader_account.js).
@MainActor final class UsageBillingModel: ObservableObject {
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

    @Published private(set) var status: UsageBillingStatus
    @Published private(set) var historyState: HistoryState = .notSetUp
    @Published var limitText = ""
    @Published private(set) var limitMessage: Message?
    @Published private(set) var isSavingLimit = false
    @Published private(set) var isOpeningStripe = false
    @Published private(set) var stripeMessage: Message?

    let api: AIClassifierAPI
    var browser: UsageBillingBrowser?
    var readStatus: () -> UsageBillingStatus
    /// Reloads /reader/feeds so NewsBlurAppDelegate.m's dictUserProfile carries the new billing flags.
    var refreshProfile: () -> Void

    private var hasEditedLimit = false

    /// Stripe's webhook turns billing on server side, which can land after the checkout returns to the app, so
    /// UsageBillingView.swift keeps showing billing as active and re-reads the profile a few times until it agrees.
    private var activationChecksRemaining = 0
    static let activationCheckLimit = 4
    var scheduleActivationCheck: (_ delay: TimeInterval, _ check: @escaping () -> Void) -> Void = { delay, check in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: check)
    }

    init(api: AIClassifierAPI? = nil, browser: UsageBillingBrowser? = nil,
         readStatus: (() -> UsageBillingStatus)? = nil,
         refreshProfile: (() -> Void)? = nil) {
        let readStatus = readStatus ?? { UsageBillingStatus.current }
        self.api = api ?? AIClassifierAPI()
        self.browser = browser
        self.readStatus = readStatus
        self.refreshProfile = refreshProfile ?? { NewsBlurAppDelegate.shared?.reloadFeedsView(false) }
        status = readStatus()
        limitText = Self.limitString(status.usageBillingLimit)
    }

    func load() {
        status = readStatus()
        if !hasEditedLimit { limitText = Self.limitString(status.usageBillingLimit) }
        fetchHistory()
    }

    /// The feed list finished reloading, so the profile's billing flags may have changed.
    func profileDidRefresh() {
        let previous = status
        let fresh = readStatus()
        if activationChecksRemaining > 0, !fresh.isUsageBilling {
            activationChecksRemaining -= 1
            scheduleActivationCheck(3) { [weak self] in self?.refreshProfile() }
            return
        }
        activationChecksRemaining = 0
        status = fresh
        if status != previous {
            if !hasEditedLimit { limitText = Self.limitString(status.usageBillingLimit) }
            fetchHistory()
        }
    }

    func fetchHistory() {
        guard status.canUseAIClassifiers else {
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
            if !self.hasEditedLimit { self.limitText = Self.limitString(history.usageBillingLimit) }
        }
    }

    // MARK: Spending limit

    func editLimit(_ text: String) {
        // UsageBillingView.swift keeps whole dollars and cents, like the web's number field.
        let filtered = String(text.filter { $0.isNumber || $0 == "." }.prefix(9))
        guard filtered != limitText else { return }
        limitText = filtered
        hasEditedLimit = true
        limitMessage = nil
    }

    func saveLimit() {
        guard !isSavingLimit else { return }
        isSavingLimit = true
        limitMessage = nil
        api.saveUsageBillingLimit(limitText) { [weak self] result in
            guard let self else { return }
            self.isSavingLimit = false
            switch result {
            case .saved(let limit):
                self.hasEditedLimit = false
                self.limitText = Self.limitString(limit)
                self.status.usageBillingLimit = limit
                self.limitMessage = Message(text: NBLocalization.text("Saved"), isError: false)
                self.fetchHistory()
            case .failed(let message):
                self.limitMessage = Message(text: message ?? NBLocalization.text("Couldn't save your spending limit. Please try again."),
                                            isError: true)
            }
        }
    }

    static func limitString(_ limit: Double?) -> String {
        guard let limit, limit > 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: limit)) ?? ""
    }

    // MARK: Stripe

    /// Self-hosted AI has nothing to bill; everyone else either sets billing up or manages it on Stripe.
    var stripeAction: UsageBillingStripeAction? {
        if status.isUsageBilling { return .manage }
        if status.isSelfHostedAI { return nil }
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
                self.stripeMessage = Message(text: NBLocalization.text("Usage-based billing is enabled for natural language classifiers."),
                                             isError: false)
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
            stripeMessage = Message(text: NBLocalization.text("Usage-based billing is enabled for natural language classifiers."),
                                    isError: false)
            status.isUsageBilling = true
            status.canUseAIClassifiers = true
            activationChecksRemaining = Self.activationCheckLimit
        case .cancelled, .portalReturn:
            break
        }
        refresh()
    }

    private func refresh() {
        refreshProfile()
        fetchHistory()
    }
}

// MARK: - View

/// UsageBillingView.swift: the usage-based billing screen for natural language classifiers, opened from the
/// settings menu, the Premium screen and the trainer's billing banners.
struct UsageBillingView: View {
    @ObservedObject var model: UsageBillingModel
    var onDone: () -> Void
    var openURL: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    billingSection
                    historySection
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .background(UsageBillingPalette.background.ignoresSafeArea())
        .onAppear { model.load() }
    }

    var header: some View {
        HStack {
            Button(NBLocalization.text("Done"), action: onDone)
                .foregroundColor(UsageBillingPalette.link)
            Spacer()
            Text(NBLocalization.text("Usage Billing"))
                .font(.headline)
                .foregroundColor(UsageBillingPalette.text)
            Spacer()
            // UsageBillingView.swift balances the Done button so the title stays centered.
            Button(NBLocalization.text("Done"), action: {}).hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(UsageBillingPalette.headerBackground)
    }

    // MARK: Billing

    var billingSection: some View {
        card(title: NBLocalization.text("Natural language classifier billing")) {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.status.statusText)
                    .font(.system(size: 14))
                    .foregroundColor(UsageBillingPalette.text)
                    .fixedSize(horizontal: false, vertical: true)

                if model.status.canUseAIClassifiers, case .loaded(let history) = model.historyState {
                    currentSpend(history)
                }

                if let action = model.stripeAction {
                    Button(action: model.openStripe) {
                        HStack(spacing: 8) {
                            if model.isOpeningStripe {
                                ProgressView().tint(.white)
                            }
                            Text(action == .manage ? NBLocalization.text("Manage billing on Stripe")
                                                   : NBLocalization.text("Set up billing"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(UsageBillingPalette.green))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isOpeningStripe)
                    .accessibilityIdentifier("usage-billing-stripe")
                }

                if let message = model.stripeMessage {
                    messageText(message)
                }

                if model.status.canUseAIClassifiers {
                    limitSection
                }
            }
        }
    }

    func currentSpend(_ history: UsageBillingHistory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UsageBillingFormat.money(history.currentCycleSpend))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(UsageBillingPalette.text)
            if let period = UsageBillingFormat.period(start: history.cycleStart, end: history.cycleEnd) {
                Text(period)
                    .font(.system(size: 13))
                    .foregroundColor(UsageBillingPalette.secondaryText)
            }

            if let progress = history.limitProgress, let limit = history.usageBillingLimit {
                limitBar(progress: progress, spend: history.currentCycleSpend, limit: limit,
                         isReached: history.isLimitReached, isNear: history.isNearLimit)
                if history.isLimitReached {
                    Text(NBLocalization.text("Spending limit reached. Classifiers paused until next cycle."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UsageBillingPalette.errorText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let upcoming = history.upcomingInvoice {
                (Text(NBLocalization.text("Upcoming charge: ")).foregroundColor(UsageBillingPalette.secondaryText)
                    + Text(UsageBillingFormat.money(upcoming.amount)).bold().foregroundColor(UsageBillingPalette.text))
                    .font(.system(size: 13))
            }
        }
    }

    func limitBar(progress: Double, spend: Double, limit: Double, isReached: Bool, isNear: Bool) -> some View {
        let fill = isReached ? UsageBillingPalette.red : isNear ? UsageBillingPalette.orange : UsageBillingPalette.green
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(UsageBillingPalette.track)
                RoundedRectangle(cornerRadius: 6).fill(fill)
                    .frame(width: max(0, geometry.size.width * progress))
                Text("\(UsageBillingFormat.money(spend)) / \(UsageBillingFormat.money(limit))")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(UsageBillingPalette.text)
                    .padding(.horizontal, 8)
            }
        }
        .frame(height: 22)
    }

    var limitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NBLocalization.text("Monthly spending limit"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(UsageBillingPalette.text)

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(UsageBillingPalette.secondaryText)
                TextField(NBLocalization.text("No limit"), text: Binding(get: { model.limitText }, set: { model.editLimit($0) }))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15).monospacedDigit())
                    .padding(8)
                    .frame(maxWidth: 140)
                    .background(UsageBillingPalette.fieldBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(UsageBillingPalette.fieldBorder, lineWidth: 1))
                    .accessibilityIdentifier("usage-billing-limit")
                Text(NBLocalization.text("/month"))
                    .font(.system(size: 13))
                    .foregroundColor(UsageBillingPalette.secondaryText)
                Spacer(minLength: 8)
                Button(action: model.saveLimit) {
                    Text(model.isSavingLimit ? NBLocalization.text("Saving...") : NBLocalization.text("Save"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(UsageBillingPalette.green))
                }
                .buttonStyle(.plain)
                .disabled(model.isSavingLimit)
                .accessibilityIdentifier("usage-billing-save-limit")
            }

            Text(NBLocalization.text("Optional. Classifiers pause when the limit is reached and resume next billing cycle."))
                .font(.system(size: 12))
                .foregroundColor(UsageBillingPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let message = model.limitMessage {
                messageText(message)
            }
        }
        .padding(.top, 4)
    }

    // MARK: History

    var historySection: some View {
        card(title: NBLocalization.text("Usage billing history")) {
            switch model.historyState {
            case .notSetUp:
                emptyText(NBLocalization.text("No usage billing set up."))
            case .loading:
                emptyText(NBLocalization.text("Loading..."))
            case .failed:
                emptyText(NBLocalization.text("Couldn't load usage billing history."))
            case .loaded(let history):
                if !history.hasInvoices {
                    emptyText(NBLocalization.text("No usage billing invoices yet."))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if let upcoming = history.upcomingInvoice {
                            invoiceRow(upcoming, provider: NBLocalization.text("(upcoming)"))
                        }
                        ForEach(Array(history.invoices.enumerated()), id: \.offset) { index, invoice in
                            if index > 0 || history.upcomingInvoice != nil { Divider() }
                            invoiceRow(invoice, provider: "stripe")
                        }
                    }
                }
            }
        }
    }

    func invoiceRow(_ invoice: UsageBillingHistory.Invoice, provider: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(UsageBillingFormat.invoiceDate(invoice.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(invoice.isScheduled ? UsageBillingPalette.secondaryText : UsageBillingPalette.text)
                Spacer(minLength: 8)
                Text(UsageBillingFormat.money(invoice.amount))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(UsageBillingPalette.text)
                Text(provider)
                    .font(.system(size: 12))
                    .foregroundColor(UsageBillingPalette.secondaryText)
                if let url = invoice.hostedInvoiceURL {
                    Button(NBLocalization.text("Invoice")) { openURL(url) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(UsageBillingPalette.link)
                        .buttonStyle(.plain)
                }
            }
            ForEach(Array(invoice.lineItems.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.description)
                        .foregroundColor(UsageBillingPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text("\u{00D7}\(NBLocalization.formattedCount(item.quantity))")
                        .foregroundColor(UsageBillingPalette.secondaryText)
                    Text(UsageBillingFormat.money(item.amount))
                        .foregroundColor(UsageBillingPalette.secondaryText)
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
                .foregroundColor(UsageBillingPalette.secondaryText)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(UsageBillingPalette.card))
        }
    }

    func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .italic()
            .foregroundColor(UsageBillingPalette.secondaryText)
    }

    func messageText(_ message: UsageBillingModel.Message) -> some View {
        Text(message.text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(message.isError ? UsageBillingPalette.errorText : UsageBillingPalette.green)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// UsageBillingView.swift formats dollars like reader_account.js and dates in the interface language.
enum UsageBillingFormat {
    static func money(_ amount: Double) -> String {
        String(format: "$%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
    }

    static func period(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        return String(format: NBLocalization.text("%1$@ – %2$@"),
                      date(start, template: "MMMd"), date(end, template: "MMMdyyyy"))
    }

    static func invoiceDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.date(date, template: "MMMMddyyyy")
    }

    private static func date(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: NBLocalization.resolvedLanguage)
        // AIClassifiers.swift parses the server's YYYY-MM-DD days in UTC, so they print in UTC too.
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}

/// UsageBillingView.swift's colors for the Light, Sepia, Medium and Dark themes.
enum UsageBillingPalette {
    static var background: Color { Color.themed([0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x111111]) }
    static var headerBackground: Color { Color.themed([0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222]) }
    static var card: Color { Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x222222]) }
    static var text: Color { Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7]) }
    static var secondaryText: Color { Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]) }
    static var link: Color { Color.themed([0x2F6FB3, 0x8A5A1E, 0x8CC4FF, 0x8CC4FF]) }
    static var green: Color { Color.themed([0x5F9B4C, 0x5F9B4C, 0x4E8A3E, 0x4E8A3E]) }
    static var orange: Color { Color.themed([0xE59A2F, 0xD98C24, 0xC98426, 0xC98426]) }
    static var red: Color { Color.themed([0xD9534F, 0xC9483F, 0xB94A48, 0xB94A48]) }
    static var track: Color { Color.themed([0xE6E8E3, 0xE8DED0, 0x48484A, 0x333333]) }
    static var errorText: Color { Color.themed([0xC62828, 0xB0352B, 0xFFA3A5, 0xFFA3A5]) }
    static var fieldBackground: Color { Color.themed([0xFFFFFF, 0xFFFBF5, 0x2C2C2E, 0x1C1C1E]) }
    static var fieldBorder: Color { Color.themed([0xC7C7CC, 0xD4C8B8, 0x555555, 0x444444]) }
}

// MARK: - Controller

/// UsageBillingView.swift's controller, presented as a sheet by NewsBlurAppDelegate.m showUsageBillingDialog.
@objc final class UsageBillingViewController: UIViewController {
    let model: UsageBillingModel
    private var feedsObserver: NSObjectProtocol?

    init(model: UsageBillingModel? = nil) {
        self.model = model ?? UsageBillingModel()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        model = UsageBillingModel()
        super.init(coder: coder)
    }

    deinit {
        if let feedsObserver { NotificationCenter.default.removeObserver(feedsObserver) }
    }

    /// A sheet ready to present, sized like the Premium screen in NewsBlurAppDelegate.m.
    @objc static func makePresentable() -> UIViewController {
        let controller = UsageBillingViewController()
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
        let hosting = UIHostingController(rootView: UsageBillingView(
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
        view.backgroundColor = UIColor(UsageBillingPalette.background)

        // FeedsObjCViewController.m posts this after /reader/feeds refreshes dictUserProfile.
        feedsObserver = NotificationCenter.default.addObserver(forName: Notification.Name("FinishedLoadingFeedsNotification"),
                                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.profileDidRefresh() }
        }
    }
}
