//
//  ListenRemoteCommands.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import MediaPlayer
import UIKit

/// A player the lock screen, Control Center, CarPlay, headphone buttons and the Mac's media keys can control:
/// ListenPlayer.swift reading a story aloud or ListenMediaPlayer.swift playing a podcast. Only one is active at once.
protocol ListenRemoteControllable: AnyObject {
    var isActive: Bool { get }
    var wantsToPlay: Bool { get }
    var canSeek: Bool { get }
    var hasNextTrack: Bool { get }
    func play()
    func pause()
    func togglePlayPause()
    func skipBackward()
    func skipForward()
    func seek(toRemotePosition time: TimeInterval)
    func playNextTrack()
}

/// ListenRemoteCommands.swift owns MPRemoteCommandCenter for both players, so each command has one handler and goes
/// to whichever player is active. The skip buttons use the skip_back_seconds and skip_forward_seconds the web's
/// player settings save (15 and 30 by default), for podcasts and stories read aloud alike, as on the web.
final class ListenRemoteCommands {
    static let shared: ListenRemoteCommands = ListenRemoteCommands(sessions: { [ListenMediaPlayer.shared, ListenPlayer.shared] },
                                             settings: { ListenQueue.shared.settings })

    enum Command: Equatable {
        case play
        case pause
        case togglePlayPause
        case skipBackward
        case skipForward
        case nextTrack
        case changePosition(TimeInterval)
    }

    private let sessions: () -> [ListenRemoteControllable]
    private let settings: () -> ListenPlaybackSettings
    private var isConfigured = false

    /// Test_ListenMediaPlayer builds one around its own players and never touches the shared command center.
    init(sessions: @escaping () -> [ListenRemoteControllable], settings: @escaping () -> ListenPlaybackSettings) {
        self.sessions = sessions
        self.settings = settings
    }

    var activeSession: ListenRemoteControllable? {
        sessions().first { $0.isActive }
    }

    /// The lock screen's skip buttons, in seconds.
    var skipIntervals: (backward: Int, forward: Int) {
        let settings = settings()
        return (settings.skipBackSeconds, settings.skipForwardSeconds)
    }

    func handle(_ command: Command) -> MPRemoteCommandHandlerStatus {
        guard let session = activeSession else { return .noActionableNowPlayingItem }
        switch command {
        case .play:
            session.play()
        case .pause:
            session.pause()
        case .togglePlayPause:
            session.togglePlayPause()
        case .skipBackward:
            session.skipBackward()
        case .skipForward:
            session.skipForward()
        case .nextTrack:
            guard session.hasNextTrack else { return .noSuchContent }
            session.playNextTrack()
        case .changePosition(let time):
            guard session.canSeek else { return .commandFailed }
            session.seek(toRemotePosition: time)
        }
        return .success
    }

    /// Either player changed: commands follow the active one, and the skip intervals follow the server's settings.
    /// Targets are added on the first call, which comes from a player starting, never from a player's init.
    func refresh() {
        let center = MPRemoteCommandCenter.shared()
        configure(center)
        let session = activeSession
        let enabled = session != nil
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.skipBackwardCommand, center.skipForwardCommand] {
            command.isEnabled = enabled
        }
        let intervals = skipIntervals
        let backward = [NSNumber(value: intervals.backward)]
        let forward = [NSNumber(value: intervals.forward)]
        if center.skipBackwardCommand.preferredIntervals != backward {
            center.skipBackwardCommand.preferredIntervals = backward
        }
        if center.skipForwardCommand.preferredIntervals != forward {
            center.skipForwardCommand.preferredIntervals = forward
        }
        center.nextTrackCommand.isEnabled = session?.hasNextTrack ?? false
        center.changePlaybackPositionCommand.isEnabled = session?.canSeek ?? false
        center.previousTrackCommand.isEnabled = false
    }

    private func configure(_ center: MPRemoteCommandCenter) {
        guard !isConfigured else { return }
        isConfigured = true
        let commands: [(MPRemoteCommand, Command)] = [
            (center.playCommand, .play),
            (center.pauseCommand, .pause),
            (center.togglePlayPauseCommand, .togglePlayPause),
            (center.skipBackwardCommand, .skipBackward),
            (center.skipForwardCommand, .skipForward),
            (center.nextTrackCommand, .nextTrack)
        ]
        for (command, action) in commands {
            command.addTarget { [weak self] _ in
                self?.handle(action) ?? .commandFailed
            }
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return self.handle(.changePosition(event.positionTime))
        }
    }
}

/// The lock screen and Control Center artwork for a story or episode: the feed's favicon on its own color
/// (ListenRemoteCommands.swift).
enum ListenArtwork {
    static func make(feedId: String?) -> MPMediaItemArtwork? {
        guard let feedId, let appDelegate = NewsBlurAppDelegate.shared(),
              let favicon = appDelegate.getFavicon(feedId) else { return nil }
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
}
