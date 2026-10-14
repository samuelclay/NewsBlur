// NBLocalization.swift selects bundled translations and synchronizes the account preference.
import Foundation
import SwiftUI
import UIKit

@objcMembers final class NBLocalization: NSObject {
    static let preferenceKey = "newsblur_language"
    static let pendingKey = "newsblur_language_pending"
    static let changed = Notification.Name("NewsBlurLanguageChanged")
    static var language: String { UserDefaults.standard.string(forKey: preferenceKey) ?? "auto" }
    static let languages: [(String, String)] = [
        ("en", "English"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"),
        ("pt-BR", "Português (Brasil)"), ("it", "Italiano"), ("nl", "Nederlands"), ("pl", "Polski"),
        ("tr", "Türkçe"), ("ru", "Русский"), ("uk", "Українська"), ("ar", "العربية"), ("he", "עברית"),
        ("hi", "हिन्दी"), ("id", "Bahasa Indonesia"), ("vi", "Tiếng Việt"), ("th", "ไทย"),
        ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文")
    ]
    static var deviceLanguage: String {
        Bundle.preferredLocalizations(from: languages.map { $0.0 }, forPreferences: Locale.preferredLanguages).first ?? "en"
    }
    static var resolvedLanguage: String { language == "auto" ? deviceLanguage : language }
    private static let bundleLock = NSLock()
    private static var cachedBundle: (code: String, bundle: Bundle)?
    // NBLocalization.swift resolves the .lproj bundle again only after the effective language changes.
    static var bundle: Bundle {
        let code = resolvedLanguage
        bundleLock.lock()
        defer { bundleLock.unlock() }
        if let cachedBundle, cachedBundle.code == code { return cachedBundle.bundle }
        let resolved = bundle(for: code)
        cachedBundle = (code, resolved)
        return resolved
    }
    static var isRightToLeft: Bool {
        Locale.Language(identifier: resolvedLanguage).characterDirection == .rightToLeft
    }
    static func bundle(for code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
    static func text(_ source: String) -> String {
        bundle.localizedString(forKey: source, value: source, table: nil)
    }
    static func text(_ source: String, language code: String) -> String {
        bundle(for: code).localizedString(forKey: source, value: source, table: nil)
    }
    // NBLocalization.swift labels Automatic in the device language, so someone who picked a language
    // they can't read still recognizes the way back.
    static var automaticLabel: String {
        NBLocalization.text("Automatic (device language)", language: deviceLanguage)
    }
    // FeedDetailObjCViewController.m, FeedsObjCViewController.m and FolderTitleView.m describe the collection
    // with an English identifier; each known one becomes a complete translated sentence.
    static func markReadTitle(_ collection: String) -> String {
        switch collection {
        case "all stories": return NBLocalization.text("Mark all stories as read")
        case "everything": return NBLocalization.text("Mark everything as read")
        case "entire folder": return NBLocalization.text("Mark entire folder as read")
        case "this site": return NBLocalization.text("Mark this site as read")
        case "site": return NBLocalization.text("Mark site as read")
        case "this list": return NBLocalization.text("Mark this list as read")
        case "daily briefing": return NBLocalization.text("Mark daily briefing as read")
        default: return String(format: NBLocalization.text("Mark %@ as read"), collection)
        }
    }
    static func plural(_ source: String, count: NSNumber?) -> String {
        // NotificationsViewController.m can receive feeds without monthly story statistics.
        guard let count else { return "" }
        // NBLocalization.swift must use the override's plural rules, not the system locale's rules.
        return String(format: text(source), locale: Locale(identifier: resolvedLanguage), arguments: [count])
    }
    // NBLocalization.swift remembers the newest requested language so an older save can't override it.
    @MainActor private static var latestRequest: String?
    @MainActor static func apply(_ value: String, pending: Bool) {
        guard value == "auto" || languages.contains(where: { $0.0 == value }) else { return }
        if pending { latestRequest = value }
        UserDefaults.standard.set(value, forKey: preferenceKey)
        UserDefaults.standard.set(pending, forKey: pendingKey)
        configureDirection()
        NotificationCenter.default.post(name: changed, object: nil)
        // NBLocalization.swift rebuilds the Mac/iPad menu bar and key command titles in the new language.
        UIMenuSystem.main.setNeedsRebuild()
    }
    @MainActor static func configureDirection() {
        NewsBlurAppDelegate.shared?.networkManager?.requestSerializer.setValue(resolvedLanguage, forHTTPHeaderField: "Accept-Language")
        let direction: UISemanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = direction
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows { window.semanticContentAttribute = direction }
        }
    }
    // NewsBlurAppDelegate.m clears the previous account's language on login, but keeps a choice made on
    // the login screen; syncProfile saves that pending choice to the new account.
    @MainActor static func resetForAccountChange() {
        guard !UserDefaults.standard.bool(forKey: pendingKey) else { return }
        apply("auto", pending: false)
    }
    @MainActor static func syncProfile(_ profile: [String: Any]?) {
        guard let profile = profile else { return }
        if UserDefaults.standard.bool(forKey: pendingKey) {
            save(language) { _ in }
            return
        }
        var preferences = profile["preferences"] as? [String: Any]
        if let raw = profile["preferences"] as? String, let data = raw.data(using: .utf8) {
            preferences = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        let value = preferences?["language"] as? String ?? "auto"
        if value != language { apply(value, pending: false) }
    }
    @MainActor static func save(_ value: String, completion: @escaping (Bool) -> Void) {
        guard let app = NewsBlurAppDelegate.shared, let base = app.url else { completion(false); return }
        latestRequest = value
        app.post("\(base)/profile/set_preference", parameters: ["language": value], success: { _, response in
            MainActor.assumeIsolated {
                guard latestRequest == value else { return }
                let succeeded = (response as? [String: Any])?["code"] as? Int == 1
                if succeeded { apply(value, pending: false) }
                completion(succeeded)
            }
        }, failure: { _, _ in
            MainActor.assumeIsolated {
                guard latestRequest == value else { return }
                completion(false)
            }
        })
    }
}

// XIB/storyboard labels opt in explicitly through these runtime attributes.
// The keys are extracted from the interface files by localization/manage.py.
extension NSObject {
    @objc var nbLocalizedText: String {
        get { "" }
        set {
            let value = NBLocalization.text(newValue)
            if let label = self as? UILabel { label.text = value }
            else if let button = self as? UIButton { button.setTitle(value, for: .normal) }
            else if let textView = self as? UITextView { textView.text = value }
            else if let item = self as? UIBarItem { item.title = value }
            else if let item = self as? UINavigationItem { item.title = value }
        }
    }
    @objc var nbLocalizedPlaceholder: String {
        get { "" }
        set {
            if let field = self as? UITextField { field.placeholder = NBLocalization.text(newValue) }
            else if let search = self as? UISearchBar { search.placeholder = NBLocalization.text(newValue) }
        }
    }
}
