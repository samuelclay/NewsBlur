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
    @objc var isFeedsListHidden: Bool {
        return [.oneOverSecondary, .secondaryOnly].contains(displayMode)
    }

    /// Draggable divider between the feeds list and detail columns.
    private let feedsDividerView = DividerView(frame: .zero)

    /// Whether the user is currently dragging the feeds divider.
    private var isDraggingFeedsDivider = false

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

        headerView.translatesAutoresizingMaskIntoConstraints = false

        updateTheme()

        view.addSubview(headerView)

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
        view.addSubview(feedsDividerView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

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

    private func updateFeedsDividerPosition() {
        let shouldShow: Bool
        if isCollapsed {
            shouldShow = false
        } else {
            switch displayMode {
            case .oneBesideSecondary, .twoBesideSecondary:
                shouldShow = true
            default:
                shouldShow = false
            }
        }
        feedsDividerView.isHidden = !shouldShow

        guard shouldShow else { return }

        let safeTop = view.safeAreaInsets.top
        let dividerWidth: CGFloat = 5
        let xPosition: CGFloat

        if isDraggingFeedsDivider {
            xPosition = feedsDividerView.frame.origin.x
        } else {
            let columnWidth = primaryColumnWidth
            guard columnWidth > 0 else {
                feedsDividerView.isHidden = true
                return
            }
            xPosition = columnWidth - dividerWidth / 2
        }

        feedsDividerView.frame = CGRect(
            x: xPosition,
            y: safeTop,
            width: dividerWidth,
            height: view.bounds.height - safeTop
        )

        view.bringSubviewToFront(feedsDividerView)
    }

    // MARK: - Touch handling for feeds divider

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch.view === feedsDividerView else {
            super.touchesBegan(touches, with: event)
            return
        }

        isDraggingFeedsDivider = true
        feedsDividerView.isHighlighted = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingFeedsDivider, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }

        let point = touch.location(in: view)
        let newWidth = point.x

        guard newWidth >= minimumPrimaryColumnWidth,
              newWidth <= min(maximumPrimaryColumnWidth, view.bounds.width - 200) else {
            return
        }

        preferredPrimaryColumnWidth = newWidth

        let dividerWidth: CGFloat = 5
        feedsDividerView.frame.origin.x = newWidth - dividerWidth / 2

        UserDefaults.standard.set(Float(newWidth), forKey: Self.feedsWidthKey)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDraggingFeedsDivider {
            isDraggingFeedsDivider = false
            feedsDividerView.isHighlighted = false
        } else {
            super.touchesEnded(touches, with: event)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDraggingFeedsDivider {
            isDraggingFeedsDivider = false
            feedsDividerView.isHighlighted = false
        } else {
            super.touchesCancelled(touches, with: event)
        }
    }

    // Can do menu validation here.
//    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        print("canPerformAction: \(action) with \(sender ?? "nil")")
//        return true
//    }
}
