//
//  SplitViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Subclass of `UISplitViewController` to enable customizations.
class SplitViewController: UISplitViewController {
    private var ownsCompactPhoneWidth = false
    private var previousPhoneWidthOverride: UIUserInterfaceSizeClass?
    private var isUpdatingPhoneWidthPolicy = false

    func updatePhoneWidthPolicy(for traits: UITraitCollection) {
        guard !isUpdatingPhoneWidthPolicy else { return }
        isUpdatingPhoneWidthPolicy = true
        defer { isUpdatingPhoneWidthPolicy = false }

        let needsCompactWidth = traits.userInterfaceIdiom == .phone && traits.verticalSizeClass == .compact &&
            !Utilities.usesSystemVerticalBar(traits)
        if needsCompactWidth {
            guard !ownsCompactPhoneWidth else { return }
            previousPhoneWidthOverride = traitOverrides.contains(UITraitHorizontalSizeClass.self)
                ? traitOverrides.horizontalSizeClass : nil
            ownsCompactPhoneWidth = true
            // SplitViewController.swift keeps conventional landscape phones in UIKit's real collapsed navigation, not a squeezed expanded reader.
            traitOverrides.horizontalSizeClass = .compact
        } else if ownsCompactPhoneWidth {
            ownsCompactPhoneWidth = false
            if let previousPhoneWidthOverride {
                traitOverrides.horizontalSizeClass = previousPhoneWidthOverride
            } else {
                traitOverrides.remove(UITraitHorizontalSizeClass.self)
            }
            previousPhoneWidthOverride = nil
        }
    }

    @objc var isFeedsListHidden: Bool {
        // SplitViewController.swift distinguishes a primary overlay from a triple split's supplementary column.
        if style == .tripleColumn {
            return [.secondaryOnly, .oneBesideSecondary, .oneOverSecondary].contains(displayMode)
        }
        return displayMode == .secondaryOnly
    }

    /// Draggable divider between the feeds list and detail columns.
    private let feedsDividerView = DividerView(frame: .zero)

    /// Whether the user is currently dragging the feeds divider.
    private var isDraggingFeedsDivider = false
    private var feedsDividerDragStart = CGPoint.zero
    private var feedsDividerInitialWidth: CGFloat = 0
    private var duoPrimaryWidthLimits: (minimum: CGFloat, maximum: CGFloat)?
    private var hasManagedDuoSidebarWidth = false
    private var isUpdatingDuoSidebarWidth = false

    /// A folded Duo must retain the user's width instead of persisting a transient native column width.
    var preservesDuoSidebarWidth: Bool {
        hasManagedDuoSidebarWidth && traitCollection.userInterfaceIdiom == .phone
    }

    /// Preference key for the feeds column width.
    private static let feedsWidthKey = "split_primary_width"

    /// Update the theme of the split view controller.
    @objc func updateTheme() {
        headerView.backgroundColor = ThemeManager.color(fromRGB: [0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222])
        feedsDividerView.updateTheme()
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return ThemeManager.shared.isDarkTheme ? .lightContent : .darkContent
    }

    override var childForStatusBarStyle: UIViewController? {
        return nil
    }

