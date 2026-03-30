//
//  DiscoverSitesViewController.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
@objc class DiscoverSitesViewController: BaseViewController {
    private var hostingController: UIHostingController<DiscoverSitesView>?
    private var viewModel: DiscoverSitesViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.appDelegate = NewsBlurAppDelegate.shared()
        self.title = "Add + Discover Sites"

        updateBackgroundColor()

        let vm = DiscoverSitesViewModel()
        self.viewModel = vm

        let discoverView = DiscoverSitesView(
            viewModel: vm,
            onTryFeed: { [weak self] feed in
                self?.handleTryFeed(feed)
            },
            onAddFeed: { [weak self] feed in
                self?.handleAddFeed(feed)
            }
        )

        let hosting = UIHostingController(rootView: discoverView)
        hosting.view.backgroundColor = .clear
        self.hostingController = hosting

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

    private func handleTryFeed(_ feed: DiscoverPopularFeed) {
        let rawDict = feed.rawFeedDict
        let feedId = feed.id
        appDelegate?.loadTryFeedDetailView(
            feedId,
            withStory: nil,
            isSocial: false,
            withUser: rawDict,
            showFindingStory: false
        )
    }

    private func handleAddFeed(_ feed: DiscoverPopularFeed) {
        let feedAddress = feed.feedAddress
        appDelegate?.openAddSite(withFeedAddress: feedAddress)
    }
}
