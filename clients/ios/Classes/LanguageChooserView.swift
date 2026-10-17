// LanguageChooserView.swift makes the automatically detected interface language visible and reversible in one tap.
// The detected language and English sit side by side like a bilingual edition, so someone who can't read the
// detected language still finds the way back. English-detected people see a grid of every language instead.
// FeedsViewController.swift shows it once as a sheet after the feed list loads, and OnboardingViewController.swift
// hosts the same chooser as the first step of setup.
import SwiftUI
import UIKit

// MARK: - When the dialog shows

@MainActor final class LanguageDialog {
    private static var savingAutomaticLanguage = false

    private static var menuPresenter: UIViewController? {
        guard !savingAutomaticLanguage, let app = NewsBlurAppDelegate.shared,
              let username = app.activeUsername, !username.isEmpty,
              let presenter = app.splitViewController,
              presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return nil }
        return presenter
    }

    static var canPresentFromMenu: Bool { menuPresenter != nil }

    static func presentFromMenu() {
        guard let presenter = menuPresenter else { return }
        // LanguageChooserView.swift bypasses the one-time offer when opened from the Mac menu.
        let controller = LanguageDialogViewController(startsInGrid: true, presenter: presenter, manualSelection: true)
        presenter.present(controller, animated: true)
    }

    static func useAutomaticLanguage() {
        guard let presenter = menuPresenter, NBLocalization.language != "auto" else { return }
        savingAutomaticLanguage = true
        UIMenuSystem.main.setNeedsRebuild()
        NBLocalization.save("auto") { success in
            savingAutomaticLanguage = false
            UIMenuSystem.main.setNeedsRebuild()
            guard !success else { return }
            let alert = UIAlertController(title: NBLocalization.text("Could not save your language. Please try again."),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NBLocalization.text("OK"), style: .default))
            guard presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return }
            presenter.present(alert, animated: true)
        }
    }

    static let seenKey = "language_dialog_seen"
    // LanguageChooserView.swift screenshot hooks. The first forces the dialog regardless of the seen flag and
    // account language, the second opens it in grid mode, the third shows it as the first onboarding step instead.
    static let forceArgument = "-newsblur-show-language-dialog"
    static let gridArgument = "-newsblur-language-dialog-grid"
    static let onboardingArgument = "-newsblur-language-dialog-onboarding"
    private static var presentedThisSession = false

    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: seenKey) }
        set { UserDefaults.standard.set(newValue, forKey: seenKey) }
    }

    static var isForced: Bool { ProcessInfo.processInfo.arguments.contains(forceArgument) }
    static var startsInGrid: Bool { ProcessInfo.processInfo.arguments.contains(gridArgument) }

    // LanguageChooserView.swift stays out of unit tests and the UI-test harness, which drive their own screens.
    private static var isAutomatedTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.arguments.contains("-newsblur-ui-testing")
    }

    // LanguageChooserView.swift only asks people still on automatic detection. Someone who already picked a
    // language never needs the dialog, so it is marked seen without showing.
    private static func shouldOffer() -> Bool {
        if isForced { return true }
        guard !isAutomatedTest, !seen else { return false }
        guard NBLocalization.language == "auto" else {
            seen = true
            return false
        }
        return true
    }

    // OnboardingViewController.swift asks once, when setup opens, whether its first step is the language step.
    static func offersOnboardingStep() -> Bool {
        shouldOffer()
    }

    // FeedsViewController.swift calls this after a network feed list has rendered and
    // FeedsObjCViewController.m has synced the account language from the same response.
    static func feedListDidLoad() {
        guard !presentedThisSession, let appDelegate = NewsBlurAppDelegate.shared(),
              let username = appDelegate.activeUsername, !username.isEmpty, shouldOffer() else { return }
        // OnboardingViewController.swift hosts the chooser itself, so setup never shows both.
        if appDelegate.ftuxNavigationController?.presentingViewController != nil { return }
        if isForced && ProcessInfo.processInfo.arguments.contains(onboardingArgument) {
            presentedThisSession = true
            appDelegate.showFirstTimeUser()
            return
        }
        // LanguageChooserView.swift waits for the next feed list load instead of covering another sheet.
        guard let presenter = appDelegate.splitViewController, presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil else { return }
        presentedThisSession = true
        seen = true
        let controller = LanguageDialogViewController(startsInGrid: startsInGrid, presenter: presenter)
        presenter.present(controller, animated: true)
    }
}

