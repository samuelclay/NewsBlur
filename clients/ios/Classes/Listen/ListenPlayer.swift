//
//  ListenPlayer.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation
import MediaPlayer
import UIKit

/// An inline playback problem shown in the mini player and Now Playing (ListenPlayer.swift).
struct ListenPlaybackError: Equatable {
    enum Upgrade: Equatable {
        case none
        case archive
        case pro
    }

    let message: String
    let upgrade: Upgrade
    let retryable: Bool
}

/// ListenPlayer.swift reads a story aloud: it asks apps/listen for the story's manifest, downloads one segment at a
/// time (never more than one ahead of the one playing) and plays them back to back in an AVQueuePlayer. The
/// timeline spans every segment, using the manifest's estimated durations until each file's real duration is
/// known, so scrubbing and skipping work across segments.
final class ListenPlayer: NSObject, ObservableObject {
    static let shared = ListenPlayer()

    /// Posted when the playing story, the play/pause state or the status changes.
    static let stateDidChange = Notification.Name("ListenPlayerStateDidChange")
    /// Posted when a different segment (and so different paragraphs) starts.
    static let segmentDidChange = Notification.Name("ListenPlayerSegmentDidChange")

    enum Status: Equatable {
        case idle
        case loading
        case buffering
        case playing
        case paused
        case finished
        case previewEnded
        case failed
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var storyHash: String?
    @Published private(set) var storyTitle = ""
    @Published private(set) var feedTitle = ""
    @Published private(set) var feedId: String?
    @Published private(set) var manifest: ListenManifest?
    @Published private(set) var segmentIndex = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var speed: Double = ListenPreferences.speed
    @Published private(set) var playbackError: ListenPlaybackError?
    @Published private(set) var usage: ListenUsage?
    /// True while the user wants audio (playing, or waiting for audio to arrive).
    @Published private(set) var wantsToPlay = false

    private(set) var story: [String: Any]?

    private let player = AVQueuePlayer()
    private var itemSegments: [ObjectIdentifier: Int] = [:]
    private var itemObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var pendingItemSeeks: [ObjectIdentifier: TimeInterval] = [:]
    private var files: [Int: URL] = [:]
    private var knownDurations: [Int: TimeInterval] = [:]
    private var requests: [Int: UUID] = [:]
    private var downloadTasks: [Int: URLSessionDownloadTask] = [:]
    private var retriedSegments: Set<Int> = []
    private var pendingStart: (segment: Int, offset: TimeInterval)?
    /// True while a voice or delivery change fetches the new manifest; nothing plays or loads from the old one.
    private var isLoadingManifest = false
    private var pendingJumpParagraph: Int?
    /// Scrubbing and skips wait for the position to settle before asking for audio, since each segment requested
    /// counts against the weekly allowance (apps/listen/usage.py).
    private var seekSettleWork: DispatchWorkItem?
    private var isSettlingSeek = false
    private var generation = 0
    private var voiceOverride: String?
    private var artwork: MPMediaItemArtwork?
    private var timeObserver: Any?
    private var currentItemObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var resumeAfterInterruption = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    /// Listening analytics (listen-spec "Listening analytics beacon"): audio timeline played since the last report.
    private var unreportedSeconds: TimeInterval = 0
    private var lastPlayedPosition: TimeInterval?
    private var lastReportDate = Date()
    private var appDelegate: NewsBlurAppDelegate? { NewsBlurAppDelegate.shared() }

