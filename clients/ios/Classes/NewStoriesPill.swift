//
//  NewStoriesPill.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI
import UIKit

/// The "3 new stories" capsule that floats over the story list when RealtimeUpdates.swift has fetched stories that
/// arrived over the socket. It sits at the top of a newest-first list and at the bottom of an oldest-first one.
/// Tapping it puts the stories into the list.
@objcMembers final class NewStoriesPill: UIControl {
    private let capsuleView = UIView()
    private let arrowImageView = UIImageView()
    private let titleLabel = UILabel()
    private(set) var count = 0
    private(set) var atBottom = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "new-stories-pill"

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.isUserInteractionEnabled = false
        capsuleView.layer.cornerRadius = 17
        capsuleView.layer.cornerCurve = .continuous
        capsuleView.layer.shadowOffset = CGSize(width: 0, height: 3)
        capsuleView.layer.shadowRadius = 10
        capsuleView.layer.shadowOpacity = 0.22
        addSubview(capsuleView)

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        capsuleView.addSubview(arrowImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "WhitneySSm-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = false
        titleLabel.numberOfLines = 1
        capsuleView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            capsuleView.topAnchor.constraint(equalTo: topAnchor),
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: bottomAnchor),
            capsuleView.heightAnchor.constraint(equalToConstant: 34),

            arrowImageView.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 13),
            arrowImageView.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 13),

            titleLabel.leadingAnchor.constraint(equalTo: arrowImageView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -15),
            titleLabel.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor)
        ])

        updateTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(count: Int, atBottom: Bool) {
        self.count = count
        self.atBottom = atBottom
        let title = NewStoriesAppearance.title(count: count)
        titleLabel.text = title
        accessibilityLabel = title
        arrowImageView.image = UIImage(systemName: NewStoriesAppearance.arrowName(atBottom: atBottom))?
            .withRenderingMode(.alwaysTemplate)
    }

    func updateTheme() {
        capsuleView.backgroundColor = ThemeManager.color(fromRGB: NewStoriesAppearance.accentRGB)
        capsuleView.layer.shadowColor = ThemeManager.shared.isDarkTheme
            ? UIColor.black.cgColor
            : ThemeManager.color(fromRGB: [0x3B4A5C]).cgColor
        titleLabel.textColor = .white
        arrowImageView.tintColor = .white
    }

    override var isHighlighted: Bool {
        didSet { capsuleView.alpha = isHighlighted ? 0.8 : 1 }
    }

    /// VoiceOver, and the Mac's accessibility press, activate the pill without touching it. A custom UIControl
    /// ignores that by default, so NewStoriesPill.swift treats it as a tap.
    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchUpInside)
        return true
    }
}

/// NewStoriesPill.swift: whether the pill shows. While stories wait, the inline row tops the list (NewStoriesRowCell,
/// NewStoriesRowView) and the pill floats only while that row is off screen. The first scroll away from
/// a showing pill (down from the top pill of a newest-first list, up from the bottom pill of an oldest-first one)
/// starts a `hideAfterScrollingAway` timer; when it runs out the pill tucks away, whatever the reader did meanwhile,
/// unless it was tapped or hidden first. It comes back `returnAfterIdle` after it tucked away or the last scroll,
/// whichever came later, and starts over then. The web and Android use the same numbers.
struct NewStoriesPillPresence {
    static let hideAfterScrollingAway: TimeInterval = 5
    static let returnAfterIdle: TimeInterval = 180

    /// When the pill tucks away, counted from the first scroll away from it.
    private(set) var hideTime: TimeInterval?
    private(set) var isHiddenByScrolling = false
    private(set) var lastScroll: TimeInterval?
    private var hiddenAt: TimeInterval?

    /// The list scrolled at `time`. Returns when the pill should tuck away if this is the first scroll away from it.
    mutating func scrolled(awayFromPill away: Bool, at time: TimeInterval) -> TimeInterval? {
        lastScroll = time
        guard away, hideTime == nil, !isHiddenByScrolling else { return nil }
        hideTime = time + Self.hideAfterScrollingAway
        return hideTime
    }

    /// The timer `scrolled` started ran out at `time`. Returns true when the pill tucks away now.
    mutating func hideTimerFired(at time: TimeInterval) -> Bool {
        guard !isHiddenByScrolling, let hideTime, time >= hideTime else { return false }
        isHiddenByScrolling = true
        hiddenAt = time
        return true
    }

    /// Whether the floating pill shows. The inline "N new stories" row tops the list whenever stories wait, so the
    /// pill stays away while any of the row is on screen, and after scrolling dismissed it.
    func showsPill(waiting: Int, rowOnScreen: Bool) -> Bool {
        waiting > 0 && !rowOnScreen && !isHiddenByScrolling
    }

    /// When a tucked-away pill may come back, unless the list scrolls again first. The scroll that started the
    /// countdown is often the last one, so the wait also runs from the moment the pill tucked away.
    func returnTime(idle: TimeInterval = Self.returnAfterIdle) -> TimeInterval? {
        guard isHiddenByScrolling else { return nil }
        return max(lastScroll ?? 0, hiddenAt ?? 0) + idle
    }

    func shouldReturn(at time: TimeInterval, idle: TimeInterval = Self.returnAfterIdle) -> Bool {
        guard let returnTime = returnTime(idle: idle) else { return false }
        return time >= returnTime
    }
}

/// NewStoriesPill.swift: which moves of the story list are the reader scrolling. A Mac's mouse wheel and trackpad
/// scroll a list without UIKit's tracking, dragging or decelerating flags, so every offset change counts except
/// the list's own: the scrolls the pill code makes (to the top, the arrival, the gap) and moves that come with a new
/// content size, which are reloads and lazy layout.
struct NewStoriesPillScrollFilter {
    /// How long after the pill code scrolls the list its moves aren't the reader's.
    static let ownScrollGrace: TimeInterval = 0.5

    private var lastContentSize: CGSize
    private var ignoreUntil: TimeInterval = -.infinity

    init(contentSize: CGSize) {
        lastContentSize = contentSize
    }

    /// Starts over with another scroll view, keeping any scroll the pill code just made.
    mutating func rebase(contentSize: CGSize) {
        lastContentSize = contentSize
    }

    /// The pill code is about to scroll the list.
    mutating func listScrollsItself(at time: TimeInterval) {
        ignoreUntil = max(ignoreUntil, time + Self.ownScrollGrace)
    }

    /// How far the reader scrolled the list in this change, or nil when the move was the list's own.
    mutating func readerScroll(from old: CGFloat, to new: CGFloat, contentSize: CGSize,
                               at time: TimeInterval) -> CGFloat? {
        let resized = contentSize != lastContentSize
        lastContentSize = contentSize
        guard new != old, !resized, time >= ignoreUntil else { return nil }
        return new - old
    }
}