// MARK: - Choices

@MainActor final class LanguageChooserModel: ObservableObject {
    enum Mode { case bilingual, grid }

    // LanguageChooserView.swift treats the language the interface resolved to as the detected language.
    let current: String
    @Published var mode: Mode
    @Published var selection: String
    @Published private(set) var openedFromBilingual: Bool
    @Published private(set) var savingCode: String?
    @Published var saveFailed = false
    let manualSelection: Bool
    private let saveLanguage: (String, @escaping (Bool) -> Void) -> Void

    init(startsInGrid: Bool, manualSelection: Bool = false,
         saveLanguage: @escaping (String, @escaping (Bool) -> Void) -> Void = NBLocalization.save) {
        self.manualSelection = manualSelection
        self.saveLanguage = saveLanguage
        current = NBLocalization.resolvedLanguage
        let english = current == "en"
        mode = english || startsInGrid ? .grid : .bilingual
        openedFromBilingual = !manualSelection && !english && startsInGrid
        selection = current
    }

    var isSaving: Bool { savingCode != nil }

    func showGrid() {
        selection = current
        openedFromBilingual = true
        mode = .grid
    }

    func showBilingual() {
        mode = .bilingual
    }

    // LanguageChooserView.swift keeps automatic detection, so the account preference stays auto.
    func keep(then finish: @escaping () -> Void) {
        LanguageDialog.seen = true
        finish()
    }

    // LanguageChooserView.swift saves through the same NBLocalization.save path as the Preferences language row,
    // which applies the language live once the server accepts it.
    func choose(_ code: String, then finish: @escaping () -> Void) {
        LanguageDialog.seen = true
        // LanguageChooserView.swift pins an explicit menu choice even when Automatic currently resolves to it.
        let unchanged = manualSelection ? NBLocalization.language : NBLocalization.resolvedLanguage
        guard code != unchanged else {
            finish()
            return
        }
        savingCode = code
        saveLanguage(code) { [weak self] success in
            guard let self else { return }
            savingCode = nil
            if success { finish() } else { saveFailed = true }
        }
    }
}

// MARK: - Theme

enum LanguageChooserColors {
    // LanguageChooserView.swift lifts the medium and dark sheet like OnboardingViewController.swift's background,
    // so it stays distinct from the dimmed reader behind it.
    static var surface: Color { DiscoverColors.themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x3D3D3D, dark: 0x1A1A1A) }
    static var ink: Color { DiscoverColors.themedColor(light: 0x404040, sepia: 0x5C4A3D, medium: 0xE0E0E0, dark: 0xE8E8E8) }
    static var body: Color { DiscoverColors.themedColor(light: 0x606060, sepia: 0x5C4A3D, medium: 0xC0C0C0, dark: 0xC0C0C0) }
    static var muted: Color { DiscoverColors.themedColor(light: 0x95968E, sepia: 0x8B7B6B, medium: 0xA0A0A0, dark: 0x8F8F8F) }
    static var hairline: Color { DiscoverColors.themedColor(light: 0xD0D2CC, sepia: 0xD4C8B8, medium: 0x5A5A5A, dark: 0x404040) }
    // LanguageChooserView.swift shares OnboardingViewController.swift's accent and primary button color.
    static var accent: Color { DiscoverColors.themedColor(light: 0x3B6863, sepia: 0x3B6863, medium: 0xA3CBC3, dark: 0xA3CBC3) }
    static let button = Color(red: 0.25, green: 0.40, blue: 0.39)
}

