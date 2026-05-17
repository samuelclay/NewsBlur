//
//  PreferencesView.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-09.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Preferences Colors (Theme-aware)

@available(iOS 15.0, *)
private struct PreferencesColors {
    static var background: Color {
        themedColor(light: 0xF0F2ED, sepia: 0xF3E2CB, medium: 0x2C2C2E, dark: 0x1C1C1E)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x3A3A3C, dark: 0x2C2C2E)
    }

    static var secondaryBackground: Color {
        themedColor(light: 0xF7F7F5, sepia: 0xFAF5ED, medium: 0x48484A, dark: 0x38383A)
    }

    static var textPrimary: Color {
        themedColor(light: 0x1C1C1E, sepia: 0x3C3226, medium: 0xF2F2F7, dark: 0xF2F2F7)
    }

    static var textSecondary: Color {
        themedColor(light: 0x6E6E73, sepia: 0x8B7B6B, medium: 0xAEAEB2, dark: 0x98989D)
    }

    static var border: Color {
        themedColor(light: 0xD1D1D6, sepia: 0xD4C8B8, medium: 0x545458, dark: 0x48484A)
    }

    static var destructive: Color { Color(red: 0.9, green: 0.3, blue: 0.3) }
    static var newsblurGreen: Color { Color(red: 0.439, green: 0.620, blue: 0.365) }
    static var newsblurBlue: Color { Color(red: 0.33, green: 0.47, blue: 0.65) }
    static var clusterMatch: Color {
        themedColor(light: 0x5A8C6A, sepia: 0x6E865F, medium: 0x7DC99A, dark: 0x7DC99A)
    }

    static var clusterRelated: Color {
        themedColor(light: 0xA88246, sepia: 0x9B7540, medium: 0xD2A76B, dark: 0xD2A76B)
    }

    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            return colorFromHex(light)
        }

        let hex: Int

        // Use effectiveTheme which resolves "auto" to the actual visual theme
        let effectiveTheme = themeManager.effectiveTheme

        if effectiveTheme == ThemeStyleMedium || effectiveTheme == "medium" {
            hex = medium
        } else if effectiveTheme == ThemeStyleDark || effectiveTheme == "dark" {
            hex = dark
        } else if effectiveTheme == ThemeStyleSepia || effectiveTheme == "sepia" {
            hex = sepia
        } else {
            hex = light
        }
        return colorFromHex(hex)
    }

    private static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - App Icon Choices

/// Whether the app icon follows the device's light/dark setting or stays pinned
/// to a single appearance. The active alternate-icon name encodes this, so no
/// extra persistence is needed.
@available(iOS 15.0, *)
private enum NewsBlurAppIconAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case auto
    case dark

    var id: String { rawValue }

    /// Label shown in the chooser's segmented control.
    var title: String {
        switch self {
        case .light: return "Light"
        case .auto: return "Use both"
        case .dark: return "Dark"
        }
    }

    /// SF Symbol paired with the label in the segmented control.
    var symbolName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .auto: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        }
    }

    /// One-line explanation shown beneath the segmented control.
    var caption: String {
        switch self {
        case .light: return "Keeps the light icon no matter how your device is set."
        case .auto: return "The icon follows your device's light and dark appearance."
        case .dark: return "Keeps the dark icon no matter how your device is set."
        }
    }

    /// The appearance a pinned mode forces, or `nil` when following the system.
    var pinnedAppearance: String? {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return nil
        }
    }
}

@available(iOS 15.0, *)
private struct NewsBlurAppIconOption: Identifiable {
    let id: String
    let title: String
    let flavor: String
    let appearance: String
    let previewAssetName: String
    let tintColor: Color
}

@available(iOS 15.0, *)
private struct NewsBlurAppIconFlavorGroup: Identifiable {
    let id: String
    let title: String
    /// Shared stem of the flavor's appiconset names, e.g. "AppIconArcticCyan".
    let assetBaseName: String
    /// True for the flavor whose "Use both" icon is the bundle's primary icon.
    let isPrimary: Bool
    let options: [NewsBlurAppIconOption]

    /// Alternate-icon name to hand to `setAlternateIconName` for a given mode.
    /// `nil` is the bundle's primary icon (only the primary flavor in `.auto`).
    func iconName(for mode: NewsBlurAppIconAppearanceMode) -> String? {
        switch mode {
        case .auto: return isPrimary ? nil : assetBaseName
        case .light: return assetBaseName + "Light"
        case .dark: return assetBaseName + "Dark"
        }
    }

    /// The preview option matching a single appearance ("Light" or "Dark").
    func option(forAppearance appearance: String) -> NewsBlurAppIconOption {
        options.first { $0.appearance == appearance } ?? options[0]
    }
}

@available(iOS 15.0, *)
private enum NewsBlurAppIconLibrary {
    static let groups: [NewsBlurAppIconFlavorGroup] = [
        group("sunrise-gold", title: "Sunrise Gold", assetBaseName: "AppIconSunriseGold",
              isPrimary: true, lightTint: 0xD88A26, darkTint: 0xDDA033),
        group("meadow-sage", title: "Meadow Sage", assetBaseName: "AppIconMeadowSage",
              isPrimary: false, lightTint: 0x6F9E5B, darkTint: 0x7DBD63),
        group("atlantic-blue", title: "Atlantic Blue", assetBaseName: "AppIconAtlanticBlue",
              isPrimary: false, lightTint: 0x3F85BC, darkTint: 0x4FA2D9),
        group("coral-rose", title: "Coral Rose", assetBaseName: "AppIconCoralRose",
              isPrimary: false, lightTint: 0xD86868, darkTint: 0xE96E76),
        group("ruby-red", title: "Ruby Red", assetBaseName: "AppIconRubyRed",
              isPrimary: false, lightTint: 0xCC3147, darkTint: 0xE5475C),
        group("ember-orange", title: "Ember Orange", assetBaseName: "AppIconEmberOrange",
              isPrimary: false, lightTint: 0xD96B27, darkTint: 0xE56F28),
        group("teal-mint", title: "Teal Mint", assetBaseName: "AppIconTealMint",
              isPrimary: false, lightTint: 0x2FA28E, darkTint: 0x3CC3AD),
        group("lavender-iris", title: "Lavender Iris", assetBaseName: "AppIconLavenderIris",
              isPrimary: false, lightTint: 0x8261CE, darkTint: 0x9879EA),
        group("slate-gray", title: "Slate Gray", assetBaseName: "AppIconSlateGray",
              isPrimary: false, lightTint: 0x6C7D8A, darkTint: 0x81919D),
        group("sepia-cocoa", title: "Sepia Cocoa", assetBaseName: "AppIconSepiaCocoa",
              isPrimary: false, lightTint: 0xA16E44, darkTint: 0xB87945),
        group("arctic-cyan", title: "Arctic Cyan", assetBaseName: "AppIconArcticCyan",
              isPrimary: false, lightTint: 0x37A8CA, darkTint: 0x44BADB),
        group("plum-berry", title: "Plum Berry", assetBaseName: "AppIconPlumBerry",
              isPrimary: false, lightTint: 0xA74A98, darkTint: 0xC060B2)
    ]

    static var canChooseIcons: Bool {
        NewsBlurAppDelegate.shared?.isPremium == true
    }

