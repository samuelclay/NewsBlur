import UIKit
import SwiftUI

/// ReaderMotion.swift keeps story identity separate from reusable cells and SwiftUI view lifetime.
@objcMembers final class ReaderMotionSession: NSObject, ObservableObject {
    private var seen = Set<String>()
    private var starts = [String: CFTimeInterval]()
    private var batchStart: CFTimeInterval = 0
    private var batchIndex = 0
    @Published private(set) var presentationReady = true
    @Published private(set) var visit = 0
    private var hasPresented = false

    func reset() {
        seen.removeAll(); starts.removeAll(); batchStart = 0; batchIndex = 0
        hasPresented = false; presentationReady = true; visit += 1
    }

    func prepareForAppearance() { if !hasPresented { presentationReady = false } }
    func didAppear() { hasPresented = true; presentationReady = true }
    func hasSeen(_ key: String) -> Bool { seen.contains(key) }
    func recordStart(_ start: CFTimeInterval, key: String) { starts[key] = start }
    func ongoingStart(for key: String) -> CFTimeInterval? {
        guard let start = starts[key], CACurrentMediaTime() < start + 0.36 else { return nil }
        return start
    }

    func delay(for key: String) -> Double? {
        guard presentationReady, seen.insert(key).inserted else { return nil }
        let now = CACurrentMediaTime()
        if now - batchStart > 0.1 { batchStart = now; batchIndex = 0 }
        defer { batchIndex += 1 }
        return min(Double(batchIndex) * 0.035, 0.175)
    }

    func start(for key: String, position: Int, maximumDelay: Double) -> CFTimeInterval? {
        start(for: key, visualPosition: Double(position), maximumDelay: maximumDelay)
    }

    func start(for key: String, frame: CGRect, viewport: CGRect) -> CFTimeInterval? {
        // ReaderMotion.swift orders variable-height SwiftUI cards by their top edge, including prefetched cards.
        let position = max(0, frame.minY - viewport.minY) / 100
        return start(for: key, visualPosition: position, maximumDelay: 0.175)
    }

    private func start(for key: String, visualPosition: Double, maximumDelay: Double) -> CFTimeInterval? {
        guard presentationReady, seen.insert(key).inserted else { return nil }
        let now = CACurrentMediaTime()
        if now - batchStart > 0.1 { batchStart = now; batchIndex = 0 }
        // ReaderMotion.swift anchors the batch to screen order, never UIKit's willDisplay callback order.
        // ReaderMotion.swift compresses later gaps without starting the bottom rows simultaneously at a hard cap.
        let decay = 1 - min(0.035 / maximumDelay, 1)
        let start = batchStart + maximumDelay * (1 - pow(decay, max(visualPosition, 0)))
        starts[key] = start
        return start
    }
}

@objcMembers final class ReaderMotion: NSObject {
    private static var themeSnapshotKey: UInt8 = 0

