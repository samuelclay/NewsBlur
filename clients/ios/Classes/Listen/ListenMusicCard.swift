//
//  ListenMusicCard.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-02.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// ListenMusicCard.swift is the Music section in Listen's Now Playing screen (ListenNowPlayingView.swift): Play over
/// other audio, which keeps music from the Music app or Spotify playing under the voice, then lowering that music
/// while the voice speaks and the Music / Voice balance (ListenAudioMix.swift). The chevron collapses the section,
/// and it stays collapsed.
struct ListenMusicCard: View {
    @ObservedObject private var theme = ListenThemeObserver.shared
    @State private var isCollapsed = ListenAudioMix.isMusicSectionCollapsed
    @State private var playsOverOtherAudio = ListenAudioMix.playsOverOtherAudio
    @State private var lowersMusic = ListenAudioMix.lowersMusicWhileSpeaking
    @State private var balance = ListenAudioMix.balance(forVoiceVolume: ListenAudioMix.voiceVolume)

    var body: some View {
        let _ = theme.version
        VStack(alignment: .leading, spacing: 8) {
            header
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 14) {
                    playOverToggle
                    if playsOverOtherAudio {
                        lowerMusicToggle
                            .transition(.opacity)
                        balanceSlider
                            .transition(.opacity)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ListenColors.card))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .tint(ListenColors.accent)
        .accessibilityIdentifier("listen-music-card")
        .onAppear {
            isCollapsed = ListenAudioMix.isMusicSectionCollapsed
            playsOverOtherAudio = ListenAudioMix.playsOverOtherAudio
            lowersMusic = ListenAudioMix.lowersMusicWhileSpeaking
            balance = ListenAudioMix.balance(forVoiceVolume: ListenAudioMix.voiceVolume)
        }
        .onChange(of: playsOverOtherAudio) { _, value in
            ListenAudioMix.playsOverOtherAudio = value
        }
        .onChange(of: lowersMusic) { _, value in
            ListenAudioMix.lowersMusicWhileSpeaking = value
        }
    }

    /// "MUSIC" with a chevron on the right; the whole row toggles the section.
    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
            ListenAudioMix.isMusicSectionCollapsed = isCollapsed
        } label: {
            HStack {
                Text(NBLocalization.text("Music"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundColor(ListenColors.textSecondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ListenColors.textSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NBLocalization.text("Music"))
        .accessibilityValue(isCollapsed ? NBLocalization.text("Collapsed") : NBLocalization.text("Expanded"))
        .accessibilityHint(isCollapsed ? NBLocalization.text("Shows the music settings")
                                       : NBLocalization.text("Hides the music settings"))
        .accessibilityIdentifier("listen-music-collapse")
    }

    private var playOverToggle: some View {
        Toggle(isOn: $playsOverOtherAudio.animation(.easeInOut(duration: 0.2))) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NBLocalization.text("Play over other audio"))
                    .font(.system(size: 14))
                    .foregroundColor(ListenColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(NBLocalization.text("Start music in the Music app or Spotify and Listen reads over it. That app's controls take over the lock screen."))
                    .font(.system(size: 12))
                    .foregroundColor(ListenColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("listen-music-play-over")
    }

    private var lowerMusicToggle: some View {
        Toggle(isOn: $lowersMusic) {
            Text(NBLocalization.text("Lower music while voice speaks"))
                .font(.system(size: 14))
                .foregroundColor(ListenColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("listen-music-lower")
    }

    /// Music on the left, Voice on the right. The middle is the voice at 100%; toward Voice boosts it past 100%
    /// (ListenVoiceBoost.swift) and toward Music lowers it, since NewsBlur can't turn another app's music down.
    private var balanceSlider: some View {
        HStack(spacing: 10) {
            Text(NBLocalization.text("Music"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ListenColors.textSecondary)
            Slider(value: $balance, in: -1...1)
                .background(
                    Capsule()
                        .fill(ListenColors.textSecondary.opacity(0.45))
                        .frame(width: 2, height: 14)
                )
                .onChange(of: balance) { _, value in
                    ListenAudioMix.voiceVolume = ListenAudioMix.voiceVolume(forBalance: Self.snapped(value))
                }
                .sensoryFeedback(.selection, trigger: Self.snapped(balance) == 0) { _, centered in centered }
                .accessibilityLabel(NBLocalization.text("Voice and music balance"))
                .accessibilityValue(NumberFormatter.localizedString(
                    from: NSNumber(value: ListenAudioMix.voiceVolume(forBalance: Self.snapped(balance))), number: .percent))
                .accessibilityIdentifier("listen-music-balance")
            Text(NBLocalization.text("Voice"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ListenColors.textSecondary)
        }
    }

    /// Near the middle the balance snaps to it, so the voice is easy to put back at 100%.
    private static func snapped(_ balance: Double) -> Double {
        abs(balance) < 0.06 ? 0 : balance
    }
}
