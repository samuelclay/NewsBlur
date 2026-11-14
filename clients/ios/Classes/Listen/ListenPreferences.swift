//
//  ListenPreferences.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// How the voice reads: a preset, or custom ElevenLabs voice settings (ListenPreferences.swift).
struct ListenDeliverySettings: Equatable {
    var delivery: String
    var stability: Double
    var similarity: Double
    var style: Double
    var speakerBoost: Bool

    static let presetIds = ["steady", "natural", "expressive"]

    var isCustom: Bool { delivery == "custom" }

    /// The overrides POST /listen/preview accepts so a voice can be auditioned before it's saved.
    var previewParameters: [String: String] {
        var parameters = ["delivery": delivery]
        if isCustom {
            parameters["stability"] = ListenPreferences.numberString(stability)
            parameters["similarity"] = ListenPreferences.numberString(similarity)
            parameters["style"] = ListenPreferences.numberString(style)
            parameters["speaker_boost"] = speakerBoost ? "true" : "false"
        }
        return parameters
    }
}

/// ListenPreferences.swift keeps the Listen and story button preferences that sync across platforms through the
/// server's Profile.preferences. Values live in NSUserDefaults (so PreferencesView.swift can bind to them) and every
/// change is written back with POST /profile/set_preference.
@objcMembers final class ListenPreferences: NSObject {
    static let didChange = Notification.Name("ListenPreferencesDidChange")

    static let voicesKey = "listen_voices"
    static let deliveryKey = "listen_delivery"
    static let stabilityKey = "listen_stability"
    static let similarityKey = "listen_similarity"
    static let styleKey = "listen_style"
    static let speakerBoostKey = "listen_speaker_boost"
    static let speedKey = "listen_speed"
    static let autoContinueKey = "listen_auto_continue"
    static let highlightKey = "listen_highlight"

    /// The story buttons in reading order, with the NSUserDefaults key each uses. Ask AI keeps its original
    /// show_ask_ai key, which FontSettingsViewController.m and RowActionMenus.swift already read.
    static let storyButtons: [(name: String, localKey: String)] = [
        ("train", "show_sideoption_train"),
        ("share", "show_sideoption_share"),
        ("save", "show_sideoption_save"),
        ("ask_ai", "show_ask_ai"),
        ("listen", "show_sideoption_listen")
    ]

    private static let listenKeys = [voicesKey, deliveryKey, stabilityKey, similarityKey, styleKey, speakerBoostKey,
                                     speedKey, autoContinueKey, highlightKey]
    private static let askAIMigrationKey = "listen_migrated_show_ask_ai"

    private static var defaults: UserDefaults { .standard }

    /// Stores `value` only when it differs from what's saved and says whether it did. Every write posts
    /// UserDefaults.didChangeNotification, which redraws all of Preferences (PreferencesView.swift), so unchanged
    /// values from a sync or a repeated tap aren't written again.
    @discardableResult
    private static func store(_ value: Any, forKey key: String) -> Bool {
        if let current = defaults.object(forKey: key) as? NSObject, let new = value as? NSObject, current.isEqual(new) {
            return false
        }
        defaults.set(value, forKey: key)
        return true
    }

    // MARK: - Story buttons

    /// Whether the story button named train, share, save, ask_ai or listen is shown.
    static func showsStoryButton(_ name: String) -> Bool {
        guard let key = storyButtons.first(where: { $0.name == name })?.localKey else { return true }
        return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }

    static func serverKey(forLocalKey key: String) -> String {
        key == "show_ask_ai" ? "show_sideoption_ask_ai" : key
    }

    static func isStoryButtonKey(_ key: String) -> Bool {
        storyButtons.contains { $0.localKey == key }
    }

    /// Whether NSUserDefaults key is one of the synced Listen or story button preferences.
    static func isSyncedKey(_ key: String) -> Bool {
        listenKeys.contains(key) || isStoryButtonKey(key)
    }

    // MARK: - Listen values

