//
//  ListenMiniPlayer.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI
import UIKit

/// ListenMiniPlayer.swift floats a small player over the whole app while a story is loaded. It lives in the split
/// view controller's view, so it stays put while navigating feeds, story lists and stories, and it rides just above
/// whichever bottom toolbar is showing in its column (feed list toolbar, story list bar or story traverse bar).
final class ListenMiniPlayerController: NSObject {
    static let shared = ListenMiniPlayerController()

    static let barHeight: CGFloat = 58
    private static let margin: CGFloat = 8
    private static let maximumWidth: CGFloat = 560

    private let container = ListenMiniPlayerContainerView()
    private var hostingController: UIHostingController<ListenMiniPlayerBar>?
    private var displayLink: CADisplayLink?
    private var lastFrame: CGRect = .zero
    private(set) var isShown = false

    private var appDelegate: NewsBlurAppDelegate? { NewsBlurAppDelegate.shared() }

    /// The height of the area the mini player covers, so lists can leave room for it.
    var coveredHeight: CGFloat { isShown ? Self.barHeight + Self.margin : 0 }

    /// Where the player sits in the split view's view, for ListenToast above it.
    var playerFrame: CGRect? { isShown && container.superview != nil ? container.frame : nil }

    /// Extra bottom inset a scrolling list needs so its last rows can scroll clear of the player: the covered
    /// height when the player sits over that list's column, else nothing (FeedsObjCViewController.m and
    /// FeedDetailObjCViewController.m).
    func bottomInset(for view: UIView) -> CGFloat {
        guard isShown, let window = view.window, container.window === window else { return 0 }
        let viewFrame = view.convert(view.bounds, to: window)
        let playerFrame = container.convert(container.bounds, to: window)
        let overlap = min(viewFrame.maxX, playerFrame.maxX) - max(viewFrame.minX, playerFrame.minX)
        guard overlap > min(viewFrame.width, playerFrame.width) * 0.5,
              playerFrame.minY < viewFrame.maxY, playerFrame.maxY > viewFrame.minY else { return 0 }
        return coveredHeight
    }

    /// Lets the feed list and story list recompute their insets after the player appears, moves or goes away.
    private func relayoutLists() {
        guard let appDelegate else { return }
        for view in [appDelegate.feedsViewController?.viewIfLoaded, appDelegate.feedDetailViewController?.viewIfLoaded] {
            view?.setNeedsLayout()
        }
    }

