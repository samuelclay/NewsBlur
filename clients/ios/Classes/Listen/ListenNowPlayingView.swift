//
//  ListenNowPlayingView.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// ListenNowPlayingView.swift is the expanded player: scrubber, skips, speed, voice settings, Up Next, the
/// preview banner and upgrade button, inline errors with Retry, and the listening allowance.
struct ListenNowPlayingView: View {
    @ObservedObject private var player = ListenPlayer.shared
    @ObservedObject private var queue = ListenQueue.shared
    @ObservedObject private var theme = ListenThemeObserver.shared
    @State private var scrubValue: Double?
    /// The auto-continue stories after Up Next ("Then from <list>").
    @State private var upNext: [[String: Any]] = []
    @State private var showsSpeed = false

    private static let queueRowHeight: CGFloat = 56

    var body: some View {
        let _ = theme.version
        ScrollView {
            VStack(spacing: 20) {
                header
                if let remaining = player.previewRemaining, player.status != .previewEnded {
                    previewBanner(remaining: remaining)
                }
                if player.status == .previewEnded {
                    previewEndedCard
                }
                if let error = player.playbackError {
                    errorCard(error)
                }
                scrubber
                transport
                secondaryControls
                if !queue.listenItems.isEmpty {
                    queueSection
                }
                if !upNext.isEmpty {
                    upNextSection
                }
                if let usageText {
                    Text(usageText)
                        .font(.system(size: 12))
                        .foregroundColor(ListenColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
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
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ListenVoiceSettingsView(showsDoneButton: false)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel(NBLocalization.text("Voice settings"))
                .accessibilityIdentifier("listen-voice-settings")
            }
        }
        .tint(ListenColors.accent)
        .onAppear {
            // ListenNowPlayingView.swift picks up anything queued on another device.
            queue.refresh()
            refreshUpNext()
        }
        .onReceive(queue.$items) { _ in
            DispatchQueue.main.async(execute: refreshUpNext)
        }
        .onReceive(player.$storyHash) { hash in
            if hash == nil {
                ListenPresenter.dismissNowPlaying()
            }
            DispatchQueue.main.async(execute: refreshUpNext)
        }
        .onReceive(player.$status) { _ in
            DispatchQueue.main.async(execute: refreshUpNext)
        }
        .environment(\.colorScheme, ListenColors.colorScheme)
        .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ListenFeedIcon(feedId: player.feedId, size: 64)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            Text(player.feedTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ListenColors.textSecondary)
                .lineLimit(1)
            Text(player.storyTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ListenColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if let voiceName = player.voiceName {
                NavigationLink {
                    ListenVoiceSettingsView(showsDoneButton: false)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.system(size: 12))
                        Text(String(format: NBLocalization.text("Read by %@"), voiceName))
                            .font(.system(size: 13))
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(ListenColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(ListenColors.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            } else if player.status == .loading {
                Text(NBLocalization.text("Preparing audio…"))
                    .font(.system(size: 13))
                    .foregroundColor(ListenColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Preview

    private func previewBanner(remaining: TimeInterval) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: NBLocalization.text("Previewing %@ seconds. Premium Archive unlocks full stories"),
                            ListenPreferences.numberString(player.previewLimit ?? 30)))
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: NBLocalization.text("%@ left in this preview"), ListenFormat.clock(remaining)))
                    .font(.system(size: 12).monospacedDigit())
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            Button(NBLocalization.text("Upgrade")) {
                ListenPresenter.showUpgrade(.archive)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.22)))
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [ListenColors.archivePurple, ListenColors.archivePurpleLight],
                                     startPoint: .leading, endPoint: .trailing))
        )
    }

    private var previewEndedCard: some View {
        VStack(spacing: 10) {
            Text(usageUpgradeMessage)
                .font(.system(size: 14))
                .foregroundColor(ListenColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            upgradeButton(.archive)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ListenColors.card))
        .transition(.opacity)
    }

    private var usageUpgradeMessage: String {
        player.usage?.upgradeMessage ?? NBLocalization.text("That was a 30 second preview. Premium Archive unlocks full stories.")
    }

    private func upgradeButton(_ upgrade: ListenPlaybackError.Upgrade) -> some View {
        Button {
            ListenPresenter.showUpgrade(upgrade)
        } label: {
            Text(upgrade == .pro ? NBLocalization.text("Upgrade to Premium Pro")
                                 : NBLocalization.text("Upgrade to Premium Archive"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [ListenColors.archivePurple, ListenColors.archivePurpleLight],
                                             startPoint: .leading, endPoint: .trailing))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("listen-upgrade")
    }

    // MARK: - Errors

    private func errorCard(_ error: ListenPlaybackError) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ListenColors.error)
                Text(error.message)
                    .font(.system(size: 14))
                    .foregroundColor(ListenColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if error.retryable {
                Button {
                    player.retry()
                } label: {
                    Label(NBLocalization.text("Retry"), systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ListenColors.error, lineWidth: 1))
                        .foregroundColor(ListenColors.error)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("listen-retry")
            }
            if error.upgrade != .none {
                upgradeButton(error.upgrade)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ListenColors.errorBackground))
    }

    // MARK: - Scrubber and controls

    private var timelineTotal: Double {
        let total = player.previewLimit.map { min($0, player.duration) } ?? player.duration
        return max(1, total)
    }

    private var scrubber: some View {
        let position = min(scrubValue ?? player.elapsed, timelineTotal)
        return VStack(spacing: 4) {
            Slider(value: Binding(get: { position }, set: { scrubValue = $0 }), in: 0...timelineTotal,
                   onEditingChanged: { editing in
                if !editing, let value = scrubValue {
                    player.seek(to: value)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrubValue = nil
                    }
                }
            })
            .disabled(player.manifest == nil)
            .accessibilityLabel(NBLocalization.text("Playback position"))
            .accessibilityValue(ListenFormat.clock(position))
            HStack {
                Text(ListenFormat.clock(position))
                Spacer()
                Text("-" + ListenFormat.clock(max(0, timelineTotal - position)))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundColor(ListenColors.textSecondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 36) {
            Button {
                player.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(ListenColors.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NBLocalization.text("Back 15 seconds"))
            .disabled(player.manifest == nil)

            ListenPlayPauseButton(size: 68, filled: true)

            Button {
                player.skip(by: 30)
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(ListenColors.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NBLocalization.text("Forward 30 seconds"))
            .disabled(player.manifest == nil)
        }
        .padding(.vertical, 4)
    }

    private var secondaryControls: some View {
        HStack {
            Button {
                showsSpeed = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                    Text(ListenFormat.speed(player.speed))
                        .monospacedDigit()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ListenColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ListenColors.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NBLocalization.text("Speed"))
            .accessibilityValue(ListenFormat.speed(player.speed))
            .accessibilityIdentifier("listen-speed")
            .popover(isPresented: $showsSpeed, arrowEdge: .bottom) {
                // ListenNowPlayingView.swift: a compact sheet on iPhone, a popover on iPad and Mac.
                ListenSpeedSheet()
                    .frame(minWidth: 340, idealWidth: 380, minHeight: 200, idealHeight: 215)
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }

            Spacer()

            Button {
                player.playNextStory()
            } label: {
                HStack(spacing: 4) {
                    Text(NBLocalization.text("Next story"))
                    Image(systemName: "forward.end.fill")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(player.hasNextStory ? ListenColors.textPrimary : ListenColors.textSecondary.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ListenColors.card))
            }
            .buttonStyle(.plain)
            .disabled(!player.hasNextStory)
        }
    }

    // MARK: - Up Next

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundColor(ListenColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 4)
    }

    /// Your queue, shared with the web and Android: drag to reorder, swipe or × to remove, tap to play now.
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(NBLocalization.text("Up Next"))
            List {
                ForEach(queue.listenItems) { item in
                    queueRow(item)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(ListenColors.card)
                        .listRowSeparatorTint(ListenColors.textSecondary.opacity(0.2))
                        .listRowSeparator(item.id == queue.listenItems.last?.id ? .hidden : .visible, edges: .bottom)
                }
                .onMove { source, destination in
                    queue.moveListenItems(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    queue.removeListenItems(atOffsets: offsets)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, Self.queueRowHeight)
            .frame(height: CGFloat(queue.listenItems.count) * Self.queueRowHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("listen-up-next-queue")
        }
    }

    private func queueRow(_ item: ListenQueueItem) -> some View {
        HStack(spacing: 10) {
            Button {
                player.play(queued: item)
            } label: {
                HStack(spacing: 10) {
                    ListenFeedIcon(feedId: item.feedId, size: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? NBLocalization.text("Untitled story") : item.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ListenColors.textPrimary)
                            .lineLimit(1)
                        Text(feedTitle(forFeedId: item.feedId))
                            .font(.system(size: 12))
                            .foregroundColor(ListenColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityHint(NBLocalization.text("Plays this story now"))

            Button {
                queue.remove(storyHash: item.storyHash)
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
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .frame(height: Self.queueRowHeight)
        .modifier(ListenQueueRowActions(item: item, queue: queue, player: player))
    }

    /// The stories auto-continue reads after Up Next, dimmer and not reorderable.
    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(player.upNextListTitle.map { String(format: NBLocalization.text("Then from %@"), $0) }
                         ?? NBLocalization.text("Then from this list"))
            VStack(spacing: 0) {
                ForEach(Array(upNext.enumerated()), id: \.offset) { index, story in
                    Button {
                        player.play(upNext: story)
                    } label: {
                        HStack(spacing: 10) {
                            ListenFeedIcon(feedId: ListenJSON.string(story["story_feed_id"]), size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ListenPlayer.decodedTitle(story["story_title"]))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ListenColors.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(feedTitle(for: story))
                                    .font(.system(size: 12))
                                    .foregroundColor(ListenColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "play.circle")
                                .foregroundColor(ListenColors.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < upNext.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ListenColors.card))
            .opacity(0.72)
        }
    }

    private func feedTitle(for story: [String: Any]) -> String {
        feedTitle(forFeedId: ListenJSON.string(story["story_feed_id"]))
    }

    private func feedTitle(forFeedId feedId: String?) -> String {
        guard let feedId, let feed = NewsBlurAppDelegate.shared()?.getFeed(feedId) as? [String: Any] else { return "" }
        return feed["feed_title"] as? String ?? ""
    }

    /// ListenNowPlayingView.swift lists auto-continue stories only when auto-continue is on, leaving out any
    /// that are already in Up Next.
    private func refreshUpNext() {
        guard ListenPreferences.autoContinue else {
            upNext = []
            return
        }
        upNext = player.upNextStories(limit: 5 + queue.listenItems.count)
            .filter { !queue.contains(storyHash: $0["story_hash"] as? String) }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Usage

    private var usageText: String? {
        guard let usage = player.usage else { return nil }
        if usage.isArchiveTier, let limit = usage.secondsLimit {
            let remaining = usage.secondsRemaining ?? max(0, limit - usage.secondsUsed)
            return String(format: NBLocalization.text("%1$@ of %2$@ of listening left this week"),
                          ListenFormat.allowance(remaining), ListenFormat.allowance(limit))
        }
        if let samplesLimit = usage.samplesLimit {
            return String(format: NBLocalization.text("%1$@ of %2$@ story previews used today"),
                          NBLocalization.formattedCount(usage.samplesUsed), NBLocalization.formattedCount(samplesLimit))
        }
        return nil
    }
}

/// ListenNowPlayingView.swift: moving a queued story without dragging. VoiceOver gets the moves as actions on
/// every platform, and the Mac gets them in a right-click menu, since its List doesn't reorder by dragging.
private struct ListenQueueRowActions: ViewModifier {
    let item: ListenQueueItem
    @ObservedObject var queue: ListenQueue
    let player: ListenPlayer

    private var index: Int? { queue.listenItems.firstIndex { $0.id == item.id } }
    private var count: Int { queue.listenItems.count }

    func body(content: Content) -> some View {
        let actions = content
            .accessibilityAction(named: Text(NBLocalization.text("Move up"))) { move(by: -1) }
            .accessibilityAction(named: Text(NBLocalization.text("Move down"))) { move(by: 1) }
        if ProcessInfo.processInfo.isMacCatalystApp {
            actions.contextMenu {
                Button {
                    player.play(queued: item)
                } label: {
                    Label(NBLocalization.text("Play now"), systemImage: "play")
                }
                Divider()
                Button {
                    moveToTop()
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
                    queue.remove(storyHash: item.storyHash)
                } label: {
                    Label(NBLocalization.text("Remove from Up Next"), systemImage: "xmark")
                }
            }
        } else {
            actions
        }
    }

    private func moveToTop() {
        guard let index, index > 0 else { return }
        queue.moveListenItems(fromOffsets: IndexSet(integer: index), toOffset: 0)
    }

    private func move(by offset: Int) {
        guard let index else { return }
        let target = index + offset
        guard target >= 0, target < count else { return }
        // ListenQueue.swift takes List-style offsets: moving down lands after the next item.
        queue.moveListenItems(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}