    static var voices: [String: String] {
        let object = ListenJSON.objectFromString(defaults.object(forKey: voicesKey)) ?? [:]
        return object.compactMapValues { ListenJSON.string($0) }
    }

    static func voiceId(forLanguage language: String) -> String? {
        voices[language]
    }

    static var deliverySettings: ListenDeliverySettings {
        let delivery = defaults.string(forKey: deliveryKey) ?? "natural"
        return ListenDeliverySettings(
            delivery: (presetIdsWithCustom.contains(delivery) ? delivery : "natural"),
            stability: clamp(ListenJSON.double(defaults.object(forKey: stabilityKey)) ?? 0.5),
            similarity: clamp(ListenJSON.double(defaults.object(forKey: similarityKey)) ?? 0.75),
            style: clamp(ListenJSON.double(defaults.object(forKey: styleKey)) ?? 0),
            speakerBoost: ListenJSON.bool(defaults.object(forKey: speakerBoostKey)) ?? true)
    }

    static var speed: Double {
        let value = ListenJSON.double(defaults.object(forKey: speedKey)) ?? 1
        return min(3, max(0.5, value))
    }

    static var autoContinue: Bool {
        ListenJSON.bool(defaults.object(forKey: autoContinueKey)) ?? true
    }

    static var highlight: Bool {
        ListenJSON.bool(defaults.object(forKey: highlightKey)) ?? true
    }

    private static let presetIdsWithCustom = ListenDeliverySettings.presetIds + ["custom"]

    // MARK: - Writing

    static func setVoice(_ voiceId: String, forLanguage language: String, completion: ((Bool) -> Void)? = nil) {
        var voices = self.voices
        voices[language] = voiceId
        let data = (try? JSONSerialization.data(withJSONObject: voices, options: [.sortedKeys])) ?? Data("{}".utf8)
        save([voicesKey: String(decoding: data, as: UTF8.self)], completion: completion)
    }

    static func setDelivery(_ settings: ListenDeliverySettings, completion: ((Bool) -> Void)? = nil) {
        var values: [String: Any] = [deliveryKey: settings.delivery]
        if settings.isCustom {
            values[stabilityKey] = settings.stability
            values[similarityKey] = settings.similarity
            values[styleKey] = settings.style
            values[speakerBoostKey] = settings.speakerBoost
        }
        save(values, completion: completion)
    }

    private static var speedSave: DispatchWorkItem?

    /// Stores the speed at once and sends it after a pause, so dragging the slider saves only where it stops.
    static func setSpeed(_ speed: Double) {
        let value = speedString(speed)
        guard store(value, forKey: speedKey) else { return }
        speedSave?.cancel()
        let work = DispatchWorkItem {
            save([speedKey: value], completion: nil)
        }
        speedSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    static func setAutoContinue(_ enabled: Bool) {
        save([autoContinueKey: enabled], completion: nil)
    }

    static func setHighlight(_ enabled: Bool) {
        save([highlightKey: enabled], completion: nil)
    }

    /// Writes local values and sends them to the server in one set_preference request.
    static func save(_ values: [String: Any], completion: ((Bool) -> Void)?) {
        let changed = values.filter { store($0.value, forKey: $0.key) }.map(\.key)
        if !changed.isEmpty {
            NotificationCenter.default.post(name: didChange, object: nil, userInfo: ["keys": changed])
        }
        var serverValues: [String: String] = [:]
        for (key, value) in values {
            serverValues[serverKey(forLocalKey: key)] = serverString(value)
        }
        send(serverValues, completion: completion)
    }

    /// PreferencesView.swift already stored the new value; this sends it to the server (FeedsObjCViewController.m).
    static func pushLocalValue(forKey key: String) {
        guard isSyncedKey(key), let value = defaults.object(forKey: key) else { return }
        NotificationCenter.default.post(name: didChange, object: nil, userInfo: ["keys": [key]])
        send([serverKey(forLocalKey: key): serverString(value)], completion: nil)
    }

    // MARK: - Syncing from the server

    /// Adopts the server's values from user_profile.preferences after /reader/feeds (FeedsObjCViewController.m).
    static func syncFromUserProfile(_ userProfile: [AnyHashable: Any]?) {
        guard let userProfile, let preferences = ListenJSON.objectFromString(userProfile["preferences"]) else { return }
        var changed: [String] = []

        for key in listenKeys {
            guard let value = preferences[key], !(value is NSNull) else {
                // ListenPreferences.swift: the server never saved this one, so it's the default. Clearing it keeps
                // a previous account's voice or speed from carrying over after switching accounts.
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    changed.append(key)
                }
                continue
            }
            let local: Any?
            switch key {
            case voicesKey:
                if let string = value as? String {
                    local = string
                } else if let object = ListenJSON.dictionary(value),
                          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) {
                    local = String(decoding: data, as: UTF8.self)
                } else {
                    local = nil
                }
            case deliveryKey:
                local = ListenJSON.string(value)
            case stabilityKey, similarityKey, styleKey:
                local = ListenJSON.double(value).map { clamp($0) }
            case speedKey:
                local = ListenJSON.double(value).map { speedString($0) }
            default:
                local = ListenJSON.bool(value)
            }
            if let local, store(local, forKey: key) {
                changed.append(key)
            }
        }