    private override init() {
        super.init()
        player.actionAtItemEnd = .advance
        player.automaticallyWaitsToMinimizeStalling = false
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] _ in
            self?.tick()
        }
        currentItemObservation = player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.currentItemChanged() }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.timeControlChanged() }
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(itemDidPlayToEnd(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        center.addObserver(self, selector: #selector(itemFailedToPlayToEnd(_:)), name: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil)
        center.addObserver(self, selector: #selector(audioSessionInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(audioRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(queueDidChange), name: ListenQueue.didChange, object: nil)
        center.addObserver(self, selector: #selector(preferencesDidChange(_:)), name: ListenPreferences.didChange, object: nil)
        configureRemoteCommands()
    }

    /// A speed synced from another device (or reset to the default) applies to the story playing now.
    @objc private func preferencesDidChange(_ notification: Notification) {
        guard isActive, let keys = notification.userInfo?["keys"] as? [String],
              keys.contains(ListenPreferences.speedKey) else { return }
        let synced = ListenPreferences.speed
        guard !ListenSpeed.isSame(synced, speed) else { return }
        applyRate(synced)
    }

    /// Up Next changed here or on another device: the lock screen's next-track button follows it.
    @objc private func queueDidChange() {
        updateNowPlaying()
    }

    // MARK: - State

    var isActive: Bool { storyHash != nil }

    /// Whether `storyHash` is the story loaded in the player, playing or not.
    func isLoaded(storyHash hash: String?) -> Bool {
        guard let hash, let storyHash else { return false }
        return hash == storyHash
    }

    /// Whether `storyHash` is loaded and audio is playing or about to.
    func isPlaying(storyHash hash: String?) -> Bool {
        isLoaded(storyHash: hash) && wantsToPlay
    }

    var isPreview: Bool { manifest?.preview.isPreview ?? false }

    /// Seconds of audio a preview may play, or nil for full stories.
    var previewLimit: TimeInterval? {
        guard let manifest, manifest.preview.isPreview else { return nil }
        return manifest.preview.seconds ?? usage?.previewSeconds ?? 30
    }

    /// Seconds left in a preview: the preview's limit, or its audio when that's shorter.
    var previewRemaining: TimeInterval? {
        guard let previewLimit else { return nil }
        let end = duration > 0 ? min(previewLimit, duration) : previewLimit
        return max(0, end - elapsed)
    }

    /// Paragraph indexes the current segment reads.
    var currentParagraphs: [Int] {
        guard let manifest, segmentIndex < manifest.segments.count else { return [] }
        return manifest.segments[segmentIndex].paragraphs
    }

    var voiceName: String? { manifest?.voice?.displayName }

    var language: String? { manifest?.language }

    // MARK: - Controls

    /// The story button and the Y shortcut: start this story, or play/pause it when it's already loaded.
    func toggle(story: [AnyHashable: Any]) {
        let story = Self.stringKeyed(story)
        guard let hash = story["story_hash"] as? String else { return }
        if isLoaded(storyHash: hash) {
            togglePlayPause()
        } else {
            start(story: story)
        }
    }

    func start(story: [String: Any], resumeParagraph: Int? = nil) {
        guard let hash = story["story_hash"] as? String, !hash.isEmpty else { return }
        if let previous = self.story, let previousHash = storyHash, previousHash != hash, manifest != nil {
            // ListenPlayer.swift: Listen always plays now, and the story it replaces goes to History with its
            // place so it can be resumed (listen-spec "Up Next queue").
            ListenQueue.shared.addToHistory(story: previous, position: elapsed, duration: duration)
        }
        if ListenQueue.shared.contains(storyHash: hash) {
            ListenQueue.shared.remove(storyHash: hash)
        }
        reportProgress()
        resetPlayback()
        generation += 1
        let generation = self.generation
        self.story = story
        storyHash = hash
        feedId = ListenJSON.string(story["story_feed_id"])
        storyTitle = Self.decodedTitle(story["story_title"])
        feedTitle = feedTitle(forFeedId: feedId) ?? ""
        artwork = makeArtwork()
        manifest = nil
        segmentIndex = 0
        elapsed = 0
        duration = 0
        playbackError = nil
        voiceOverride = nil
        speed = ListenPreferences.speed
        player.volume = 1
        wantsToPlay = true
        setStatus(.loading)
        setRemoteCommandsEnabled(true)
        updateNowPlaying()
        ListenMiniPlayerController.shared.show()
        loadManifest(generation: generation, resumeParagraph: resumeParagraph, voiceId: nil, startsStory: true)
    }

    func play() {
        guard isActive else { return }
        switch status {
        case .failed:
            retry()
            return
        case .finished, .previewEnded:
            // ListenPlayer.swift replays from the start with the audio it already downloaded.
            wantsToPlay = true
            player.volume = 1
            setStatus(.buffering)
            move(to: 0, offset: 0)
            return
        default:
            break
        }
        wantsToPlay = true
        if isLoadingManifest {
            setStatus(.loading)
            return
        }
        if let pendingStart {
            setStatus(manifest == nil ? .loading : .buffering)
            requestSegment(pendingStart.segment)
        } else if player.currentItem != nil {
            startPlayback()
        } else if manifest != nil {
            prepare(segment: segmentIndex, offset: max(0, elapsed - segmentStart(segmentIndex)))
        }
        notifyState()
    }

    func pause() {
        guard isActive else { return }
        wantsToPlay = false
        player.pause()
        reportProgress()
        if status == .playing || status == .buffering || status == .loading {
            setStatus(.paused)
        } else {
            notifyState()
        }
        updateNowPlaying()
        endBackgroundTask()
    }

    func togglePlayPause() {
        wantsToPlay ? pause() : play()
    }

    /// The close button: stops playback and hides the mini player.
    func stop() {
        reportProgress()
        generation += 1
        resetPlayback()
        story = nil
        storyHash = nil
        feedId = nil
        manifest = nil
        storyTitle = ""
        feedTitle = ""
        elapsed = 0
        duration = 0
        playbackError = nil
        wantsToPlay = false
        artwork = nil
        setStatus(.idle)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        setRemoteCommandsEnabled(false)
        ListenAudioDownloader.shared.removeFiles()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        ListenMiniPlayerController.shared.hide()
        endBackgroundTask()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: elapsed + seconds)
    }

    func seek(to time: TimeInterval) {
        guard let manifest, !manifest.segments.isEmpty, !isLoadingManifest else { return }
        settleSeek()
        var limit = max(0, duration - 0.25)
        if let previewLimit {
            limit = min(limit, max(0, previewLimit - 0.5))
        }
        var remaining = min(max(0, time), limit)
        var target = manifest.segments.count - 1
        for index in manifest.segments.indices {
            let length = segmentDuration(index)
            if remaining < length || index == manifest.segments.count - 1 {
                target = index
                break
            }
            remaining -= length
        }
        if status == .finished || status == .previewEnded {
            setStatus(.paused)
        }
        move(to: target, offset: min(remaining, max(0, segmentDuration(target) - 0.1)))
    }

    /// A paragraph tap in the story while it plays (StoryDetailViewController.swift).
    func jump(toParagraph paragraph: Int) {
        if isLoadingManifest {
            // ListenPlayer.swift starts the new manifest at the tapped paragraph once it arrives.
            pendingJumpParagraph = paragraph
            wantsToPlay = true
            return
        }
        guard let manifest, let segment = manifest.segmentIndex(containingParagraph: paragraph) else { return }
        if let previewLimit, segmentStart(segment) >= previewLimit - 0.5 { return }
        wantsToPlay = true
        if status == .finished || status == .paused {
            setStatus(.buffering)
        }
        move(to: segment, offset: 0)
    }

    func setSpeed(_ newSpeed: Double) {
        let newSpeed = ListenSpeed.clamped(newSpeed)
        ListenPreferences.setSpeed(newSpeed)
        applyRate(newSpeed)
    }

    /// Plays at `newSpeed` without saving it, after reporting the span played at the old rate.
    private func applyRate(_ newSpeed: Double) {
        if !ListenSpeed.isSame(newSpeed, speed) {
            reportProgress()
        }
        speed = newSpeed
        player.defaultRate = Float(speed)
        if wantsToPlay, player.timeControlStatus != .paused {
            player.rate = Float(speed)
        }
        updateNowPlaying()
    }

    func retry() {
        guard let story else { return }
        playbackError = nil
        guard manifest != nil else {
            start(story: story)
            return
        }
        wantsToPlay = true
        let target = pendingStart ?? (segmentIndex, max(0, elapsed - segmentStart(segmentIndex)))
        retriedSegments.remove(target.segment)
        prepare(segment: target.segment, offset: target.offset)
        notifyState()
    }

    /// Voice or delivery changed in voice settings: rebuild the manifest and resume at the current paragraph.
    func restartWithCurrentSettings(voiceId: String? = nil) {
        guard let story, let hash = storyHash else { return }
        let paragraph = currentParagraphs.first
        generation += 1
        let generation = self.generation
        let shouldPlay = wantsToPlay || status == .loading || status == .buffering
        reportProgress()
        resetPlayback()
        self.story = story
        storyHash = hash
        voiceOverride = voiceId ?? voiceOverride
        wantsToPlay = shouldPlay
        playbackError = nil
        setStatus(shouldPlay ? .loading : .paused)
        loadManifest(generation: generation, resumeParagraph: paragraph, voiceId: voiceOverride, startsStory: false)
    }

    /// The next-track command and Now Playing's Next story: the first story in Up Next, else the following unread
    /// story in the current list.
    func playNextStory() {
        if let queued = takeQueuedStory() {
            continueTo(queued)
        } else if let next = upNextStories(limit: 1).first {
            continueTo(next)
        }
    }

    /// Whether Next story has anything to play.
    var hasNextStory: Bool {
        ListenQueue.shared.listenItems.contains { $0.storyHash != storyHash } || !upNextStories(limit: 1).isEmpty
    }

    /// A story from the "Then from" list in Now Playing.
    func play(upNext story: [String: Any]) {
        continueTo(story)
    }

    /// A story tapped in Up Next plays now; ListenPlayer.swift start(story:) takes it off the queue.
    func play(queued item: ListenQueueItem) {
        continueTo(item.story)
    }

    /// Takes the first queued story that isn't the one already playing off Up Next.
    private func takeQueuedStory() -> [String: Any]? {
        while let item = ListenQueue.shared.takeFirstListenItem() {
            if item.storyHash != storyHash {
                return item.story
            }
        }
        return nil
    }

    /// The name of the story list auto-continue reads from, for Now Playing's "Then from" heading.
    var upNextListTitle: String? {
        guard let appDelegate, let collection = appDelegate.storiesCollection else { return nil }
        guard collection.isRiverView || collection.isSocialRiverView else {
            return (collection.activeFeed?["feed_title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        switch collection.activeFolder ?? "" {
        case "everything": return NBLocalization.text("All Site Stories")
        case "infrequent": return NBLocalization.text("Infrequent Site Stories")
        case "river_global": return NBLocalization.text("Global Shared Stories")
        case "river_blurblogs": return NBLocalization.text("All Shared Stories")
        case "trending:well_read": return NBLocalization.text("Widely Read Stories")
        case "trending:long_reads": return NBLocalization.text("Long Reads")
        case "trending:good_reads": return NBLocalization.text("Good Reads")
        case "saved_stories": return NBLocalization.text("Saved Stories")
        case "read_stories": return NBLocalization.text("Read Stories")
        case "daily_briefing": return NBLocalization.text("Daily Briefing")
        case "dashboard": return NBLocalization.text("NewsBlur Dashboard")
        case "": return nil
        case let folder: return appDelegate.extractFolderName(folder) ?? folder
        }
    }

    /// The stories auto-continue and Next story move on to: the ones after this one in the story list being read,
    /// in the list's own order. Feeds and folders keep only their unread stories; Saved Stories and Read Stories
    /// hold stories that are already read, so there every following story counts. Nothing before the current
    /// story is ever played.
    func upNextStories(limit: Int) -> [[String: Any]] {
        guard let hash = storyHash, let collection = appDelegate?.storiesCollection else { return [] }
        return Self.upNextStories(after: hash, in: collection, limit: limit)
    }

    /// ListenPlayer.swift: `collection.isSavedView` covers Saved Stories, a saved tag and saved searches
    /// (NewsBlurAppDelegate.m), `isReadView` Read Stories; those follow the visible list without the unread filter.
    static func upNextStories(after hash: String, in collection: StoriesCollection, limit: Int) -> [[String: Any]] {
        let location = collection.location(ofStoryId: hash)
        let locations = (collection.activeFeedStoryLocations as NSArray?) as? [NSNumber] ?? []
        let stories = collection.activeFeedStories ?? []
        guard location >= 0, location < locations.count, limit > 0 else { return [] }
        let followsListOrder = collection.isSavedView || collection.isReadView
        var result: [[String: Any]] = []
        for position in (location + 1)..<locations.count {
            let index = locations[position].intValue
            guard index >= 0, index < stories.count, let story = stories[index] as? [AnyHashable: Any] else { continue }
            if !followsListOrder && !collection.isStoryUnread(story) {
                continue
            }
            result.append(Self.stringKeyed(story))
            if result.count >= limit {
                break
            }
        }
        return result
    }

    // MARK: - Manifest

    private func loadManifest(generation: Int, resumeParagraph: Int?, voiceId: String?, startsStory: Bool) {
        guard let hash = storyHash else { return }
        isLoadingManifest = true
        pendingJumpParagraph = nil
        beginBackgroundTask()
        ListenAPI.shared.manifest(storyHash: hash, language: nil, voiceId: voiceId) { [weak self] result in
            guard let self, generation == self.generation else { return }
            self.isLoadingManifest = false
            switch result {
            case .success(let manifest):
                let paragraph = self.pendingJumpParagraph ?? resumeParagraph
                self.pendingJumpParagraph = nil
                self.apply(manifest: manifest, resumeParagraph: paragraph)
                if startsStory, manifest.textSource == "original", self.appDelegate?.isPremium == true {
                    // ListenPlayer.swift: the feed only has a summary, so Listen reads the extracted article.
                    // Showing that story's Text view lets follow-along highlight what's being read. Text view is
                    // a premium feature, so free accounts stay on the story view.
                    ListenStoryBridge.showFullText(forStoryHash: manifest.storyHash.isEmpty ? self.storyHash : manifest.storyHash)
                }
            case .failure(let error):
                if let usage = error.usage {
                    self.usage = usage
                }
                self.fail(error)
            }
        }
    }

    private func apply(manifest: ListenManifest, resumeParagraph: Int?) {
        self.manifest = manifest
        if let usage = manifest.usage {
            self.usage = usage
        }
        if !manifest.storyTitle.isEmpty {
            storyTitle = manifest.storyTitle
        }
        if !manifest.feedTitle.isEmpty {
            feedTitle = manifest.feedTitle
        }
        recalculateDuration()
        guard !manifest.segments.isEmpty else {
            fail(ListenAPIError(reason: "no_text", message: NBLocalization.text("This story has no text to read aloud."), usage: nil))
            return
        }
        let segment = resumeParagraph.flatMap { manifest.segmentIndex(containingParagraph: $0) } ?? 0
        if !wantsToPlay {
            setStatus(.paused)
        }
        prepare(segment: segment, offset: 0)
        NotificationCenter.default.post(name: Self.segmentDidChange, object: self)
        updateNowPlaying()
    }

    /// /listen/segment answered manifest_expired: fetch a fresh manifest and resume at the same paragraph.
    private func refreshExpiredManifest() {
        restartWithCurrentSettings(voiceId: voiceOverride)
    }

    // MARK: - Segments

    private func segmentDuration(_ index: Int) -> TimeInterval {
        if let known = knownDurations[index] {
            return known
        }
        guard let manifest, index >= 0, index < manifest.segments.count else { return 0 }
        return manifest.segments[index].duration
    }

    private func segmentStart(_ index: Int) -> TimeInterval {
        guard index > 0 else { return 0 }
        return (0..<index).reduce(0) { $0 + segmentDuration($1) }
    }

    private func recalculateDuration() {
        guard let manifest else {
            duration = 0
            return
        }
        duration = manifest.segments.indices.reduce(0) { $0 + segmentDuration($1) }
    }

    private func move(to segment: Int, offset: TimeInterval) {
        lastPlayedPosition = nil
        player.volume = 1
        if let item = player.currentItem, itemSegments[ObjectIdentifier(item)] == segment, pendingStart == nil {
            seek(item: item, to: offset)
            elapsed = segmentStart(segment) + offset
            if wantsToPlay {
                startPlayback()
            }
            updateNowPlaying()
            return
        }
        prepare(segment: segment, offset: offset)
    }

    /// Makes `segment` the one playing, downloading it first if needed.
    private func prepare(segment: Int, offset: TimeInterval) {
        guard let manifest, !isLoadingManifest, segment >= 0, segment < manifest.segments.count else { return }
        lastPlayedPosition = nil
        // ListenPlayer.swift drops fetches that are no longer the target or the one segment after it.
        for (index, task) in downloadTasks where index != segment && index != segment + 1 {
            task.cancel()
            downloadTasks[index] = nil
        }
        for index in requests.keys where index != segment && index != segment + 1 {
            requests[index] = nil
        }
        let changed = segment != segmentIndex
        segmentIndex = segment
        elapsed = segmentStart(segment) + offset
        if changed {
            NotificationCenter.default.post(name: Self.segmentDidChange, object: self)
        }
        if files[segment] != nil {
            startItem(segment: segment, offset: offset)
        } else {
            clearQueue()
            pendingStart = (segment, offset)
            if wantsToPlay {
                setStatus(.buffering)
                beginBackgroundTask()
            }
            requestSegment(segment)
        }
        updateNowPlaying()
    }

    private func startItem(segment: Int, offset: TimeInterval) {
        guard let file = files[segment] else { return }
        pendingStart = nil
        clearQueue()
        let item = makeItem(segment: segment, file: file)
        if offset > 0.05 {
            pendingItemSeeks[ObjectIdentifier(item)] = offset
        }
        player.insert(item, after: nil)
        appendNextIfReady()
        if wantsToPlay {
            if pendingItemSeeks[ObjectIdentifier(item)] == nil {
                startPlayback()
            } else {
                setStatus(.buffering)
            }
        } else if status != .failed {
            setStatus(.paused)
        }
        // ListenPlayer.swift fetches exactly one segment ahead of the one starting.
        requestSegment(segment + 1)
        updateNowPlaying()
    }

    private func makeItem(segment: Int, file: URL) -> AVPlayerItem {
        let item = AVPlayerItem(url: file)
        item.audioTimePitchAlgorithm = .timeDomain
        let identifier = ObjectIdentifier(item)
        itemSegments[identifier] = segment
        itemObservations[identifier] = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.itemStatusChanged(item) }
        }
        return item
    }

    private func appendNextIfReady() {
        guard let current = player.currentItem, let segment = itemSegments[ObjectIdentifier(current)],
              let file = files[segment + 1] else { return }
        let queued = player.items().contains { itemSegments[ObjectIdentifier($0)] == segment + 1 }
        guard !queued else { return }
        let next = makeItem(segment: segment + 1, file: file)
        if player.canInsert(next, after: current) {
            player.insert(next, after: current)
        }
    }

    private func clearQueue() {
        player.removeAllItems()
        itemSegments.removeAll()
        itemObservations.removeAll()
        pendingItemSeeks.removeAll()
    }

    private func seek(item: AVPlayerItem, to offset: TimeInterval) {
        guard item.status == .readyToPlay else {
            pendingItemSeeks[ObjectIdentifier(item)] = offset
            return
        }
        let time = CMTime(seconds: offset, preferredTimescale: 600)
        item.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { self?.updateNowPlaying() }
        }
    }

    private func requestSegment(_ index: Int) {
        guard let manifest, !isLoadingManifest, !isSettlingSeek, index >= 0, index < manifest.segments.count,
              files[index] == nil, requests[index] == nil else { return }
        let token = UUID()
        requests[index] = token
        let generation = self.generation
        ListenAPI.shared.segment(manifestId: manifest.manifestId, index: index) { [weak self] result in
            guard let self, generation == self.generation, self.requests[index] == token else { return }
            switch result {
            case .success(let location):
                if let usage = location.usage {
                    self.usage = usage
                }
                if let known = location.duration, known > 0 {
                    self.knownDurations[index] = known
                    self.recalculateDuration()
                }
                self.download(index, from: location.url, token: token)
            case .failure(let error):
                self.requests[index] = nil
                if let usage = error.usage {
                    self.usage = usage
                }
                if error.reason == "manifest_expired" {
                    self.refreshExpiredManifest()
                } else if error.reason == "preview_ended" {
                    if self.pendingStart?.segment == index {
                        self.endPreview()
                    }
                } else if self.pendingStart?.segment == index {
                    self.fail(error)
                }
            }
        }
    }

    private func download(_ index: Int, from url: URL, token: UUID) {
        guard let manifest else { return }
        let generation = self.generation
        let name = "\(manifest.manifestId)-\(index)"
        downloadTasks[index] = ListenAudioDownloader.shared.download(url, name: name) { [weak self] result in
            guard let self, generation == self.generation, self.requests[index] == token else { return }
            self.downloadTasks[index] = nil
            switch result {
            case .success(let file):
                self.requests[index] = nil
                self.files[index] = file
                self.loadDuration(of: file, segment: index)
                self.segmentReady(index)
            case .failure(let error):
                self.requests[index] = nil
                NSLog("Listen segment %ld failed to download: %@", index, error as NSError)
                self.streamFailed(index)
            }
        }
    }

    /// A stream error gets one fresh /listen/segment request; the server doesn't charge twice within an hour.
    private func streamFailed(_ index: Int) {
        files[index] = nil
        if !retriedSegments.contains(index) {
            retriedSegments.insert(index)
            requestSegment(index)
        } else if pendingStart?.segment == index || segmentIndex == index {
            fail(.streamFailed)
        }
    }

    /// Holds segment requests until scrubbing or repeated skips stop for 300ms, then asks for the segment the
    /// position landed in, or the one after it when that segment is already here.
    private func settleSeek() {
        isSettlingSeek = true
        seekSettleWork?.cancel()
        let generation = self.generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == self.generation else { return }
            self.isSettlingSeek = false
            if let pendingStart = self.pendingStart {
                self.requestSegment(pendingStart.segment)
            } else {
                self.requestSegment(self.segmentIndex + 1)
            }
        }
        seekSettleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func loadDuration(of file: URL, segment: Int) {
        let generation = self.generation
        Task { @MainActor [weak self] in
            let asset = AVURLAsset(url: file)
            guard let time = try? await asset.load(.duration), time.isNumeric, time.seconds > 0 else { return }
            guard let self, generation == self.generation else { return }
            self.knownDurations[segment] = time.seconds
            self.recalculateDuration()
            self.updateNowPlaying()
        }
    }

    private func segmentReady(_ index: Int) {
        if let pendingStart, pendingStart.segment == index {
            startItem(segment: index, offset: pendingStart.offset)
        } else if let current = player.currentItem, itemSegments[ObjectIdentifier(current)] == index - 1 {
            appendNextIfReady()
        }
    }

    // MARK: - Player events

    private func tick() {
        guard manifest != nil else { return }
        if let item = player.currentItem, let segment = itemSegments[ObjectIdentifier(item)], pendingStart == nil,
           pendingItemSeeks[ObjectIdentifier(item)] == nil {
            let current = item.currentTime().seconds
            if current.isFinite {
                elapsed = segmentStart(segment) + max(0, current)
            }
        }
        countPlayedTime()
        guard let previewLimit, status == .playing else { return }
        let remaining = previewLimit - elapsed
        if remaining <= 0 {
            endPreview()
        } else if remaining <= 1.5 {
            // ListenPlayer.swift fades the last moment of a preview instead of cutting it off.
            player.volume = Float(max(0, remaining / 1.5))
        }
    }

    private func currentItemChanged() {
        guard let item = player.currentItem, let segment = itemSegments[ObjectIdentifier(item)] else { return }
        if wantsToPlay {
            // ListenPlayer.swift reclaims the session when the queue advances in case another feature took it.
            activateAudioSession()
        }
        if segment != segmentIndex {
            segmentIndex = segment
            elapsed = segmentStart(segment)
            NotificationCenter.default.post(name: Self.segmentDidChange, object: self)
            requestSegment(segment + 1)
            appendNextIfReady()
            updateNowPlaying()
        }
    }

    private func timeControlChanged() {
        guard wantsToPlay, pendingStart == nil else { return }
        switch player.timeControlStatus {
        case .playing:
            if status != .playing {
                setStatus(.playing)
                endBackgroundTask()
                updateNowPlaying()
            }
        case .waitingToPlayAtSpecifiedRate:
            if status == .playing {
                setStatus(.buffering)
            }
        default:
            break
        }
    }

    private func itemStatusChanged(_ item: AVPlayerItem) {
        let identifier = ObjectIdentifier(item)
        guard let segment = itemSegments[identifier] else { return }
        if item.status == .readyToPlay {
            let itemSeconds = item.duration.seconds
            if itemSeconds.isFinite, itemSeconds > 0, knownDurations[segment] == nil {
                knownDurations[segment] = itemSeconds
                recalculateDuration()
            }
            if let offset = pendingItemSeeks.removeValue(forKey: identifier) {
                let time = CMTime(seconds: offset, preferredTimescale: 600)
                item.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if self.wantsToPlay, self.player.currentItem === item {
                            self.startPlayback()
                        }
                        self.updateNowPlaying()
                    }
                }
            }
        } else if item.status == .failed {
            NSLog("Listen segment %ld failed to play: %@", segment, (item.error as NSError?) ?? NSError())
            let offset = player.currentItem === item ? max(0, item.currentTime().seconds) : 0
            if let file = files[segment] {
                try? FileManager.default.removeItem(at: file)
            }
            files[segment] = nil
            if player.currentItem === item {
                pendingStart = (segment, offset.isFinite ? offset : 0)
                clearQueue()
                if wantsToPlay {
                    setStatus(.buffering)
                }
            }
            streamFailed(segment)
        }
    }

    @objc private func itemDidPlayToEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }
        DispatchQueue.main.async { self.segmentFinished(item) }
    }

    @objc private func itemFailedToPlayToEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }
        DispatchQueue.main.async {
            guard let segment = self.itemSegments[ObjectIdentifier(item)] else { return }
            self.files[segment] = nil
            self.pendingStart = (segment, 0)
            self.clearQueue()
            self.streamFailed(segment)
        }
    }

    private func segmentFinished(_ item: AVPlayerItem) {
        guard let segment = itemSegments[ObjectIdentifier(item)], let manifest else { return }
        let identifier = ObjectIdentifier(item)
        itemSegments[identifier] = nil
        itemObservations[identifier] = nil
        if segment >= manifest.segments.count - 1 {
            if manifest.preview.isPreview {
                endPreview()
            } else {
                finishStory()
            }
            return
        }
        let nextQueued = player.items().contains { itemSegments[ObjectIdentifier($0)] == segment + 1 }
        if !nextQueued {
            prepare(segment: segment + 1, offset: 0)
        }
    }

    private func startPlayback() {
        activateAudioSession()
        player.defaultRate = Float(speed)
        player.playImmediately(atRate: Float(speed))
        if status != .playing {
            setStatus(player.currentItem?.status == .readyToPlay ? .playing : .buffering)
        }
        updateNowPlaying()
    }

    private func endPreview() {
        wantsToPlay = false
        player.pause()
        reportProgress()
        player.volume = 1
        elapsed = previewLimit ?? elapsed
        playbackError = nil
        setStatus(.previewEnded)
        updateNowPlaying()
        endBackgroundTask()
    }

    private func finishStory() {
        let finishedStory = story
        wantsToPlay = false
        countPlayedTime()
        reportProgress(finished: true)
        elapsed = duration
        setStatus(.finished)
        if let finishedStory {
            markRead(finishedStory)
        }
        updateNowPlaying()
        // ListenPlayer.swift plays Up Next first, then auto-continues through the story list.
        if let queued = takeQueuedStory() {
            continueTo(queued)
        } else if ListenPreferences.autoContinue, let next = upNextStories(limit: 1).first {
            continueTo(next)
        } else {
            endBackgroundTask()
        }
    }

    /// Plays `next`, and keeps the reader on the story being read when it was showing the one that just ended.
    private func continueTo(_ next: [String: Any]) {
        if let appDelegate, let pages = appDelegate.storyPagesViewController, let hash = storyHash,
           pages.currentPage?.activeStoryId == hash, let nextHash = next["story_hash"] as? String {
            let location = appDelegate.storiesCollection.location(ofStoryId: nextHash)
            if location >= 0 {
                pages.changePage(location, animated: true)
            }
        }
        start(story: next)
    }

    private func markRead(_ story: [String: Any]) {
        guard let hash = story["story_hash"] as? String, let appDelegate,
              let collection = appDelegate.storiesCollection else { return }
        let activeStories = (collection.activeFeedStories ?? []).compactMap { $0 as? [AnyHashable: Any] }
        let current = activeStories.first { ($0["story_hash"] as? String) == hash } ?? appDelegate.getStory(hash)
        if let current {
            guard collection.isStoryUnread(current) else { return }
            collection.markStoryRead(current)
            collection.syncStory(asRead: current)
            appDelegate.feedDetailViewController?.reload()
            if let page = appDelegate.storyPagesViewController?.currentPage, page.activeStoryId == hash {
                page.refreshHeader()
            }
        } else {
            collection.syncStory(asRead: story)
        }
    }

    private func fail(_ error: ListenAPIError) {
        wantsToPlay = false
        player.pause()
        let upgrade: ListenPlaybackError.Upgrade
        if error.isUpgradeReason {
            let tierUsage = error.usage ?? usage
            if error.reason == "cap_reached", tierUsage?.isPro == true {
                upgrade = .none
            } else if error.reason == "cap_reached", tierUsage?.isArchiveTier == true {
                upgrade = .pro
            } else {
                upgrade = .archive
            }
        } else {
            upgrade = .none
        }
        playbackError = ListenPlaybackError(message: error.message, upgrade: upgrade,
                                            retryable: !error.isUpgradeReason && error.reason != "no_text"
                                                && error.reason != "not_found")
        setStatus(.failed)
        updateNowPlaying()
        endBackgroundTask()
    }

    private func resetPlayback() {
        player.pause()
        clearQueue()
        for task in downloadTasks.values {
            task.cancel()
        }
        downloadTasks.removeAll()
        requests.removeAll()
        files.removeAll()
        knownDurations.removeAll()
        retriedSegments.removeAll()
        pendingStart = nil
        seekSettleWork?.cancel()
        seekSettleWork = nil
        isSettlingSeek = false
        // ListenPlayer.swift leaves a voice preview that's playing in voice settings alone.
        if let manifestId = manifest?.manifestId {
            ListenAudioDownloader.shared.removeFiles(withPrefix: manifestId)
        }
    }

    private func setStatus(_ newStatus: Status) {
        let changed = status != newStatus
        status = newStatus
        if changed {
            notifyState()
        }
    }

    private func notifyState() {
        NotificationCenter.default.post(name: Self.stateDidChange, object: self)
    }

    // MARK: - Listening analytics

    /// Adds the audio timeline that advanced through real playback since the last tick. Seeks, skips, paused and
    /// buffering time don't count, and a jump from a corrected segment duration is ignored.
    private func countPlayedTime() {
        guard status == .playing, wantsToPlay, pendingStart == nil, player.timeControlStatus == .playing else {
            lastPlayedPosition = nil
            return
        }
        if let last = lastPlayedPosition {
            let advanced = elapsed - last
            if advanced > 0, advanced < 1.5 {
                unreportedSeconds += advanced
            }
        }
        lastPlayedPosition = elapsed
        if Date().timeIntervalSince(lastReportDate) >= 30 {
            reportProgress()
        }
    }

    /// POST /listen/progress for Grafana's listening stats; fire-and-forget, never shown to the reader.
    private func reportProgress(finished: Bool = false) {
        lastReportDate = Date()
        let seconds = unreportedSeconds
        guard let manifestId = manifest?.manifestId, seconds >= 1 || finished else { return }
        unreportedSeconds = 0
        ListenAPI.shared.progress(manifestId: manifestId, seconds: seconds, speed: speed, finished: finished)
    }

    /// UIKit posts this on the main thread; the app delegate's request holds a background task until it's sent.
    @objc private func appDidEnterBackground() {
        countPlayedTime()
        reportProgress()
    }

    // MARK: - Audio session

    /// VoiceRecorder.swift (Ask AI) switches the session to recording, so every start restores spoken playback.
    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            NSLog("Listen couldn't activate the audio session: %@", error as NSError)
        }
    }

    @objc private func audioSessionInterrupted(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        DispatchQueue.main.async {
            switch type {
            case .began:
                guard self.isActive else { return }
                self.resumeAfterInterruption = self.wantsToPlay
                if self.wantsToPlay {
                    self.pause()
                }
            case .ended:
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if self.resumeAfterInterruption, options.contains(.shouldResume) {
                    self.play()
                }
                self.resumeAfterInterruption = false
            @unknown default:
                break
            }
        }
    }

    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
        // ListenPlayer.swift pauses when headphones are unplugged, like other spoken audio apps.
        DispatchQueue.main.async {
            if self.wantsToPlay {
                self.pause()
            }
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        // ListenPlayer.swift keeps fetching the next segment or story while no audio is playing in the background.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Listen") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Lock screen and media keys

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            self.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            self.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            self.togglePlayPause()
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            self.skip(by: -15)
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            self.skip(by: 30)
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self, self.isActive else { return .noActionableNowPlayingItem }
            guard self.hasNextStory else { return .noSuchContent }
            self.playNextStory()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, self.isActive, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: event.positionTime)
            return .success
        }
        center.previousTrackCommand.isEnabled = false
        setRemoteCommandsEnabled(false)
    }

    private func setRemoteCommandsEnabled(_ enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.skipBackwardCommand, center.skipForwardCommand, center.nextTrackCommand,
                        center.changePlaybackPositionCommand] {
            command.isEnabled = enabled
        }
    }

    private func updateNowPlaying() {
        guard isActive else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: storyTitle,
            MPMediaItemPropertyArtist: feedTitle,
            MPMediaItemPropertyAlbumTitle: "NewsBlur",
            MPMediaItemPropertyPlaybackDuration: previewLimit.map { min($0, duration) } ?? duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? speed : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = wantsToPlay ? .playing : .paused
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = hasNextStory
    }

    /// The feed's favicon on its own color, sized for the lock screen and Control Center.
    private func makeArtwork() -> MPMediaItemArtwork? {
        guard let feedId, let appDelegate, let favicon = appDelegate.getFavicon(feedId) else { return nil }
        let feed = appDelegate.getFeed(feedId) as? [String: Any]
        let color = (feed?["favicon_color"] as? String).flatMap { NewsBlurAppDelegate.faviconColor($0) }
            ?? UIColor(red: 0.89, green: 0.9, blue: 0.88, alpha: 1)
        let size = CGSize(width: 600, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            color.withAlphaComponent(0.45).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let iconSide = size.width * 0.42
            let iconRect = CGRect(x: (size.width - iconSide) / 2, y: (size.height - iconSide) / 2,
                                  width: iconSide, height: iconSide)
            context.cgContext.interpolationQuality = .high
            favicon.draw(in: iconRect)
        }
        return MPMediaItemArtwork(boundsSize: size) { _ in image }
    }

    // MARK: - Helpers

    private func feedTitle(forFeedId feedId: String?) -> String? {
        guard let feedId, let feed = appDelegate?.getFeed(feedId) as? [String: Any] else { return nil }
        return feed["feed_title"] as? String
    }

    static func stringKeyed(_ dictionary: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dictionary {
            if let key = key as? String {
                result[key] = value
            }
        }
        return result
    }

    static func decodedTitle(_ value: Any?) -> String {
        guard let title = value as? String else { return "" }
        return (title as NSString).decodingHTMLEntities() ?? title
    }
}