    static func beginThemeTransition(_ window: UIWindow?) -> UIView? {
        guard let window, !window.isHidden, !UIAccessibility.isReduceMotionEnabled,
              UIApplication.shared.applicationState == .active,
              let snapshot = window.snapshotView(afterScreenUpdates: false) else { return nil }
        // ReaderMotion.swift captures the current presentation before replacing an interrupted crossfade.
        (objc_getAssociatedObject(window, &themeSnapshotKey) as? UIView)?.removeFromSuperview()
        snapshot.frame = window.bounds
        snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        snapshot.isUserInteractionEnabled = false
        snapshot.accessibilityElementsHidden = true
        window.addSubview(snapshot)
        objc_setAssociatedObject(window, &themeSnapshotKey, snapshot, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return snapshot
    }

    static func finishThemeTransition(_ snapshot: UIView) {
        snapshot.superview?.layoutIfNeeded()
        // ReaderMotion.swift lets SwiftUI and the article WebView publish the new theme under the cover.
        DispatchQueue.main.async {
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.3,
                           delay: 0, options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
                snapshot.alpha = 0
            } completion: { _ in
                if let window = snapshot.superview,
                   objc_getAssociatedObject(window, &themeSnapshotKey) as? UIView === snapshot {
                    objc_setAssociatedObject(window, &themeSnapshotKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                snapshot.removeFromSuperview()
            }
        }
    }

    private static var sessionKey: UInt8 = 0
    private static let waitingViews = NSHashTable<UIView>.weakObjects()
    private static let reduceMotionObserver = NotificationCenter.default.addObserver(
        forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main
    ) { _ in
        if UIAccessibility.isReduceMotionEnabled { finishPendingEntrancesForReducedMotion() }
    }
    static func session(_ owner: NSObject) -> ReaderMotionSession {
        if let session = objc_getAssociatedObject(owner, &sessionKey) as? ReaderMotionSession { return session }
        let session = ReaderMotionSession()
        objc_setAssociatedObject(owner, &sessionKey, session, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return session
    }

    static func row(_ view: UIView, key: String, owner: NSObject, scrolling: Bool) {
        let session = session(owner)
        guard prepareRow(view, key: key, owner: owner, session: session) else { return }
        if let delay = session.delay(for: key) {
            let start = CACurrentMediaTime() + (scrolling ? min(delay, 0.09) : delay)
            session.recordStart(start, key: key)
            animateEntrance(view, start: start, distance: scrolling ? 8 : 16)
        } else if view.layer.animation(forKey: "readerEntrance") == nil, let start = session.ongoingStart(for: key) {
            animateEntrance(view, start: start, distance: scrolling ? 8 : 16)
        }
    }

    static func row(_ view: UIView, key: String, owner: NSObject, scrolling: Bool, position: Int) {
        let session = session(owner)
        guard prepareRow(view, key: key, owner: owner, session: session) else { return }
        if session.hasSeen(key), view.layer.animation(forKey: "readerEntrance") != nil { return }
        guard let start = session.start(for: key, position: position, maximumDelay: scrolling ? 0.09 : 0.175)
            ?? session.ongoingStart(for: key) else { return }
        animateEntrance(view, start: start, distance: scrolling ? 8 : 16)
    }

    private static func prepareRow(_ view: UIView, key: String, owner: NSObject, session: ReaderMotionSession) -> Bool {
        guard view.window != nil, session.presentationReady else {
            // ReaderMotion.swift holds cached story content through preparation/push without changing reusable view alpha.
            if UIAccessibility.isReduceMotionEnabled {
                view.layer.removeAnimation(forKey: "readerWaitingForAppearance")
                waitingViews.remove(view)
            } else if owner is FeedDetailObjCViewController, !session.hasSeen(key) {
                _ = reduceMotionObserver
                waitingViews.add(view)
                let hold = CABasicAnimation(keyPath: "opacity")
                hold.fromValue = 0; hold.toValue = 0; hold.duration = 3600
                view.layer.add(hold, forKey: "readerWaitingForAppearance")
            }
            return false
        }
        view.layer.removeAnimation(forKey: "readerWaitingForAppearance")
        waitingViews.remove(view)
        return true
    }

    static func finishPendingEntrancesForReducedMotion() {
        // ReaderMotion.swift responds immediately if accessibility changes during an in-progress navigation push.
        for view in waitingViews.allObjects { view.layer.removeAnimation(forKey: "readerWaitingForAppearance") }
        waitingViews.removeAllObjects()
    }

    static func presentRows(_ table: UITableView, owner: NSObject) {
        session(owner).didAppear()
        table.layoutIfNeeded()
        for cell in table.visibleCells {
            guard let path = table.indexPath(for: cell) else { continue }
            table.delegate?.tableView?(table, willDisplay: cell, forRowAt: path)
        }
    }

    @objc(positionForIndexPath:table:) static func position(for indexPath: IndexPath, table: UITableView) -> Int {
        let visibleTop = table.contentOffset.y + table.adjustedContentInset.top
        let first = visibleTop <= 0.5 ? IndexPath(row: 0, section: 0)
            : table.indexPathForRow(at: CGPoint(x: table.bounds.midX, y: visibleTop + 1))
                ?? table.indexPathsForVisibleRows?.min() ?? indexPath
        func ordinal(_ path: IndexPath) -> Int {
            path.row + (0..<path.section).reduce(0) { $0 + table.numberOfRows(inSection: $1) + 1 }
        }
        return max(0, ordinal(indexPath) - ordinal(first))
    }

    /// ReaderMotion.swift retires a presentation copy; data and reusable cells update immediately.
    static func leave(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled, view.window != nil, !view.isHidden,
              view.alpha > 0, let host = view.superview,
              let snapshot = view.snapshotView(afterScreenUpdates: false) else { return }
        snapshot.frame = view.frame
        snapshot.isUserInteractionEnabled = false
        snapshot.accessibilityElementsHidden = true
        host.addSubview(snapshot)
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            snapshot.alpha = 0
            snapshot.transform = CGAffineTransform(translationX: 0, y: -8)
        } completion: { _ in snapshot.removeFromSuperview() }
    }

    static func retireLoadingRows(_ table: UITableView) {
        guard !UIAccessibility.isReduceMotionEnabled, table.window != nil,
              !table.isHidden, table.alpha > 0, let host = table.superview else { return }
        // ReaderMotion.swift inspects existing views: visibleCells can force layout during a data reload
        // and invoke FeedDetailObjCViewController.m's pagination callbacks before the reload is complete.
        func loadingCells(in view: UIView) -> [NBLoadingCell] {
            if let cell = view as? NBLoadingCell { return [cell] }
            if view is UITableViewCell { return [] }
            return view.subviews.flatMap { loadingCells(in: $0) }
        }
        for cell in loadingCells(in: table) where !cell.isHidden && cell.alpha > 0 {
            let frame = cell.convert(cell.bounds, to: host).intersection(table.frame)
            guard !frame.isNull, !frame.isEmpty else { continue }
            guard let snapshot = cell.snapshotView(afterScreenUpdates: false) else { continue }
            snapshot.frame = frame
            snapshot.isUserInteractionEnabled = false
            snapshot.accessibilityElementsHidden = true
            host.addSubview(snapshot)
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
                snapshot.alpha = 0
                snapshot.transform = CGAffineTransform(translationX: 0, y: -10)
            } completion: { _ in snapshot.removeFromSuperview() }
        }
    }

    static func enter(_ view: UIView, delay: Double = 0, distance: CGFloat = 8) {
        animateEntrance(view, start: CACurrentMediaTime() + delay, distance: distance)
    }

    private static func animateEntrance(_ view: UIView, start: CFTimeInterval, distance: CGFloat) {
        view.layer.removeAnimation(forKey: "readerEntrance")
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // ReaderMotion.swift uses additive presentation motion so toolbar and swipe transforms remain owned by navigation.
        let lift = CASpringAnimation(keyPath: "transform.translation.y")
        lift.isAdditive = true
        #if targetEnvironment(macCatalyst)
        lift.fromValue = distance * 0.65
        #else
        lift.fromValue = distance
        #endif
        lift.toValue = 0
        lift.mass = 1; lift.stiffness = 300; lift.damping = 23
        lift.duration = 0.36
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = view.layer.opacity; fade.duration = 0.18
        let group = CAAnimationGroup()
        group.animations = [lift, fade]; group.duration = 0.36
        group.beginTime = view.layer.convertTime(start, from: nil)
        group.fillMode = .backwards
        view.layer.add(group, forKey: "readerEntrance")
    }

    static func pop(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 0.86, 1.12, 1]
        animation.keyTimes = [0, 0.2, 0.65, 1]
        animation.duration = 0.32
        view.layer.add(animation, forKey: "readerPop")
    }