    static var supportsIconSelection: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return UIApplication.shared.supportsAlternateIcons
        #endif
    }

    /// Resolves the live alternate-icon name into a flavor + appearance mode.
    static var currentSelection: (group: NewsBlurAppIconFlavorGroup, mode: NewsBlurAppIconAppearanceMode) {
        guard let name = UIApplication.shared.alternateIconName else {
            return (groups[0], .auto)
        }

        if name.hasSuffix("Light"),
           let group = groups.first(where: { $0.assetBaseName == String(name.dropLast("Light".count)) }) {
            return (group, .light)
        }

        if name.hasSuffix("Dark"),
           let group = groups.first(where: { $0.assetBaseName == String(name.dropLast("Dark".count)) }) {
            return (group, .dark)
        }

        if let group = groups.first(where: { $0.assetBaseName == name }) {
            return (group, .auto)
        }

        return (groups[0], .auto)
    }

    /// The preview option to show for a flavor given the mode and system appearance.
    static func displayOption(for group: NewsBlurAppIconFlavorGroup,
                              mode: NewsBlurAppIconAppearanceMode,
                              colorScheme: ColorScheme) -> NewsBlurAppIconOption {
        let appearance = mode.pinnedAppearance ?? (colorScheme == .dark ? "Dark" : "Light")
        return group.option(forAppearance: appearance)
    }

    static func shouldIgnoreSimulatorIconChangeError(_ error: Error) -> Bool {
        #if targetEnvironment(simulator)
        let nsError = error as NSError
        return (nsError.domain == NSPOSIXErrorDomain && nsError.code == 35) ||
            nsError.localizedDescription.localizedCaseInsensitiveContains("resource temporarily unavailable")
        #else
        return false
        #endif
    }

    static func apply(group: NewsBlurAppIconFlavorGroup,
                      mode: NewsBlurAppIconAppearanceMode,
                      completion: @escaping (Error?) -> Void) {
        UIApplication.shared.setAlternateIconName(group.iconName(for: mode), completionHandler: completion)
    }

    private static func group(
        _ id: String,
        title: String,
        assetBaseName: String,
        isPrimary: Bool,
        lightTint: Int,
        darkTint: Int
    ) -> NewsBlurAppIconFlavorGroup {
        NewsBlurAppIconFlavorGroup(
            id: id,
            title: title,
            assetBaseName: assetBaseName,
            isPrimary: isPrimary,
            options: [
                option(id: "\(id)-light", title: "\(title) Light", flavor: title,
                       appearance: "Light", assetBaseName: assetBaseName, tint: lightTint),
                option(id: "\(id)-dark", title: "\(title) Dark", flavor: title,
                       appearance: "Dark", assetBaseName: assetBaseName, tint: darkTint)
            ]
        )
    }

    private static func option(
        id: String,
        title: String,
        flavor: String,
        appearance: String,
        assetBaseName: String,
        tint: Int
    ) -> NewsBlurAppIconOption {
        NewsBlurAppIconOption(
            id: id,
            title: title,
            flavor: flavor,
            appearance: appearance,
            previewAssetName: "\(assetBaseName)\(appearance)Preview",
            tintColor: colorFromHex(tint)
        )
    }

    private static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Preference Section Model

struct PreferenceSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    let footerText: String?
    var items: [PreferenceItem]

    init(title: String, icon: String, iconColor: Color, footerText: String? = nil, items: [PreferenceItem]) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.footerText = footerText
        self.items = items
    }
}

// MARK: - Preference Item Model

enum PreferenceItemType {
    case toggle(key: String, defaultValue: Bool)
    case multiValue(key: String, titles: [String], values: [Any], defaultValue: Any)
    case slider(key: String, minValue: Double, maxValue: Double, defaultValue: Double, minImage: String?, maxImage: String?)
    case textField(key: String, placeholder: String, keyboardType: UIKeyboardType)
    case button(key: String, action: String)
    case staticValue(key: String, value: String)
    case link(title: String, url: String)
    case appIcon
}

struct PreferenceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    let type: PreferenceItemType
    let subtitle: String?
    let footerText: String?
    let isCritical: Bool

    init(title: String, icon: String, iconColor: Color, type: PreferenceItemType, subtitle: String? = nil, footerText: String? = nil, isCritical: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.type = type
        self.subtitle = subtitle
        self.footerText = footerText
        self.isCritical = isCritical
    }
}

// MARK: - Preferences View Model

@available(iOS 15.0, *)
class PreferencesViewModel: ObservableObject {
    @Published var sections: [PreferenceSection] = []
    @Published var hiddenKeys: Set<String> = []
    @Published var refreshTrigger = false

    weak var delegate: PreferencesViewDelegate?

