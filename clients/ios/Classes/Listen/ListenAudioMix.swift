//
//  ListenAudioMix.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-02.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation
import Foundation

/// ListenAudioMix.swift decides how Listen's voice shares the speaker with music from other apps (the Music app,
/// Spotify, podcasts): whether Listen plays over that music instead of pausing it, whether the music is lowered while
/// the voice speaks, and the Music / Voice balance.
/// These settings depend on this device's audio, so they live only in NSUserDefaults and never sync through
/// ListenPreferences.swift.
enum ListenAudioMix {
    /// Posted when playing over other audio or lowering the music changes, so ListenPlayer.swift can reconfigure the
    /// audio session.
    static let didChange = Notification.Name("ListenAudioMixDidChange")
    /// Posted as the balance slider moves, so ListenPlayer.swift only changes the voice's volume.
    static let voiceVolumeDidChange = Notification.Name("ListenAudioMixVoiceVolumeDidChange")

    static let playOverOtherAudioKey = "listen_play_over_other_audio"
    static let lowersMusicKey = "listen_lower_music_while_speaking"
    static let voiceVolumeKey = "listen_voice_volume"
    static let musicSectionCollapsedKey = "listen_music_section_collapsed"

    /// The quietest the voice goes with the balance all the way toward Music (-40 dB), nearly silent but never off.
    static let minimumVoiceVolume = 0.01
    /// The loudest the voice goes with the balance all the way toward Voice (+20 dB), boosted past 100% by
    /// ListenVoiceBoost.swift. NewsBlur can't turn another app's music down, so this is how far above the music the
    /// voice can get, on top of lowering the music while it speaks.
    static let maximumVoiceVolume = 10.0

    private static var defaults: UserDefaults { .standard }

    /// Playing over other audio needs iOS's audio session; a Mac mixes apps on its own.
    static var isAvailable: Bool {
        !(ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac)
    }

    /// Keep music from other apps playing when Listen starts. Off by default, since iOS only shows Listen on the lock
    /// screen and responds to headphone buttons when it doesn't mix.
    static var playsOverOtherAudio: Bool {
        get { isAvailable && defaults.bool(forKey: playOverOtherAudioKey) }
        set { store(newValue, forKey: playOverOtherAudioKey) }
    }

    /// Lower the other app's music while the voice speaks. On by default.
    static var lowersMusicWhileSpeaking: Bool {
        get { defaults.object(forKey: lowersMusicKey) == nil || defaults.bool(forKey: lowersMusicKey) }
        set { store(newValue, forKey: lowersMusicKey) }
    }

    /// The balance slider's voice volume relative to the device volume, from minimumVoiceVolume to
    /// maximumVoiceVolume. Up to 1 it's the player's volume; above 1 it's boosted (ListenVoiceBoost.swift).
    static var voiceVolume: Double {
        get { clampedVoiceVolume(defaults.object(forKey: voiceVolumeKey) as? Double ?? 1) }
        set { store(clampedVoiceVolume(newValue), forKey: voiceVolumeKey, notification: voiceVolumeDidChange) }
    }

    /// The voice's volume right now: the balance only applies while Listen plays over other audio, where its slider
    /// is shown, so a voice turned down there can't stay quiet once the slider is hidden.
    static var effectiveVoiceVolume: Double {
        playsOverOtherAudio ? voiceVolume : 1
    }

    /// The Music section in Now Playing (ListenMusicCard.swift) stays collapsed once someone collapses it.
    static var isMusicSectionCollapsed: Bool {
        get { defaults.bool(forKey: musicSectionCollapsedKey) }
        set { defaults.set(newValue, forKey: musicSectionCollapsedKey) }
    }

    static func clampedVoiceVolume(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(maximumVoiceVolume, max(minimumVoiceVolume, value))
    }

    /// The Music / Voice balance slider's position for a voice volume: -1 all the way toward Music, 0 in the middle
    /// (the voice at 100%), 1 all the way toward Voice. Each side is even in decibels, so the slider moves the
    /// loudness steadily.
    static func balance(forVoiceVolume volume: Double) -> Double {
        let decibels = 20 * log10(clampedVoiceVolume(volume))
        let maximumDecibels = 20 * log10(maximumVoiceVolume)
        let minimumDecibels = 20 * log10(minimumVoiceVolume)
        return decibels >= 0 ? decibels / maximumDecibels : -decibels / minimumDecibels
    }

    static func voiceVolume(forBalance balance: Double) -> Double {
        let position = min(1, max(-1, balance.isFinite ? balance : 0))
        let edge = position >= 0 ? maximumVoiceVolume : minimumVoiceVolume
        return clampedVoiceVolume(pow(10, abs(position) * 20 * log10(edge) / 20))
    }

    /// The route sharing policy and category options for Listen's .playback session. Long-form audio can't mix, so
    /// a mixing session uses the default policy.
    static func sessionConfiguration(mixes: Bool, lowersMusic: Bool)
        -> (policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions) {
        guard mixes else { return (.longFormAudio, []) }
        return (.default, lowersMusic ? [.mixWithOthers, .duckOthers] : [.mixWithOthers])
    }

    private static func store(_ value: Any, forKey key: String, notification: Notification.Name = didChange) {
        if let current = defaults.object(forKey: key) as? NSObject, let new = value as? NSObject, current.isEqual(new) {
            return
        }
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
