//
//  DiscoverFeedsViewController.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
@objc class DiscoverFeedsViewController: BaseViewController {
    private let feedId: String?
    private let feedIds: [String]?
    private var hostingController: UIHostingController<DiscoverFeedsView>?
    private var viewModel: DiscoverFeedsViewModel?

    @objc var onDismiss: (() -> Void)?
    @objc var onTryFeed: (([String: Any]) -> Void)?
    @objc var onAddFeed: ((String) -> Void)?

    @objc init(feedId: String) {
        self.feedId = feedId
        self.feedIds = nil
        super.init(nibName: nil, bundle: nil)
        self.appDelegate = NewsBlurAppDelegate.shared()
    }

    @objc init(feedIds: [String]) {
        self.feedId = nil
        self.feedIds = feedIds
        super.init(nibName: nil, bundle: nil)
        self.appDelegate = NewsBlurAppDelegate.shared()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBackgroundColor()

        let viewModel: DiscoverFeedsViewModel
        if let feedIds = feedIds {
            viewModel = DiscoverFeedsViewModel(feedIds: feedIds)
        } else if let feedId = feedId {
            viewModel = DiscoverFeedsViewModel(feedId: feedId)
        } else {
            return
        }
        self.viewModel = viewModel

        let discoverView = DiscoverFeedsView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            },
            onTryFeed: { [weak self] feed in
                self?.handleTryFeed(feed)
            },
            onAddFeed: { [weak self] feed in
                self?.handleAddFeed(feed)
            }
        )

        let hostingController = UIHostingController(rootView: discoverView)
        hostingController.view.backgroundColor = .clear
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateBackgroundColor() {
        let theme = ThemeManager.shared.effectiveTheme ?? ThemeStyleLight
        let backgroundColor: UIColor
        switch theme {
        case ThemeStyleSepia:
            backgroundColor = UIColor(red: 0.96, green: 0.90, blue: 0.83, alpha: 1.0)
        case ThemeStyleMedium:
            backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.24, alpha: 1.0)
        case ThemeStyleDark:
            backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        default:
            backgroundColor = UIColor(red: 0.92, green: 0.93, blue: 0.90, alpha: 1.0)
        }
        view.backgroundColor = backgroundColor
    }

    private func handleTryFeed(_ feed: DiscoverFeed) {
        let rawDict = feed.rawFeedDict
        dismiss(animated: true) { [weak self] in
            guard let appDelegate = self?.appDelegate else { return }
            appDelegate.loadTryFeedDetailView(
                feed.id,
                withStory: nil,
                isSocial: false,
                withUser: rawDict,
                showFindingStory: false
            )
        }
    }

    private func handleAddFeed(_ feed: DiscoverFeed) {
        let feedAddress = feed.feedAddress
        dismiss(animated: true) { [weak self] in
            guard let appDelegate = self?.appDelegate else { return }
            appDelegate.openAddSite(withFeedAddress: feedAddress)
        }
    }
}