    init() {
        buildSections()
        updateHiddenKeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func settingDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateHiddenKeys()
            self.refreshTrigger.toggle()
        }
    }

    func updateHiddenKeys() {
        var hidden = Set<String>()
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: "offline_allowed") {
            hidden.insert("offline_text_download")
            hidden.insert("offline_image_download")
            hidden.insert("offline_download_connection")
            hidden.insert("offline_store_limit")
        }

        if defaults.bool(forKey: "use_system_font_size") {
            hidden.insert("feed_list_font_size")
            hidden.insert("story_font_size")
        }

        // Show brightness threshold slider only when brightness override is enabled
        if !defaults.bool(forKey: "theme_auto_toggle") {
            hidden.insert("theme_auto_brightness")
        }

        // Hide infrequent stories per month when infrequent site stories is disabled
        if !defaults.bool(forKey: "show_infrequent_site_stories") {
            hidden.insert("infrequent_stories_per_month")
        }

        if !defaults.bool(forKey: "story_clustering") {
            hidden.insert("cluster_mode")
        }

        hiddenKeys = hidden
    }

    func shouldShow(key: String) -> Bool {
        !hiddenKeys.contains(key)
    }

    func buildSections() {
        sections = [
            // MARK: Story List Section
            PreferenceSection(
                title: "Story List",
                icon: "list.bullet.rectangle",
                iconColor: .blue,
                items: [
                    PreferenceItem(
                        title: "Story order",
                        icon: "arrow.up.arrow.down",
                        iconColor: .blue,
                        type: .multiValue(
                            key: "default_order",
                            titles: ["Newest first", "Oldest first"],
                            values: ["newest", "oldest"],
                            defaultValue: "newest"
                        )
                    ),
                    PreferenceItem(
                        title: "Stories in a folder",
                        icon: "folder",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "default_folder_read_filter",
                            titles: ["All stories", "Unread only"],
                            values: ["all", "unread"],
                            defaultValue: "unread"
                        )
                    ),
                    PreferenceItem(
                        title: "Stories in a site",
                        icon: "newspaper",
                        iconColor: .purple,
                        type: .multiValue(
                            key: "default_feed_read_filter",
                            titles: ["All stories", "Unread only"],
                            values: ["all", "unread"],
                            defaultValue: "all"
                        )
                    ),
                    PreferenceItem(
                        title: "Confirm mark read",
                        icon: "checkmark.circle",
                        iconColor: .green,
                        type: .multiValue(
                            key: "default_confirm_read_filter",
                            titles: ["On folders and sites", "On folders only", "Never"],
                            values: ["all", "folders", "never"],
                            defaultValue: "folders"
                        ),
                        footerText: "Mark read options are always available via long press on the mark read button."
                    ),
                    PreferenceItem(
                        title: "After mark read",
                        icon: "arrow.right.circle",
                        iconColor: .teal,
                        type: .multiValue(
                            key: "after_mark_read",
                            titles: ["Open the next site/folder", "Stay on the feeds list"],
                            values: ["next", "stay"],
                            defaultValue: "next"
                        )
                    ),
                    PreferenceItem(
                        title: "When opening a site",
                        icon: "rectangle.and.text.magnifyingglass",
                        iconColor: .indigo,
                        type: .multiValue(
                            key: "feed_opening",
                            titles: ["Open first story", "Show stories"],
                            values: ["story", "list"],
                            defaultValue: "list"
                        )
                    ),
                    PreferenceItem(
                        title: "Mark stories read",
                        icon: "scroll",
                        iconColor: .cyan,
                        type: .multiValue(
                            key: "default_mark_read_filter",
                            titles: ["On scroll or selection", "Only on selection", "After 1 second", "After 2 seconds", "After 3 seconds", "After 4 seconds", "After 5 seconds", "After 10 seconds", "After 15 seconds", "After 30 seconds", "After 45 seconds", "After 60 seconds", "Manually"],
                            values: ["scroll", "selection", "after1", "after2", "after3", "after4", "after5", "after10", "after15", "after30", "after45", "after60", "manually"],
                            defaultValue: "scroll"
                        )
                    ),
                    PreferenceItem(
                        title: "Discover sites",
                        icon: "sparkle.magnifyingglass",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "discover_display",
                            titles: ["Show with feed icons", "Show without icons", "Hidden"],
                            values: ["with_icons", "without_icons", "hidden"],
                            defaultValue: "with_icons"
                        ),
                        subtitle: "Show related feeds in the story list header"
                    ),
                    PreferenceItem(
                        title: "Cluster related stories",
                        icon: "square.stack.3d.down.right",
                        iconColor: .indigo,
                        type: .toggle(key: "story_clustering", defaultValue: true),
                        subtitle: "Show duplicate stories from other feeds beneath a story title"
                    ),
                    PreferenceItem(
                        title: "Cluster matches",
                        icon: "tag",
                        iconColor: .green,
                        type: .multiValue(
                            key: "cluster_mode",
                            titles: ["Title match only", "Title match plus related"],
                            values: ["title", "related"],
                            defaultValue: "related"
                        ),
                        subtitle: "Choose whether clusters show only duplicate titles or also related stories"
                    )
                ]
            ),

            // MARK: Story Layout Section
            PreferenceSection(
                title: "Story Layout",
                icon: "rectangle.3.group",
                iconColor: .purple,
                items: [
                    PreferenceItem(
                        title: "Story titles layout",
                        icon: "rectangle.split.3x1",
                        iconColor: .purple,
                        type: .multiValue(
                            key: "story_titles_position",
                            titles: ["Titles in list", "Titles in grid"],
                            values: ["titles_on_left", "titles_in_grid"],
                            defaultValue: "titles_on_left"
                        )
                    ),
                    PreferenceItem(
                        title: "List style",
                        icon: "list.bullet",
                        iconColor: .blue,
                        type: .multiValue(
                            key: "story_titles_style",
                            titles: ["Standard", "Experimental"],
                            values: ["standard", "experimental"],
                            defaultValue: "standard"
                        )
                    ),
                    PreferenceItem(
                        title: "Story title preview",
                        icon: "doc.text",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "story_list_preview_text_size",
                            titles: ["Title only", "Short", "Medium", "Long"],
                            values: ["title", "short", "medium", "long"],
                            defaultValue: "short"
                        )
                    ),
                    PreferenceItem(
                        title: "Preview images",
                        icon: "photo",
                        iconColor: .green,
                        type: .multiValue(
                            key: "story_list_preview_images_size",
                            titles: ["None", "Small Left", "Large Left", "Large Right", "Small Right"],
                            values: ["none", "small_left", "large_left", "large_right", "small_right"],
                            defaultValue: "large_right"
                        )
                    )
                ]
            ),

            // MARK: Feed List Section
            PreferenceSection(
                title: "Feed List",
                icon: "list.star",
                iconColor: .orange,
                items: [
                    PreferenceItem(
                        title: "Feed list order",
                        icon: "arrow.up.arrow.down.circle",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "feed_list_sort_order",
                            titles: ["Alphabetical", "Most used first"],
                            values: ["title", "usage"],
                            defaultValue: "title"
                        )
                    ),
                    PreferenceItem(
                        title: "Show feeds after being read",
                        icon: "eye",
                        iconColor: .blue,
                        type: .toggle(key: "show_feeds_after_being_read", defaultValue: false)
                    ),
                    PreferenceItem(
                        title: "When opening app",
                        icon: "app.badge",
                        iconColor: .green,
                        type: .multiValue(
                            key: "app_opening",
                            titles: ["Show feed list", "Open All Stories"],
                            values: ["feeds", "everything"],
                            defaultValue: "feeds"
                        )
                    ),
                    PreferenceItem(
                        title: "Show Infrequent Site Stories",
                        icon: "calendar.badge.clock",
                        iconColor: .teal,
                        type: .toggle(key: "show_infrequent_site_stories", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Infrequent stories per month",
                        icon: "chart.bar.doc.horizontal",
                        iconColor: .indigo,
                        type: .multiValue(
                            key: "infrequent_stories_per_month",
                            titles: ["< 5/month", "< 15/month", "< 30/month", "< 60/month", "< 90/month"],
                            values: [5, 15, 30, 60, 90],
                            defaultValue: 30
                        )
                    ),
                    PreferenceItem(
                        title: "Show Global Shared Stories",
                        icon: "globe",
                        iconColor: .purple,
                        type: .toggle(key: "show_global_shared_stories", defaultValue: true)
                    )
                ]
            ),

            // MARK: Text Size Section
            PreferenceSection(
                title: "Text Size",
                icon: "textformat.size",
                iconColor: .cyan,
                items: [
                    PreferenceItem(
                        title: "Use system size",
                        icon: "textformat",
                        iconColor: .cyan,
                        type: .toggle(key: "use_system_font_size", defaultValue: false)
                    ),
                    PreferenceItem(
                        title: "Feed and story list",
                        icon: "list.bullet.rectangle",
                        iconColor: .blue,
                        type: .multiValue(
                            key: "feed_list_font_size",
                            titles: ["Extra small", "Small", "Medium", "Large", "Extra Large"],
                            values: ["xs", "small", "medium", "large", "xl"],
                            defaultValue: "medium"
                        )
                    ),
                    PreferenceItem(
                        title: "Story detail",
                        icon: "doc.richtext",
                        iconColor: .purple,
                        type: .multiValue(
                            key: "story_font_size",
                            titles: ["Extra small", "Small", "Medium", "Large", "Extra Large"],
                            values: ["xs", "small", "medium", "large", "xl"],
                            defaultValue: "medium"
                        )
                    )
                ]
            ),

            // MARK: Theme Section
            PreferenceSection(
                title: "Theme",
                icon: "paintbrush",
                iconColor: .pink,
                items: [
                    PreferenceItem(
                        title: "Theme",
                        icon: "paintpalette",
                        iconColor: .pink,
                        type: .multiValue(
                            key: "theme_style",
                            titles: ["Auto", "Light", "Dark"],
                            values: ["auto", "light", "dark"],
                            defaultValue: "auto"
                        ),
                        subtitle: "Auto follows system appearance"
                    ),
                    PreferenceItem(
                        title: "Light appearance",
                        icon: "sun.max",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "theme_light",
                            titles: ["Normal", "Warm"],
                            values: ["light", "sepia"],
                            defaultValue: "light"
                        ),
                        subtitle: "Theme variant for light mode"
                    ),
                    PreferenceItem(
                        title: "Dark appearance",
                        icon: "moon.fill",
                        iconColor: .indigo,
                        type: .multiValue(
                            key: "theme_dark",
                            titles: ["Gray", "Black"],
                            values: ["medium", "dark"],
                            defaultValue: "dark"
                        ),
                        subtitle: "Theme variant for dark mode"
                    ),
                    PreferenceItem(
                        title: "Two-finger swipe to switch",
                        icon: "hand.draw",
                        iconColor: .purple,
                        type: .toggle(key: "theme_gesture", defaultValue: true),
                        subtitle: "Swipe up/down with two fingers to change theme"
                    )
                ]
            ),

            // MARK: App Icon Section
            PreferenceSection(
                title: "App Icon",
                icon: "app",
                iconColor: PreferencesColors.newsblurGreen,
                footerText: "Premium subscribers can choose a custom NewsBlur icon. Each flavor includes light and dark variants.",
                items: [
                    PreferenceItem(
                        title: "Choose Icon",
                        icon: "sun.max",
                        iconColor: PreferencesColors.newsblurGreen,
                        type: .appIcon,
                        subtitle: "12 color flavors with light and dark variants."
                    )
                ]
            ),

            // MARK: Brightness Override Section
            PreferenceSection(
                title: "Brightness Override",
                icon: "sun.max.trianglebadge.exclamationmark",
                iconColor: .orange,
                footerText: "Instead of following system dark/light mode, automatically switch themes based on your screen brightness level. Useful for switching themes based on ambient lighting.",
                items: [
                    PreferenceItem(
                        title: "Override system with brightness",
                        icon: "light.max",
                        iconColor: .yellow,
                        type: .toggle(key: "theme_auto_toggle", defaultValue: false),
                        subtitle: "Ignore system theme, use screen brightness instead"
                    ),
                    PreferenceItem(
                        title: "Brightness threshold",
                        icon: "slider.horizontal.3",
                        iconColor: .orange,
                        type: .slider(
                            key: "theme_auto_brightness",
                            minValue: 0,
                            maxValue: 1,
                            defaultValue: 0.5,
                            minImage: "moon.fill",
                            maxImage: "sun.max.fill"
                        ),
                        subtitle: "Dark theme below, light theme above"
                    )
                ]
            ),

            // MARK: Offline Stories Section
            PreferenceSection(
                title: "Offline Stories",
                icon: "icloud.and.arrow.down",
                iconColor: .teal,
                footerText: "More stories take more disk space, but otherwise have no noticeable effect on performance.",
                items: [
                    PreferenceItem(
                        title: "Download stories",
                        icon: "arrow.down.circle",
                        iconColor: .teal,
                        type: .toggle(key: "offline_allowed", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Download text",
                        icon: "doc.text",
                        iconColor: .blue,
                        type: .toggle(key: "offline_text_download", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Download images",
                        icon: "photo",
                        iconColor: .green,
                        type: .toggle(key: "offline_image_download", defaultValue: false)
                    ),
                    PreferenceItem(
                        title: "Download using",
                        icon: "wifi",
                        iconColor: .purple,
                        type: .multiValue(
                            key: "offline_download_connection",
                            titles: ["WiFi + Cellular", "WiFi only"],
                            values: ["cellular", "wifi"],
                            defaultValue: "cellular"
                        )
                    ),
                    PreferenceItem(
                        title: "Stories to store",
                        icon: "internaldrive",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "offline_store_limit",
                            titles: ["100 stories", "500 stories", "1,000 stories", "2,000 stories", "5,000 stories", "10,000 stories"],
                            values: [100, 500, 1000, 2000, 5000, 10000],
                            defaultValue: 1000
                        )
                    ),
                    PreferenceItem(
                        title: "Delete offline stories",
                        icon: "trash",
                        iconColor: .red,
                        type: .button(key: "offline_cache_empty_stories", action: "deleteOfflineStories")
                    )
                ]
            ),

            // MARK: Gestures Section
            PreferenceSection(
                title: "Gestures",
                icon: "hand.tap",
                iconColor: .indigo,
                items: [
                    PreferenceItem(
                        title: "Swipe feed and story titles",
                        icon: "arrow.left.arrow.right",
                        iconColor: .indigo,
                        type: .toggle(key: "enable_feed_cell_swipe", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Double tap story",
                        icon: "hand.tap",
                        iconColor: .blue,
                        type: .multiValue(
                            key: "double_tap_story",
                            titles: ["Open original story", "Show original text", "Mark as unread", "Save story", "Do nothing"],
                            values: ["open_original_story", "show_original_text", "mark_unread", "save_story", "nothing"],
                            defaultValue: "open_original_story"
                        )
                    ),
                    PreferenceItem(
                        title: "Two finger double tap",
                        icon: "hand.point.up.braille",
                        iconColor: .purple,
                        type: .multiValue(
                            key: "two_finger_double_tap",
                            titles: ["Open original story", "Show original text", "Mark as unread", "Save story", "Do nothing"],
                            values: ["open_original_story", "show_original_text", "mark_unread", "save_story", "nothing"],
                            defaultValue: "show_original_text"
                        )
                    ),
                    PreferenceItem(
                        title: "Long press feed/folder",
                        icon: "hand.raised",
                        iconColor: .orange,
                        type: .multiValue(
                            key: "long_press_feed_title",
                            titles: ["Mark read X days back...", "Mark everything read", "Do nothing"],
                            values: ["mark_read_choose_days", "mark_read_immediate", "nothing"],
                            defaultValue: "mark_read_choose_days"
                        )
                    ),
                    PreferenceItem(
                        title: "Long press story title",
                        icon: "text.line.first.and.arrowtriangle.forward",
                        iconColor: .green,
                        type: .multiValue(
                            key: "long_press_story_title",
                            titles: ["Ask", "Send to third-party", "Mark as unread", "Save story", "Train story", "Do nothing"],
                            values: ["ask", "open_send_to", "mark_unread", "save_story", "train_story", "nothing"],
                            defaultValue: "ask"
                        )
                    ),
                    PreferenceItem(
                        title: "Swipe left edge",
                        icon: "arrow.backward.to.line",
                        iconColor: .cyan,
                        type: .multiValue(
                            key: "story_detail_swipe_left_edge",
                            titles: ["Go back to story list", "Previous story"],
                            values: ["pop_to_story_list", "previous_story"],
                            defaultValue: "pop_to_story_list"
                        )
                    ),
                    PreferenceItem(
                        title: "Swipe left on feed",
                        icon: "arrow.left.to.line",
                        iconColor: .pink,
                        type: .multiValue(
                            key: "feed_swipe_left",
                            titles: ["Train intelligence", "Notifications", "Statistics"],
                            values: ["trainer", "notifications", "statistics"],
                            defaultValue: "notifications"
                        )
                    )
                ]
            ),

            // MARK: Reading Stories Section
            PreferenceSection(
                title: "Reading Stories",
                icon: "book",
                iconColor: .green,
                items: [
                    PreferenceItem(
                        title: "Scroll horizontally",
                        icon: "arrow.left.arrow.right.square",
                        iconColor: .green,
                        type: .toggle(key: "scroll_stories_horizontally", defaultValue: true),
                        subtitle: "Swipe left/right between stories"
                    ),
                    PreferenceItem(
                        title: "Show public comments",
                        icon: "bubble.left.and.bubble.right",
                        iconColor: .blue,
                        type: .toggle(key: "show_public_comments", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Default browser",
                        icon: "safari",
                        iconColor: .cyan,
                        type: .multiValue(
                            key: "story_browser",
                            titles: ["In-app browser", "In-app Safari", "Safari Reader Mode", "Safari", "Chrome", "Opera Mini", "Firefox", "Edge", "Brave"],
                            values: ["inapp", "inappsafari", "inappsafarireader", "safari", "chrome", "opera_mini", "firefox", "edge", "brave"],
                            defaultValue: "inappsafari"
                        )
                    ),
                    PreferenceItem(
                        title: "Full screen",
                        icon: "arrow.up.left.and.arrow.down.right",
                        iconColor: .purple,
                        type: .toggle(key: "story_full_screen", defaultValue: true),
                        subtitle: "Hide toolbars when reading"
                    ),
                    PreferenceItem(
                        title: "Hide status bar",
                        icon: "rectangle.topthird.inset.filled",
                        iconColor: .indigo,
                        type: .toggle(key: "story_hide_status_bar", defaultValue: true)
                    ),
                    PreferenceItem(
                        title: "Show autoscroll",
                        icon: "arrow.down.to.line.compact",
                        iconColor: .orange,
                        type: .toggle(key: "story_autoscroll", defaultValue: false)
                    ),
                    PreferenceItem(
                        title: "Show Ask AI",
                        icon: "sparkles",
                        iconColor: Color(red: 0.85, green: 0.45, blue: 0.37),
                        type: .toggle(key: "show_ask_ai", defaultValue: true)
                    )
                ]
            ),

            // MARK: App Badge Section
            PreferenceSection(
                title: "App Badge",
                icon: "app.badge",
                iconColor: .red,
                items: [
                    PreferenceItem(
                        title: "Show unread count",
                        icon: "number.circle",
                        iconColor: .red,
                        type: .multiValue(
                            key: "app_unread_badge",
                            titles: ["Off", "Unread + Focus", "Focus only"],
                            values: ["off", "unread", "focus"],
                            defaultValue: "off"
                        )
                    )
                ]
            ),

            // MARK: Custom Domain Section
            PreferenceSection(
                title: "Custom Domain",
                icon: "server.rack",
                iconColor: .gray,
                footerText: "Leave blank to use NewsBlur, or enter the URL of your self-hosted installation. Takes effect next time the app is opened.",
                items: [
                    PreferenceItem(
                        title: "Server URL",
                        icon: "link",
                        iconColor: .gray,
                        type: .textField(key: "custom_domain", placeholder: "https://www.domain.com", keyboardType: .URL)
                    )
                ]
            ),

            // MARK: Import & Export Section
            PreferenceSection(
                title: "Import & Export",
                icon: "square.and.arrow.up.on.square",
                iconColor: .blue,
                items: [
                    PreferenceItem(
                        title: "Import Preferences",
                        icon: "square.and.arrow.down",
                        iconColor: .blue,
                        type: .button(key: "import_prefs", action: "importPreferences")
                    ),
                    PreferenceItem(
                        title: "Export Preferences",
                        icon: "square.and.arrow.up",
                        iconColor: .green,
                        type: .button(key: "export_prefs", action: "exportPreferences")
                    )
                ]
            ),

            // MARK: About Section
            PreferenceSection(
                title: "About NewsBlur",
                icon: "info.circle",
                iconColor: .gray,
                items: [
                    PreferenceItem(
                        title: "Version",
                        icon: "number",
                        iconColor: .gray,
                        type: .staticValue(key: "version", value: getAppVersion())
                    ),
                    PreferenceItem(
                        title: "Copyright",
                        icon: "c.circle",
                        iconColor: .gray,
                        type: .staticValue(key: "copyright", value: "NewsBlur, Inc.")
                    ),
                    PreferenceItem(
                        title: "Privacy Policy",
                        icon: "hand.raised",
                        iconColor: .blue,
                        type: .link(title: "Privacy Policy", url: "https://www.newsblur.com/privacy")
                    ),
                    PreferenceItem(
                        title: "Terms of Use",
                        icon: "doc.text",
                        iconColor: .purple,
                        type: .link(title: "Terms of Use", url: "https://www.newsblur.com/tos")
                    )
                ]
            ),

            // MARK: Account Section
            PreferenceSection(
                title: "Account",
                icon: "person.circle",
                iconColor: .red,
                items: [
                    PreferenceItem(
                        title: "Delete Account",
                        icon: "trash",
                        iconColor: .red,
                        type: .button(key: "delete_account", action: "deleteAccount"),
                        isCritical: true
                    )
                ]
            )
        ]
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(version) (\(build))"
    }

    func handleButtonAction(_ action: String, key: String) {
        delegate?.preferencesButtonTapped(key: key, action: action)
    }

    func valueChanged(key: String, value: Any) {
        delegate?.preferenceValueChanged(key: key, value: value)
    }
}

