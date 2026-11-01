//
//  ListenVoiceSettingsModel.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

/// The voice filters, one value per category because /listen/library takes one each (ListenVoiceSettingsModel.swift).
enum ListenVoiceFilter: String, CaseIterable, Identifiable {
    case gender
    case age
    case accent
    case descriptive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gender: return NBLocalization.text("Gender", context: "voice filter")
        case .age: return NBLocalization.text("Age", context: "voice filter")
        case .accent: return NBLocalization.text("Accent", context: "voice filter")
        case .descriptive: return NBLocalization.text("Style", context: "voice filter")
        }
    }

    func value(of voice: ListenVoice) -> String {
        switch self {
        case .gender: return voice.gender
        case .age: return voice.age
        case .accent: return voice.accent
        case .descriptive: return voice.descriptive
        }
    }
}

/// ListenVoiceSettingsModel.swift backs the voice picker: the curated voices for each language, the ElevenLabs
/// library searched with the same filters, and the delivery and playback settings. A change that affects the
/// story playing restarts it at the paragraph being read.
final class ListenVoiceSettingsModel: ObservableObject {
    @Published private(set) var catalog: ListenVoicesCatalog?
    @Published private(set) var isLoadingCatalog = false
    @Published private(set) var loadError: String?
    @Published private(set) var language: String
    @Published var delivery: ListenDeliverySettings
    @Published private(set) var selectedVoices: [String: String]
    @Published private(set) var filters: [ListenVoiceFilter: String] = [:]
    @Published var search = ""
    @Published private(set) var libraryVoices: [ListenVoice] = []
    @Published private(set) var isLoadingLibrary = false
    @Published private(set) var libraryError: String?
    /// Bumped whenever the filters, search or language change, so the list scrolls back to its top.
    @Published private(set) var listGeneration = 0

    let preview = ListenVoicePreviewPlayer()
    private var libraryPage = 0
    private var libraryHasMore = false
    private var libraryGeneration = 0
    private var knownVoices: [String: ListenVoice] = [:]
    private var searchWork: DispatchWorkItem?
    private var restartWork: DispatchWorkItem?
    private var previewChanges: AnyCancellable?