/// NewStoriesPill.swift watches one list scroll view and reports the reader's scrolling, as
/// NewStoriesPillScrollFilter decides it.
@MainActor final class NewStoriesPillScrollWatch: NSObject {
    private(set) weak var scrollView: UIScrollView?
    private(set) var filter: NewStoriesPillScrollFilter
    private var observation: NSKeyValueObservation?

    /// `isListMovingItself` answers whether the pill's own arrival is moving the list; `onReaderScroll` gets each
    /// reader scroll's distance, `onMove` hears every move, and `onLost` hears that the scroll view left the screen, as
    /// when SwiftUI replaces it.
    init(scrollView: UIScrollView, filter: NewStoriesPillScrollFilter, isListMovingItself: @escaping () -> Bool,
         onReaderScroll: @escaping (CGFloat) -> Void, onMove: @escaping () -> Void = {},
         onLost: @escaping () -> Void) {
        self.scrollView = scrollView
        var rebased = filter
        rebased.rebase(contentSize: scrollView.contentSize)
        self.filter = rebased
        super.init()
        observation = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] scrollView, change in
            guard let old = change.oldValue?.y, let new = change.newValue?.y, old != new else { return }
            let contentSize = scrollView.contentSize
            let inWindow = scrollView.window != nil
            MainActor.assumeIsolated {
                guard let self else { return }
                guard inWindow else { onLost(); return }
                let now = CACurrentMediaTime()
                if isListMovingItself() { self.filter.listScrollsItself(at: now) }
                if let delta = self.filter.readerScroll(from: old, to: new, contentSize: contentSize, at: now) {
                    onReaderScroll(delta)
                }
                onMove()
            }
        }
    }

    func listScrollsItself(at time: TimeInterval) {
        filter.listScrollsItself(at: time)
    }

    func stop() {
        observation?.invalidate()
        observation = nil
    }
}

/// NewStoriesPill.swift clips the pill to the list's edge under the bar above it, or over the bar below it, so the
/// pill slides out from beneath that bar and never draws over it. Touches outside the pill reach the list.
final class NewStoriesPillTrack: UIView {
    static let height: CGFloat = 64

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === self ? nil : view
    }
}

/// NewStoriesPill.swift: the inline "N new stories" row that stands in for a tucked-away pill.
struct NewStoriesRowState: Equatable {
    let count: Int
    /// At the end of an oldest-first list rather than the top of a newest-first one.
    let atBottom: Bool
    /// The theme it's drawn in, so a theme change redraws it in the table and the cards.
    var theme = ""
}

/// NewStoriesPill.swift's colors and label, shared by the pill and the inline row.
enum NewStoriesAppearance {
    /// The pill's accent blue in the light, sepia, medium and dark themes.
    static let accentRGB: [NSNumber] = [0x477DBF, 0x8A6A33, 0x4F7FBA, 0x3F6EA8]

    static func title(count: Int) -> String {
        NBLocalization.plural("%@ new stories", groupedCount: count)
    }

    static func arrowName(atBottom: Bool) -> String {
        atBottom ? "arrow.down" : "arrow.up"
    }
}

/// FeedDetailObjCViewController.m's inline row: a full-width button the size of a compact story title, in the pill's
/// accent blue. It isn't a story, so it has no story location.
@objcMembers final class NewStoriesRowCell: UITableViewCell {
    static let reuseIdentifier = "NewStoriesRowCell"
    static var height: CGFloat { NewStoriesRowView.height(isGrid: false) }

    private let capsuleView = UIView()
    private let arrowImageView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "new-stories-row"

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.layer.cornerRadius = NewStoriesRowView.capsuleHeight / 2
        capsuleView.layer.cornerCurve = .continuous
        capsuleView.isUserInteractionEnabled = false
        contentView.addSubview(capsuleView)

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tintColor = .white
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "WhitneySSm-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        let label = UIStackView(arrangedSubviews: [arrowImageView, titleLabel])
        label.translatesAutoresizingMaskIntoConstraints = false
        label.spacing = 7
        label.alignment = .center
        capsuleView.addSubview(label)

        NSLayoutConstraint.activate([
            capsuleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: NewStoriesRowView.listInset),
            capsuleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -NewStoriesRowView.listInset),
            capsuleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            capsuleView.heightAnchor.constraint(equalToConstant: NewStoriesRowView.capsuleHeight),
            label.centerXAnchor.constraint(equalTo: capsuleView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 13)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(count: Int, atBottom: Bool) {
        let title = NewStoriesAppearance.title(count: count)
        titleLabel.text = title
        accessibilityLabel = title
        arrowImageView.image = UIImage(systemName: NewStoriesAppearance.arrowName(atBottom: atBottom))?
            .withRenderingMode(.alwaysTemplate)
        backgroundColor = ThemeManager.shared.storyListBackgroundColor
        contentView.backgroundColor = backgroundColor
        capsuleView.backgroundColor = ThemeManager.color(fromRGB: NewStoriesAppearance.accentRGB)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        capsuleView.alpha = highlighted ? 0.8 : 1
    }
}

/// FeedDetailGridView.swift's inline row, the SwiftUI twin of NewStoriesRowCell.
struct NewStoriesRowView: View {
    private func report(_ frame: CGRect?) {
        NewsBlurAppDelegate.shared?.feedDetailViewController?.newStoriesRowFrameChanged(frame)
    }

    static let capsuleHeight: CGFloat = 36
    static let listInset: CGFloat = 12

    /// The row's height in the list, its capsule and the space around it.
    static func height(isGrid: Bool) -> CGFloat {
        capsuleHeight + (isGrid ? 16 : 12)
    }

    let row: NewStoriesRowState
    let isGrid: Bool

    var body: some View {
        let title = NewStoriesAppearance.title(count: row.count)
        Button {
            NewsBlurAppDelegate.shared?.feedDetailViewController?.didTapNewStoriesRow()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: NewStoriesAppearance.arrowName(atBottom: row.atBottom))
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(Font.custom("WhitneySSm-Medium", size: 14))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: Self.capsuleHeight, maxHeight: Self.capsuleHeight)
            .background(Capsule().fill(Color.themed(NewStoriesAppearance.accentRGB)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isGrid ? 0 : Self.listInset)
        .frame(height: Self.height(isGrid: isGrid))
        // NewStoriesPill.swift keeps the floating pill away while any of this row is on screen.
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { report(geometry.frame(in: .global)) }
                .onChange(of: geometry.frame(in: .global)) { report($0) }
                .onDisappear { report(nil) }
        })
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("new-stories-row")
    }
}