    func show() {
        guard let host = appDelegate?.splitViewController?.view else { return }
        if hostingController == nil {
            let hosting = UIHostingController(rootView: ListenMiniPlayerBar(onOpen: { [weak self] in
                self?.openNowPlaying()
            }))
            hosting.view.backgroundColor = .clear
            hosting.sizingOptions = []
            hostingController = hosting
            container.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        updateTheme()
        if container.superview !== host {
            container.removeFromSuperview()
            host.addSubview(container)
        }
        host.bringSubviewToFront(container)
        let wasShown = isShown
        isShown = true
        layout(force: true)
        startDisplayLink()
        if !wasShown {
            container.alpha = 0
            container.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25, delay: 0,
                           options: [.curveEaseOut, .allowUserInteraction]) {
                self.container.alpha = 1
                self.container.transform = .identity
            }
        }
        NotificationCenter.default.post(name: ListenPlayer.stateDidChange, object: nil)
        relayoutLists()
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        stopDisplayLink()
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2, animations: {
            self.container.alpha = 0
            self.container.transform = CGAffineTransform(translationX: 0, y: 20)
        }, completion: { _ in
            guard !self.isShown else { return }
            self.container.removeFromSuperview()
            self.container.transform = .identity
            self.relayoutLists()
        })
    }

    func updateTheme() {
        hostingController?.overrideUserInterfaceStyle = ListenColors.interfaceStyle
        ListenThemeObserver.shared.themeChanged()
    }

    func openNowPlaying() {
        ListenPresenter.presentNowPlaying()
    }

    // MARK: - Layout

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 20, preferred: 15)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkFired() {
        layout(force: false)
    }

    private func layout(force: Bool) {
        guard isShown, let split = appDelegate?.splitViewController, let host = split.view else { return }
        if container.superview !== host {
            host.addSubview(container)
        }
        if host.subviews.last !== container {
            host.bringSubviewToFront(container)
        }
        let safe = host.safeAreaInsets
        var area = CGRect(x: safe.left, y: 0, width: host.bounds.width - safe.left - safe.right, height: host.bounds.height)
        if !split.isCollapsed, let column = readingColumn(in: host) {
            // ListenMiniPlayer.swift keeps the player over the reading column on iPad and Mac.
            area = CGRect(x: max(area.minX, column.minX), y: 0,
                          width: min(area.maxX, column.maxX) - max(area.minX, column.minX),
                          height: host.bounds.height)
        }
        let width = min(Self.maximumWidth, area.width - Self.margin * 2)
        let x = area.minX + (area.width - width) / 2
        let safeBottom = host.bounds.height - safe.bottom
        let barTop = bottomBarTop(in: host, spanning: CGRect(x: x, y: 0, width: width, height: host.bounds.height),
                                  safeBottom: safeBottom)
        let bottom = min(safeBottom, barTop ?? safeBottom) - Self.margin
        let frame = CGRect(x: x, y: bottom - Self.barHeight, width: width, height: Self.barHeight).integral
        guard force || abs(frame.minY - lastFrame.minY) > 0.5 || abs(frame.width - lastFrame.width) > 0.5
                || abs(frame.minX - lastFrame.minX) > 0.5 else { return }
        let movedColumn = abs(frame.minX - lastFrame.minX) > 0.5 || abs(frame.width - lastFrame.width) > 0.5
        lastFrame = frame
        container.bounds = CGRect(origin: .zero, size: frame.size)
        container.center = CGPoint(x: frame.midX, y: frame.midY)
        if movedColumn {
            relayoutLists()
        }
    }

    /// The story pages when they're showing (the iPad and Mac detail column can also hold the story list beside
    /// them), else the whole detail column.
    private func readingColumn(in host: UIView) -> CGRect? {
        for view in [appDelegate?.storyPagesViewController?.viewIfLoaded, appDelegate?.detailViewController?.viewIfLoaded] {
            guard let view, view.window === host.window, Self.isVisible(view) else { continue }
            let frame = view.convert(view.bounds, to: host)
            if frame.width > 280 {
                return frame
            }
        }
        return nil
    }

    /// The top of the highest visible toolbar along the bottom of the column the player sits in.
    private func bottomBarTop(in host: UIView, spanning area: CGRect, safeBottom: CGFloat) -> CGFloat? {
        guard let appDelegate else { return nil }
        var candidates: [UIView?] = [
            appDelegate.feedsViewController?.feedViewToolbar,
            appDelegate.storyPagesViewController?.traverseView,
            appDelegate.feedDetailViewController?.storyTitlesHeaderBar?.headerContainer
        ]
        for navigationController in [appDelegate.feedsNavigationController, appDelegate.feedDetailNavigationController,
                                     appDelegate.detailNavigationController] {
            if let navigationController, !navigationController.isToolbarHidden {
                candidates.append(navigationController.toolbar)
            }
        }
        var top: CGFloat?
        for case let view? in candidates {
            guard Self.isVisible(view), view.window === host.window else { continue }
            let frame = view.convert(view.bounds, to: host)
            let overlap = min(frame.maxX, area.maxX) - max(frame.minX, area.minX)
            guard overlap > area.width * 0.3, frame.height > 10, frame.height < 140,
                  frame.maxY >= safeBottom - 40, frame.minY > host.bounds.height * 0.4 else { continue }
            top = min(top ?? frame.minY, frame.minY)
        }
        return top
    }

    private static func isVisible(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let candidate = current {
            if candidate.isHidden || candidate.alpha < 0.05 {
                return false
            }
            current = candidate.superview
        }
        return view.window != nil
    }
}

/// ListenMiniPlayer.swift's short confirmation ("Added to Up Next · 2nd") just above the mini player, or near the
/// bottom of the screen when the player isn't showing. VoiceOver reads it aloud.
enum ListenToast {
    private static weak var current: UIView?

    static func show(_ message: String) {
        guard let host = NewsBlurAppDelegate.shared()?.splitViewController?.view else { return }
        current?.removeFromSuperview()
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        let toast = UIView()
        toast.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        toast.layer.cornerCurve = .continuous
        toast.isUserInteractionEnabled = false
        toast.accessibilityIdentifier = "listen-toast"
        toast.addSubview(label)
        let maxWidth = min(360, host.bounds.width - 48)
        let size = label.sizeThatFits(CGSize(width: maxWidth - 32, height: 60))
        let width = min(maxWidth, ceil(size.width) + 32)
        let height = ceil(size.height) + 18
        toast.layer.cornerRadius = height / 2
        label.frame = CGRect(x: 16, y: 9, width: width - 32, height: ceil(size.height))
        let anchor = ListenMiniPlayerController.shared.playerFrame
        let centerX = anchor?.midX ?? host.bounds.midX
        let bottom = anchor.map { $0.minY - 10 } ?? (host.bounds.height - host.safeAreaInsets.bottom - 90)
        toast.frame = CGRect(x: centerX - width / 2, y: bottom - height, width: width, height: height).integral
        host.addSubview(toast)
        current = toast
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 8)
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.2
        UIView.animate(withDuration: duration) {
            toast.alpha = 1
            toast.transform = .identity
        }
        UIView.animate(withDuration: duration * 1.5, delay: 2.0, options: [.beginFromCurrentState]) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

/// Passes touches through everywhere except the player itself (ListenMiniPlayer.swift).
private final class ListenMiniPlayerContainerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        accessibilityIdentifier = "listen-mini-player"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// The mini player bar: feed icon, story title, feed and status, play/pause, next story and close (ListenMiniPlayer.swift).
struct ListenMiniPlayerBar: View {
    @ObservedObject private var player = ListenPlayer.shared
    /// ListenMiniPlayer.swift: Next story depends on Up Next too, so the bar redraws when the queue changes.
    @ObservedObject private var queue = ListenQueue.shared
    @ObservedObject private var theme = ListenThemeObserver.shared
    let onOpen: () -> Void

