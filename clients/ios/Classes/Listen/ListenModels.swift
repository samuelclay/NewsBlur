//
//  ListenModels.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// ListenModels.swift reads the Listen API's JSON leniently: the server's set_preference stores strings, and
/// numbers may arrive as either strings or numbers.
enum ListenJSON {
    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "true", "1", "yes", "on":
                return true
            case "false", "0", "no", "off":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                if let key = key as? String {
                    result[key] = value
                }
            }
            return result
        }
        return nil
    }

    static func array(_ value: Any?) -> [Any] {
        (value as? [Any]) ?? []
    }

    /// A JSON object stored as a string preference, such as `listen_voices`.
    static func objectFromString(_ value: Any?) -> [String: Any]? {
        if let dictionary = dictionary(value) {
            return dictionary
        }
        guard let string = value as? String, let data = string.data(using: .utf8) else { return nil }
        return dictionary(try? JSONSerialization.jsonObject(with: data))
    }
}

/// A voice from the curated catalog, the ElevenLabs library or the premade set (ListenModels.swift).
struct ListenVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let gender: String
    let age: String
    let accent: String
    let useCase: String
    let descriptive: String
    let language: String
    let locale: String?
    let previewURL: URL?
    let category: String
    let source: String

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json),
              let voiceId = ListenJSON.string(json["voice_id"]), !voiceId.isEmpty else { return nil }
        id = voiceId
        name = ListenJSON.string(json["name"]) ?? ""
        description = ListenJSON.string(json["description"]) ?? ""
        gender = ListenJSON.string(json["gender"]) ?? ""
        age = ListenJSON.string(json["age"]) ?? ""
        accent = ListenJSON.string(json["accent"]) ?? ""
        useCase = ListenJSON.string(json["use_case"]) ?? ""
        descriptive = ListenJSON.string(json["descriptive"]) ?? ""
        language = ListenJSON.string(json["language"]) ?? ""
        locale = ListenJSON.string(json["locale"])
        previewURL = ListenJSON.string(json["preview_url"]).flatMap { URL(string: $0) }
        category = ListenJSON.string(json["category"]) ?? ""
        source = ListenJSON.string(json["source"]) ?? ""
    }

    /// Voice names come from ElevenLabs and are never translated.
    var displayName: String {
        name.isEmpty ? id : name
    }
}

/// Monthly listening allowance and daily sample/preview counters (ListenModels.swift).
struct ListenUsage: Equatable {
    let tier: String
    let isArchiveTier: Bool
    let secondsUsed: Double
    let secondsLimit: Double?
    let secondsRemaining: Double?
    let resetsAt: Date?
    let samplesUsed: Int
    let samplesLimit: Int?
    let previewSeconds: Double?
    let previewsUsed: Int
    let previewsLimit: Int?
    let upgradeMessage: String?

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json) else { return nil }
        tier = ListenJSON.string(json["tier"]) ?? "free"
        isArchiveTier = ListenJSON.bool(json["is_archive_tier"]) ?? false
        secondsUsed = ListenJSON.double(json["seconds_used"]) ?? 0
        secondsLimit = ListenJSON.double(json["seconds_limit"])
        secondsRemaining = ListenJSON.double(json["seconds_remaining"])
        if let resets = ListenJSON.string(json["resets_at"]) {
            resetsAt = ISO8601DateFormatter().date(from: resets)
        } else {
            resetsAt = nil
        }
        samplesUsed = ListenJSON.int(json["samples_used"]) ?? 0
        samplesLimit = ListenJSON.int(json["samples_limit"])
        previewSeconds = ListenJSON.double(json["preview_seconds"])
        previewsUsed = ListenJSON.int(json["previews_used"]) ?? 0
        previewsLimit = ListenJSON.int(json["previews_limit"])
        upgradeMessage = ListenJSON.string(json["upgrade_message"])
    }

    var isPro: Bool { tier == "pro" }
}

struct ListenParagraph: Equatable {
    let index: Int
    let kind: String
    let text: String

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json), let index = ListenJSON.int(json["index"]) else { return nil }
        self.index = index
        kind = ListenJSON.string(json["kind"]) ?? "text"
        text = ListenJSON.string(json["text"]) ?? ""
    }

    var dictionary: [String: Any] {
        ["index": index, "kind": kind, "text": text]
    }
}

struct ListenSegment: Equatable {
    let index: Int
    let paragraphs: [Int]
    let characters: Int
    let duration: Double
    let estimated: Bool
    let cached: Bool

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json), let index = ListenJSON.int(json["index"]) else { return nil }
        self.index = index
        paragraphs = ListenJSON.array(json["paragraphs"]).compactMap { ListenJSON.int($0) }
        characters = ListenJSON.int(json["characters"]) ?? 0
        duration = max(0.5, ListenJSON.double(json["duration"]) ?? 1)
        estimated = ListenJSON.bool(json["estimated"]) ?? true
        cached = ListenJSON.bool(json["cached"]) ?? false
    }
}

