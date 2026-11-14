//
//  ListenMediaNowPlayingView.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVKit
import SwiftUI

/// ListenMediaNowPlayingView.swift: Now Playing holds whichever player is active, a story read aloud
/// (ListenNowPlayingView.swift) or a podcast (ListenMediaNowPlayingView), and closes once neither is.
struct ListenNowPlayingRoot: View {
    @ObservedObject private var listen = ListenPlayer.shared
    @ObservedObject private var media = ListenMediaPlayer.shared

    var body: some View {
        Group {
            if media.isActive {
                ListenMediaNowPlayingView()
            } else {
                ListenNowPlayingView()
            }
        }
        .onReceive(listen.$storyHash) { _ in dismissIfIdle() }
        .onReceive(media.$item) { _ in dismissIfIdle() }
    }

    /// Waits a turn: a handoff stops one player just before the other starts.
    private func dismissIfIdle() {
        DispatchQueue.main.async {
            if !ListenPlayer.shared.isActive && !ListenMediaPlayer.shared.isActive {
                ListenPresenter.dismissNowPlaying()
            }
        }
    }
}

/// The expanded podcast player: artwork, scrubber, skips by the web's intervals, speed, AirPlay and audio output,
/// and Up Next shared with the web and Android (ListenMediaNowPlayingView.swift).
struct ListenMediaNowPlayingView: View {
    @ObservedObject private var media = ListenMediaPlayer.shared
    @ObservedObject private var queue = ListenQueue.shared
    @ObservedObject private var theme = ListenThemeObserver.shared
    @State private var scrubValue: Double?

    private static let queueRowHeight: CGFloat = 56

