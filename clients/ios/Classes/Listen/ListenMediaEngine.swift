//
//  ListenMediaEngine.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation

/// What the audio engine under ListenMediaPlayer.swift reports, always on the main thread.
enum ListenMediaEngineEvent: Equatable {
    /// The episode can play, already at the place it was loaded to start from.
    case ready(duration: TimeInterval)
    case playing
    case waiting
    /// The playhead, about twice a second while an episode is loaded.
    case time(TimeInterval)
    case duration(TimeInterval)
    case finished
    case failed(String?)
}

/// Plays one remote audio file for ListenMediaPlayer.swift. Test_ListenMediaPlayer drives a fake one, so the
/// player's rules are tested without the network or AVFoundation.
protocol ListenMediaEngine: AnyObject {
    var onEvent: ((ListenMediaEngineEvent) -> Void)? { get set }
    var currentTime: TimeInterval { get }
    /// Loads `url` to start at `startAt` seconds. Nothing plays until play(rate:).
    func load(_ url: URL, startAt: TimeInterval)
    func play(rate: Double)
    func pause()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Double)
    func unload()
}

/// ListenMediaEngine.swift's AVPlayer engine. It streams the enclosure, waits to start until the seek to a resumed
/// position has landed (so the first seconds of the episode never play), and keeps speech pitch-corrected at any
/// speed like ListenPlayer.swift.
final class ListenAVMediaEngine: NSObject, ListenMediaEngine {
    var onEvent: ((ListenMediaEngineEvent) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private var pendingStart: TimeInterval?
    private var isReady = false
    private var wantsToPlay = false
    private var rate: Double = 1

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: .main) { [weak self] time in
            guard let self, self.player.currentItem != nil, self.isReady, time.isNumeric else { return }
            self.onEvent?(.time(max(0, time.seconds)))
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.timeControlChanged() }
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(itemDidPlayToEnd(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        center.addObserver(self, selector: #selector(itemFailedToPlayToEnd(_:)), name: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil)
    }

    var currentTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    func load(_ url: URL, startAt: TimeInterval) {
        unload()
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        pendingStart = startAt > 0.5 ? startAt : nil
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.statusChanged(item) }
        }
        durationObservation = item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, item === self.player.currentItem else { return }
                let seconds = Self.seconds(item.duration)
                if seconds > 0 {
                    self.onEvent?(.duration(seconds))
                }
            }
        }
        player.replaceCurrentItem(with: item)
    }

    func play(rate: Double) {
        wantsToPlay = true
        self.rate = rate
        player.defaultRate = Float(rate)
        // ListenMediaEngine.swift holds playback until a resumed episode has reached its saved place.
        guard isReady || pendingStart == nil, player.currentItem != nil else { return }
        player.play()
    }

    func pause() {
        wantsToPlay = false
        player.pause()
    }

    func seek(to time: TimeInterval) {
        guard player.currentItem != nil else { return }
        if !isReady {
            pendingStart = time
            return
        }
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: max(0, time), preferredTimescale: 600), toleranceBefore: tolerance,
                    toleranceAfter: tolerance)
    }

    func setRate(_ rate: Double) {
        self.rate = rate
        player.defaultRate = Float(rate)
        if wantsToPlay, player.timeControlStatus != .paused {
            player.rate = Float(rate)
        }
    }

    func unload() {
        wantsToPlay = false
        isReady = false
        pendingStart = nil
        statusObservation = nil
        durationObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - AVPlayer events

    private func statusChanged(_ item: AVPlayerItem) {
        guard item === player.currentItem else { return }
        switch item.status {
        case .readyToPlay:
            guard !isReady else { return }
            if let start = pendingStart {
                pendingStart = nil
                item.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero,
                          toleranceAfter: .zero) { [weak self] _ in
                    DispatchQueue.main.async { self?.becameReady(item) }
                }
            } else {
                becameReady(item)
            }
        case .failed:
            NSLog("Listen couldn't play audio: %@", (item.error as NSError?) ?? NSError())
            onEvent?(.failed(item.error?.localizedDescription))
        default:
            break
        }
    }

    private func becameReady(_ item: AVPlayerItem) {
        guard item === player.currentItem, !isReady else { return }
        isReady = true
        onEvent?(.ready(duration: Self.seconds(item.duration)))
        if let start = pendingStart {
            // A seek made while the item was still loading.
            pendingStart = nil
            seek(to: start)
        }
        if wantsToPlay {
            player.defaultRate = Float(rate)
            player.play()
        }
    }

    private func timeControlChanged() {
        guard player.currentItem != nil, wantsToPlay else { return }
        switch player.timeControlStatus {
        case .playing:
            onEvent?(.playing)
        case .waitingToPlayAtSpecifiedRate:
            onEvent?(.waiting)
        default:
            break
        }
    }

    @objc private func itemDidPlayToEnd(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let item = notification.object as? AVPlayerItem, item === self.player.currentItem else { return }
            self.wantsToPlay = false
            self.onEvent?(.finished)
        }
    }

    @objc private func itemFailedToPlayToEnd(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let item = notification.object as? AVPlayerItem, item === self.player.currentItem else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            NSLog("Listen audio stopped before its end: %@", error ?? NSError())
            self.onEvent?(.failed(error?.localizedDescription))
        }
    }

    private static func seconds(_ time: CMTime) -> TimeInterval {
        guard time.isNumeric, !time.isIndefinite else { return 0 }
        let seconds = time.seconds
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }
}