        for button in storyButtons {
            let serverKey = serverKey(forLocalKey: button.localKey)
            if button.localKey == "show_ask_ai", !defaults.bool(forKey: askAIMigrationKey) {
                // ListenPreferences.swift carries a Show Ask AI choice made before story buttons synced, once. The
                // web's preferences dialog saves show_sideoption_ask_ai: true for most accounts, so a hidden Ask AI
                // goes to the server instead of being overwritten by it.
                defaults.set(true, forKey: askAIMigrationKey)
                if defaults.object(forKey: "show_ask_ai") != nil, !defaults.bool(forKey: "show_ask_ai") {
                    send([serverKey: "false"], completion: nil)
                    continue
                }
            }
            if let value = ListenJSON.bool(preferences[serverKey]), store(value, forKey: button.localKey) {
                changed.append(button.localKey)
            }
        }

        if !changed.isEmpty {
            NotificationCenter.default.post(name: didChange, object: nil, userInfo: ["keys": changed])
        }
    }

    // MARK: - Helpers

    static func speedString(_ speed: Double) -> String {
        numberString(min(3, max(0.5, speed)))
    }

    static func numberString(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return String(format: "%g", rounded)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func serverString(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return numberString(number.doubleValue)
        }
        return "\(value)"
    }

    private static func send(_ values: [String: String], completion: ((Bool) -> Void)?) {
        guard !values.isEmpty else {
            completion?(true)
            return
        }
        let appDelegate = NewsBlurAppDelegate.shared()
        updateCachedProfile(values)
        let url = "\(ListenAPI.shared.baseURL)/profile/set_preference"
        appDelegate?.post(url, parameters: values, success: { _, _ in
            completion?(true)
        }, failure: { _, error in
            NSLog("Failed to save Listen preferences %@: %@", values.keys.joined(separator: ", "),
                  (error as NSError?) ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
            completion?(false)
        })
    }

    /// Mirrors FeedsObjCViewController.m's updateCachedUserProfilePreferenceWithKey: so later reads see the change.
    private static func updateCachedProfile(_ values: [String: String]) {
        guard let appDelegate = NewsBlurAppDelegate.shared(),
              let profile = appDelegate.dictUserProfile, !profile.isEmpty else { return }
        var userProfile = profile
        var preferences = ListenJSON.objectFromString(userProfile["preferences"]) ?? [:]
        for (key, value) in values {
            // apps/profile/views.py set_preference turns only "true" and "false" into booleans.
            switch value {
            case "true": preferences[key] = true
            case "false": preferences[key] = false
            default: preferences[key] = value
            }
        }
        userProfile["preferences"] = preferences
        appDelegate.dictUserProfile = userProfile
    }
}