    static func cascade(_ views: [UIView]) {
        for (index, view) in views.filter({ !$0.isHidden }).enumerated() {
            enter(view, delay: min(Double(index) * 0.03, 0.15), distance: 8)
        }
    }

    static func screen(_ controller: UIViewController) {
        // ReaderMotion.swift leaves the reader's identity-based row and article choreography to its own hooks.
        guard !(controller is FeedsObjCViewController), !(controller is FeedDetailObjCViewController),
              !(controller is StoryDetailObjCViewController), !(controller is MenuViewController) else { return }
        func sections(_ view: UIView, depth: Int) -> [UIView] {
            guard !view.isHidden, view.alpha > 0 else { return [] }
            if let table = view as? UITableView { return table.visibleCells.sorted { $0.frame.minY < $1.frame.minY } }
            if let collection = view as? UICollectionView {
                return collection.visibleCells.sorted {
                    $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
                }
            }
            if depth == 0 || view is UIControl || view is UILabel || view is UIImageView { return [view] }
            return view.subviews.flatMap { sections($0, depth: depth - 1) }
        }
        cascade(Array(sections(controller.view, depth: 3).prefix(40)))
    }

    static func finishRefresh(_ control: UIRefreshControl) {
        guard control.isRefreshing, !UIAccessibility.isReduceMotionEnabled else { control.endRefreshing(); return }
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = control.tintColor
        check.frame = CGRect(x: control.bounds.midX - 12, y: control.bounds.midY - 12, width: 24, height: 24)
        control.addSubview(check)
        pop(check)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            leave(check)
            check.removeFromSuperview()
            control.endRefreshing()
        }
    }
}

private struct ReaderMotionViewportKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}

extension EnvironmentValues {
    var readerMotionViewport: CGRect {
        get { self[ReaderMotionViewportKey.self] }
        set { self[ReaderMotionViewportKey.self] = newValue }
    }
}

struct ReaderEntrance: ViewModifier {
    @ObservedObject var session: ReaderMotionSession
    let key: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.readerMotionViewport) private var viewport
    @State private var appeared = false
    @State private var appearedVisit = -1

    private var isVisible: Bool { reduceMotion || (appeared && appearedVisit == session.visit) }

    func body(content: Content) -> some View {
        content.opacity(isVisible ? 1 : 0).offset(y: isVisible ? 0 : 12)
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { reveal(in: geometry.frame(in: .global)) }
                    .onChange(of: geometry.frame(in: .global)) { reveal(in: $0) }
                    .onChange(of: viewport) { _ in reveal(in: geometry.frame(in: .global)) }
                    .onChange(of: session.presentationReady) { _ in reveal(in: geometry.frame(in: .global)) }
                    .onChange(of: session.visit) { _ in
                        appeared = false
                        reveal(in: geometry.frame(in: .global))
                    }
            })
            .onChange(of: reduceMotion) { _ in appearedVisit = session.visit; appeared = true }
    }

    private func reveal(in frame: CGRect) {
        // ReaderMotion.swift waits for the viewport, not SwiftUI's offscreen prefetch callback.
        guard !appeared || appearedVisit != session.visit else { return }
        guard session.presentationReady, !viewport.isEmpty, frame.intersects(viewport) else { return }
        if appearedVisit != session.visit { appeared = false; appearedVisit = session.visit }
        guard !reduceMotion, let start = session.start(for: key, frame: frame, viewport: viewport) else { appeared = true; return }
        let delay = max(0, start - CACurrentMediaTime())
        withAnimation(.spring(response: 0.36, dampingFraction: 0.76).delay(delay)) { appeared = true }
    }
}