struct ListenPreviewInfo: Equatable {
    let isPreview: Bool
    let seconds: Double?
    let samplesUsed: Int?
    let samplesLimit: Int?

    init(json: Any?) {
        let json = ListenJSON.dictionary(json) ?? [:]
        isPreview = ListenJSON.bool(json["is_preview"]) ?? false
        seconds = ListenJSON.double(json["seconds"])
        samplesUsed = ListenJSON.int(json["samples_used"])
        samplesLimit = ListenJSON.int(json["samples_limit"])
    }
}

/// The reading plan for one story: its paragraphs and the segments that get generated and streamed.
struct ListenManifest: Equatable {
    let manifestId: String
    let expiresAt: Date?
    let storyHash: String
    let feedId: String
    let storyTitle: String
    let feedTitle: String
    let language: String
    let detectedLanguage: String
    let voice: ListenVoice?
    let voiceFallback: Bool
    let textSource: String
    let paragraphs: [ListenParagraph]
    let segments: [ListenSegment]
    let totalDuration: Double
    let preview: ListenPreviewInfo
    let usage: ListenUsage?

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json),
              let manifestId = ListenJSON.string(json["manifest_id"]), !manifestId.isEmpty else { return nil }
        self.manifestId = manifestId
        expiresAt = ListenJSON.double(json["expires_at"]).map { Date(timeIntervalSince1970: $0) }
        storyHash = ListenJSON.string(json["story_hash"]) ?? ""
        feedId = ListenJSON.string(json["feed_id"]) ?? ""
        storyTitle = ListenJSON.string(json["story_title"]) ?? ""
        feedTitle = ListenJSON.string(json["feed_title"]) ?? ""
        language = ListenJSON.string(json["language"]) ?? "en"
        detectedLanguage = ListenJSON.string(json["detected_language"]) ?? language
        voice = ListenVoice(json: json["voice"])
        voiceFallback = ListenJSON.bool(json["voice_fallback"]) ?? false
        textSource = ListenJSON.string(json["text_source"]) ?? "story"
        paragraphs = ListenJSON.array(json["paragraphs"]).compactMap { ListenParagraph(json: $0) }
        segments = ListenJSON.array(json["segments"]).compactMap { ListenSegment(json: $0) }
            .sorted { $0.index < $1.index }
        totalDuration = ListenJSON.double(json["total_duration"]) ?? segments.reduce(0) { $0 + $1.duration }
        preview = ListenPreviewInfo(json: json["preview"])
        usage = ListenUsage(json: json["usage"])
    }

    /// The first segment that reads the given paragraph, or nil when no segment covers it.
    func segmentIndex(containingParagraph paragraph: Int) -> Int? {
        if let exact = segments.firstIndex(where: { $0.paragraphs.contains(paragraph) }) {
            return exact
        }
        return segments.firstIndex(where: { ($0.paragraphs.max() ?? -1) >= paragraph })
    }
}

struct ListenLanguage: Identifiable, Equatable {
    let code: String
    let name: String

    var id: String { code }
}

struct ListenFilterOption: Identifiable, Equatable, Hashable {
    let value: String
    let label: String

    var id: String { value }

    init(value: String, label: String) {
        self.value = value
        self.label = label
    }

    init?(json: Any?) {
        if let raw = json as? String {
            // ListenModels.swift shows raw ElevenLabs accents title-cased and sends them back unchanged.
            value = raw
            label = raw.replacingOccurrences(of: "_", with: " ").capitalized
            return
        }
        guard let json = ListenJSON.dictionary(json), let value = ListenJSON.string(json["value"]) else { return nil }
        self.value = value
        label = ListenJSON.string(json["label"]) ?? value
    }
}

struct ListenDeliveryPreset: Identifiable, Equatable {
    let id: String
    let stability: Double
    let similarity: Double
    let style: Double

    init(id: String, stability: Double, similarity: Double, style: Double) {
        self.id = id
        self.stability = stability
        self.similarity = similarity
        self.style = style
    }

    init?(json: Any?) {
        guard let json = ListenJSON.dictionary(json), let id = ListenJSON.string(json["id"]) else { return nil }
        self.id = id
        stability = ListenJSON.double(json["stability"]) ?? 0.5
        similarity = ListenJSON.double(json["similarity"]) ?? 0.75
        style = ListenJSON.double(json["style"]) ?? 0
    }

    /// Matches apps/listen/voices.py DELIVERY_PRESETS until /listen/voices answers.
    static let fallback: [ListenDeliveryPreset] = [
        ListenDeliveryPreset(id: "steady", stability: 0.75, similarity: 0.75, style: 0),
        ListenDeliveryPreset(id: "natural", stability: 0.5, similarity: 0.75, style: 0),
        ListenDeliveryPreset(id: "expressive", stability: 0.3, similarity: 0.75, style: 0.35)
    ]
}

