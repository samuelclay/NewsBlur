//
//  DiscoverSitesViewController.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI
import Combine

@available(iOS 15.0, *)
@objc class DiscoverSitesViewController: BaseViewController {
    static var viewModelFactory: (() -> DiscoverSitesViewModel)?
    var initialTab: DiscoverTab = .search
    private var subscriptions = Set<AnyCancellable>()
    private var hostingController: UIHostingController<DiscoverSitesView>?
    private var viewModel: DiscoverSitesViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        if self.appDelegate == nil { self.appDelegate = NewsBlurAppDelegate.shared() }
        self.title = "Add + Discover Sites"

        updateBackgroundColor()

        let vm = Self.viewModelFactory?() ?? DiscoverSitesViewModel()
        vm.activeTab = initialTab
        self.viewModel = vm
        vm.$addedSuccess.filter { $0 }.sink { [weak self] _ in
            self?.appDelegate?.reloadFeedsView(false)
        }.store(in: &subscriptions)

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
        updateBackgroundColor()
        if let viewModel { viewModel.onTabSelected(viewModel.activeTab) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel?.stopPolling()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appDelegate?.detailViewController.discoverSitesDidAppear(self)
    }

    private func handleTryFeed(_ feed: DiscoverPopularFeed) {
        Task { [weak self] in
            guard let self, let resolved = await self.viewModel?.resolvePreviewFeed(feed) else { return }
            guard self.appDelegate?.detailViewController.isDiscoverSitesVisible == true else { return }
            self.appDelegate?.detailViewController.beginDiscoverPreview()
            self.appDelegate?.loadTryFeedDetailView(
                resolved.id, withStory: nil, isSocial: false,
                withUser: resolved.rawFeedDict, showFindingStory: false
            )
        }
    }

    private func handleAddFeed(_ feed: DiscoverPopularFeed) {
        viewModel?.addFeed(url: feed.feedAddress)
    }
}