    var body: some View {
        let _ = theme.version
        HStack(spacing: 10) {
            // ListenMiniPlayer.swift opens Now Playing from anywhere on the bar except its buttons.
            HStack(spacing: 10) {
                ListenFeedIcon(feedId: player.feedId, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.storyTitle.isEmpty ? NBLocalization.text("Listen") : player.storyTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ListenColors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(NBLocalization.text("Opens Now Playing"))

            HStack(spacing: 2) {
                ListenPlayPauseButton(size: 34, filled: false)

                // ListenMiniPlayer.swift: the first story in Up Next, else the next one in the list being read.
                Button {
                    player.playNextStory()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(player.hasNextStory ? ListenColors.textPrimary : ListenColors.textSecondary.opacity(0.4))
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!player.hasNextStory)
                .accessibilityLabel(NBLocalization.text("Next story"))
                .accessibilityIdentifier("listen-next-story")

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ListenColors.textSecondary)
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NBLocalization.text("Stop listening"))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: ListenMiniPlayerController.barHeight)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ListenColors.miniBar)
                .shadow(color: Color.black.opacity(ListenColors.isDark ? 0.5 : 0.16), radius: 10, x: 0, y: 3)
        )
        .overlay(alignment: .bottom) {
            GeometryReader { geometry in
                Capsule()
                    .fill(ListenColors.accent)
                    .frame(width: geometry.size.width * progress, height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, 14)
            .padding(.bottom, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ListenColors.border.opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .environment(\.colorScheme, ListenColors.colorScheme)
        .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    private var progress: CGFloat {
        let total = player.previewLimit.map { min($0, player.duration) } ?? player.duration
        guard total > 0 else { return 0 }
        return CGFloat(min(1, max(0, player.elapsed / total)))
    }

    private var subtitle: String {
        if let error = player.playbackError {
            return error.message
        }
        switch player.status {
        case .loading:
            return NBLocalization.text("Preparing audio…")
        case .buffering:
            return NBLocalization.text("Loading…")
        case .previewEnded:
            return NBLocalization.text("Preview ended. Premium Archive unlocks full stories")
        case .finished:
            return NBLocalization.text("Finished")
        default:
            break
        }
        if let remaining = player.previewRemaining {
            return String(format: NBLocalization.text("Preview · %@ left"), ListenFormat.clock(remaining))
        }
        return player.feedTitle
    }

    private var subtitleColor: Color {
        player.playbackError != nil ? ListenColors.error : ListenColors.textSecondary
    }
}

/// Play, pause or a spinner, shared by the mini player and Now Playing (ListenMiniPlayer.swift).
struct ListenPlayPauseButton: View {
    @ObservedObject private var player = ListenPlayer.shared
    let size: CGFloat
    let filled: Bool

    var body: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                if filled {
                    Circle()
                        .fill(ListenColors.accent)
                }
                if isWaiting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(filled ? .white : ListenColors.textSecondary)
                        .scaleEffect(filled ? 1.1 : 0.8)
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: size * (filled ? 0.36 : 0.5), weight: .semibold))
                        .foregroundColor(filled ? .white : ListenColors.textPrimary)
                        .offset(x: symbolName == "play.fill" && filled ? size * 0.03 : 0)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.wantsToPlay ? NBLocalization.text("Pause")
                            : (symbolName == "play.fill" ? NBLocalization.text("Play") : NBLocalization.text("Play again")))
        .accessibilityIdentifier("listen-play-pause")
    }

    private var symbolName: String {
        if player.wantsToPlay {
            return "pause.fill"
        }
        return player.status == .finished || player.status == .previewEnded ? "arrow.counterclockwise" : "play.fill"
    }

    private var isWaiting: Bool {
        player.wantsToPlay && (player.status == .loading || player.status == .buffering)
    }
}

/// A feed's favicon from the app's favicon cache (ListenMiniPlayer.swift).
struct ListenFeedIcon: View {
    let feedId: String?
    let size: CGFloat

    var body: some View {
        if let feedId, let image = NewsBlurAppDelegate.shared()?.getFavicon(feedId) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        } else {
            Image(systemName: "headphones")
                .font(.system(size: size * 0.6))
                .foregroundColor(ListenColors.textSecondary)
                .frame(width: size, height: size)
        }
    }
}
