//
//  ListenMediaPlayer.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation
import MediaPlayer
import UIKit

/// What ListenMediaPlayer.swift needs from ListenPlayer.swift, so a podcast and a story read aloud never play at
/// once and Up Next can hand a queued Listen story over.
protocol ListenSessionHandoff: AnyObject {
    var isActive: Bool { get }
    /// Stops without hiding the mini player or giving up the audio session; the story goes to History.
    func stopForHandoff()
    func play(queued item: ListenQueueItem)
}

/// ListenMediaPlayer.swift plays podcast episodes and other audio from stories in Listen's mini player, Now Playing,
/// lock screen and Control Center controls, instead of inside the story's web view. It shares the account's
/// playback state with the web (media_player_view.js) and Android through apps/media_player:
/// - an episode starts where any device left it, read from /media_player/playback_state when it starts;
/// - it becomes the current item as it starts (save_playback_state with the place it starts from), and is saved
///   paused again on pause, scrubbing, speed changes, going to the background, quitting, closing and when another
///   episode or a story read aloud takes over;
/// - while it plays, its place is synced every 10 seconds (media_player_view.js POSITION_SYNC_INTERVAL) through
///   sync_playback_position, which writes only Redis like the web's websocket. Once the server says another item is
///   current (code -1), syncing stops until this player saves the episode as current again;
/// - a finished episode goes to History and, with auto-play on, the first audio or Listen story in Up Next plays.
final class ListenMediaPlayer: NSObject, ObservableObject {
    static let shared: ListenMediaPlayer = ListenMediaPlayer(engine: ListenAVMediaEngine(), queue: .shared,
                                                             environment: .app)

    enum Status: Equatable {
        case idle
        case loading
        case buffering
        case playing
        case paused
        case finished
        case failed
    }

    /// The hooks into the app; Test_ListenMediaPlayer swaps them for recorders and a clock it controls.
    struct Environment {
        var now: () -> Date
        /// Runs `work` after `delay` seconds on the main queue.
        var schedule: (TimeInterval, @escaping () -> Void) -> Void
        var showMiniPlayer: () -> Void
        var hideMiniPlayer: () -> Void
        /// Lets the story pages, the Mac toolbar and the remote commands know the player changed.
        var stateDidChange: () -> Void
        var publishesNowPlaying: Bool
        var listenSession: () -> ListenSessionHandoff?
        var feedTitle: (String?) -> String?
        var activateAudioSession: () -> Void
        var deactivateAudioSession: () -> Void

        static let app: Environment = Environment(
            now: Date.init,
            schedule: { delay, work in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work) },
            showMiniPlayer: { ListenMiniPlayerController.shared.show() },
            hideMiniPlayer: { ListenMiniPlayerController.shared.hide() },
            stateDidChange: {
                NotificationCenter.default.post(name: ListenPlayer.stateDidChange, object: nil)
                ListenRemoteCommands.shared.refresh()
            },
            publishesNowPlaying: true,
            listenSession: { ListenPlayer.shared },
            feedTitle: { feedId in
                guard let feedId, let feed = NewsBlurAppDelegate.shared()?.getFeed(feedId) as? [String: Any] else { return nil }
                return feed["feed_title"] as? String
            },
            activateAudioSession: { ListenPlayer.shared.activateAudioSession(forNarration: false) },
            deactivateAudioSession: {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        )
    }

    /// media_player_view.js POSITION_SYNC_INTERVAL.
    static let positionSaveInterval: TimeInterval = 10
    /// How long an episode waits for the server to say where it was left before starting from what's cached.
    static let playbackStateTimeout: TimeInterval = 4
    /// A save that didn't make the episode current is tried again after 5, 10, 20 and 40 seconds, then every minute.
    static let saveRetryDelay: TimeInterval = 5
    static let saveRetryMaximumDelay: TimeInterval = 60

    @Published private(set) var item: ListenMediaItem?
    @Published private(set) var status: Status = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var speed: Double = 1
    @Published private(set) var feedTitle = ""
    @Published private(set) var errorMessage: String?
    /// True while the user wants audio (playing, or waiting for it to arrive).
    @Published private(set) var wantsToPlay = false

