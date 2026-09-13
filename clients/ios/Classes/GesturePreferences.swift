import Foundation

// GesturePreferences.swift keeps feed and story swipe choices independent, including upgrades from the shared toggle.
@objc final class GesturePreferences: NSObject {
    static let feedActions = ["read", "trainer", "notifications", "statistics"]
    static let feedActionTitles = ["Mark all stories read", "Train intelligence", "Notifications", "Statistics"]

    @objc static var feedsEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "enable_feed_swipes") == nil || defaults.bool(forKey: "enable_feed_swipes")
    }

    @objc static var storiesEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "enable_story_swipes") == nil || defaults.bool(forKey: "enable_story_swipes")
    }

    @objc static var feedLeftAction: String { feedAction(right: false) }
    @objc static var feedRightAction: String { feedAction(right: true) }

    private static func feedAction(right: Bool) -> String {
        let fallback = right ? "notifications" : "read"
        let value = UserDefaults.standard.string(forKey: right ? "feed_title_swipe_right" : "feed_title_swipe_left") ?? fallback
        return feedActions.contains(value) ? value : fallback
    }

    @objc static func feedIcon(action: String, social: Bool) -> String {
        if action == "read" { return "indicator-unread" }
        if social { return "menu_icn_fetch_subscribers.png" }
        switch action {
        case "notifications": return "menu_icn_notifications.png"
        case "statistics": return "menu_icn_statistics.png"
        default: return "train.png"
        }
    }

    @objc static func migrateLegacyPreferences() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        migrateLegacyPreferences(in: .standard, domain: domain)
    }

    static func migrateLegacyPreferences(in defaults: UserDefaults, domain: String) {
        let saved = defaults.persistentDomain(forName: domain) ?? [:]
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        func explicit(_ key: String) -> Any? { arguments[key] ?? saved[key] }

        if let enabled = explicit("enable_feed_cell_swipe") as? Bool {
            for key in ["enable_feed_swipes", "enable_story_swipes"] where explicit(key) == nil {
                defaults.set(enabled, forKey: key)
            }
        }
        // GesturePreferences.swift preserves the legacy setting's actual rightward gesture despite its old name.
        if explicit("feed_title_swipe_right") == nil,
           let action = explicit("feed_swipe_left") as? String {
            defaults.set(feedActions.contains(action) ? action : "trainer", forKey: "feed_title_swipe_right")
        }
        defaults.removeObject(forKey: "enable_feed_cell_swipe")
        defaults.removeObject(forKey: "feed_swipe_left")
    }
}