    private let headerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitUserInterfaceIdiom.self, UITraitVerticalSizeClass.self,
                                UITraitHorizontalSizeClass.self]) { (controller: SplitViewController, _) in
            controller.updatePhoneWidthPolicy(for: controller.traitCollection)
        }
        updatePhoneWidthPolicy(for: traitCollection)

        headerView.translatesAutoresizingMaskIntoConstraints = false

        updateTheme()

        view.insertSubview(headerView, at: 0)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])

        // Set up primary column width constraints for draggable resizing.
        minimumPrimaryColumnWidth = 250
        maximumPrimaryColumnWidth = 700
        let savedWidth = CGFloat(UserDefaults.standard.float(forKey: Self.feedsWidthKey))
        if savedWidth > 0 {
            preferredPrimaryColumnWidth = savedWidth
        }

        // Add draggable divider between feeds and detail columns.
        // Hide the drawn line since UISplitViewController already draws a column separator.
        feedsDividerView.showsLine = false
        feedsDividerView.handleOffset = 8
        feedsDividerView.isAccessibilityElement = true
        feedsDividerView.accessibilityIdentifier = "feeds-sidebar-resize-handle"
        feedsDividerView.accessibilityLabel = "Resize sidebar"
        feedsDividerView.accessibilityHint = "Drag to change the feed and story list width."
        view.addSubview(feedsDividerView)

        // Use a pan gesture on the divider view itself so it captures the drag
        // before the system's NSSplitView (on Catalyst) can intercept it.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleFeedsDividerPan(_:)))
        feedsDividerView.addGestureRecognizer(pan)
    }

    override func viewWillLayoutSubviews() {
        // SplitViewController.swift also observes native side-bar capability changes when a fold keeps the same size classes.
        updatePhoneWidthPolicy(for: traitCollection)
        super.viewWillLayoutSubviews()
        updateDuoSidebarWidthPolicy()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDuoSidebarWidthPolicy()

        // SplitViewController.swift reconciles embedded panes after UIKit resolves the actual fold-dependent display mode.
        let detailNavigation = viewController(for: .secondary) as? UINavigationController
        (detailNavigation?.viewControllers.first as? DetailViewController)?.updateResolvedFeedSidebarLayout()
        updateFeedsDividerPosition()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            NewsBlurAppDelegate.shared?.updateSplitBehavior(false)
        })

        coordinator.animate { _ in
            self.updateFeedsDividerPosition()
        }
    }

    // MARK: - Feeds divider

    private var isExpandedDuoSplit: Bool {
        !isCollapsed && style == .doubleColumn && traitCollection.userInterfaceIdiom == .phone &&
            (Utilities.usesSystemVerticalBar(traitCollection) ||
             (traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass != .compact))
    }

    private func updateDuoSidebarWidthPolicy() {
        guard !isUpdatingDuoSidebarWidth else { return }
        isUpdatingDuoSidebarWidth = true
        defer { isUpdatingDuoSidebarWidth = false }

        guard isExpandedDuoSplit else {
            if let limits = duoPrimaryWidthLimits {
                duoPrimaryWidthLimits = nil
                setPrimaryWidthLimits(minimum: limits.minimum, maximum: limits.maximum)
            }
            return
        }

        hasManagedDuoSidebarWidth = true
        if duoPrimaryWidthLimits == nil {
            duoPrimaryWidthLimits = (minimumPrimaryColumnWidth, maximumPrimaryColumnWidth)
        }
        guard let limits = duoPrimaryWidthLimits else { return }
        let maximumWidth = min(limits.maximum, view.bounds.width - 200)
        guard maximumWidth > 0 else { return }
        let savedWidth = CGFloat(UserDefaults.standard.float(forKey: Self.feedsWidthKey))
        let requestedWidth = savedWidth > 0 ? savedWidth : 320
        let width = min(max(requestedWidth, limits.minimum), maximumWidth)

        // SplitViewController.swift uses public bounds because Duo retains its default width when only the preferred width changes.
        // Keep the original drag limits separately, and reread the shared preference so folds and test cleanup cannot leave a stale request.
        if preferredPrimaryColumnWidth != width { preferredPrimaryColumnWidth = width }
        setPrimaryWidthLimits(minimum: width, maximum: width)
    }

    private func setPrimaryWidthLimits(minimum: CGFloat, maximum: CGFloat) {
        // SplitViewController.swift avoids an intermediate minimum greater than the maximum when shrinking.
        if minimumPrimaryColumnWidth > minimum { minimumPrimaryColumnWidth = minimum }
        if maximumPrimaryColumnWidth != maximum { maximumPrimaryColumnWidth = maximum }
        if minimumPrimaryColumnWidth != minimum { minimumPrimaryColumnWidth = minimum }
    }

    private var resizesDuoPrimaryOverlay: Bool {
        isExpandedDuoSplit && displayMode == .oneOverSecondary
    }

    private var primaryColumnFrame: CGRect? {
        guard let primary = viewController(for: .primary)?.viewIfLoaded,
              primary.window === view.window, !primary.isHidden, primary.bounds.width > 0 else { return nil }
        return primary.convert(primary.bounds, to: view)
    }

    private var primaryColumnIsOnLeft: Bool {
        (primaryEdge == .leading) == (view.effectiveUserInterfaceLayoutDirection == .leftToRight)
    }

    private func updateFeedsDividerPosition() {
        let shouldShow: Bool
        if isCollapsed {
            shouldShow = false
        } else {
            switch displayMode {
            case .oneBesideSecondary, .twoBesideSecondary:
                shouldShow = true
            case .oneOverSecondary:
                // SplitViewController.swift enables the native primary handle for expanded Duo overlays without changing iPad overlay behavior.
                shouldShow = resizesDuoPrimaryOverlay
            default:
                shouldShow = false
            }
        }
        feedsDividerView.isHidden = !shouldShow

        guard shouldShow, let primaryFrame = primaryColumnFrame,
              view.bounds.intersects(primaryFrame) else {
            feedsDividerView.isHidden = true
            return
        }

        let safeTop = max(view.safeAreaInsets.top, primaryFrame.minY)
        let dividerWidth: CGFloat = 5
        let edge = primaryColumnIsOnLeft ? primaryFrame.maxX : primaryFrame.minX

        // SplitViewController.swift follows UIKit's rendered column, including during a drag that UIKit clamps.
        feedsDividerView.frame = CGRect(
            x: edge - dividerWidth / 2,
            y: safeTop,
            width: dividerWidth,
            height: max(0, min(view.bounds.maxY, primaryFrame.maxY) - safeTop)
        )
        feedsDividerView.handleOffset = resizesDuoPrimaryOverlay ? 0 : 8
        feedsDividerView.setNeedsLayout()

        view.bringSubviewToFront(feedsDividerView)
    }

    // MARK: - Feeds divider drag via gesture recognizer

    @objc private func handleFeedsDividerPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard !feedsDividerView.isHidden, let primaryFrame = primaryColumnFrame else { return }
            isDraggingFeedsDivider = true
            feedsDividerDragStart = gesture.location(in: view)
            feedsDividerInitialWidth = primaryFrame.width
            feedsDividerView.isHighlighted = true

        case .changed:
            guard isDraggingFeedsDivider else { return }
            let point = gesture.location(in: view)
            let direction: CGFloat = primaryColumnIsOnLeft ? 1 : -1
            let requestedWidth = feedsDividerInitialWidth + (point.x - feedsDividerDragStart.x) * direction
            let limits = duoPrimaryWidthLimits ?? (minimum: minimumPrimaryColumnWidth, maximum: maximumPrimaryColumnWidth)
            let maximumWidth = min(limits.maximum, view.bounds.width - 200)
            guard maximumWidth >= limits.minimum else { return }
            let newWidth = min(max(requestedWidth, limits.minimum), maximumWidth)

            UIView.performWithoutAnimation {
                if isExpandedDuoSplit {
                    UserDefaults.standard.set(Float(newWidth), forKey: Self.feedsWidthKey)
                    updateDuoSidebarWidthPolicy()
                } else {
                    preferredPrimaryColumnWidth = newWidth
                }
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            updateFeedsDividerPosition()
            persistRenderedPrimaryWidth()

        case .ended, .cancelled, .failed:
            guard isDraggingFeedsDivider else { return }
            isDraggingFeedsDivider = false
            feedsDividerView.isHighlighted = false
            view.setNeedsLayout()
            view.layoutIfNeeded()
            updateFeedsDividerPosition()
            persistRenderedPrimaryWidth()

        default:
            break
        }
    }

    private func persistRenderedPrimaryWidth() {
        guard let primaryFrame = primaryColumnFrame else { return }
        UserDefaults.standard.set(Float(primaryFrame.width), forKey: Self.feedsWidthKey)
    }

    // Can do menu validation here.
//    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        print("canPerformAction: \(action) with \(sender ?? "nil")")
//        return true
//    }
}