    var body: some View {
        let _ = theme.version
        ScrollView {
            VStack(spacing: 20) {
                header
                if let message = media.errorMessage {
                    errorCard(message)
                }
                scrubber
                transport
                secondaryControls
                if !queue.playableItems.isEmpty {
                    queueSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(ListenColors.sheetBackground.ignoresSafeArea())
        .navigationTitle(NBLocalization.text("Now Playing"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    ListenPresenter.dismissNowPlaying()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                }
                .accessibilityLabel(NBLocalization.text("Close"))
            }
        }
        .tint(ListenColors.accent)
        .onAppear {
            // ListenMediaNowPlayingView.swift picks up anything queued on another device.
            queue.refresh()
        }
        .environment(\.colorScheme, ListenColors.colorScheme)
        .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
        .accessibilityIdentifier("listen-media-now-playing")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ListenMediaArtwork(item: media.item, size: 132)
            if !media.feedTitle.isEmpty {
                Text(media.feedTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ListenColors.textSecondary)
                    .lineLimit(1)
            }
            Text(media.item?.title ?? "")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ListenColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if media.status == .loading {
                Text(NBLocalization.text("Loading…"))
                    .font(.system(size: 13))
                    .foregroundColor(ListenColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ListenColors.error)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(ListenColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Button {
                media.retry()
            } label: {
                Label(NBLocalization.text("Retry"), systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ListenColors.error, lineWidth: 1))
                    .foregroundColor(ListenColors.error)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ListenColors.errorBackground))
    }

    // MARK: - Scrubber and controls

    private var timelineTotal: Double { max(1, media.duration) }

    private var scrubber: some View {
        let position = min(scrubValue ?? media.elapsed, timelineTotal)
        return VStack(spacing: 4) {
            Slider(value: Binding(get: { position }, set: { scrubValue = $0 }), in: 0...timelineTotal,
                   onEditingChanged: { editing in
                if !editing, let value = scrubValue {
                    media.seek(to: value, save: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrubValue = nil
                    }
                }
            })
            .disabled(media.duration <= 0)
            .accessibilityLabel(NBLocalization.text("Playback position"))
            .accessibilityValue(ListenFormat.clock(position))
            HStack {
                Text(ListenFormat.clock(position))
                Spacer()
                Text(media.duration > 0 ? "-" + ListenFormat.clock(max(0, media.duration - position)) : "")
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundColor(ListenColors.textSecondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 36) {
            ListenSkipButton(direction: .backward, seconds: queue.settings.skipBackSeconds, pointSize: 28) {
                media.skipBackward()
            }
            .disabled(media.status == .loading || media.status == .failed)

            ListenPlayPauseButton(size: 68, filled: true)

            ListenSkipButton(direction: .forward, seconds: queue.settings.skipForwardSeconds, pointSize: 28) {
                media.skipForward()
            }
            .disabled(media.status == .loading || media.status == .failed)
        }
        .padding(.vertical, 4)
    }

    private var secondaryControls: some View {
        HStack {
            Menu {
                ForEach(ListenSpeed.presets, id: \.self) { preset in
                    Button {
                        media.setSpeed(preset)
                    } label: {
                        if ListenSpeed.isSame(preset, media.speed) {
                            Label(ListenFormat.speed(preset), systemImage: "checkmark")
                        } else {
                            Text(ListenFormat.speed(preset))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                    Text(ListenFormat.speed(media.speed))
                        .monospacedDigit()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ListenColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ListenColors.card))
            }
            .accessibilityLabel(NBLocalization.text("Speed"))
            .accessibilityValue(ListenFormat.speed(media.speed))
            .accessibilityIdentifier("listen-media-speed")

            Spacer()

            ListenRoutePicker()
                .frame(width: 40, height: 36)
                .background(Capsule().fill(ListenColors.card))

            Spacer()

            Button {
                media.playNextTrack()
            } label: {
                HStack(spacing: 4) {
                    Text(NBLocalization.text("Next"))
                    Image(systemName: "forward.end.fill")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(media.hasNextTrack ? ListenColors.textPrimary : ListenColors.textSecondary.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ListenColors.card))
            }
            .buttonStyle(.plain)
            .disabled(!media.hasNextTrack)
            .accessibilityIdentifier("listen-media-next")
        }
    }

    // MARK: - Up Next

    /// The shared queue's audio and Listen stories: drag to reorder, swipe or × to remove, tap to play now.
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NBLocalization.text("Up Next"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundColor(ListenColors.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 4)
            List {
                ForEach(queue.playableItems) { item in
                    queueRow(item)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(ListenColors.card)
                        .listRowSeparatorTint(ListenColors.textSecondary.opacity(0.2))
                        .listRowSeparator(item.id == queue.playableItems.last?.id ? .hidden : .visible, edges: .bottom)
                }
                .onMove { source, destination in
                    queue.movePlayableItems(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    queue.removePlayableItems(atOffsets: offsets)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, Self.queueRowHeight)
            .frame(height: CGFloat(queue.playableItems.count) * Self.queueRowHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("listen-media-up-next")
        }
    }

    private func queueRow(_ item: ListenQueueItem) -> some View {
        HStack(spacing: 10) {
            Button {
                media.play(queued: item)
            } label: {
                HStack(spacing: 10) {
                    ListenFeedIcon(feedId: item.feedId, size: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? NBLocalization.text("Untitled story") : item.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ListenColors.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: item.isListen ? "person.wave.2.fill" : "headphones")
                                .font(.system(size: 10))
                            Text(subtitle(for: item))
                                .lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(ListenColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityHint(NBLocalization.text("Plays this story now"))

            Button {
                queue.remove(item: item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ListenColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(NBLocalization.text("Remove from Up Next"))

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ListenColors.textSecondary.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.queueRowHeight)
        .modifier(ListenMediaQueueRowActions(item: item, queue: queue, media: media))
    }

    private func subtitle(for item: ListenQueueItem) -> String {
        var parts: [String] = []
        if let feedId = item.feedId, let feed = NewsBlurAppDelegate.shared()?.getFeed(feedId) as? [String: Any],
           let title = feed["feed_title"] as? String, !title.isEmpty {
            parts.append(title)
        }
        if let duration = item.duration {
            parts.append(ListenFormat.clock(duration))
        }
        return parts.joined(separator: " · ")
    }
}

/// ListenMediaNowPlayingView.swift: moving a queued item without dragging, as VoiceOver actions everywhere and a
/// right-click menu on the Mac, whose List doesn't reorder by dragging.
private struct ListenMediaQueueRowActions: ViewModifier {
    let item: ListenQueueItem
    @ObservedObject var queue: ListenQueue
    let media: ListenMediaPlayer

    private var index: Int? { queue.playableItems.firstIndex { $0.id == item.id } }
    private var count: Int { queue.playableItems.count }

    func body(content: Content) -> some View {
        let actions = content
            .accessibilityAction(named: Text(NBLocalization.text("Move up"))) { move(by: -1) }
            .accessibilityAction(named: Text(NBLocalization.text("Move down"))) { move(by: 1) }
        if ProcessInfo.processInfo.isMacCatalystApp {
            actions.contextMenu {
                Button {
                    media.play(queued: item)
                } label: {
                    Label(NBLocalization.text("Play now"), systemImage: "play")
                }
                Divider()
                Button {
                    if let index, index > 0 {
                        queue.movePlayableItems(fromOffsets: IndexSet(integer: index), toOffset: 0)
                    }
                } label: {
                    Label(NBLocalization.text("Move to top"), systemImage: "arrow.up.to.line")
                }
                .disabled(index == 0)
                Button {
                    move(by: -1)
                } label: {
                    Label(NBLocalization.text("Move up"), systemImage: "arrow.up")
                }
                .disabled(index == 0)
                Button {
                    move(by: 1)
                } label: {
                    Label(NBLocalization.text("Move down"), systemImage: "arrow.down")
                }
                .disabled(index == count - 1)
                Divider()
                Button(role: .destructive) {
                    queue.remove(item: item)
                } label: {
                    Label(NBLocalization.text("Remove from Up Next"), systemImage: "xmark")
                }
            }
        } else {
            actions
        }
    }

    private func move(by offset: Int) {
        guard let index else { return }
        let target = index + offset
        guard target >= 0, target < count else { return }
        // ListenQueue.swift takes List-style offsets: moving down lands after the next item.
        queue.movePlayableItems(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}

/// The episode's image from the story when it has one, else the feed's favicon (ListenMediaNowPlayingView.swift).
struct ListenMediaArtwork: View {
    let item: ListenMediaItem?
    let size: CGFloat

    var body: some View {
        if let url = item.flatMap({ URL(string: $0.imageURL) }), url.scheme?.hasPrefix("http") == true {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
                } else {
                    favicon
                }
            }
            .frame(height: size)
        } else {
            favicon
        }
    }

    private var favicon: some View {
        ListenFeedIcon(feedId: item?.feedId, size: 64)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

/// Skip back or forward by the seconds chosen in the web's player settings, drawn with the matching SF Symbol
/// (gobackward.15 and friends cover the web's 5, 10, 15, 30 and 60) (ListenMediaNowPlayingView.swift).
struct ListenSkipButton: View {
    enum Direction {
        case backward
        case forward
    }

    private static let numberedSymbols: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]

    let direction: Direction
    let seconds: Int
    let pointSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: pointSize, weight: .regular))
                .foregroundColor(ListenColors.textPrimary)
                .frame(minWidth: pointSize + 8, minHeight: pointSize + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(direction == .backward ? "listen-skip-backward" : "listen-skip-forward")
    }

    private var symbolName: String {
        let base = direction == .backward ? "gobackward" : "goforward"
        return Self.numberedSymbols.contains(seconds) ? "\(base).\(seconds)" : base
    }

    private var label: String {
        switch direction {
        case .backward:
            return NBLocalization.plural("Back %@ seconds", count: NSNumber(value: seconds))
        case .forward:
            return NBLocalization.plural("Forward %@ seconds", count: NSNumber(value: seconds))
        }
    }
}

/// AirPlay and the choice of speaker, headphones or car (ListenMediaNowPlayingView.swift).
struct ListenRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        apply(to: picker)
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        apply(to: picker)
    }

    private func apply(to picker: AVRoutePickerView) {
        picker.tintColor = UIColor(ListenColors.textPrimary)
        picker.activeTintColor = UIColor(ListenColors.accent)
    }
}
