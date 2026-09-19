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
@objc class DiscoverSitesViewController: BaseViewController, UIGestureRecognizerDelegate {
    static var viewModelFactory: (() -> DiscoverSitesViewModel)?
    var initialTab: DiscoverTab = .search
    private var subscriptions = Set<AnyCancellable>()
    private var hostingController: UIHostingController<DiscoverSitesView>?
    private(set) var sourcePager: DiscoverSourcesPagerController?
    private var viewModel: DiscoverSitesViewModel?
    private var accountGeneration = UUID()

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

        let pager = DiscoverSourcesPagerController(
            viewModel: vm,
            onTryFeed: { [weak self] feed in
                self?.handleTryFeed(feed)
            },
            onOpenStory: { [weak self] feed, story in
                self?.handleTryFeed(feed, story: story)
            },
            onAddFeed: { [weak self] feed in
                self?.handleAddFeed(feed)
            }
        )
        sourcePager = pager
        let discoverView = DiscoverSitesView(viewModel: vm, pager: pager)

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

        // DiscoverSitesViewController.swift receives swipes across all hosted content, including empty space.
        let sourceSwipe = UIPanGestureRecognizer(target: self, action: #selector(handleSourceSwipe(_:)))
        sourceSwipe.name = "discover-source-swipe"
        sourceSwipe.maximumNumberOfTouches = 1
        sourceSwipe.delaysTouchesBegan = false
        sourceSwipe.delaysTouchesEnded = false
        sourceSwipe.delegate = self
        view.addGestureRecognizer(sourceSwipe)
        if let backGesture = navigationController?.interactivePopGestureRecognizer {
            sourceSwipe.require(toFail: backGesture)
        }
    }

    private func updateBackgroundColor() {
        view.backgroundColor = UIColor(DiscoverColors.background)
    }

    override func updateTheme() {
        super.updateTheme()
        guard isViewLoaded else { return }
        updateBackgroundColor()
        sourcePager?.updateTheme()
        ThemeManager.shared.update(navigationController)
        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func handleSourceSwipe(_ gesture: UIPanGestureRecognizer) {
        guard let sourcePager else { return }
        switch gesture.state {
        case .began:
            view.endEditing(true)
            sourcePager.beginPaging()
        case .changed:
            sourcePager.updatePaging(translation: gesture.translation(in: view).x)
        case .ended:
            sourcePager.endPaging(velocity: gesture.velocity(in: view).x, cancelled: false)
        case .cancelled, .failed:
            sourcePager.endPaging(velocity: 0, cancelled: true)
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y) * 1.5
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // DiscoverSitesViewController.swift reserves gestures for the horizontal control touched at the start.
        var touchedView = touch.view
        while let candidate = touchedView, candidate !== view {
            if let scrollView = candidate as? UIScrollView,
               scrollView !== sourcePager?.scrollView, scrollView.isScrollEnabled {
                let horizontalInsets = scrollView.adjustedContentInset.left + scrollView.adjustedContentInset.right
                if scrollView.alwaysBounceHorizontal || scrollView.contentSize.width + horizontalInsets > scrollView.bounds.width + 1 {
                    return false
                }
            }
            touchedView = candidate.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // DiscoverSitesViewController.swift preserves nested scrolling while the pager handles content drags.
        otherGestureRecognizer is UIPanGestureRecognizer && !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer)
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

    private func handleTryFeed(_ feed: DiscoverPopularFeed, story: DiscoverStory? = nil) {
        Task { [weak self] in await self?.openPreview(feed, story: story) }
    }

    func openPreview(_ feed: DiscoverPopularFeed, story: DiscoverStory?) async {
        guard let model = viewModel, !model.isPreparingPreview,
              appDelegate?.detailViewController.isDiscoverSitesVisible == true else { return }
        let generation = accountGeneration
        let previousSelection = model.selectedPreviewStoryID
        model.selectedPreviewStoryID = story?.id
        guard let resolved = await model.resolvePreviewFeed(feed) else {
            if accountGeneration == generation { model.selectedPreviewStoryID = previousSelection }
            return
        }
        guard accountGeneration == generation,
              let app = appDelegate, app.detailViewController.isDiscoverSitesVisible else { return }
        app.detailViewController.beginDiscoverPreview()
        app.storiesCollection.readFilterOverride = story == nil ? nil : "all"
        // DiscoverSitesViewController.swift reuses the reader's exact-hash lookup for cached stories outside the first page.
        app.storiesCollection.notificationStoryHash = story?.id
        app.storiesCollection.notificationStory = nil
        app.loadTryFeedDetailView(resolved.id, withStory: story?.id, isSocial: false,
                                  withUser: resolved.rawFeedDict, showFindingStory: story != nil)
        // DiscoverSitesViewController.swift restores lookup metadata after NewsBlurAppDelegate.m clears prior preview state.
        app.inFindingStoryMode = story != nil
        app.findingStoryStartDate = story == nil ? nil : Date()
        app.findingStoryDictionary = nil
        app.tryFeedStoryTitle = nil
    }

    private func handleAddFeed(_ feed: DiscoverPopularFeed) {
        viewModel?.addFeed(url: feed.feedAddress)
    }

    func resetForAccountChange() {
        accountGeneration = UUID()
        subscriptions.removeAll()
        // DiscoverSitesViewController.swift removes SwiftUI observers before resetting account-owned state.
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        sourcePager?.reset()
        sourcePager = nil
        viewModel?.reset()
        viewModel = nil
    }
}

// DiscoverSitesViewController.swift retains each visited page so source navigation preserves its scroll position.
@available(iOS 15.0, *)
final class DiscoverSourcesPagerController: UIViewController, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    private let viewModel: DiscoverSitesViewModel
    private let onTryFeed: ((DiscoverPopularFeed) -> Void)?
    private let onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)?
    private let onAddFeed: ((DiscoverPopularFeed) -> Void)?
    private var pages: [DiscoverTab: UIHostingController<DiscoverSourcePageView>] = [:]
    private var selectedTab: DiscoverTab
    private var lastRequestedTab: DiscoverTab
    private var dragStartIndex: Int?
    private var dragStartOffset: CGFloat = 0
    private var settlingTab: DiscoverTab?
    private var previousWidth: CGFloat = 0

