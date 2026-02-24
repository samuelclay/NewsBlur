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
                        title: "Site-specific mark read",
                        icon: "hand.raised",
                        iconColor: .yellow,
                        type: .toggle(key: "override_mark_read_filter", defaultValue: true),
                        subtitle: "Allow per-site/folder mark read settings"
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

    @State private var selectedValue: String = ""
    @State private var selectedIndex: Int = 0
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
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
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadCurrentValue()
        }
        .sheet(isPresented: $showPicker) {
            PickerSheet(
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
                                Text(titles[index])
                                    .foregroundColor(PreferencesColors.textPrimary)

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