    init() {
        language = Self.initialLanguage()
        delivery = ListenPreferences.deliverySettings
        selectedVoices = ListenPreferences.voices
        if let voice = ListenPlayer.shared.manifest?.voice {
            knownVoices[voice.id] = voice
        }
        // ListenVoiceSettingsModel.swift redraws the picker when a preview starts, stops or fails.
        previewChanges = preview.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// The playing story's language, else the interface language when it's one of the 21, else English.
    private static func initialLanguage() -> String {
        if let language = ListenPlayer.shared.language {
            return language
        }
        let interface = NBLocalization.resolvedLanguage
        if NBLocalization.languages.contains(where: { $0.0 == interface }) {
            return interface
        }
        return "en"
    }

    // MARK: - Catalog

    var languages: [ListenLanguage] {
        if let languages = catalog?.languages, !languages.isEmpty {
            return languages
        }
        return NBLocalization.languages.map { ListenLanguage(code: $0.0, name: $0.1) }
    }

    var languageName: String {
        languages.first { $0.code == language }?.name ?? language
    }

    var filterOptions: ListenFilters {
        catalog?.filters ?? ListenFilters()
    }

    var presets: [ListenDeliveryPreset] {
        catalog?.deliveryPresets ?? ListenDeliveryPreset.fallback
    }

    var selectedVoiceId: String? {
        selectedVoices[language] ?? catalog?.selected[language] ?? catalog?.defaults[language]
    }

    func load() {
        if catalog == nil, !isLoadingCatalog {
            isLoadingCatalog = true
            loadError = nil
            ListenAPI.shared.voices(language: nil) { [weak self] result in
                guard let self else { return }
                self.isLoadingCatalog = false
                switch result {
                case .success(let catalog):
                    self.catalog = catalog
                    for (language, voiceId) in catalog.selected where self.selectedVoices[language] == nil {
                        self.selectedVoices[language] = voiceId
                    }
                    for voice in catalog.voices.values.flatMap({ $0 }) {
                        self.knownVoices[voice.id] = voice
                    }
                    if !self.delivery.isCustom {
                        self.applyPresetValues(self.delivery.delivery)
                    }
                case .failure(let error):
                    self.loadError = error.message
                }
            }
        }
        if libraryVoices.isEmpty, !isLoadingLibrary {
            reloadLibrary()
        }
    }

    func setLanguage(_ code: String) {
        guard code != language else { return }
        language = code
        // ListenVoiceSettingsModel.swift drops an accent that belongs to the previous language.
        filters[.accent] = nil
        reloadLibrary()
    }

    // MARK: - Filters and search

    func options(for filter: ListenVoiceFilter) -> [ListenFilterOption] {
        let options = filterOptions
        switch filter {
        case .gender: return options.gender
        case .age: return options.age
        case .accent: return options.accents(for: language)
        case .descriptive: return options.descriptive
        }
    }

    func label(for filter: ListenVoiceFilter, value: String) -> String {
        filterOptions.label(for: value, in: options(for: filter))
    }

    func setFilter(_ filter: ListenVoiceFilter, to value: String?) {
        let value = (value?.isEmpty ?? true) ? nil : value
        guard filters[filter] != value else { return }
        filters[filter] = value
        reloadLibrary()
    }

    var hasFilters: Bool {
        !filters.isEmpty || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearFilters() {
        filters = [:]
        search = ""
        reloadLibrary()
    }

    func searchChanged() {
        searchWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reloadLibrary() }
        searchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func matches(_ voice: ListenVoice) -> Bool {
        for (filter, value) in filters where filter.value(of: voice) != value {
            return false
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        let haystack = [voice.name, voice.description, voice.accent, voice.descriptive, voice.useCase]
            .joined(separator: " ").lowercased()
        return haystack.contains(query)
    }

    /// The curated voices for this language, with a library voice the reader picked kept at the top.
    private var allRecommended: [ListenVoice] {
        var voices = catalog?.voices[language] ?? []
        if let selected = selectedVoiceId, !voices.contains(where: { $0.id == selected }),
           let voice = knownVoices[selected], voice.language.isEmpty || voice.language == language {
            voices.insert(voice, at: 0)
        }
        return voices
    }

    var recommended: [ListenVoice] {
        allRecommended.filter(matches)
    }

    /// Library voices that aren't already in Recommended.
    var moreVoices: [ListenVoice] {
        let listed = Set(allRecommended.map(\.id))
        return libraryVoices.filter { !listed.contains($0.id) }
    }

    var isLoadingVoices: Bool {
        (catalog == nil && isLoadingCatalog) || isLoadingLibrary
    }

    private func reloadLibrary() {
        listGeneration += 1
        libraryGeneration += 1
        libraryPage = 0
        libraryHasMore = false
        libraryVoices = []
        fetchLibrary()
    }

    func loadMoreIfNeeded(after voice: ListenVoice) {
        guard libraryHasMore, !isLoadingLibrary, voice.id == moreVoices.last?.id else { return }
        libraryPage += 1
        fetchLibrary()
    }

    private func fetchLibrary() {
        let generation = libraryGeneration
        var query = ListenLibraryQuery(language: language)
        query.gender = filters[.gender] ?? ""
        query.age = filters[.age] ?? ""
        query.accent = filters[.accent] ?? ""
        query.descriptive = filters[.descriptive] ?? ""
        query.search = search
        isLoadingLibrary = true
        libraryError = nil
        ListenAPI.shared.library(query: query, page: libraryPage) { [weak self] result in
            guard let self, generation == self.libraryGeneration else { return }
            self.isLoadingLibrary = false
            switch result {
            case .success(let page):
                let known = Set(self.libraryVoices.map(\.id))
                let voices = page.voices.filter { !known.contains($0.id) }
                for voice in voices {
                    self.knownVoices[voice.id] = voice
                }
                self.libraryVoices.append(contentsOf: voices)
                self.libraryHasMore = page.hasMore
            case .failure(let error):
                self.libraryError = error.message
                self.libraryHasMore = false
            }
        }
    }

    // MARK: - Voice rows

    /// "Male · Middle aged · American", in the server's localized labels.
    func traits(for voice: ListenVoice) -> String {
        [ListenVoiceFilter.gender, .age, .accent].compactMap { filter in
            let value = filter.value(of: voice)
            return value.isEmpty ? nil : label(for: filter, value: value)
        }.joined(separator: " · ")
    }

    func select(_ voice: ListenVoice) {
        let language = self.language
        guard selectedVoiceId != voice.id else { return }
        knownVoices[voice.id] = voice
        selectedVoices[language] = voice.id
        ListenPreferences.setVoice(voice.id, forLanguage: language) { [weak self] _ in
            let player = ListenPlayer.shared
            if player.isActive, player.language == language {
                self?.scheduleRestart(voiceId: voice.id)
            }
        }
    }

    func togglePreview(_ voice: ListenVoice) {
        preview.toggle(voice: voice, language: language, delivery: delivery)
    }

    /// The voice reading the story now when it isn't the one chosen (the chosen voice is unavailable).
    var fallbackVoiceName: String? {
        let player = ListenPlayer.shared
        guard let manifest = player.manifest, manifest.voiceFallback, manifest.language == language,
              let voice = manifest.voice else { return nil }
        return voice.displayName
    }

    // MARK: - Delivery

    var deliveryChoices: [String] {
        ListenDeliverySettings.presetIds + (delivery.isCustom ? ["custom"] : [])
    }

    func deliveryTitle(_ id: String) -> String {
        switch id {
        case "steady": return NBLocalization.text("Steady", context: "listen delivery")
        case "natural": return NBLocalization.text("Natural", context: "listen delivery")
        case "expressive": return NBLocalization.text("Expressive", context: "listen delivery")
        default: return NBLocalization.text("Custom", context: "listen delivery")
        }
    }

    func choosePreset(_ id: String) {
        guard id != "custom" else { return }
        delivery.delivery = id
        applyPresetValues(id)
        commitDelivery()
    }

    /// Presets show their own values on the fine-tune sliders, so a slider starts from what you were hearing.
    private func applyPresetValues(_ id: String) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        delivery.stability = preset.stability
        delivery.similarity = preset.similarity
        delivery.style = preset.style
    }

    /// A fine-tune control moved: the delivery becomes custom and is saved when the change ends.
    func fineTuneChanged() {
        delivery.delivery = "custom"
    }

    func commitDelivery() {
        let settings = delivery
        ListenPreferences.setDelivery(settings) { [weak self] _ in
            if ListenPlayer.shared.isActive {
                self?.scheduleRestart(voiceId: nil)
            }
        }
    }

    /// ListenVoiceSettingsModel.swift waits for a pause in changes before re-reading the story.
    private func scheduleRestart(voiceId: String?) {
        restartWork?.cancel()
        let work = DispatchWorkItem {
            ListenPlayer.shared.restartWithCurrentSettings(voiceId: voiceId)
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Usage

    /// The muted footer: listening left this week, or free previews left today. apps/listen/usage.py caps Listen
    /// per week, from Sunday at midnight in the account's timezone, so the reset reads as a weekday.
    var usageText: String? {
        guard let usage = ListenPlayer.shared.usage ?? catalog?.usage else { return nil }
        var parts: [String] = []
        if usage.isArchiveTier {
            if let remaining = usage.secondsRemaining {
                parts.append(String(format: NBLocalization.text("%@ left this week"), ListenFormat.allowance(remaining)))
                if let resets = usage.resetsAt {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: NBLocalization.resolvedLanguage)
                    formatter.setLocalizedDateFormatFromTemplate("EEEE")
                    parts.append(String(format: NBLocalization.text("Resets %@"), formatter.string(from: resets)))
                }
            }
        } else {
            if let samplesLimit = usage.samplesLimit {
                parts.append(NBLocalization.plural("%@ free story previews left today",
                                                   groupedCount: max(0, samplesLimit - usage.samplesUsed)))
            }
            if let previewsLimit = usage.previewsLimit {
                parts.append(NBLocalization.plural("%@ voice previews left",
                                                   groupedCount: max(0, previewsLimit - usage.previewsUsed)))
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var showsUpgrade: Bool {
        !((ListenPlayer.shared.usage ?? catalog?.usage)?.isArchiveTier ?? true)
    }
}

/// Plays a short sample of a voice reading the current article, or the voice's own sample when no article is
/// open (ListenVoiceSettingsModel.swift). The story playing pauses for the sample and resumes after it.
final class ListenVoicePreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var loadingVoiceId: String?
    @Published private(set) var playingVoiceId: String?
    @Published private(set) var errorMessage: String?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var generation = 0
    private var resumesStory = false

    func toggle(voice: ListenVoice, language: String, delivery: ListenDeliverySettings) {
        if playingVoiceId == voice.id || loadingVoiceId == voice.id {
            stop()
            return
        }
        // ListenVoiceSettingsModel.swift moves straight from one sample to the next without the story
        // resuming in between; it resumes once the last sample ends or is stopped.
        stopPlayback(resumeStory: false)
        generation += 1
        let generation = self.generation
        errorMessage = nil
        loadingVoiceId = voice.id
        let storyHash = ListenPlayer.shared.storyHash
            ?? (NewsBlurAppDelegate.shared()?.activeStory?["story_hash"] as? String)
        if storyHash == nil, let url = voice.previewURL {
            fetch(url, voice: voice, generation: generation)
            return
        }
        ListenAPI.shared.preview(voiceId: voice.id, storyHash: storyHash, language: language,
                                 delivery: delivery) { [weak self] result in
            guard let self, generation == self.generation else { return }
            switch result {
            case .success(let preview):
                self.fetch(preview.url, voice: voice, generation: generation)
            case .failure(let error):
                self.loadingVoiceId = nil
                self.errorMessage = error.message
            }
        }
    }

    private func fetch(_ url: URL, voice: ListenVoice, generation: Int) {
        ListenAudioDownloader.shared.download(url, name: "preview-\(voice.id)") { [weak self] result in
            guard let self, generation == self.generation else { return }
            switch result {
            case .success(let file):
                self.play(file, voice: voice)
            case .failure:
                self.loadingVoiceId = nil
                self.errorMessage = ListenAPIError.streamFailed.message
            }
        }
    }

    private func play(_ file: URL, voice: ListenVoice) {
        let story = ListenPlayer.shared
        if story.wantsToPlay {
            story.pause()
            resumesStory = true
        }
        story.activateAudioSession()
        let item = AVPlayerItem(url: file)
        let player = AVPlayer(playerItem: item)
        self.player = player
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: item, queue: .main) { [weak self] _ in
            self?.stop()
        }
        loadingVoiceId = nil
        playingVoiceId = voice.id
        player.play()
    }

    func stop() {
        stopPlayback(resumeStory: true)
    }

    private func stopPlayback(resumeStory: Bool) {
        generation += 1
        player?.pause()
        player = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        loadingVoiceId = nil
        playingVoiceId = nil
        if resumeStory, resumesStory {
            resumesStory = false
            ListenPlayer.shared.play()
        }
    }
}