    init(viewModel: DiscoverSitesViewModel,
         onTryFeed: ((DiscoverPopularFeed) -> Void)?,
         onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)? = nil,
         onAddFeed: ((DiscoverPopularFeed) -> Void)?) {
        self.viewModel = viewModel
        self.selectedTab = viewModel.activeTab
        self.lastRequestedTab = viewModel.activeTab
        self.onTryFeed = onTryFeed
        self.onOpenStory = onOpenStory
        self.onAddFeed = onAddFeed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bounces = false
        scrollView.delaysContentTouches = false
        scrollView.delegate = self
        scrollView.accessibilityIdentifier = "discover-source-pager"
        // DiscoverSitesViewController.swift forwards its ancestor pan to page content while preserving horizontal controls.
        scrollView.panGestureRecognizer.isEnabled = false
        view.addSubview(scrollView)
        preparePage(selectedTab)
        updateTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: width * CGFloat(DiscoverTab.allCases.count), height: view.bounds.height)
        for (tab, page) in pages { page.view.frame = frame(for: tab) }
        if width > 0, width != previousWidth {
            let destination = settlingTab ?? selectedTab
            dragStartIndex = nil
            settlingTab = destination
            scrollView.setContentOffset(CGPoint(x: offset(for: destination), y: 0), animated: false)
            finishSettling()
            previousWidth = width
        }
    }

    func select(_ tab: DiscoverTab, animated: Bool) {
        loadViewIfNeeded()
        guard tab != lastRequestedTab else { return }
        lastRequestedTab = tab
        dragStartIndex = nil
        let start = DiscoverTab.allCases.firstIndex(of: selectedTab) ?? 0
        let end = DiscoverTab.allCases.firstIndex(of: tab) ?? 0
        // DiscoverSitesViewController.swift jumps distant tab selections without loading unrelated source catalogs.
        settle(on: tab, animated: animated && abs(start - end) == 1)
    }

    func beginPaging() {
        loadViewIfNeeded()
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        settlingTab = nil
        dragStartOffset = scrollView.contentOffset.x
        let nearest = view.bounds.width > 0 ? Int((dragStartOffset / view.bounds.width).rounded()) : 0
        dragStartIndex = min(max(nearest, 0), DiscoverTab.allCases.count - 1)
    }

    func updatePaging(translation: CGFloat) {
        guard let start = dragStartIndex, view.bounds.width > 0 else { return }
        let width = view.bounds.width
        let destination = start + (translation < 0 ? 1 : -1)
        if DiscoverTab.allCases.indices.contains(destination) { preparePage(DiscoverTab.allCases[destination]) }
        let minOffset = CGFloat(max(start - 1, 0)) * width
        let maxOffset = CGFloat(min(start + 1, DiscoverTab.allCases.count - 1)) * width
        let position = min(max(dragStartOffset - translation, minOffset), maxOffset)
        scrollView.setContentOffset(CGPoint(x: position, y: 0), animated: false)
    }

    func endPaging(velocity: CGFloat, cancelled: Bool) {
        guard let start = dragStartIndex else { return }
        dragStartIndex = nil
        let distance = scrollView.contentOffset.x - CGFloat(start) * view.bounds.width
        var destination = start
        if !cancelled {
            if abs(velocity) > 450 { destination += velocity < 0 ? 1 : -1 }
            else if abs(distance) > view.bounds.width * 0.5 { destination += distance > 0 ? 1 : -1 }
        }
        destination = min(max(destination, 0), DiscoverTab.allCases.count - 1)
        settle(on: DiscoverTab.allCases[destination], animated: true)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { finishSettling() }

    private func settle(on tab: DiscoverTab, animated: Bool) {
        preparePage(tab)
        settlingTab = tab
        let target = CGPoint(x: offset(for: tab), y: 0)
        if animated && UIView.areAnimationsEnabled && view.window != nil && abs(scrollView.contentOffset.x - target.x) > 0.5 {
            scrollView.setContentOffset(target, animated: true)
        } else {
            scrollView.setContentOffset(target, animated: false)
            finishSettling()
        }
    }

    private func finishSettling() {
        guard let tab = settlingTab else { return }
        settlingTab = nil
        selectedTab = tab
        lastRequestedTab = tab
        for (pageTab, page) in pages { page.view.accessibilityElementsHidden = pageTab != tab }
        if viewModel.activeTab != tab { viewModel.activeTab = tab }
    }

    private func preparePage(_ tab: DiscoverTab) {
        guard pages[tab] == nil else { return }
        let page = UIHostingController(rootView: DiscoverSourcePageView(tab: tab, viewModel: viewModel,
            onTryFeed: onTryFeed, onOpenStory: onOpenStory, onAddFeed: onAddFeed))
        pages[tab] = page
        addChild(page)
        page.view.frame = frame(for: tab)
        page.view.backgroundColor = UIColor(DiscoverColors.background)
        page.view.accessibilityIdentifier = "discover-page-\(tab.rawValue)"
        page.view.accessibilityElementsHidden = tab != selectedTab
        scrollView.addSubview(page.view)
        page.didMove(toParent: self)
    }

    private func offset(for tab: DiscoverTab) -> CGFloat {
        CGFloat(DiscoverTab.allCases.firstIndex(of: tab) ?? 0) * view.bounds.width
    }

    private func frame(for tab: DiscoverTab) -> CGRect {
        CGRect(x: offset(for: tab), y: 0, width: view.bounds.width, height: view.bounds.height)
    }

    func updateTheme() {
        guard isViewLoaded else { return }
        let color = UIColor(DiscoverColors.background)
        view.backgroundColor = color
        scrollView.backgroundColor = color
        for page in pages.values { page.view.backgroundColor = color }
    }

    func reset() {
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        dragStartIndex = nil
        settlingTab = nil
        for page in pages.values {
            page.willMove(toParent: nil)
            page.view.removeFromSuperview()
            page.removeFromParent()
        }
        pages.removeAll()
    }
}