struct ListenFilters: Equatable {
    var gender: [ListenFilterOption] = []
    var age: [ListenFilterOption] = []
    var useCase: [ListenFilterOption] = []
    var descriptive: [ListenFilterOption] = []
    var sort: [ListenFilterOption] = []
    var accents: [String: [ListenFilterOption]] = [:]

    init() {}

    init(json: Any?) {
        let json = ListenJSON.dictionary(json) ?? [:]
        gender = ListenJSON.array(json["gender"]).compactMap { ListenFilterOption(json: $0) }
        age = ListenJSON.array(json["age"]).compactMap { ListenFilterOption(json: $0) }
        useCase = ListenJSON.array(json["use_case"]).compactMap { ListenFilterOption(json: $0) }
        descriptive = ListenJSON.array(json["descriptive"]).compactMap { ListenFilterOption(json: $0) }
        sort = ListenJSON.array(json["sort"]).compactMap { ListenFilterOption(json: $0) }
        if let accentsByLanguage = ListenJSON.dictionary(json["accent"]) {
            for (language, accents) in accentsByLanguage {
                self.accents[language] = ListenJSON.array(accents).compactMap { ListenFilterOption(json: $0) }
            }
        } else {
            let shared = ListenJSON.array(json["accent"]).compactMap { ListenFilterOption(json: $0) }
            if !shared.isEmpty {
                accents["*"] = shared
            }
        }
    }

    func accents(for language: String) -> [ListenFilterOption] {
        accents[language] ?? accents["*"] ?? []
    }

    /// The server's localized label for a voice trait, falling back to a readable form of the raw value.
    func label(for value: String, in options: [ListenFilterOption]) -> String {
        if let option = options.first(where: { $0.value == value }) {
            return option.label
        }
        return value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// GET /listen/voices
struct ListenVoicesCatalog {
    let languages: [ListenLanguage]
    let voices: [String: [ListenVoice]]
    let defaults: [String: String]
    let selected: [String: String]
    let deliveryPresets: [ListenDeliveryPreset]
    let filters: ListenFilters
    let usage: ListenUsage?

    init(json: [String: Any]) {
        languages = ListenJSON.array(json["languages"]).compactMap { entry in
            guard let entry = ListenJSON.dictionary(entry), let code = ListenJSON.string(entry["code"]) else { return nil }
            return ListenLanguage(code: code, name: ListenJSON.string(entry["name"]) ?? code)
        }
        var voices: [String: [ListenVoice]] = [:]
        for (language, list) in ListenJSON.dictionary(json["voices"]) ?? [:] {
            voices[language] = ListenJSON.array(list).compactMap { ListenVoice(json: $0) }
        }
        self.voices = voices
        defaults = (ListenJSON.dictionary(json["defaults"]) ?? [:]).compactMapValues { ListenJSON.string($0) }
        selected = (ListenJSON.dictionary(json["selected"]) ?? [:]).compactMapValues { ListenJSON.string($0) }
        let presets = ListenJSON.array(json["delivery_presets"]).compactMap { ListenDeliveryPreset(json: $0) }
        deliveryPresets = presets.isEmpty ? ListenDeliveryPreset.fallback : presets
        filters = ListenFilters(json: json["filters"])
        usage = ListenUsage(json: json["usage"])
    }
}

/// GET /listen/library
struct ListenLibraryPage {
    let voices: [ListenVoice]
    let hasMore: Bool
    let page: Int

    init(json: [String: Any]) {
        voices = ListenJSON.array(json["voices"]).compactMap { ListenVoice(json: $0) }
        hasMore = ListenJSON.bool(json["has_more"]) ?? false
        page = ListenJSON.int(json["page"]) ?? 0
    }
}

/// POST /listen/segment
struct ListenSegmentLocation {
    let index: Int
    let url: URL
    let cached: Bool
    let duration: Double?
    let usage: ListenUsage?
}

/// POST /listen/preview
struct ListenVoicePreview {
    let url: URL
    let text: String
    let voice: ListenVoice?
    let usage: ListenUsage?
}

/// A Listen request that failed. `message` is localized by the server and safe to show; `reason` never is.
struct ListenAPIError: Error, Equatable {
    let reason: String?
    let message: String
    let usage: ListenUsage?

    static let upgradeReasons: Set<String> = ["cap_reached", "sample_limit", "preview_ended", "preview_limit"]

    var isUpgradeReason: Bool {
        reason.map { Self.upgradeReasons.contains($0) } ?? false
    }

    static func network(_ error: Error?) -> ListenAPIError {
        ListenAPIError(reason: "network",
                       message: NBLocalization.text("Couldn't reach NewsBlur. Check your connection and try again."),
                       usage: nil)
    }

    static var invalidResponse: ListenAPIError {
        ListenAPIError(reason: "invalid_response",
                       message: NBLocalization.text("Listening isn't available right now."),
                       usage: nil)
    }

    static var streamFailed: ListenAPIError {
        ListenAPIError(reason: "stream",
                       message: NBLocalization.text("The audio couldn't be loaded. Try again in a moment."),
                       usage: nil)
    }
}