    private let engine: ListenMediaEngine
    private let queue: ListenQueue
    private let environment: Environment
    private var generation = 0
    /// True from an episode's start until the server's playback state (or the timeout) says where it begins.
    private var isWaitingForState = false
    private var pendingSeek: TimeInterval?
    private var lastPositionSave: Date?
    private var artwork: MPMediaItemArtwork?
    private var resumeAfterInterruption = false

    private enum PositionSync {
        /// Until the start save lands, the server would refuse a sync for an item it doesn't know is current.
        case waitingForSave
        case syncing
        /// Another device made something else current; sync_playback_position answered code -1.
        case stopped
    }

    private var positionSync = PositionSync.waitingForSave
    /// Failed tries at making the episode current, for the retry backoff (retrySaveLater).
    private var saveRetryAttempts = 0
    /// The generation a save retry is waiting to run for, so an episode started after one whose retry is still
    /// pending gets its own, and that stale retry can't cancel it.
    private var saveRetryGeneration: Int?
    /// Whether the podcast speed was changed here, which is the only time a save carries current_playback_rate.
    private var speedChosenHere = false
    /// The file this app last saved as the server's current item. It went to History when it stopped here, so
    /// ListenPlaybackState.replacedItem leaves it alone.
    private var lastSavedMediaURL: String?