// MARK: - Preferences View Delegate

@objc protocol PreferencesViewDelegate: AnyObject {
    func preferencesButtonTapped(key: String, action: String)
    func preferenceValueChanged(key: String, value: Any)
    func preferencesDidDismiss()
}

// MARK: - Preferences View

@available(iOS 15.0, *)
struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    var onDismiss: () -> Void

    @State private var expandedSections: Set<String> = []

    init(viewModel: PreferencesViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        // Initially expand all sections
        _expandedSections = State(initialValue: Set(viewModel.sections.map { $0.title }))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Spacer()
                Text("Preferences")
                    .font(.headline)
                    .foregroundColor(PreferencesColors.textPrimary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button("Done") {
                    onDismiss()
                }
                .font(.body.bold())
                .foregroundColor(PreferencesColors.newsblurGreen)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            .background(PreferencesColors.cardBackground)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.sections) { section in
                        PreferenceSectionView(
                            section: section,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(PreferencesColors.background.ignoresSafeArea())
        .onAppear {
            // Refresh state when view appears
            viewModel.updateHiddenKeys()
        }
    }
}

// MARK: - Section View

@available(iOS 15.0, *)
struct PreferenceSectionView: View {
    let section: PreferenceSection
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Section Header - Standalone, outside the card
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(section.iconColor)

                Text(section.title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(PreferencesColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .padding(.top, 4)

            // Card containing items
            VStack(spacing: 0) {
                // Section Items
                let visibleItems = section.items.filter { item in
                    if case .toggle(let key, _) = item.type {
                        return viewModel.shouldShow(key: key)
                    } else if case .multiValue(let key, _, _, _) = item.type {
                        return viewModel.shouldShow(key: key)
                    } else if case .slider(let key, _, _, _, _, _) = item.type {
                        return viewModel.shouldShow(key: key)
                    }
                    return true
                }

                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    PreferenceItemView(item: item, viewModel: viewModel)

                    if index < visibleItems.count - 1 {
                        Divider()
                            .background(PreferencesColors.border.opacity(0.5))
                            .padding(.leading, 56)
                    }
                }

                // Footer
                if let footer = section.footerText {
                    Text(footer)
                        .font(.system(size: 12))
                        .foregroundColor(PreferencesColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PreferencesColors.secondaryBackground.opacity(0.5))
                }
            }
            .background(PreferencesColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }
}

// MARK: - Shared Icon View

@available(iOS 15.0, *)
struct PreferenceIconView: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 28, height: 28)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Cluster Mode Preview

@available(iOS 15.0, *)
struct ClusterTierPillView: View {
    let label: String
    let tier: String
    var compact: Bool = false

    private var tierColor: Color {
        tier == "title" ? PreferencesColors.clusterMatch : PreferencesColors.clusterRelated
    }

    private var horizontalPadding: CGFloat { compact ? 6 : 8 }
    private var verticalPadding: CGFloat { compact ? 2 : 3 }
    private var fontSize: CGFloat { compact ? 9 : 10 }

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(tierColor)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .overlay(
                Capsule()
                    .stroke(tierColor, lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: true)
    }
}

@available(iOS 15.0, *)
struct ClusterModePreviewView: View {
    let mode: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ClusterTierPillView(label: "Match", tier: "title", compact: compact)

            if mode != "title" {
                Text("+")
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundColor(PreferencesColors.textSecondary)
                ClusterTierPillView(label: "Related", tier: "related", compact: compact)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

@available(iOS 15.0, *)
struct ClusterSettingStateView: View {
    let isEnabled: Bool
    let mode: String

    private var stateTitle: String {
        if !isEnabled {
            return "Title only"
        }

        return mode == "title" ? "Title match only" : "Title match plus related"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stateTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PreferencesColors.textSecondary)

            if isEnabled {
                ClusterModePreviewView(mode: mode, compact: true)
            }
        }
        .padding(.top, 2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Item View

@available(iOS 15.0, *)
struct PreferenceItemView: View {
    let item: PreferenceItem
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch item.type {
            case .toggle(let key, let defaultValue):
                ToggleItemView(item: item, key: key, defaultValue: defaultValue, viewModel: viewModel)

            case .multiValue(let key, let titles, let values, let defaultValue):
                MultiValueItemView(item: item, key: key, titles: titles, values: values, defaultValue: defaultValue, viewModel: viewModel)

            case .slider(let key, let minValue, let maxValue, let defaultValue, let minImage, let maxImage):
                SliderItemView(item: item, key: key, minValue: minValue, maxValue: maxValue, defaultValue: defaultValue, minImage: minImage, maxImage: maxImage, viewModel: viewModel)

            case .textField(let key, let placeholder, let keyboardType):
                TextFieldItemView(item: item, key: key, placeholder: placeholder, keyboardType: keyboardType, viewModel: viewModel)

            case .button(let key, let action):
                ButtonItemView(item: item, key: key, action: action, viewModel: viewModel)

            case .staticValue(_, let value):
                StaticValueItemView(item: item, value: value)

            case .link(_, let url):
                LinkItemView(item: item, url: url)

            case .appIcon:
                AppIconPreferenceItemView(item: item, viewModel: viewModel)
            }

            // Footer text for individual items (indented to align with content)
            if let footerText = item.footerText {
                Text(footerText)
                    .font(.system(size: 11))
                    .foregroundColor(PreferencesColors.textSecondary)
                    .padding(.leading, 54) // Indent to align with text after icon
                    .padding(.trailing, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
            }
        }
        .background(PreferencesColors.cardBackground)
    }
}

// MARK: - Toggle Item View

@available(iOS 15.0, *)
struct ToggleItemView: View {
    let item: PreferenceItem
    let key: String
    let defaultValue: Bool
    @ObservedObject var viewModel: PreferencesViewModel

    @AppStorage private var isOn: Bool
    @AppStorage("cluster_mode") private var clusterMode = "related"

    init(item: PreferenceItem, key: String, defaultValue: Bool, viewModel: PreferencesViewModel) {
        self.item = item
        self.key = key
        self.defaultValue = defaultValue
        self.viewModel = viewModel
        self._isOn = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        HStack(spacing: 12) {
            PreferenceIconView(icon: item.icon, color: item.iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PreferencesColors.textPrimary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(PreferencesColors.textSecondary)
                        .lineLimit(2)
                }

                if key == "story_clustering" {
                    ClusterSettingStateView(isEnabled: isOn, mode: clusterMode)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(PreferencesColors.newsblurGreen)
                .onChange(of: isOn) { newValue in
                    viewModel.valueChanged(key: key, value: newValue)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Multi Value Item View

@available(iOS 15.0, *)
struct MultiValueItemView: View {
    let item: PreferenceItem
    let key: String
    let titles: [String]
    let values: [Any]
    let defaultValue: Any
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var selectedIndex: Int = 0
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            if key == "cluster_mode" {
                clusterModeRow
            } else {
                standardRow
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadCurrentValue()
        }
        .sheet(isPresented: $showPicker) {
            PickerSheet(
                key: key,
                title: item.title,
                titles: titles,
                values: values,
                selectedIndex: $selectedIndex,
                onSelect: { index in
                    selectedIndex = index
                    saveValue(at: index)
                    showPicker = false
                }
            )
        }
    }

    private var currentTitle: String {
        if selectedIndex >= 0 && selectedIndex < titles.count {
            return titles[selectedIndex]
        }
        return titles.first ?? ""
    }

    private var currentValue: String {
        if selectedIndex >= 0 && selectedIndex < values.count {
            return "\(values[selectedIndex])"
        }

        return "\(defaultValue)"
    }

    private var standardRow: some View {
        HStack(spacing: 12) {
            PreferenceIconView(icon: item.icon, color: item.iconColor)

            VStack(alignment: .leading, spacing: 2) {
                titleText

                if let subtitle = item.subtitle {
                    subtitleText(subtitle)
                }
            }

            Spacer()

            Text(currentTitle)
                .font(.system(size: 14))
                .foregroundColor(PreferencesColors.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PreferencesColors.textSecondary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var clusterModeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            PreferenceIconView(icon: item.icon, color: item.iconColor)

            VStack(alignment: .leading, spacing: 6) {
                titleText
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    subtitleText(subtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currentTitle)
                            .font(.system(size: 14))
                            .foregroundColor(PreferencesColors.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        ClusterModePreviewView(mode: currentValue, compact: true)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PreferencesColors.textSecondary.opacity(0.4))
                .padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var titleText: some View {
        Text(item.title)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(PreferencesColors.textPrimary)
    }

    private func subtitleText(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(.system(size: 12))
            .foregroundColor(PreferencesColors.textSecondary)
            .lineLimit(2)
    }

    private func loadCurrentValue() {
        let defaults = UserDefaults.standard

        if let storedValue = defaults.object(forKey: key) {
            let storedString = "\(storedValue)"
            for (index, value) in values.enumerated() {
                if "\(value)" == storedString {
                    selectedIndex = index
                    return
                }
            }
        }

        // Use default
        let defaultString = "\(defaultValue)"
        for (index, value) in values.enumerated() {
            if "\(value)" == defaultString {
                selectedIndex = index
                return
            }
        }
        selectedIndex = 0
    }

    private func saveValue(at index: Int) {
        guard index >= 0 && index < values.count else { return }
        let value = values[index]

        if let intValue = value as? Int {
            UserDefaults.standard.set(intValue, forKey: key)
        } else if let stringValue = value as? String {
            UserDefaults.standard.set(stringValue, forKey: key)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }

        viewModel.valueChanged(key: key, value: value)
    }
}

// MARK: - Picker Sheet

@available(iOS 15.0, *)
struct PickerSheet: View {
    let key: String
    let title: String
    let titles: [String]
    let values: [Any]
    @Binding var selectedIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Spacer()
                Text(title)
                    .font(.headline)
                    .foregroundColor(PreferencesColors.textPrimary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.body.bold())
                .foregroundColor(PreferencesColors.newsblurGreen)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            .background(PreferencesColors.cardBackground)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(0..<titles.count, id: \.self) { index in
                        Button(action: { onSelect(index) }) {
                            HStack {
                                if key == "cluster_mode" {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(titles[index])
                                            .foregroundColor(PreferencesColors.textPrimary)
                                        ClusterModePreviewView(mode: "\(values[index])")
                                    }
                                } else {
                                    Text(titles[index])
                                        .foregroundColor(PreferencesColors.textPrimary)
                                }

                                Spacer()

                                if index == selectedIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(PreferencesColors.newsblurGreen)
                                        .font(.body.bold())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(PreferencesColors.cardBackground)
                        }
                    }
                }
                .cornerRadius(12)
                .padding(16)
            }
        }
        .background(PreferencesColors.background.ignoresSafeArea())
    }
}

// MARK: - Slider Item View

@available(iOS 15.0, *)
struct SliderItemView: View {
    let item: PreferenceItem
    let key: String
    let minValue: Double
    let maxValue: Double
    let defaultValue: Double
    let minImage: String?
    let maxImage: String?
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var value: Double = 0.5

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                PreferenceIconView(icon: item.icon, color: item.iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PreferencesColors.textPrimary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(PreferencesColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            HStack(spacing: 12) {
                if let minImg = minImage {
                    Image(systemName: minImg)
                        .font(.system(size: 14))
                        .foregroundColor(PreferencesColors.textSecondary)
                }

                Slider(value: $value, in: minValue...maxValue)
                    .tint(PreferencesColors.newsblurGreen)
                    .onChange(of: value) { newValue in
                        UserDefaults.standard.set(newValue, forKey: key)
                        viewModel.valueChanged(key: key, value: newValue)
                    }

                if let maxImg = maxImage {
                    Image(systemName: maxImg)
                        .font(.system(size: 14))
                        .foregroundColor(PreferencesColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .onAppear {
            value = UserDefaults.standard.double(forKey: key)
            if value == 0 && defaultValue != 0 {
                value = defaultValue
            }
        }
    }
}

// MARK: - Text Field Item View

@available(iOS 15.0, *)
struct TextFieldItemView: View {
    let item: PreferenceItem
    let key: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 12) {
            PreferenceIconView(icon: item.icon, color: item.iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PreferencesColors.textPrimary)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(PreferencesColors.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PreferencesColors.secondaryBackground)
                    .cornerRadius(8)
                    .onChange(of: text) { newValue in
                        UserDefaults.standard.set(newValue, forKey: key)
                        viewModel.valueChanged(key: key, value: newValue)
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            text = UserDefaults.standard.string(forKey: key) ?? ""
        }
    }
}

// MARK: - Button Item View

@available(iOS 15.0, *)
struct ButtonItemView: View {
    let item: PreferenceItem
    let key: String
    let action: String
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var buttonLabel: String = ""

    var body: some View {
        Button(action: {
            viewModel.handleButtonAction(action, key: key)
        }) {
            HStack(spacing: 12) {
                PreferenceIconView(icon: item.icon, color: item.iconColor)

                Text(buttonLabel.isEmpty ? item.title : buttonLabel)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(item.isCritical ? PreferencesColors.destructive : PreferencesColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Check for dynamic button label
            if let label = UserDefaults.standard.string(forKey: key), !label.isEmpty {
                buttonLabel = label
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            if let label = UserDefaults.standard.string(forKey: key), !label.isEmpty {
                buttonLabel = label
            } else {
                buttonLabel = ""
            }
        }
    }
}

// MARK: - Static Value Item View

@available(iOS 15.0, *)
struct StaticValueItemView: View {
    let item: PreferenceItem
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            PreferenceIconView(icon: item.icon, color: item.iconColor)

            Text(item.title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PreferencesColors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(PreferencesColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Link Item View

@available(iOS 15.0, *)
struct LinkItemView: View {
    let item: PreferenceItem
    let url: String

    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                PreferenceIconView(icon: item.icon, color: item.iconColor)

                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PreferencesColors.newsblurBlue)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PreferencesColors.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Icon Item View

@available(iOS 15.0, *)
struct AppIconPreferenceItemView: View {
    let item: PreferenceItem
    @ObservedObject var viewModel: PreferencesViewModel

    @Environment(\.colorScheme) private var colorScheme
    @State private var showChooser = false
    @State private var currentGroup = NewsBlurAppIconLibrary.currentSelection.group
    @State private var currentMode = NewsBlurAppIconLibrary.currentSelection.mode

    private var isPremium: Bool {
        NewsBlurAppIconLibrary.canChooseIcons
    }

    private var rowValue: String {
        if !NewsBlurAppIconLibrary.supportsIconSelection {
            return "Unavailable"
        }

        return isPremium ? currentGroup.title : "Premium"
    }

    private var rowPreviewOption: NewsBlurAppIconOption {
        NewsBlurAppIconLibrary.displayOption(for: currentGroup, mode: currentMode, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: openChooser) {
            HStack(spacing: 12) {
                AppIconPreviewImage(option: rowPreviewOption, size: 42, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PreferencesColors.textPrimary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(PreferencesColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if !isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(PreferencesColors.textSecondary.opacity(0.7))
                    }

                    Text(rowValue)
                        .font(.system(size: 14))
                        .foregroundColor(PreferencesColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PreferencesColors.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            syncCurrentSelection()
        }
        .sheet(isPresented: $showChooser, onDismiss: syncCurrentSelection) {
            AppIconChooserView(currentGroup: $currentGroup, currentMode: $currentMode)
        }
    }

    private func openChooser() {
        guard NewsBlurAppIconLibrary.supportsIconSelection else { return }

        if isPremium {
            syncCurrentSelection()
            showChooser = true
        } else {
            viewModel.handleButtonAction("showPremium", key: "app_icon")
        }
    }

    /// Re-reads the live flavor + appearance mode so the row preview stays in sync.
    private func syncCurrentSelection() {
        let selection = NewsBlurAppIconLibrary.currentSelection
        currentGroup = selection.group
        currentMode = selection.mode
    }
}

// MARK: - App Icon Chooser

@available(iOS 15.0, *)
private struct AppIconChooserView: View {
    @Binding var currentGroup: NewsBlurAppIconFlavorGroup
    @Binding var currentMode: NewsBlurAppIconAppearanceMode

    @Environment(\.dismiss) private var dismiss
    @State private var isChangingIcon = false
    @State private var pendingGroup = NewsBlurAppIconLibrary.currentSelection.group
    @State private var pendingMode = NewsBlurAppIconLibrary.currentSelection.mode
    @State private var errorMessage: String?

    private let flavorColumns = [
        GridItem(.flexible(minimum: 132), spacing: 12),
        GridItem(.flexible(minimum: 132), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        AppIconAppearancePicker(mode: $pendingMode, isChangingIcon: isChangingIcon)
                            .id("appearance-picker")

                        if pendingMode == .auto {
                            ForEach(NewsBlurAppIconLibrary.groups) { group in
                                AppIconFlavorSection(
                                    group: group,
                                    isSelected: group.id == pendingGroup.id,
                                    isChangingIcon: isChangingIcon,
                                    onSelect: { select(group) }
                                )
                                .id(group.id)
                            }
                        } else {
                            let appearance = pendingMode.pinnedAppearance ?? "Light"
                            LazyVGrid(columns: flavorColumns, spacing: 12) {
                                ForEach(NewsBlurAppIconLibrary.groups) { group in
                                    AppIconOptionCard(
                                        option: group.option(forAppearance: appearance),
                                        displayTitle: group.title,
                                        appearanceTag: nil,
                                        isSelected: group.id == pendingGroup.id,
                                        isChangingIcon: isChangingIcon,
                                        onSelect: { select(group) }
                                    )
                                    .id(group.id)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(PreferencesColors.destructive)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("appearance-picker", anchor: .top)
                    }
                }
            }
        }
        .background(PreferencesColors.background.ignoresSafeArea())
        .interactiveDismissDisabled(isChangingIcon)
        .onAppear {
            let selection = NewsBlurAppIconLibrary.currentSelection
            currentGroup = selection.group
            currentMode = selection.mode
            pendingGroup = selection.group
            pendingMode = selection.mode
        }
    }

    private var header: some View {
        ZStack {
            Text("App Icon")
                .font(.headline)
                .foregroundColor(PreferencesColors.textPrimary)

            HStack {
                Spacer()

                if isChangingIcon {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 64, height: 36, alignment: .trailing)
                } else {
                    Text("Done")
                        .font(.body.bold())
                        .foregroundColor(PreferencesColors.newsblurGreen)
                        .frame(width: 64, height: 36, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            applyPendingSelection()
                        }
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PreferencesColors.cardBackground)
    }

    private func select(_ group: NewsBlurAppIconFlavorGroup) {
        guard !isChangingIcon else { return }
        guard pendingGroup.id != group.id else { return }

        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            pendingGroup = group
        }
    }

    private func applyPendingSelection() {
        guard !isChangingIcon else { return }

        guard pendingGroup.id != currentGroup.id || pendingMode != currentMode else {
            dismiss()
            return
        }

        errorMessage = nil
        isChangingIcon = true

        NewsBlurAppIconLibrary.apply(group: pendingGroup, mode: pendingMode) { error in
            DispatchQueue.main.async {
                isChangingIcon = false

                if let error {
                    if NewsBlurAppIconLibrary.shouldIgnoreSimulatorIconChangeError(error) {
                        errorMessage = "The iOS simulator could not change the Home Screen icon. Try this on a device."
                        return
                    }

                    errorMessage = error.localizedDescription
                    return
                }

                withAnimation(.easeInOut(duration: 0.18)) {
                    currentGroup = pendingGroup
                    currentMode = pendingMode
                }
                dismiss()
            }
        }
    }
}

// MARK: - Appearance Mode Picker

@available(iOS 15.0, *)
private struct AppIconAppearancePicker: View {
    @Binding var mode: NewsBlurAppIconAppearanceMode
    let isChangingIcon: Bool

    @Namespace private var thumbNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(NewsBlurAppIconAppearanceMode.allCases) { option in
                    segment(for: option)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PreferencesColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PreferencesColors.border.opacity(0.35), lineWidth: 1)
            )

            Text(mode.caption)
                .font(.system(size: 12))
                .foregroundColor(PreferencesColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                .padding(.horizontal, 4)
                .id(mode)
                .transition(.opacity)
        }
    }

    private func segment(for option: NewsBlurAppIconAppearanceMode) -> some View {
        let isSelected = option == mode

        return Button {
            guard !isChangingIcon, option != mode else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                mode = option
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 11, weight: .bold))
                Text(option.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : PreferencesColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(PreferencesColors.newsblurGreen)
                            .matchedGeometryEffect(id: "thumb", in: thumbNamespace)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isChangingIcon)
    }
}

// MARK: - Icon Cards

@available(iOS 15.0, *)
private struct AppIconCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

@available(iOS 15.0, *)
private struct AppIconFlavorSection: View {
    let group: NewsBlurAppIconFlavorGroup
    let isSelected: Bool
    let isChangingIcon: Bool
    let onSelect: () -> Void

    private let columns = [
        GridItem(.flexible(minimum: 132), spacing: 12),
        GridItem(.flexible(minimum: 132), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(group.title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? PreferencesColors.newsblurGreen : PreferencesColors.textSecondary)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(PreferencesColors.newsblurGreen)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.86)
                    .accessibilityHidden(!isSelected)

                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(group.options) { option in
                    AppIconOptionCard(
                        option: option,
                        displayTitle: option.title,
                        appearanceTag: option.appearance,
                        isSelected: false,
                        isChangingIcon: isChangingIcon,
                        onSelect: onSelect
                    )
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? PreferencesColors.newsblurGreen.opacity(0.08) : Color.clear)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? PreferencesColors.newsblurGreen : Color.clear, lineWidth: 2)
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
    }
}

@available(iOS 15.0, *)
private struct AppIconOptionCard: View {
    let option: NewsBlurAppIconOption
    let displayTitle: String
    let appearanceTag: String?
    let isSelected: Bool
    let isChangingIcon: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    AppIconPreviewImage(option: option, size: 76, cornerRadius: 18)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PreferencesColors.newsblurGreen)
                            .background(Circle().fill(PreferencesColors.cardBackground).padding(1))
                            .offset(x: 7, y: -7)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(spacing: 3) {
                    Text(displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PreferencesColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if let appearanceTag {
                        Text(appearanceTag.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(option.tintColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(option.tintColor.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                .frame(minHeight: appearanceTag == nil ? 20 : 42)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(PreferencesColors.cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? PreferencesColors.newsblurGreen : PreferencesColors.border.opacity(0.35),
                            lineWidth: isSelected ? 2 : 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(AppIconCardButtonStyle())
        .disabled(isChangingIcon)
    }
}

@available(iOS 15.0, *)
private struct AppIconPreviewImage: View {
    let option: NewsBlurAppIconOption
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image(option.previewAssetName)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
    }
}

// MARK: - UIKit Hosting Controller

@available(iOS 15.0, *)
@objc class PreferencesViewHostingController: UIViewController {
    private var viewModel: PreferencesViewModel!
    private var hostingController: UIViewController?
    @objc weak var delegate: PreferencesViewDelegate?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupViewModel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewModel()
    }

    private func setupViewModel() {
        viewModel = PreferencesViewModel()
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }

    private func setupHostingController() {
        let preferencesView = PreferencesView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.delegate?.preferencesDidDismiss()
            }
        )

        let hosting = UIHostingController(rootView: preferencesView)
        hostingController = hosting

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hosting.didMove(toParent: self)
    }

    @objc func configureDelegate(_ newDelegate: PreferencesViewDelegate?) {
        self.delegate = newDelegate
        viewModel.delegate = newDelegate
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.updateHiddenKeys()
    }
}
