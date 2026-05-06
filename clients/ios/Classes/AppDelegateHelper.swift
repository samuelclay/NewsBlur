//
//  AppDelegateHelper.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-07-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import UIKit

/// Singleton class to provide Swift functions to the app delegate. Can't make `NewsBlurAppDelegate` Swift code, or inherit from Swift code, due to circular references.
class AppDelegateHelper: NSObject {
    /// Singleton shared instance.
    @MainActor @objc static let shared = AppDelegateHelper()

    /// Private init to prevent others constructing a new instance.
    private override init() {
    }

    /// Called at launch with the running build's `CFBundleVersion`. Reads the
    /// *previously* stored release, runs any pending one-time migrations, then
    /// overwrites the stored release with the current one.
    @objc func applyReleaseUpgrade(currentRelease: Int, defaults: UserDefaults) {
        let previousRelease = defaults.integer(forKey: "release")
        upgradeSettings(from: previousRelease)
        defaults.set(currentRelease, forKey: "release")
    }

    /// Convenience overload that uses `.standard` defaults.
    @objc func applyReleaseUpgrade(currentRelease: Int) {
        applyReleaseUpgrade(currentRelease: currentRelease, defaults: .standard)
    }

    @objc func upgradeSettings(from release: Int) {
        if release < 154 {
            upgradeFeedScrollSettings()
        }
    }

    /// Migrates the legacy boolean `default_scroll_read_filter` preference
    /// (iOS 13.x and early 14.x) into the string `default_mark_read_filter`.
    /// Only runs when the old key was explicitly set by the user and the new
    /// key has not yet been written. `persistentDomain(forName:)` excludes
    /// registered defaults from Settings.bundle, so a fresh install keeps the
    /// `scroll` default instead of being forced to `selection`.
    func upgradeFeedScrollSettings() {
        let settings = UserDefaults.standard
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let userValues = settings.persistentDomain(forName: bundleID) ?? [:]

        guard userValues["default_scroll_read_filter"] != nil,
              userValues["default_mark_read_filter"] == nil else {
            return
        }

        let isScroll = settings.bool(forKey: "default_scroll_read_filter")
        settings.set(isScroll ? "scroll" : "selection", forKey: "default_mark_read_filter")
    }
}
