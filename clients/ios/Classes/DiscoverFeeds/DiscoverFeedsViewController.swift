//
//  DiscoverFeedsViewController.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import SwiftUI
import Combine

@available(iOS 15.0, *)
@objc class DiscoverFeedsViewController: BaseViewController {
    static var viewModelFactory: ((String?, [String]?) -> DiscoverFeedsViewModel)?
    static var cardActionsFactory: (() -> DiscoverSitesViewModel)?
    private let feedId: String?
    private let feedIds: [String]?
    private var hostingController: UIHostingController<DiscoverFeedsView>?
    private var viewModel: DiscoverFeedsViewModel?
    private var cardActions: DiscoverSitesViewModel?
    private var subscriptions = Set<AnyCancellable>()

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

        view.accessibilityIdentifier = "related-sites-dialog"
        updateBackgroundColor()

        let viewModel: DiscoverFeedsViewModel
        if let factory = Self.viewModelFactory {
            viewModel = factory(feedId, feedIds)
        } else if let feedIds = feedIds {
            viewModel = DiscoverFeedsViewModel(feedIds: feedIds)
        } else if let feedId = feedId {
            viewModel = DiscoverFeedsViewModel(feedId: feedId)
        } else {
            return
        }
        self.viewModel = viewModel
        let cardActions = Self.cardActionsFactory?() ?? DiscoverSitesViewModel()
        self.cardActions = cardActions
        cardActions.$addedSuccess.filter { $0 }.sink { [weak self] _ in
            self?.appDelegate?.reloadFeedsView(false)
        }.store(in: &subscriptions)

        let discoverView = DiscoverFeedsView(
            viewModel: viewModel,
            cardActions: cardActions,
            onDismiss: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true, completion: self.onDismiss)
            },
            onTryFeed: { [weak self] feed in
                self?.handleTryFeed(feed)
            },
            onOpenStory: { [weak self] feed, story in
                self?.handleTryFeed(feed, story: story)
            },
            onAddFeed: { [weak self] feed in
                self?.handleAddFeed(feed)
            },
            onUpgrade: { [weak self] in
                self?.handleUpgrade()
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

    private func handleTryFeed(_ feed: DiscoverPopularFeed, story: DiscoverStory? = nil) {
        Task { [weak self] in await self?.openPreview(feed, story: story) }
    }

    func openPreview(_ feed: DiscoverPopularFeed, story: DiscoverStory?) async {
        guard let model = cardActions, !model.isPreparingPreview,
              let resolved = await model.resolvePreviewFeed(feed),
              viewIfLoaded?.window != nil, let app = appDelegate else { return }
        dismiss(animated: true) {
            // DiscoverFeedsViewController.swift establishes exact lookup before the reader chooses its first-page cache path.
            app.cleanUpTryFeed()
            app.inFindingStoryMode = story != nil
            app.findingStoryStartDate = story == nil ? nil : Date()
            app.findingStoryDictionary = nil
            app.tryFeedStoryTitle = nil
            app.storiesCollection.readFilterOverride = story == nil ? nil : "all"
            app.storiesCollection.notificationStoryHash = story?.id
            app.storiesCollection.notificationStory = nil
            app.loadTryFeedDetailView(resolved.id, withStory: story?.id, isSocial: false,
                                     withUser: resolved.rawFeedDict, showFindingStory: story != nil)
        }
    }

    private func handleAddFeed(_ feed: DiscoverPopularFeed) {
        cardActions?.addFeed(url: feed.feedAddress)
    }

    private func handleUpgrade() {
        dismiss(animated: true) { [weak self] in
            self?.appDelegate?.showPremiumDialogForArchive()
        }
    }
}