    /// The app uses `shared`; Test_ListenMediaPlayer makes its own player in front of a fake engine and server.
    init(engine: ListenMediaEngine, queue: ListenQueue, environment: Environment) {
        self.engine = engine
        self.queue = queue
        self.environment = environment
        super.init()
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(applicationDidEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(applicationWillTerminate),
                           name: UIApplication.willTerminateNotification, object: nil)
        center.addObserver(self, selector: #selector(queueDidChange), name: ListenQueue.didChange, object: queue)
        center.addObserver(self, selector: #selector(audioSessionInterrupted(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(audioRouteChanged(_:)),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }

    // MARK: - State

    var isActive: Bool { item != nil }

    var settings: ListenPlaybackSettings { queue.settings }

    func isLoaded(_ media: ListenMediaItem?) -> Bool {
        item?.isSame(as: media) ?? false
    }

    func isPlaying(_ media: ListenMediaItem?) -> Bool {
        isLoaded(media) && wantsToPlay
    }

    /// Whether the next-track command and Now Playing's Next have anything to play.
    var hasNextTrack: Bool {
        queue.playableItems.contains { queued in
            !(item.map { $0.storyHash == queued.storyHash && $0.mediaURL == queued.mediaURL } ?? false)
        }
    }

    /// Up Next while an episode plays: what this device can play from the shared queue.
    var upNextItems: [ListenQueueItem] { queue.playableItems }

    // MARK: - Controls

    /// A story's audio card: plays the episode, or pauses and resumes it when it's the one loaded.
    func toggle(_ media: ListenMediaItem) {
        if isLoaded(media) {
            togglePlayPause()
        } else {
            start(media)
        }
    }

    /// Plays `media` from where any device left it (ListenPlaybackState.resumePosition).
    func start(_ media: ListenMediaItem) {
        guard media.url != nil else { return }
        if let previous = item, !previous.isSame(as: media), status != .finished {
            // media_player_view.js play_media: what was playing is saved paused and goes to History with its place,
            // both before the new episode becomes current (ListenQueue.swift sends them in order).
            save(previous, position: currentPosition, isPlaying: false)
            queue.addToHistory(media: previous, position: currentPosition, duration: duration)
        }
        if let listen = environment.listenSession(), listen.isActive {
            listen.stopForHandoff()
        }
        if queue.contains(media: media) {
            queue.remove(media: media)
        }
        generation += 1
        let generation = self.generation
        engine.unload()
        item = media
        elapsed = 0
        duration = media.duration ?? 0
        speed = queue.playbackState?.currentPlaybackRate ?? speed
        feedTitle = environment.feedTitle(media.feedId) ?? ""
        artwork = environment.publishesNowPlaying ? ListenArtwork.make(feedId: media.feedId) : nil
        errorMessage = nil
        wantsToPlay = true
        pendingSeek = nil
        lastPositionSave = nil
        positionSync = .waitingForSave
        saveRetryAttempts = 0
        saveRetryGeneration = nil
        isWaitingForState = true
        status = .loading
        environment.showMiniPlayer()
        stateChanged()
        queue.fetchPlaybackState { [weak self] state in
            // ListenMediaPlayer.swift: a failed read falls back to the state cached from the last one.
            guard let self else { return }
            self.playbackStateArrived(state ?? self.queue.playbackState, generation: generation)
        }
        environment.schedule(Self.playbackStateTimeout) { [weak self] in
            guard let self, generation == self.generation, self.isWaitingForState else { return }
            NSLog("Listen started audio without the server's playback state")
            self.playbackStateArrived(self.queue.playbackState, generation: generation)
        }
    }

    /// Starts the engine at the saved place once the server has answered, or the timeout used the cached state.
    private func playbackStateArrived(_ state: ListenPlaybackState?, generation: Int) {
        guard generation == self.generation, isWaitingForState, let item, let url = item.url else { return }
        isWaitingForState = false
        let resume = pendingSeek ?? state?.resumePosition(for: item) ?? 0
        pendingSeek = nil
        if let rate = state?.currentPlaybackRate {
            speed = rate
        }
        if duration <= 0, let known = state?.savedPosition(for: item)?.duration, known > 0 {
            // ListenMediaPlayer.swift shows the length another device saw until the stream reports its own.
            duration = known
        }
        elapsed = resume
        if let replaced = state?.replacedItem(by: item, savedHere: lastSavedMediaURL) {
            queue.addToHistory(media: replaced.mediaItem, position: replaced.position, duration: replaced.duration)
        }
        engine.load(url, startAt: resume)
        if wantsToPlay {
            environment.activateAudioSession()
            engine.play(rate: speed)
            status = .buffering
        } else {
            status = .paused
        }
        // media_player_view.js play_media saves the new current item at once, so other devices see what plays.
        savePosition(isPlaying: wantsToPlay)
        stateChanged()
    }

    func play() {
        guard isActive else { return }
        switch status {
        case .failed:
            retry()
            return
        case .finished:
            wantsToPlay = true
            seek(to: 0)
        default:
            wantsToPlay = true
        }
        if isWaitingForState {
            status = .loading
        } else {
            environment.activateAudioSession()
            engine.play(rate: speed)
            if status != .playing {
                status = .buffering
            }
        }
        stateChanged()
    }

    func pause() {
        guard isActive else { return }
        wantsToPlay = false
        engine.pause()
        if status == .playing || status == .buffering || status == .loading {
            status = .paused
        }
        savePosition(isPlaying: false)
        stateChanged()
    }

    func togglePlayPause() {
        wantsToPlay ? pause() : play()
    }

    /// Back by the skip_back_seconds chosen on the web (15 by default).
    func skipBackward() {
        seek(to: currentPosition - TimeInterval(settings.skipBackSeconds))
    }

    /// Forward by skip_forward_seconds (30 by default), never past the end.
    func skipForward() {
        seek(to: currentPosition + TimeInterval(settings.skipForwardSeconds))
    }

    /// `save` is for scrubbing, which media_player_view.js on_seek saves at once; skips wait for the next save.
    func seek(to time: TimeInterval, save: Bool = false) {
        guard isActive else { return }
        var target = max(0, time)
        if duration > 0 {
            target = min(target, duration)
        }
        elapsed = target
        if isWaitingForState {
            pendingSeek = target
        } else {
            engine.seek(to: target)
        }
        if status == .finished {
            status = .paused
        }
        if save {
            savePosition(isPlaying: wantsToPlay)
        }
        stateChanged()
    }

    func setSpeed(_ newSpeed: Double) {
        guard isActive else { return }
        speed = ListenSpeed.clamped(newSpeed)
        speedChosenHere = true
        engine.setRate(speed)
        // media_player_view.js set_playback_rate saves the podcast speed as current_playback_rate.
        savePosition(isPlaying: wantsToPlay)
        stateChanged()
    }

    func retry() {
        guard let media = item else { return }
        let position = elapsed
        generation += 1
        errorMessage = nil
        wantsToPlay = true
        status = .buffering
        guard let url = media.url else { return }
        engine.load(url, startAt: position)
        environment.activateAudioSession()
        engine.play(rate: speed)
        stateChanged()
    }

    /// The mini player's close button. The place is saved as paused rather than cleared: the web's close wipes the
    /// whole state (apps/media_player clear_playback_state), queue and History included, which would lose the
    /// place this player exists to keep. The episode also goes to History, as Android does when it stops one: once
    /// the next episode replaces it as the current item, History is the only place left that remembers where it
    /// stopped (ListenPlaybackState.replacedItem skips an item this app saved, expecting it there).
    func stop(saving: Bool = true) {
        guard let media = item else { return }
        if saving, !isWaitingForState, status != .finished {
            savePosition(isPlaying: false)
            queue.addToHistory(media: media, position: elapsed, duration: duration)
        }
        clearSession()
        environment.hideMiniPlayer()
        environment.deactivateAudioSession()
        if environment.publishesNowPlaying {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        stateChanged()
    }

    /// Listen is starting a story (ListenPlayer.swift start(story:)). The episode is saved paused and goes to
    /// History with its place, where ListenPlaybackState.resumePosition finds it next time. Listen's own save as the
    /// current item follows these in ListenQueue.swift's order, so the story ends up current.
    func stopForHandoff() {
        guard let media = item else { return }
        if status != .finished {
            save(media, position: currentPosition, isPlaying: false)
            queue.addToHistory(media: media, position: currentPosition, duration: duration)
        }
        clearSession()
        stateChanged()
    }

    /// The next-track command and Now Playing's Next: the first audio or Listen story in Up Next.
    func playNextTrack() {
        guard let next = queue.takeFirstPlayableItem(excludingId: item.map { ListenQueueItem(media: $0).id }) else { return }
        play(queued: next)
    }

    /// A row in Up Next: an episode plays here, a story read aloud goes to ListenPlayer.swift.
    func play(queued entry: ListenQueueItem) {
        if let media = ListenMediaItem(queueItem: entry) {
            start(media)
        } else if entry.isListen, let listen = environment.listenSession() {
            listen.play(queued: entry)
        }
    }

    private var currentPosition: TimeInterval {
        isWaitingForState ? (pendingSeek ?? elapsed) : elapsed
    }

    private func clearSession() {
        generation += 1
        engine.unload()
        item = nil
        status = .idle
        elapsed = 0
        duration = 0
        feedTitle = ""
        errorMessage = nil
        wantsToPlay = false
        isWaitingForState = false
        pendingSeek = nil
        lastPositionSave = nil
        positionSync = .waitingForSave
        saveRetryAttempts = 0
        saveRetryGeneration = nil
        artwork = nil
    }

    // MARK: - Engine events

    private func handle(_ event: ListenMediaEngineEvent) {
        guard isActive, !isWaitingForState else { return }
        switch event {
        case .ready(let length):
            if length > 0 {
                duration = length
            }
            if !wantsToPlay, status != .failed {
                status = .paused
            }
            stateChanged()
        case .playing:
            guard wantsToPlay else { return }
            if status != .playing {
                status = .playing
                stateChanged()
            }
        case .waiting:
            if status == .playing {
                status = .buffering
                stateChanged()
            }
        case .time(let time):
            elapsed = duration > 0 ? min(time, duration) : time
            saveIfDue()
        case .duration(let length):
            duration = length
            updateNowPlaying()
        case .finished:
            finishEpisode()
        case .failed:
            wantsToPlay = false
            status = .failed
            errorMessage = NBLocalization.text("This audio couldn't be played.")
            stateChanged()
        }
    }

    /// The throttled update while playing: one sync_playback_position per positionSaveInterval since the last
    /// sync or save.
    private func saveIfDue() {
        guard wantsToPlay, status == .playing, positionSync == .syncing, let item, !isWaitingForState else { return }
        if let last = lastPositionSave, environment.now().timeIntervalSince(last) < Self.positionSaveInterval {
            return
        }
        lastPositionSave = environment.now()
        let generation = self.generation
        queue.syncPlaybackPosition(mediaURL: item.mediaURL, position: elapsed, duration: duration, playbackRate: speed,
                                   isPlaying: true) { [weak self] result in
            guard let self, generation == self.generation, result == .rejected else { return }
            // ListenMediaPlayer.swift: another device took over, so this one stops moving its position.
            NSLog("Listen stopped syncing: another item is current")
            self.positionSync = .stopped
        }
    }

    /// media_player_view.js play_next: History gets the finished episode, then Up Next plays on when auto-play is
    /// on. Otherwise the player stays on the episode, finished, and its end is saved.
    private func finishEpisode() {
        guard let finished = item else { return }
        let length = duration > 0 ? duration : elapsed
        elapsed = length
        status = .finished
        queue.addToHistory(media: finished, position: length, duration: length)
        if settings.autoPlayNext, let next = queue.takeFirstPlayableItem(excludingId: ListenQueueItem(media: finished).id) {
            play(queued: next)
            return
        }
        wantsToPlay = false
        savePosition(isPlaying: false)
        stateChanged()
    }

    private func savePosition(isPlaying: Bool) {
        guard let item, !isWaitingForState else { return }
        lastPositionSave = environment.now()
        let generation = self.generation
        save(item, position: elapsed, isPlaying: isPlaying) { [weak self] saved in
            guard let self, generation == self.generation else { return }
            if saved {
                // ListenMediaPlayer.swift: the episode is the server's current item again, so its position may sync.
                self.positionSync = .syncing
                self.saveRetryAttempts = 0
            } else if self.positionSync == .waitingForSave {
                self.retrySaveLater(generation: generation)
            }
        }
    }

    /// The save that makes an episode current didn't reach the server (the phone was offline as it started, say), and
    /// syncs only go out once it has. It's tried again with growing waits until it lands, saving the place the
    /// episode has reached by then. A retry for an episode that was handed off, closed or replaced since
    /// (`generation` moved on), or that a later save already made current, does nothing.
    private func retrySaveLater(generation: Int) {
        guard saveRetryGeneration != generation else { return }
        saveRetryGeneration = generation
        let delay = min(Self.saveRetryMaximumDelay, Self.saveRetryDelay * pow(2, Double(saveRetryAttempts)))
        saveRetryAttempts += 1
        environment.schedule(delay) { [weak self] in
            guard let self, self.saveRetryGeneration == generation else { return }
            self.saveRetryGeneration = nil
            guard generation == self.generation, self.isActive, self.positionSync == .waitingForSave else { return }
            self.savePosition(isPlaying: self.wantsToPlay)
        }
    }

    /// save_playback_state for `media`, with the podcast rate only once it was changed here.
    private func save(_ media: ListenMediaItem, position: TimeInterval, isPlaying: Bool,
                      completion: ((Bool) -> Void)? = nil) {
        lastSavedMediaURL = media.mediaURL
        queue.savePlaybackState(media.stateParameters(position: position, duration: media.isSame(as: item) ? duration : 0,
                                                      isPlaying: isPlaying,
                                                      playbackRate: speedChosenHere ? speed : nil),
                                completion: completion)
    }

    // MARK: - App lifecycle

    /// The web resumes from the last save, so the place goes out as the app leaves the screen.
    @objc func applicationDidEnterBackground() {
        guard isActive else { return }
        savePosition(isPlaying: wantsToPlay)
    }

    @objc func applicationWillTerminate() {
        guard isActive else { return }
        savePosition(isPlaying: false)
    }

    /// A call or another app's audio pauses the episode, and it carries on afterwards when iOS says it should.
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
                if self.resumeAfterInterruption, self.isActive,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    self.play()
                }
                self.resumeAfterInterruption = false
            @unknown default:
                break
            }
        }
    }

    /// Unplugged headphones pause the episode, like other podcast apps (ListenPlayer.swift does the same).
    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async {
            if self.wantsToPlay {
                self.pause()
            }
        }
    }

    @objc private func queueDidChange() {
        // Up Next and the skip intervals feed the next-track button and the lock screen skips.
        stateChanged()
    }

    // MARK: - Now Playing

    private func stateChanged() {
        updateNowPlaying()
        environment.stateDidChange()
    }

    private func updateNowPlaying() {
        guard environment.publishesNowPlaying, let item else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: feedTitle,
            MPMediaItemPropertyAlbumTitle: "NewsBlur",
            MPMediaItemPropertyPlaybackDuration: duration,
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
    }
}

extension ListenMediaPlayer: ListenRemoteControllable {
    var canSeek: Bool { isActive && status != .failed }

    func seek(toRemotePosition time: TimeInterval) {
        seek(to: time, save: true)
    }
}