/// NewStoriesPill.swift's state for the pill on one story list: where it is, and the scroll watch that tucks it away.
@MainActor final class NewStoriesPillState: NSObject {
    var presence = NewStoriesPillPresence()
    var isPresented = false
    var scrollWatch: NewStoriesPillScrollWatch?
    /// Kept across watches so a scroll the pill code just made isn't counted on the next scroll view either.
    var scrollFilter = NewStoriesPillScrollFilter(contentSize: .zero)
    var returnWork: DispatchWorkItem?
    var hideWork: DispatchWorkItem?
    /// The inline row the list shows now, so a change can insert or remove just that row.
    var shownRow: NewStoriesRowState?
    /// How many stories wait, as the pill and the row show them.
    var waiting = 0
    /// FeedDetailGridView.swift's row, in window coordinates, while SwiftUI has it laid out.
    var rowFrame: CGRect?

    func stopWatching() {
        stopScrollWatch()
        returnWork?.cancel()
        returnWork = nil
        hideWork?.cancel()
        hideWork = nil
    }

    /// Stops watching the scroll view, keeping the return timer for a pill scrolling tucked away.
    func stopScrollWatch() {
        if let scrollWatch { scrollFilter = scrollWatch.filter }
        scrollWatch?.stop()
        scrollWatch = nil
    }
}

extension FeedDetailViewController {
    private static var newStoriesPillStateKey: UInt8 = 0

    private var newStoriesPillState: NewStoriesPillState {
        if let state = objc_getAssociatedObject(self, &Self.newStoriesPillStateKey) as? NewStoriesPillState { return state }
        let state = NewStoriesPillState()
        objc_setAssociatedObject(self, &Self.newStoriesPillStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    private var newStoriesPillTrack: NewStoriesPillTrack? {
        view.subviews.first { $0 is NewStoriesPillTrack } as? NewStoriesPillTrack
    }

    private var newStoriesPill: NewStoriesPill? {
        newStoriesPillTrack?.subviews.first { $0 is NewStoriesPill } as? NewStoriesPill
    }

    /// Show or update the pill and the inline row. RealtimeUpdates.swift passes the number of waiting stories the list
    /// would show.
    @objc func showNewStoriesPill(count: Int, atBottom: Bool) {
        guard isViewLoaded else { return }
        let state = newStoriesPillState
        if let pill = newStoriesPill, pill.atBottom != atBottom {
            newStoriesPillTrack?.removeFromSuperview()
            state.isPresented = false
        }
        let pill = newStoriesPill ?? makeNewStoriesPill(atBottom: atBottom)
        pill.configure(count: count, atBottom: atBottom)
        state.waiting = count
        if let track = newStoriesPillTrack { view.bringSubviewToFront(track) }
        watchScrollingForNewStoriesPill()
        updateNewStoriesRow()
        refreshNewStoriesPill()
    }

    @objc func hideNewStoriesPill() {
        guard isViewLoaded else { return }
        let state = newStoriesPillState
        state.stopWatching()
        state.presence = NewStoriesPillPresence()
        state.waiting = 0
        state.rowFrame = nil
        slideNewStoriesPill(in: false)
        updateNewStoriesRow()
    }

    /// The inline row FeedDetailObjCViewController.m and FeedDetailGridView.swift show while stories wait, or nil.
    var newStoriesRow: NewStoriesRowState? {
        let state = newStoriesPillState
        guard isViewLoaded, let pill = newStoriesPill, state.waiting > 0, RealtimeNewStories.isEnabled() else { return nil }
        return NewStoriesRowState(count: state.waiting, atBottom: pill.atBottom, theme: ThemeManager.shared.theme ?? "")
    }

    /// The inline row's count for FeedDetailObjCViewController.m, 0 when it isn't shown.
    @objc var newStoriesRowCount: Int { newStoriesRow?.count ?? 0 }
    @objc var newStoriesRowAtBottom: Bool { newStoriesRow?.atBottom ?? false }

    /// Shows, updates or removes the inline row, keeping the stories on screen where they are.
    func updateNewStoriesRow() {
        let state = newStoriesPillState
        let row = newStoriesRow
        guard row != state.shownRow else { return }
        state.shownRow = row
        if isLegacyTable {
            newStoriesRowDidChange()
        } else {
            // SwiftUI's lazy layout keeps the cards on screen in place when a header appears or leaves above them.
            storyCache.newStoriesRow = row
        }
    }

    /// Whether any of the inline row is on screen.
    private var isNewStoriesRowOnScreen: Bool {
        let state = newStoriesPillState
        guard let row = state.shownRow else { return false }
        if isLegacyTable { return isNewStoriesRowVisible() }
        guard let scrollView = gridScrollView, scrollView.window != nil else { return false }
        let inset = scrollView.adjustedContentInset
        let visible = scrollView.bounds.inset(by: UIEdgeInsets(top: inset.top, left: 0, bottom: inset.bottom, right: 0))
        guard let frame = state.rowFrame else {
            // FeedDetailGridView.swift lays the row out on its next pass; at the top of the list, it's there.
            return !row.atBottom && visible.minY < NewStoriesRowView.height(isGrid: storyCache.isGrid) + 16
        }
        return frame.intersects(scrollView.convert(visible, to: nil))
    }

    /// Floats the pill when the inline row is off screen, unless scrolling dismissed it.
    func refreshNewStoriesPill() {
        let state = newStoriesPillState
        slideNewStoriesPill(in: state.presence.showsPill(waiting: state.waiting, rowOnScreen: isNewStoriesRowOnScreen))
    }

    /// FeedDetailGridView.swift's row moved on screen, or left it (nil).
    func newStoriesRowFrameChanged(_ frame: CGRect?) {
        let state = newStoriesPillState
        guard state.rowFrame != frame else { return }
        state.rowFrame = frame
        if state.waiting > 0 { refreshNewStoriesPill() }
    }

    /// FeedDetailObjCViewController.m and FeedDetailGridView.swift: the inline row was tapped. It does what tapping the
    /// pill does.
    @objc func didTapNewStoriesRow() {
        didTapNewStoriesPill()
    }

    @objc func updateNewStoriesPillTheme() {
        newStoriesPill?.updateTheme()
        updateNewStoriesRow()
    }

    func bringNewStoriesPillToFront() {
        guard let track = newStoriesPillTrack else { return }
        view.bringSubviewToFront(track)
        // The list may have switched between the table and the cards, or SwiftUI may have made a new scroll view.
        if newStoriesPillState.waiting > 0 { watchScrollingForNewStoriesPill() }
    }

    /// The pill code is about to scroll the list; NewStoriesPillScrollFilter doesn't count that as the reader's.
    @objc func newStoriesListScrollsItself() {
        let state = newStoriesPillState
        let now = CACurrentMediaTime()
        state.scrollFilter.listScrollsItself(at: now)
        state.scrollWatch?.listScrollsItself(at: now)
    }

    private func makeNewStoriesPill(atBottom: Bool) -> NewStoriesPill {
        let track = NewStoriesPillTrack()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.clipsToBounds = true
        view.addSubview(track)
        let pill = NewStoriesPill(frame: .zero)
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.isHidden = true
        pill.transform = Self.newStoriesPillTuckedAway(atBottom: atBottom)
        pill.addTarget(self, action: #selector(didTapNewStoriesPill), for: .touchUpInside)
        track.addSubview(pill)
        var constraints = [
            track.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            track.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: NewStoriesPillTrack.height),
            pill.centerXAnchor.constraint(equalTo: track.centerXAnchor)
        ]
        if atBottom {
            constraints.append(track.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor))
            constraints.append(pill.bottomAnchor.constraint(equalTo: track.bottomAnchor, constant: -14))
        } else {
            if let headerBar = storyTitlesHeaderBar {
                constraints.append(track.topAnchor.constraint(equalTo: headerBar.contentTopAnchor))
            } else {
                constraints.append(track.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor))
            }
            constraints.append(pill.topAnchor.constraint(equalTo: track.topAnchor, constant: 10))
        }
        NSLayoutConstraint.activate(constraints)
        return pill
    }