private struct LanguageChooserButtonStyle: ButtonStyle {
    let fontSize: CGFloat
    let minHeight: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
            .background(LanguageChooserColors.button.opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chooser

struct LanguageChooserView: View {
    // LanguageChooserView.swift lines up the two columns row by row, the one memorable thing in the design.
    private enum Row: CaseIterable {
        case tag, title, body, note, button, link
    }

    @ObservedObject var model: LanguageChooserModel
    // The host paints its own background; the grid's pinned button bar repeats it over scrolled content.
    let background: Color
    let topPadding: CGFloat
    // LanguageDialogViewController.swift measures the chooser before presenting, before any width is known.
    let wideHint: Bool
    var scrolls = true
    let onFinish: () -> Void
    var onHeightChange: (CGFloat) -> Void = { _ in }

    @State private var measuredWidth: CGFloat?
    @State private var contentHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .footnote) private var tagSize = 13.0
    @ScaledMetric(relativeTo: .title3) private var titleSize = 20.0
    @ScaledMetric(relativeTo: .subheadline) private var bodySize = 15.0
    @ScaledMetric(relativeTo: .subheadline) private var controlHeight = 46.0
    @ScaledMetric(relativeTo: .subheadline) private var optionHeight = 48.0

    private static let wideWidth: CGFloat = 560
    private var isWide: Bool { measuredWidth.map { $0 >= Self.wideWidth } ?? wideHint }
    private var horizontalPadding: CGFloat { isWide ? 32 : 24 }
    private var bodyLineSpacing: CGFloat { bodySize * 0.32 }

    var body: some View {
        Group {
            if scrolls {
                ScrollView {
                    content
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0; reportHeight() }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if model.mode == .grid {
                        gridActions
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0; reportHeight() }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    content
                    if model.mode == .grid { gridActions }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { measuredWidth = $0 }
        .onChange(of: model.mode) {
            if model.mode == .bilingual { barHeight = 0 }
            reportHeight()
        }
        .onAppear { LanguageDialog.seen = true }
        .disabled(model.isSaving)
        .alert(NBLocalization.text("Could not save your language. Please try again."), isPresented: $model.saveFailed) {
            Button(NBLocalization.text("OK"), role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NBLocalization.text("Language"))
    }

    private func reportHeight() {
        onHeightChange(contentHeight + (model.mode == .grid ? barHeight : 0))
    }

    @ViewBuilder private var content: some View {
        Group {
            switch model.mode {
            case .bilingual: bilingual
            case .grid: grid
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        // LanguageChooserView.swift counts the link's 44 point touch target as part of the bottom margin.
        .padding(.bottom, model.mode == .grid ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Bilingual mode

    @ViewBuilder private var bilingual: some View {
        if isWide {
            // LanguageChooserView.swift places each row of both languages in one grid row, so a longer
            // translation pushes the matching English row down with it. The hairline is its own column.
            Grid(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 0) {
                ForEach(Row.allCases, id: \.self) { row in
                    GridRow {
                        cell(row, code: model.current)
                        Rectangle().fill(LanguageChooserColors.hairline).frame(width: 1)
                            .gridCellUnsizedAxes(.vertical)
                        cell(row, code: "en")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                column(code: model.current)
                // The link above already ends with 12 points of its touch target.
                Rectangle().fill(LanguageChooserColors.hairline).frame(height: 1)
                    .padding(.top, 12).padding(.bottom, 24)
                column(code: "en")
            }
        }
    }

    private func column(code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Row.allCases, id: \.self) { row in cell(row, code: code) }
        }
    }

    private func cell(_ row: Row, code: String) -> some View {
        rowContent(row, code: code)
            .padding(.top, spacing(before: row))
            .frame(maxWidth: .infinity, maxHeight: row == .button ? .infinity : nil, alignment: .topLeading)
            .languageDirection(code)
    }

    private func spacing(before row: Row) -> CGFloat {
        switch row {
        case .tag: return 0
        case .title: return 6
        case .body: return 10
        case .note: return 8
        case .button: return 20
        case .link: return 2
        }
    }

    @ViewBuilder private func rowContent(_ row: Row, code: String) -> some View {
        let english = code == "en"
        switch row {
        case .tag:
            languageText(Self.nativeName(code), code: code)
                .font(.system(size: tagSize, weight: .semibold))
                .foregroundColor(LanguageChooserColors.muted)
        case .title:
            languageText(NBLocalization.text("Choose your language", language: code), code: code)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundColor(LanguageChooserColors.ink)
                .accessibilityAddTraits(.isHeader)
        case .body:
            // LanguageChooserView.swift names the detected language natively in its own column and in English
            // in the English column.
            let name = english ? Self.englishName(model.current) : Self.nativeName(model.current)
            paragraph(String(format: NBLocalization.text("NewsBlur detected %@ from your device.", language: code), name), code: code)
        case .note:
            paragraph(NBLocalization.text("You can change this anytime in Preferences.", language: code), code: code)
        case .button:
            Button {
                if english { model.choose("en", then: onFinish) } else { model.keep(then: onFinish) }
            } label: {
                savingLabel(String(format: NBLocalization.text("Use %@", language: code), Self.nativeName(code)),
                            code: code, saving: model.savingCode == code)
            }
            .buttonStyle(LanguageChooserButtonStyle(fontSize: bodySize, minHeight: controlHeight))
        case .link:
            link(NBLocalization.text("Choose another language", language: code), code: code) { model.showGrid() }
        }
    }

    // MARK: Grid mode

    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            // LanguageChooserView.swift previews the selected language in the introduction, and repeats it in
            // English below so the way back stays readable.
            intro(code: model.selection, muted: false)
            if model.selection != "en" {
                intro(code: "en", muted: true).padding(.top, 18)
            }
            options.padding(.top, 22)
        }
    }

    private func intro(code: String, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            languageText(NBLocalization.text("Choose your language", language: code), code: code)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundColor(muted ? LanguageChooserColors.muted : LanguageChooserColors.ink)
                .accessibilityAddTraits(.isHeader)
            #if targetEnvironment(macCatalyst)
            paragraph(NBLocalization.text("Pick the language you'd like NewsBlur to use. You can change this anytime in the NewsBlur menu.",
                                          language: code), code: code, color: muted ? LanguageChooserColors.muted : nil)
            #else
            paragraph(NBLocalization.text("Pick the language you'd like NewsBlur to use. You can change this anytime in Preferences.",
                                          language: code), code: code, color: muted ? LanguageChooserColors.muted : nil)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .languageDirection(code)
    }

    private var options: some View {
        let columns = isWide ? 3 : 2
        let codes = NBLocalization.languages.map(\.0)
        let rows = stride(from: 0, to: codes.count, by: columns).map { Array(codes[$0..<min($0 + columns, codes.count)]) }
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { code in option(code) }
                }
            }
        }
    }

    private func option(_ code: String) -> some View {
        let selected = model.selection == code
        let shape = RoundedRectangle(cornerRadius: 10)
        return Button { model.selection = code } label: {
            HStack(spacing: 4) {
                // LanguageChooserView.swift sets each name's own direction while every option keeps the
                // interface's alignment, so the grid reads as one even column of names. Names keep one weight
                // so the longest ones (Português (Brasil), Bahasa Indonesia) fit a phone's two columns.
                languageText(Self.nativeName(code), code: code)
                    .font(.system(size: bodySize))
                    .foregroundColor(selected ? LanguageChooserColors.ink : LanguageChooserColors.body)
                    .languageDirection(code)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: bodySize * 0.75, weight: .bold))
                    .foregroundColor(LanguageChooserColors.accent)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: optionHeight, maxHeight: .infinity)
            .background(shape.fill(selected ? LanguageChooserColors.accent.opacity(0.1) : Color.clear))
            .overlay(shape.stroke(selected ? LanguageChooserColors.accent.opacity(0.5) : LanguageChooserColors.hairline, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var gridActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button { model.choose(model.selection, then: onFinish) } label: {
                // LanguageChooserView.swift words the button entirely in the selected language.
                savingLabel(String(format: NBLocalization.text("Use %@", language: model.selection),
                                   Self.nativeName(model.selection)),
                            code: model.selection, saving: model.savingCode != nil)
            }
            .buttonStyle(LanguageChooserButtonStyle(fontSize: bodySize, minHeight: controlHeight))
            .fixedSize(horizontal: false, vertical: true)
            if model.openedFromBilingual {
                link(NBLocalization.text("Back"), code: model.current) { model.showBilingual() }
            } else if model.manualSelection {
                link(NBLocalization.text("Cancel"), code: model.current, action: onFinish)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, model.openedFromBilingual ? 8 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(alignment: .top) {
            // LanguageChooserView.swift separates the pinned button only while languages scroll beneath it.
            if contentHeight > viewportHeight + 1 {
                Rectangle().fill(LanguageChooserColors.hairline).frame(height: 1)
            }
        }
    }

    // MARK: Pieces

    private func paragraph(_ string: String, code: String, color: Color? = nil) -> some View {
        languageText(string, code: code)
            .font(.system(size: bodySize))
            .lineSpacing(bodyLineSpacing)
            .foregroundColor(color ?? LanguageChooserColors.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func link(_ string: String, code: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            languageText(string, code: code)
                .font(.system(size: bodySize, weight: .medium))
                .foregroundColor(LanguageChooserColors.accent)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .languageDirection(code)
    }

    private func savingLabel(_ string: String, code: String, saving: Bool) -> some View {
        ZStack {
            languageText(string, code: code).opacity(saving ? 0 : 1)
            if saving { ProgressView().tint(.white) }
        }
    }

    // LanguageChooserView.swift tags each string with its language so typesetting picks the right glyphs.
    private func languageText(_ string: String, code: String) -> Text {
        var attributed = AttributedString(string)
        attributed.languageIdentifier = code
        return Text(attributed)
    }

    static func nativeName(_ code: String) -> String {
        NBLocalization.languages.first { $0.0 == code }?.1 ?? code
    }

    // LanguageChooserView.swift takes English language names from the platform instead of the catalog.
    static func englishName(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forIdentifier: code) ?? nativeName(code)
    }
}

private extension View {
    // LanguageChooserView.swift gives every column and option its own language and direction instead of
    // inheriting the interface direction, so an Arabic half reads right to left beside an English half.
    func languageDirection(_ code: String) -> some View {
        let language = Locale.Language(identifier: code)
        return environment(\.layoutDirection, language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: code))
            .typesettingLanguage(language)
    }
}

// MARK: - Standalone sheet

final class LanguageDialogViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private static let formWidth: CGFloat = 680
    private static let fittedDetent = UISheetPresentationController.Detent.Identifier("language-fitted")
    private let model: LanguageChooserModel
    private var contentHeight: CGFloat

    init(startsInGrid: Bool, presenter: UIViewController, manualSelection: Bool = false) {
        model = LanguageChooserModel(startsInGrid: startsInGrid, manualSelection: manualSelection)
        // LanguageDialogViewController.swift measures the chooser without scrolling first, so the sheet opens
        // at its final height instead of growing after the first layout pass.
        let regular = presenter.traitCollection.horizontalSizeClass == .regular
        let width = regular ? Self.formWidth : presenter.view.bounds.width
        let measuring = UIHostingController(rootView: LanguageChooserView(
            model: model, background: .clear, topPadding: Self.topPadding, wideHint: regular, scrolls: false, onFinish: {}))
        contentHeight = measuring.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = regular ? .formSheet : .pageSheet
        preferredContentSize = CGSize(width: Self.formWidth, height: contentHeight)
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom(identifier: Self.fittedDetent) { [weak self] context in
                min(self?.contentHeight ?? context.maximumDetentValue, context.maximumDetentValue)
            }]
            sheet.prefersGrabberVisible = !regular
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        presentationController?.delegate = self
    }

    private static let topPadding: CGFloat = 30

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("LanguageDialogViewController.swift is created in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(LanguageChooserColors.surface)
        view.accessibilityViewIsModal = true
        let host = UIHostingController(rootView: LanguageChooserView(
            model: model, background: LanguageChooserColors.surface, topPadding: Self.topPadding,
            wideHint: modalPresentationStyle == .formSheet,
            onFinish: { [weak self] in self?.dismiss(animated: true) },
            onHeightChange: { [weak self] height in self?.contentHeightDidChange(height) }))
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    // LanguageDialogViewController.swift refits the sheet when the mode or text size changes its content height.
    private func contentHeightDidChange(_ height: CGFloat) {
        guard height > 0, abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        preferredContentSize = CGSize(width: Self.formWidth, height: height)
        sheetPresentationController?.animateChanges {
            sheetPresentationController?.invalidateDetents()
        }
    }

    // Swiping the sheet away keeps the current language; the seen flag was set when it appeared.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        LanguageDialog.seen = true
    }
}
