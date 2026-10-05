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
    static var resolvedLanguage: String {
        if language != "auto" { return language }
        return Bundle.preferredLocalizations(from: languages.map { $0.0 }, forPreferences: Locale.preferredLanguages).first ?? "en"
    }
    static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: resolvedLanguage, ofType: "lproj"), let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
    static func text(_ source: String) -> String {
        bundle.localizedString(forKey: source, value: source, table: nil)
    }
    static func plural(_ source: String, count: NSNumber?) -> String {
        // NotificationsViewController.m can receive feeds without monthly story statistics.
        guard let count else { return "" }
        // NBLocalization.swift must use the override's plural rules, not the system locale's rules.
        return String(format: text(source), locale: Locale(identifier: resolvedLanguage), arguments: [count])
    }
    static func apply(_ value: String, pending: Bool) {
        guard value == "auto" || languages.contains(where: { $0.0 == value }) else { return }
        UserDefaults.standard.set(value, forKey: preferenceKey)
        UserDefaults.standard.set(pending, forKey: pendingKey)
        configureDirection()
        NotificationCenter.default.post(name: changed, object: nil)
    }
    static func configureDirection() {
        NewsBlurAppDelegate.shared?.networkManager?.requestSerializer.setValue(resolvedLanguage, forHTTPHeaderField: "Accept-Language")
        let direction: UISemanticContentAttribute = ["ar", "he"].contains(resolvedLanguage) ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = direction
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows { window.semanticContentAttribute = direction }
        }
    }
    static func reset() { apply("auto", pending: false) }
    static func syncProfile(_ profile: [String: Any]?) {
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
    static func save(_ value: String, completion: @escaping (Bool) -> Void) {
        guard let app = NewsBlurAppDelegate.shared, let base = app.url else { completion(false); return }
        app.post("\(base)/profile/set_preference", parameters: ["language": value], success: { _, response in
            let succeeded = (response as? [String: Any])?["code"] as? Int == 1
            if succeeded { apply(value, pending: false) }
            completion(succeeded)
        }, failure: { _, _ in completion(false) })
    }
    static func installLoginButton(_ controller: UIViewController) {
        let button = UIButton(type: .system)
        button.setTitle("🌐 " + (languages.first { $0.0 == language }?.1 ?? text("Automatic (device language)")), for: .normal)
        button.accessibilityLabel = text("Language")
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 4),
            button.trailingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.widthAnchor.constraint(lessThanOrEqualTo: controller.view.widthAnchor, multiplier: 0.8)
        ])
        button.addAction(UIAction { [weak controller] _ in
            guard let controller = controller else { return }
            let alert = UIAlertController(title: text("Language"), message: nil, preferredStyle: .actionSheet)
            for (code, name) in [("auto", text("Automatic (device language)"))] + languages {
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                    apply(code, pending: true)
                    // Rebuild only the login UI, preserving entered credentials in memory.
                    let values = fields(in: controller.view).map { $0.text }
                    controller.view = nil
                    controller.loadViewIfNeeded()
                    for (field, value) in zip(fields(in: controller.view), values) { field.text = value }
                })
            }
            alert.addAction(UIAlertAction(title: text("Cancel"), style: .cancel))
            alert.popoverPresentationController?.sourceView = button
            alert.popoverPresentationController?.sourceRect = button.bounds
            controller.present(alert, animated: true)
        }, for: .touchUpInside)
    }
    private static func fields(in view: UIView) -> [UITextField] {
        (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { fields(in: $0) }
    }
}

@available(iOS 15.0, *)
struct NBLanguagePicker: View {
    @AppStorage(NBLocalization.preferenceKey) private var language = "auto"
    @State private var failed = false
    @State private var saving = false
    var body: some View {
        Picker(NBLocalization.text("Language"), selection: Binding(get: { language }, set: { value in
            saving = true
            NBLocalization.save(value) { success in saving = false; failed = !success }
        })) {
            Text(NBLocalization.text("Automatic (device language)")).tag("auto")
            ForEach(NBLocalization.languages, id: \.0) { code, name in Text(name).tag(code) }
        }
        .disabled(saving)
        .pickerStyle(.menu)
        .alert(NBLocalization.text("Could not save your language. Please try again."), isPresented: $failed) {
            Button(NBLocalization.text("OK"), role: .cancel) {}
        }
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