    /// Where the pill waits, just past the track's edge under the bar.
    private static func newStoriesPillTuckedAway(atBottom: Bool) -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: atBottom ? NewStoriesPillTrack.height : -NewStoriesPillTrack.height)
    }

    /// Slides the pill out from under its bar, or back under it; with Reduce Motion it fades.
    private func slideNewStoriesPill(in presenting: Bool) {
        guard let pill = newStoriesPill else { return }
        let state = newStoriesPillState
        guard state.isPresented != presenting else { return }
        state.isPresented = presenting
        let reduceMotion = ReaderMotion.reduceMotion
        let tucked = Self.newStoriesPillTuckedAway(atBottom: pill.atBottom)
        if presenting {
            pill.isHidden = false
            if reduceMotion {
                pill.transform = .identity
                pill.alpha = 0
            } else {
                pill.alpha = 1
            }
        }
        let animator = UIViewPropertyAnimator(duration: NewStoriesArrivalTiming.pillSlideDuration,
                                              timingParameters: reduceMotion ? UICubicTimingParameters(animationCurve: .easeOut)
                                                : UICubicTimingParameters(controlPoint1: CGPoint(x: 0.22, y: 1),
                                                                          controlPoint2: CGPoint(x: 0.36, y: 1)))
        animator.isInterruptible = true
        animator.addAnimations {
            if reduceMotion {
                pill.alpha = presenting ? 1 : 0
            } else {
                pill.transform = presenting ? .identity : tucked
            }
        }
        animator.addCompletion { [weak pill, weak state] _ in
            guard let pill, let state, !state.isPresented else { return }
            pill.isHidden = true
            pill.transform = tucked
            pill.alpha = 1
        }
        animator.startAnimation()
    }

    /// Watches the list's scrolling while the pill is out, or tucked away by scrolling, following the list's scroll
    /// view when it changes.
    private func watchScrollingForNewStoriesPill() {
        let state = newStoriesPillState
        guard let scrollView = isLegacyTable ? storyTitlesTable : gridScrollView else { return }
        guard state.scrollWatch?.scrollView !== scrollView else { return }
        state.stopScrollWatch()
        state.scrollWatch = NewStoriesPillScrollWatch(
            scrollView: scrollView, filter: state.scrollFilter,
            isListMovingItself: { [weak self] in
                guard let self else { return false }
                return self.newStoriesTableArrival != nil || self.storyCache.newStoryArrivals.isSettling
            },
            onReaderScroll: { [weak self] delta in
                guard let self, let pill = self.newStoriesPill else { return }
                self.newStoriesPillListScrolled(by: delta, atBottom: pill.atBottom)
            },
            onMove: { [weak self] in
                guard let self, self.newStoriesPillState.waiting > 0 else { return }
                self.refreshNewStoriesPill()
            },
            onLost: { [weak self] in
                DispatchQueue.main.async { [weak self] in self?.watchScrollingForNewStoriesPill() }
            })
    }

    private func newStoriesPillListScrolled(by delta: CGFloat, atBottom: Bool) {
        let state = newStoriesPillState
        // Only a scroll away from the pill while it shows starts its countdown; every scroll restarts the idle wait.
        let away = (atBottom ? delta < 0 : delta > 0) && state.isPresented
        guard let hideTime = state.presence.scrolled(awayFromPill: away, at: CACurrentMediaTime()) else { return }
        // The first scroll away starts the countdown; nothing the reader does next stops it, short of a tap.
        state.hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let state = self.newStoriesPillState
                state.hideWork = nil
                guard state.presence.hideTimerFired(at: CACurrentMediaTime()) else { return }
                self.refreshNewStoriesPill()
                self.scheduleNewStoriesPillReturn()
            }
        }
        state.hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, hideTime - CACurrentMediaTime()), execute: work)
    }

    /// Brings a tucked-away pill back once the list has sat still long enough, if stories are still waiting.
    private func scheduleNewStoriesPillReturn() {
        let state = newStoriesPillState
        state.returnWork?.cancel()
        guard let returnTime = state.presence.returnTime() else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let state = self.newStoriesPillState
                guard state.presence.isHiddenByScrolling else { return }
                guard state.presence.shouldReturn(at: CACurrentMediaTime()) else {
                    self.scheduleNewStoriesPillReturn()
                    return
                }
                state.presence = NewStoriesPillPresence()
                self.refreshNewStoriesPill()
            }
        }
        state.returnWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, returnTime - CACurrentMediaTime()), execute: work)
    }

    @objc private func didTapNewStoriesPill() {
        hideNewStoriesPill()
        RealtimeUpdates.shared.insertBufferedStories()
    }

    /// Put the stories the pill was holding into the list and slide them into place: from above the top of a
    /// newest-first list, pushing the rows below them down, or rising into place at the end of an oldest-first one.
    /// `insert` adds them to StoriesCollection and returns the hashes the list shows, in list order, or nil when it
    /// added nothing; `reload` redraws the list. RealtimeUpdates.swift supplies both.
    func presentNewStories(atBottom: Bool, insert: @escaping () -> [String]?, reload: @escaping () -> Void) {
        newStoriesTableArrival?.finish(cancelled: true)
        guard isViewLoaded, !isDashboard else {
            if insert() != nil { reload() }
            return
        }
        if isLegacyTable {
            presentNewStoriesInTable(atBottom: atBottom, insert: insert, reload: reload)
        } else {
            presentNewStoriesInCards(atBottom: atBottom, insert: insert, reload: reload)
        }
    }

    /// The list opened another feed or folder, or loaded its first page again: stop sliding rows that left it.
    @objc func cancelNewStoriesArrival() {
        newStoriesTableArrival?.finish(cancelled: true)
    }

    private func presentNewStoriesInTable(atBottom: Bool, insert: @escaping () -> [String]?,
                                          reload: @escaping () -> Void) {
        guard let table = storyTitlesTable, table.window != nil, !table.isHidden else {
            if insert() != nil { reload() }
            return
        }
        let reduceMotion = ReaderMotion.reduceMotion
        let top = -table.adjustedContentInset.top
        // NewStoriesPill.swift brings a newest-first list to its top before the stories go in, so the reader sees
        // them arrive. Scrolling up never passes a story, so mark-read-on-scroll leaves the list alone.
        guard !atBottom, table.contentOffset.y > top + 1 else {
            insertNewStoriesInTable(table, atBottom: atBottom, insert: insert, reload: reload)
            return
        }
        if reduceMotion {
            newStoriesListScrollsItself()
            table.contentOffset = CGPoint(x: table.contentOffset.x, y: top)
            insertNewStoriesInTable(table, atBottom: atBottom, insert: insert, reload: reload)
            return
        }
        let scroll = NewStoriesTableArrival(scrollingTable: table, to: top)
        newStoriesTableArrival = scroll
        scroll.start { [weak self, weak scroll, weak table] finished in
            guard let self, self.newStoriesTableArrival === scroll else { return }
            self.newStoriesTableArrival = nil
            if finished, let table {
                self.insertNewStoriesInTable(table, atBottom: atBottom, insert: insert, reload: reload)
            } else if insert() != nil {
                reload()
            }
        }
    }

    private func insertNewStoriesInTable(_ table: UITableView, atBottom: Bool, insert: () -> [String]?,
                                         reload: () -> Void) {
        let reduceMotion = ReaderMotion.reduceMotion
        let oldOffset = table.contentOffset.y
        // NewStoriesPill.swift keeps a picture of the rows on screen: those pushed off the bottom of a newest-first
        // list no longer have cells, but must still slide down and away. It's taken after the screen catches up, as
        // tapping the inline row has just removed that row.
        let snapshot = atBottom || reduceMotion ? nil : table.snapshotView(afterScreenUpdates: true)
        guard let hashes = insert() else { return }
        // NewStoriesPill.swift slides these rows itself, so ReaderMotion.swift's entrance must not also lift them.
        let session = ReaderMotion.session(self)
        hashes.forEach { session.markSeen($0) }
        reload()
        guard !hashes.isEmpty, let collection = storiesCollection else { return }
        // FeedDetailObjCViewController.m's reload may select or restore a row; the arrival starts from the list as
        // the reader saw it.
        newStoriesListScrollsItself()
        table.contentOffset = CGPoint(x: table.contentOffset.x, y: oldOffset)
        table.layoutIfNeeded()
        let rows: [NewStoriesTableArrival.Row] = hashes.compactMap { hash in
            let location = collection.location(ofStoryId: hash)
            guard location >= 0, let path = indexPath(forStoryLocation: location) else { return nil }
            let rect = table.rectForRow(at: path)
            return NewStoriesTableArrival.Row(hash: hash, location: Int(location), minY: rect.minY, height: rect.height)
        }.sorted { $0.minY < $1.minY }
        guard let first = rows.first else { return }

        let inset = table.adjustedContentInset
        let minimum = -inset.top
        let maximum = max(minimum, table.contentSize.height - table.bounds.height + inset.bottom)
        let visibleTop = oldOffset + inset.top
        let visibleBottom = oldOffset + table.bounds.height - inset.bottom
        let motion: NewStoriesTableArrival.Motion
        var target = oldOffset
        if atBottom {
            motion = reduceMotion ? .fade : .rise
            // NewStoriesPill.swift scrolls only when the first new row isn't already wholly on screen.
            if first.minY < visibleTop || first.minY + first.height > visibleBottom {
                let visibleHeight = table.bounds.height - inset.top - inset.bottom
                target = min(max(first.minY + first.height / 2 - visibleHeight / 2 - inset.top, minimum), maximum)
            }
        } else {
            // StoriesCollection.m put the stories at the top, where the list now is.
            motion = reduceMotion ? .fade : .push
        }
        let arrival = NewStoriesTableArrival(table: table, rows: rows, motion: motion, reduceMotion: reduceMotion,
                                             target: target)
        if motion == .push, let snapshot {
            arrival.addLeavingRows(snapshot, oldOffset: oldOffset)
        }
        newStoriesTableArrival = arrival
        arrival.start { [weak self, weak arrival] _ in
            if let self, self.newStoriesTableArrival === arrival { self.newStoriesTableArrival = nil }
        }
    }

    private func presentNewStoriesInCards(atBottom: Bool, insert: @escaping () -> [String]?,
                                          reload: @escaping () -> Void) {
        let reduceMotion = ReaderMotion.reduceMotion
        let scrollView = gridScrollView
        // NewStoriesPill.swift brings a newest-first list to its top first, so the reader sees the stories arrive.
        var scrollsToTop = false
        if !atBottom, let scrollView {
            let top = -scrollView.adjustedContentInset.top
            if scrollView.contentOffset.y > top + 1 {
                scrollsToTop = !reduceMotion
                newStoriesListScrollsItself()
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top), animated: !reduceMotion)
            }
        }
        let present = { [weak self] in
            guard let self, let hashes = insert() else { return }
            let session = self.storyCache.motionSession
            hashes.forEach { session.markArriving($0) }
            // An oldest-first list scrolls down to its new end first; the cards rise once they're in view.
            let scrollsToBottom = atBottom && scrollView != nil
            let start = CACurrentMediaTime() + (scrollsToBottom && !reduceMotion ? NewStoriesArrivalTiming.scrollDuration : 0)
            let cache = self.storyCache
            let arrivals = cache.newStoryArrivals
            // Grid cards keep their own places, so only the cards that land on screen cascade; staggering the rest
            // would leave the top of the screen empty while cards below it go first.
            let rowHeight: CGFloat = cache.isGrid ? cache.settings.gridHeight + 20 : 90
            let columns = cache.isGrid ? max(cache.settings.gridColumns, 1) : 1
            let onScreen = max(1, Int(ceil((scrollView?.bounds.height ?? 800) / rowHeight)) * columns)
            let total = arrivals.plan(hashes: hashes, atBottom: atBottom, start: start, reduceMotion: reduceMotion,
                                      onScreen: onScreen)
            if let cascade = arrivals.cascade {
                // A lazy grid stops drawing the cards pushed off the bottom, so a one-card-per-row grid covers its
                // old cards with a picture of them that slides down, uncovering the new cards above it.
                if cache.isGrid, cache.settings.gridColumns == 1, let scrollView {
                    self.slideLeavingCards(in: scrollView,
                                           by: CGFloat(hashes.count) * (cache.settings.gridHeight + 20))
                }
                // The cards already listed glide down to their new places as the new ones slide in above them;
                // FeedDetailCardView.swift keeps the reload from also crossfading every card's contents.
                var transaction = SwiftUI.Transaction(animation: cascade)
                transaction.isNewStoryArrival = true
                withTransaction(transaction) { reload() }
            } else {
                reload()
            }
            if scrollsToBottom, let scrollView {
                scrollView.layoutIfNeeded()
                let inset = scrollView.adjustedContentInset
                let bottom = max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
                self.newStoriesListScrollsItself()
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: bottom), animated: !reduceMotion)
            }
            let generation = arrivals.generation
            DispatchQueue.main.asyncAfter(deadline: .now() + (start - CACurrentMediaTime()) + total + 1) {
                arrivals.clear(generation: generation)
            }
        }
        if scrollsToTop {
            DispatchQueue.main.asyncAfter(deadline: .now() + NewStoriesArrivalTiming.scrollDuration, execute: present)
        } else {
            present()
        }
    }

    /// A picture of the cards on screen, over the SwiftUI list, sliding down `distance` on the arrival's curve. It is
    /// opaque, in FeedDetailGridView.swift's background color, so the real cards moving beneath it never show twice.
    private func slideLeavingCards(in scrollView: UIScrollView, by distance: CGFloat) {
        guard let picture = scrollView.snapshotView(afterScreenUpdates: false) else { return }
        picture.frame = scrollView.bounds
        picture.backgroundColor = ThemeManager.color(fromRGB: [0xE0E0E0, 0xF3E2CB, 0x363636, 0x000000])
        picture.isUserInteractionEnabled = false
        scrollView.addSubview(picture)
        let slide = CABasicAnimation(keyPath: "transform.translation.y")
        slide.fromValue = 0
        slide.toValue = distance
        slide.duration = NewStoriesArrivalTiming.duration
        slide.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false
        picture.layer.add(slide, forKey: "newStoryArrival")
        DispatchQueue.main.asyncAfter(deadline: .now() + NewStoriesArrivalTiming.duration + 0.05) {
            picture.removeFromSuperview()
        }
    }

    private static var newStoriesTableArrivalKey: UInt8 = 0

    /// The running table arrival, held here so a second tap, or a list that reloads, can stop it.
    var newStoriesTableArrival: NewStoriesTableArrival? {
        get { objc_getAssociatedObject(self, &Self.newStoriesTableArrivalKey) as? NewStoriesTableArrival }
        set { objc_setAssociatedObject(self, &Self.newStoriesTableArrivalKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

/// NewStoriesPill.swift: one timing for the stories the pill puts into the list. The web and Android apps use the
/// same numbers, so the stories arrive alike on every platform.
enum NewStoriesArrivalTiming {
    /// How long each row takes to slide into place.
    static let duration: Double = 0.32
    /// The delay between one row and the next.
    static let stagger: Double = 0.07
    /// The longest the stagger may spread a cascade, however many stories arrive at once.
    static let staggerSpan: Double = 0.40
    /// With Reduce Motion on, rows only fade in, this quickly.
    static let reducedMotionFade: Double = 0.15
    /// How long the pill takes to slide out from under its bar, or back under it.
    static let pillSlideDuration: Double = 0.3
    /// How long the list takes to scroll to where the stories arrive.
    static let scrollDuration: Double = 0.3

    static func stagger(count: Int) -> Double {
        count > 1 ? min(stagger, staggerSpan / Double(count - 1)) : 0
    }

    static var animation: Animation { .timingCurve(0.22, 1, 0.36, 1, duration: duration) }

    /// cubic-bezier(0.22, 1, 0.36, 1), the curve `animation` uses, for motion UIKit draws frame by frame.
    static func ease(_ progress: Double) -> Double {
        let x = min(max(progress, 0), 1)
        func bezier(_ t: Double, _ first: Double, _ second: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * first + 3 * u * t * t * second + t * t * t
        }
        var low = 0.0, high = 1.0, t = x
        for _ in 0..<24 {
            t = (low + high) / 2
            if bezier(t, 0.22, 0.36) < x { low = t } else { high = t }
        }
        return bezier(t, 1, 1)
    }
}

/// NewStoriesPill.swift slides the stories the pill put into the UITableView story list into place.
///
/// A newest-first list pushes: new row i (0 is the topmost of k) starts (k - 1 - i) staggers in and is still
/// c_i(t) = h_i * (1 - ease(t / duration)) of its height short of its place, and every row is drawn c_i higher for
/// each new row at or above it. The list doesn't scroll, so the table keeps drawing the rows on screen; each gets
/// its offset as an additive Core Animation track, and a picture of the rows pushed off the bottom slides away with
/// them. An oldest-first list scrolls to the new rows if they're off screen, then lets each rise from its own
/// height below its place, the topmost first. The same class also scrolls a list to its top beforehand.
@MainActor final class NewStoriesTableArrival: NSObject {
    struct Row {
        let hash: String
        let location: Int
        let minY: CGFloat
        let height: CGFloat
    }

    enum Motion {
        /// Scroll only, before the stories go in.
        case scroll
        /// A newest-first list's rows slide down from above, pushing the rows below.
        case push
        /// An oldest-first list's rows rise from below.
        case rise
        /// Reduce Motion: the rows only fade in.
        case fade
    }

    private static let animationKey = "newStoryArrival"
    private static let roleKey = "newStoryArrivalRole"

    private weak var table: UITableView?
    private let rows: [Row]
    private let rowIndex: [String: Int]
    private let motion: Motion
    private let reduceMotion: Bool
    private let delays: [Double]
    private let duration: Double
    private let total: Double
    private let target: CGFloat
    private var startOffset: CGFloat = 0
    private var scrollDuration: Double = 0
    private var scrollStart: CFTimeInterval = 0
    private var slideStart: CFTimeInterval = 0
    private var displayLink: CADisplayLink?
    private var leavingRows: UIView?
    private var animations: [String: CAAnimation] = [:]
    private var onFinish: ((Bool) -> Void)?

    init(table: UITableView, rows: [Row], motion: Motion, reduceMotion: Bool, target: CGFloat) {
        self.table = table
        self.rows = rows
        self.rowIndex = Dictionary(rows.enumerated().map { ($1.hash, $0) }, uniquingKeysWith: { first, _ in first })
        self.motion = motion
        self.reduceMotion = reduceMotion
        self.target = target
        let count = rows.count
        let stagger = motion == .push || motion == .rise ? NewStoriesArrivalTiming.stagger(count: count) : 0
        // The bottom-most new row leads a push from the top; the topmost leads a rise at the end.
        delays = rows.indices.map { Double(motion == .push ? count - 1 - $0 : $0) * stagger }
        duration = reduceMotion ? NewStoriesArrivalTiming.reducedMotionFade : NewStoriesArrivalTiming.duration
        total = (delays.max() ?? 0) + duration
        super.init()
    }

    convenience init(scrollingTable table: UITableView, to target: CGFloat) {
        self.init(table: table, rows: [], motion: .scroll, reduceMotion: false, target: target)
    }

    /// The rows a push moves off the bottom, pictured before the reload in `snapshot`, which shows the table's
    /// bounds at `oldOffset`.
    func addLeavingRows(_ snapshot: UIView, oldOffset: CGFloat) {
        guard let table, let first = rows.first else { return }
        let height = rows.reduce(0) { $0 + $1.height }
        let visibleBottom = oldOffset + table.bounds.height
        // Before the reload, everything from the first new row down was `height` higher than it is now.
        let top = max(first.minY, visibleBottom - height)
        guard top < visibleBottom else { return }
        let container = UIView(frame: CGRect(x: 0, y: top + height, width: table.bounds.width,
                                             height: visibleBottom - top))
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false
        snapshot.frame = CGRect(x: 0, y: oldOffset - top, width: table.bounds.width, height: table.bounds.height)
        container.addSubview(snapshot)
        table.addSubview(container)
        leavingRows = container
    }

    /// Runs the arrival; `onFinish` learns whether it ran to its end rather than being stopped.
    func start(onFinish: @escaping (Bool) -> Void) {
        guard let table else { onFinish(false); return }
        self.onFinish = onFinish
        startOffset = table.contentOffset.y
        scrollDuration = abs(target - startOffset) < 1 || reduceMotion ? 0 : NewStoriesArrivalTiming.scrollDuration
        if scrollDuration == 0 { setOffset(target, in: table) }
        scrollStart = CACurrentMediaTime()
        slideStart = scrollStart + scrollDuration
        if let leavingRows, let animation = animation(for: "above-\(rows.count)")?.copy() as? CAAnimation {
            animation.beginTime = leavingRows.layer.convertTime(slideStart, from: nil)
            leavingRows.layer.add(animation, forKey: Self.animationKey)
        }
        table.layoutIfNeeded()
        attachAnimations(in: table)
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func finish(cancelled: Bool) {
        guard let link = displayLink else { return }
        link.invalidate()
        displayLink = nil
        leavingRows?.removeFromSuperview()
        leavingRows = nil
        if let table {
            if !cancelled { setOffset(target, in: table) }
            for cell in table.visibleCells {
                if cancelled { cell.layer.removeAnimation(forKey: Self.animationKey) }
                cell.layer.setValue(nil, forKey: Self.roleKey)
            }
        }
        let onFinish = self.onFinish
        self.onFinish = nil
        onFinish?(!cancelled)
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let table, table.window != nil else { finish(cancelled: true); return }
        // NewStoriesPill.swift hands the list back as soon as the reader touches it.
        if table.isTracking { finish(cancelled: true); return }
        let now = CACurrentMediaTime()
        if now < slideStart {
            let progress = NewStoriesArrivalTiming.ease((now - scrollStart) / scrollDuration)
            setOffset(startOffset + (target - startOffset) * progress, in: table)
            table.layoutIfNeeded()
        } else {
            setOffset(target, in: table)
        }
        let end = motion == .scroll ? slideStart : slideStart + total
        if now >= end {
            finish(cancelled: false)
        } else {
            attachAnimations(in: table)
        }
    }

    private func setOffset(_ offset: CGFloat, in table: UITableView) {
        guard abs(table.contentOffset.y - offset) > 0.01 else { return }
        table.contentOffset = CGPoint(x: table.contentOffset.x, y: offset)
    }

    private func progress(of row: Int, at time: Double) -> Double {
        NewStoriesArrivalTiming.ease((time - delays[row]) / duration)
    }

    /// How far the new rows before `end` are still short of their places.
    private func collapse(before end: Int, at time: Double) -> CGFloat {
        (0..<min(end, rows.count)).reduce(0) { sum, row in
            sum + rows[row].height * CGFloat(1 - progress(of: row, at: time))
        }
    }

    /// A row's part in the arrival: a new row, or, in a push, a row below `n` new rows.
    private func role(of cell: UITableViewCell, at path: IndexPath, in table: UITableView) -> String? {
        if let hash = (cell as? FeedDetailTableCell)?.storyHash, let index = rowIndex[hash] { return "new-\(index)" }
        guard motion == .push else { return nil }
        let minY = table.rectForRow(at: path).minY
        let above = rows.filter { $0.minY < minY }.count
        return above > 0 ? "above-\(above)" : nil
    }

    private func attachAnimations(in table: UITableView) {
        guard motion != .scroll else { return }
        for cell in table.visibleCells {
            guard let path = table.indexPath(for: cell) else { continue }
            let role = role(of: cell, at: path, in: table)
            // A table reuses cells as it scrolls, so a cell may now show a row the arrival doesn't move.
            if cell.layer.value(forKey: Self.roleKey) as? String == role,
               role == nil || cell.layer.animation(forKey: Self.animationKey) != nil { continue }
            cell.layer.removeAnimation(forKey: Self.animationKey)
            cell.layer.setValue(role, forKey: Self.roleKey)
            guard let role, let animation = animation(for: role)?.copy() as? CAAnimation else { continue }
            animation.beginTime = cell.layer.convertTime(slideStart, from: nil)
            cell.layer.add(animation, forKey: Self.animationKey)
        }
    }

    private func animation(for role: String) -> CAAnimation? {
        if let animation = animations[role] { return animation }
        let parts = role.split(separator: "-")
        guard parts.count == 2, let index = Int(parts[1]) else { return nil }
        let isNew = parts[0] == "new"
        let samples = max(2, Int((total * 60).rounded(.up)) + 1)
        let times = (0..<samples).map { Double($0) / Double(samples - 1) }
        var tracks: [CAAnimation] = []
        if motion == .push || motion == .rise {
            let offsets: [CGFloat] = times.map { fraction in
                let time = fraction * total
                if motion == .rise { return rows[index].height * CGFloat(1 - progress(of: index, at: time)) }
                return -collapse(before: isNew ? index + 1 : index, at: time)
            }
            if offsets.contains(where: { abs($0) > 0.01 }) {
                let slide = CAKeyframeAnimation(keyPath: "transform.translation.y")
                slide.values = offsets
                slide.keyTimes = times.map { NSNumber(value: $0) }
                slide.isAdditive = true
                slide.duration = total
                slide.fillMode = .both
                tracks.append(slide)
            }
        }
        if isNew {
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = times.map { progress(of: index, at: $0 * total) }
            fade.keyTimes = times.map { NSNumber(value: $0) }
            fade.duration = total
            fade.fillMode = .both
            tracks.append(fade)
        }
        guard !tracks.isEmpty else { return nil }
        let group = CAAnimationGroup()
        group.animations = tracks
        group.duration = total
        group.fillMode = .backwards
        group.isRemovedOnCompletion = true
        animations[role] = group
        return group
    }
}

private struct NewStoryArrivalTransactionKey: TransactionKey {
    static let defaultValue = false
}

extension SwiftUI.Transaction {
    /// NewStoriesPill.swift marks the reload that puts the pill's stories into the SwiftUI list.
    var isNewStoryArrival: Bool {
        get { self[NewStoryArrivalTransactionKey.self] }
        set { self[NewStoryArrivalTransactionKey.self] = newValue }
    }
}

extension View {
    /// NewStoriesPill.swift: shows this view's changes at once during the reload that puts new stories into the
    /// list, so only the cards' places animate.
    func withoutNewStoryArrivalAnimation() -> some View {
        transaction { if $0.isNewStoryArrival { $0.animation = nil } }
    }
}

/// NewStoriesPill.swift's plan for the cards the pill puts into the SwiftUI grid or card list
/// (FeedDetailGridView.swift), read by each card as it's drawn.
@MainActor final class NewStoryArrivals {
    struct Arrival {
        let start: CFTimeInterval
        let delay: Double
        /// 1 rises from below, 0 only fades.
        let direction: CGFloat
        let animation: Animation
    }

    private var arrivals: [String: Arrival] = [:]
    private var transitions: [String: AnyTransition] = [:]
    /// The reload's animation when new stories arrive at the top of the list.
    private(set) var cascade: Animation?
    private(set) var generation = 0
    private var settlesAt: CFTimeInterval = 0

    func arrival(for hash: String) -> Arrival? { arrivals[hash] }
    func transition(for hash: String) -> AnyTransition? { transitions[hash] }

    /// Whether cards are still sliding into place, when FeedDetailGridView.swift must not take a card above the top
    /// edge for one the reader scrolled past.
    var isSettling: Bool { CACurrentMediaTime() < settlesAt }

    /// Plans `hashes`, in list order, and returns how long the cascade lasts. Only the `onScreen` cards nearest
    /// where the stories arrive cascade; the others are off screen and simply take their places.
    func plan(hashes: [String], atBottom: Bool, start: CFTimeInterval, reduceMotion: Bool,
              onScreen: Int = .max) -> Double {
        generation += 1
        arrivals.removeAll()
        transitions.removeAll()
        cascade = nil
        let count = min(hashes.count, max(onScreen, 1))
        let stagger = reduceMotion ? 0 : NewStoriesArrivalTiming.stagger(count: count)
        // NewStoriesPill.swift: the bottom-most new card leads at the top of the list, the topmost at its end.
        let delays = hashes.indices.map { index in
            atBottom ? Double(min(index, count - 1)) * stagger : Double(max(count - 1 - index, 0)) * stagger
        }
        let total = reduceMotion ? NewStoriesArrivalTiming.reducedMotionFade
            : (delays.max() ?? 0) + NewStoriesArrivalTiming.duration
        settlesAt = start + total + 0.1
        if reduceMotion || atBottom {
            // Cards arriving at the end of the list may still be off screen, so each rises or fades once it's in view.
            let animation = reduceMotion ? Animation.easeOut(duration: NewStoriesArrivalTiming.reducedMotionFade)
                : NewStoriesArrivalTiming.animation
            for (index, hash) in hashes.enumerated() {
                arrivals[hash] = Arrival(start: start, delay: delays[index], direction: reduceMotion ? 0 : 1,
                                         animation: animation)
            }
            return total
        }
        // A lazy SwiftUI grid draws only the cards whose places are on screen, so each new card slides down by its
        // own height into its place rather than from a stack above the list, which would leave the screen empty.
        cascade = NewStoriesArrivalTiming.animation
        for (index, hash) in hashes.enumerated() {
            transitions[hash] = AnyTransition.asymmetric(
                insertion: AnyTransition.move(edge: .top).combined(with: .opacity)
                    .animation(NewStoriesArrivalTiming.animation.delay(delays[index])),
                removal: .opacity)
        }
        return total
    }

    func clear(generation: Int) {
        guard generation == self.generation else { return }
        arrivals.removeAll()
        transitions.removeAll()
        cascade = nil
    }
}

/// NewStoriesPill.swift brings in a card the pill put into the SwiftUI list. A card arriving at the top of the list
/// slides in with the reload's transaction; one arriving at the end, which may be off screen, rises once it's in
/// view. Cards that were already listed keep SwiftUI's default fade for any other insertion.
struct NewStoryArrivalModifier: ViewModifier {
    @State private var arrival: NewStoryArrivals.Arrival?
    @State private var progress: CGFloat
    @State private var height: CGFloat = 0
    @State private var started = false
    @Environment(\.readerMotionViewport) private var viewport
    private let transition: AnyTransition

    init(arrivals: NewStoryArrivals, hash: String) {
        let arrival = arrivals.arrival(for: hash)
        _arrival = State(initialValue: arrival)
        _progress = State(initialValue: arrival == nil ? 1 : 0)
        transition = arrivals.transition(for: hash) ?? (arrival == nil ? .opacity : .identity)
    }

    func body(content: Content) -> some View {
        content
            .offset(y: (arrival?.direction ?? 0) * height * (1 - progress))
            .opacity(Double(progress))
            .background(Group {
                if arrival != nil && !started {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { reveal(in: geometry.frame(in: .global)) }
                            .onChange(of: geometry.frame(in: .global)) { reveal(in: $0) }
                            .onChange(of: viewport) { _ in reveal(in: geometry.frame(in: .global)) }
                    }
                }
            })
            .transition(transition)
    }

    private func reveal(in frame: CGRect) {
        // NewStoriesPill.swift waits for the card to reach the screen, not SwiftUI's offscreen prefetch.
        guard let arrival, !started, viewport.isEmpty || frame.intersects(viewport) else { return }
        started = true
        // The card's height places it a whole card away while it's still invisible; the rise starts on the next
        // pass, so SwiftUI animates from there rather than from where the card sits.
        height = frame.height
        let delay = max(0, arrival.start + arrival.delay - CACurrentMediaTime())
        DispatchQueue.main.async {
            withAnimation(arrival.animation.delay(delay)) { progress = 1 }
        }
    }
}
