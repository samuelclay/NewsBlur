//
//  FeedDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import SwiftUI
import QuartzCore

/// List of stories for a feed.
class FeedDetailViewController: FeedDetailObjCViewController {
    private var gridViewController: UIHostingController<FeedDetailGridView>?
    
    private var dashboardViewController: UIHostingController<FeedDetailDashboardView>?

    private var dailyBriefingViewController: UIHostingController<DailyBriefingRootView>?
    
    lazy var storyCache = StoryCache()

    private lazy var dailyBriefingStore = DailyBriefingStore(controller: self)

    private var shouldShowDailyBriefingOverlay: Bool {
        isDailyBriefingView && dailyBriefingStore.presentationState != .stories
    }

    private var shouldShowDailyBriefingStoryTitles: Bool {
        isDailyBriefingView && dailyBriefingStore.presentationState == .stories
    }
    
    enum SectionLayoutKind: Int, CaseIterable {
        /// Feed cells before the story.
        case feedBeforeStory
        
        /// The selected story.
        case selectedStory
        
        /// Feed cells after the story.
        case feedAfterStory
        
        /// Loading cell at the end.
        case loading
    }
    
    var wasGridView: Bool {
        return appDelegate.detailViewController.wasGridView
    }
    
    var isExperimental: Bool {
        return appDelegate.detailViewController.style == .experimental || isDashboard
    }
    
    var isSwiftUI: Bool {
        return isGridView || isExperimental
    }

    var isDailyBriefingView: Bool {
        return storiesCollection.isDailyBriefing
    }
    
    var feedColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            return 4
        }
        
        return columns
    }
    
    var gridHeight: CGFloat {
        guard let pref = UserDefaults.standard.string(forKey: "grid_height") else {
            return 400
        }
        
        switch pref {
        case "xs":
            return 250
        case "short":
            return 300
        case "tall":
            return 400
        case "xl":
            return 450
        default:
            return 350
        }
    }
    
    enum DashboardOperation {
        case none
        case change(DashList)
        case addFirst
        case addBefore(DashList)
        case addAfter(DashList)
    }
    
    var dashboardOperation = DashboardOperation.none
    
    private func makeGridViewController() -> UIHostingController<FeedDetailGridView> {
        let gridView = FeedDetailGridView(feedDetailInteraction: self, cache: storyCache)
        let gridViewController = UIHostingController(rootView: gridView)
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return gridViewController
    }
    
    private func makeDashboardViewController() -> UIHostingController<FeedDetailDashboardView> {
        let dashboardView = FeedDetailDashboardView(feedDetailInteraction: self, cache: storyCache)
        let dashboardViewController = UIHostingController(rootView: dashboardView)
        dashboardViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return dashboardViewController
    }

    private func makeDailyBriefingViewController() -> UIHostingController<DailyBriefingRootView> {
        let briefingView = DailyBriefingRootView(store: dailyBriefingStore)
        let briefingViewController = UIHostingController(rootView: briefingView)
        briefingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        briefingViewController.view.backgroundColor = ThemeManager.color(
            fromRGB: [0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x161618]
        )
        briefingViewController.view.isOpaque = true

        return briefingViewController
    }
    
    private func add(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)

        let topAnchor = storyTitlesHeaderBar?.headerContainer.bottomAnchor ?? view.topAnchor
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changedLayout()
    }

    fileprivate func refreshDailyBriefingPresentation() {
        guard isViewLoaded else { return }

        updateContentVisibility()
    }

    private var isPhoneOrCompactLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone || appDelegate.isCompactWidth
    }

    private func correctReturnFrameIfNeeded() {
        guard let navigationController else { return }

        let containerBounds = view.superview?.bounds ?? navigationController.view.bounds
        let correctedFrame = FeedDetailReturnFrameDecision.correctedFrame(
            view.frame,
            containerBounds: containerBounds,
            navigationBarMinY: navigationController.navigationBar.frame.minY,
            isPhoneOrCompact: isPhoneOrCompactLayout
        )

        guard correctedFrame != view.frame else { return }

        NSLog(
            "FeedDetailViewController: correcting return frame from \(view.frame) to \(correctedFrame)"
        )

        view.frame = correctedFrame
        view.setNeedsUpdateConstraints()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        view.setNeedsDisplay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        correctReturnFrameIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        correctReturnFrameIfNeeded()
    }
    
    @objc override func loadingFeed() {
        // Make sure the view has loaded.
        _ = view

        if appDelegate.detailViewController.isPhoneOrCompact {
            changedLayout()

            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                self.reload()
            }
        } else {
            let wasGridView = wasGridView

            self.appDelegate.detailViewController.updateLayout(reload: false, fetchFeeds: false)

            if wasGridView != isGridView {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    self.appDelegate.detailViewController.updateLayout(reload: true, fetchFeeds: false)
                }
            }
        }

        if appDelegate.isTryFeedView && tryFeedBannerView == nil {
            showTryFeedSubscribeBanner()
        } else if !appDelegate.isTryFeedView && tryFeedBannerView != nil {
            hideTryFeedSubscribeBanner()
        }
    }
    
    @objc override func changedLayout() {
        // Make sure the view has loaded.
        _ = view

        updateContentVisibility()

        deferredReload()
    }

    private func updateContentVisibility() {
        let shouldShowStoryTitlesTable = shouldShowDailyBriefingStoryTitles || (!isDailyBriefingView && isLegacyTable && !isDashboard)

        storyTitlesTable.isHidden = !shouldShowStoryTitlesTable

        if let gridViewController {
            gridViewController.view.isHidden = isDailyBriefingView || isLegacyTable || isDashboard
        } else if !isDailyBriefingView && !isLegacyTable && !isDashboard {
            let viewController = makeGridViewController()
            add(viewController: viewController)
            gridViewController = viewController
        }

        if let dashboardViewController {
            dashboardViewController.view.isHidden = isDailyBriefingView || !isDashboard
        } else if isDashboard {
            let viewController = makeDashboardViewController()
            add(viewController: viewController)
            dashboardViewController = viewController
        }

        if let dailyBriefingViewController {
            dailyBriefingViewController.view.isHidden = !shouldShowDailyBriefingOverlay
        } else if shouldShowDailyBriefingOverlay {
            let viewController = makeDailyBriefingViewController()
            add(viewController: viewController)
            dailyBriefingViewController = viewController
        }

        // Keep pill bar above content views
        if let headerContainer = storyTitlesHeaderBar?.headerContainer {
            view.bringSubviewToFront(headerContainer)
        }
    }
    
    var reloadWorkItem: DispatchWorkItem?
    
    var pendingStories = [Story.ID : Story]()
    
    @objc var suppressMarkAsRead = false
    
    var scrollingDate = Date.distantPast
    
//    var findingStory: Story?
    
    func deferredReload(story: Story? = nil) {
        reloadWorkItem?.cancel()
        
        if let story {
            pendingStories[story.id] = story
        } else {
            pendingStories.removeAll()
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            
            if pendingStories.isEmpty {
                let secondsSinceScroll = -scrollingDate.timeIntervalSinceNow

                if secondsSinceScroll < 0.5 {
                    deferredReload(story: story)
                    return
                }
                
                configureDataSource()
            } else {
                for story in pendingStories.values {
                    configureDataSource(story: story)
                }
            }
            
            pendingStories.removeAll()
            reloadWorkItem = nil
        }
        
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: workItem)
    }
    
    @objc override func reloadImmediately() {
        configureDataSource()
    }
    
    @objc override func reload() {
//        if appDelegate.findingStoryDictionary != nil {
//            findingStory = Story(index: 0, dictionary: appDelegate.findingStoryDictionary)
//        } else if !appDelegate.inFindingStoryMode {
//            findingStory = nil
//        }
        
        deferredReload()
    }
    
    func reload(story: Story) {
        deferredReload(story: story)
    }
    
    @objc override func reload(_ indexPath: IndexPath, with rowAnimation: UITableView.RowAnimation = .none) {
        if !isLegacyTable {
            deferredReload()
        } else if reloadWorkItem == nil, storyTitlesTable.window != nil, swipingStoryHash == nil {
            // Only do this if a deferred reload isn't pending; otherwise no point in doing a partial reload, plus the table may be stale.
            storyTitlesTable.reloadRows(at: [indexPath], with: rowAnimation)
        }
    }
    
    @objc override func doneDashboardChooseSite(_ riverId: String?) {
        guard let riverId else {
            dashboardOperation = .none
            return
        }
        
        switch dashboardOperation {
            case .none:
                break
            case .change(let dashList):
                storyCache.change(dash: dashList, to: riverId)
            case .addFirst:
                storyCache.addFirst(riverId: riverId)
            case .addBefore(let dashList):
                storyCache.add(riverId: riverId, before: true, dash: dashList)
            case .addAfter(let dashList):
                storyCache.add(riverId: riverId, before: false, dash: dashList)
        }
        
        dashboardOperation = .none
    }

    @objc func fetchDailyBriefingPage(_ page: Int32, withCallback callback: (() -> Void)?) {
        dailyBriefingStore.fetch(page: Int(page), callback: callback)
    }

    @objc func openDailyBriefingSettingsFrom(_ sourceView: UIView) {
        let host = UIHostingController(rootView: DailyBriefingSettingsPopoverView(store: dailyBriefingStore))
        host.modalPresentationStyle = .popover
        host.preferredContentSize = CGSize(width: 520, height: 760)

        if let popover = host.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = .up
        }

        present(host, animated: true)
    }
}

extension FeedDetailViewController {
    func configureDataSource(story: Story? = nil) {
        if isDailyBriefingView {
            refreshDailyBriefingPresentation()

            if shouldShowDailyBriefingStoryTitles {
                reloadTable()
            }
            return
        }

        if isDashboard {
            storyCache.redrawDashboard()
            
            if dashboardIndex < 0 {
                return
            }
        }
        
        if let story {
            storyCache.reload(story: story)
        } else {
            storyCache.reload()
        }
        
//        if findingStory != nil {
//            storyCache.selected = findingStory
//            findingStory = nil
//        }
        
        if isLegacyTable {
            reloadTable()
        }
        
//        if pageFinished, dashboardAwaitingFinish, dashboardIndex >= 0 {
//            dashboardAwaitingFinish = false
//            appDelegate.feedsViewController.loadDashboard()
//        }
    }
    
#if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let location = storyLocation(for: indexPath)
        
        guard location < storiesCollection.storyLocationsCount else {
            return nil
        }
        
        let storyIndex = storiesCollection.index(fromLocation: location)
        let story = Story(index: storyIndex)
        
        appDelegate.activeStory = story.dictionary
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let read = UIAction(title: story.isRead ? "Mark as unread" : "Mark as read", image: Utilities.imageNamed("mark-read", sized: 14)) { action in
                self.appDelegate.storiesCollection.toggleStoryUnread(story.dictionary)
                self.reload()
            }
            
            let newer = UIAction(title: "Mark newer stories read", image: Utilities.imageNamed("mark-read", sized: 14)) { action in
                self.markFeedsRead(fromTimestamp: story.timestamp, andOlder: false)
                self.reload()
            }
            
            let older = UIAction(title: "Mark older stories read", image: Utilities.imageNamed("mark-read", sized: 14)) { action in
                self.markFeedsRead(fromTimestamp: story.timestamp, andOlder: true)
                self.reload()
            }
            
            let saved = UIAction(title: story.isSaved ? "Unsave this story" : "Save this story", image: Utilities.imageNamed("saved-stories", sized: 14)) { action in
                self.appDelegate.storiesCollection.toggleStorySaved(story.dictionary)
                self.reload()
            }
            
            let send = UIAction(title: "Send this story to…", image: Utilities.imageNamed("email", sized: 14)) { action in
                self.appDelegate.showSend(to: self, sender: self.view)
            }
            
            let train = UIAction(title: "Train this story", image: Utilities.imageNamed("train", sized:    14)) { action in
                self.appDelegate.openTrainStory(self.view)
            }
            
            let submenu = UIMenu(title: "", options: .displayInline, children: [saved, send, train])
            
            return UIMenu(title: "", children: [read, newer, older, submenu])
        }
    }
#endif
}

extension FeedDetailViewController: FeedDetailInteraction {
    var hasNoMoreStories: Bool {
        return pageFinished
    }
    
    var isPremiumRestriction: Bool {
        return !appDelegate.isPremium &&
        storiesCollection.isRiverView &&
        !storiesCollection.isDailyBriefing &&
        !storiesCollection.isReadView &&
        !storiesCollection.isWidgetView &&
        !storiesCollection.isSocialView &&
        !storiesCollection.isSavedView
    }
    
    func pullToRefresh() {
        instafetchFeed()
    }
    
    func tapped(dash: DashList) {
        if dash.isFolder {
            appDelegate.feedsViewController.selectFolder(dash.folderId)
        } else if let feedId = dash.feedId {
            appDelegate.feedsViewController.selectFeed(feedId, inFolder: dash.folderId)
        }
    }
    
    func visible(story: Story) {
        NSLog("🐓 Visible: \(story.debugTitle)")
        
        guard storiesCollection.activeFeedStories != nil, !isDashboard else {
            return
        }
        
        let cacheCount = storyCache.before.count + storyCache.after.count
        
        if cacheCount > 0, story.index >= cacheCount - 5 {
            let debug = Date()
            
            if storiesCollection.isRiverView, storiesCollection.activeFolder != nil {
                fetchRiverPage(storiesCollection.feedPage + 1, withCallback: nil)
            } else {
                fetchFeedDetail(storiesCollection.feedPage + 1, withCallback: nil)
            }
            
            NSLog("🐓 Fetching next page took \(-debug.timeIntervalSinceNow) seconds")
        }
        
        scrollingDate = Date()
    }
    
    func tapped(story: Story, in dash: DashList?) {
        if presentedViewController != nil {
            return
        }
        
        NSLog("🪿 Tapped \(story.debugTitle)")
        
        if isDashboard {
            tappedDashboard(story: story, in: dash)
            return
        }
        
        let indexPath = IndexPath(row: story.index, section: 0)
        
        suppressMarkAsRead = true
        
        didSelectItem(at: indexPath)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.suppressMarkAsRead = false
        }
    }
    
    func tappedDashboard(story: Story, in dash: DashList?) {
        guard let dash/*, let feedId = story.feed?.id*/ else {
            return
        }
        
        appDelegate.detailViewController.storyTitlesFromDashboardStory = true
        
        appDelegate.inFindingStoryMode = true
        appDelegate.findingStoryStartDate = Date()
        appDelegate.findingStoryDictionary = story.dictionary
        appDelegate.tryFeedStoryId = story.hash
        appDelegate.tryFeedFeedId = dash.feedId
        
        if dash.isFolder {
            appDelegate.feedsViewController.selectFolder(dash.folderId)
        } else if let feedId = dash.feedId {
            appDelegate.feedsViewController.selectFeed(feedId, inFolder: dash.folderId)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.appDelegate.detailViewController.storyTitlesFromDashboardStory = false
        }
    }
    
    func changeDashboard(dash: DashList) {
        self.dashboardOperation = .change(dash)
        
        self.appDelegate.showDashboardSites(dash.riverId)
    }
    
    func addFirstDashboard() {
        self.dashboardOperation = .addFirst
        
        self.appDelegate.showDashboardSites(nil)
    }
    
    func addDashboard(before: Bool, dash: DashList) {
        self.dashboardOperation = before ? .addBefore(dash) : .addAfter(dash)
        
        self.appDelegate.showDashboardSites(nil)
    }
    
    func reloadOneDash(with dash: DashList) {
        self.appDelegate.feedsViewController.reloadOneDash(with: dash.index)
    }
    
    func reading(story: Story) {
        NSLog("🪿 Reading \(story.debugTitle)")
    }
    
    func read(story: Story) {
        if suppressMarkAsRead {
            return
        }
        
        let dict = story.dictionary
        
        if isSwiftUI, appDelegate.feedDetailViewController.markStoryReadIfNeeded(dict, isScrolling: false) {
            NSLog("🪿 Marking as read \(story.debugTitle)")
            
            deferredReload(story: story)
        }
    }
    
    func unread(story: Story) {
        let dict = story.dictionary
        
        if isSwiftUI, !storiesCollection.isStoryUnread(dict) {
            NSLog("🪿 Marking as unread \(story.debugTitle)")
            
            storiesCollection.markStoryUnread(dict)
            storiesCollection.syncStory(asRead: dict)
            
            deferredReload(story: story)
        }
    }
    
    func hid(story: Story) {
        NSLog("🪿 Hiding \(story.debugTitle)")
        
        appDelegate.activeStory = nil
        reload()
    }
    
    func scrolled(story: Story, offset: CGFloat?) {
        let feedDetailHeight = view.frame.size.height
        let storyHeight = appDelegate.storyPagesViewController.currentPage.view.frame.size.height
        let skipHeader: CGFloat = 200
        
        // NSLog("🪿🎛️ Scrolled story \(story.debugTitle) to offset \(offset ?? 0), story height: \(storyHeight), feed detail height: \(feedDetailHeight)")
        
        let gap = appDelegate.storyPagesViewController.traverseBottomGap
        if offset == nil {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = storyHeight - feedDetailHeight + gap
        } else if let offset, offset - storyHeight + skipHeader < feedDetailHeight, offset > feedDetailHeight {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = offset - feedDetailHeight + gap
        } else {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = gap
        }
    }

    func openPremiumDialog() {
        appDelegate.showPremiumDialog()
    }
}

private let dailyBriefingBuiltInSectionKeys = [
    "top_stories",
    "infrequent",
    "long_read",
    "classifier_match",
    "follow_up",
    "widely_covered",
]

@MainActor
private final class DailyBriefingStore: ObservableObject {
    private struct ParseMetrics {
        let groups: [Group]
        let stories: [AnyDictionary]
        let summaryCount: Int
        let curatedCount: Int
        let prepareSummaryMs: Double
        let prepareCuratedMs: Double
        let totalMs: Double
    }

    private struct ApplyStoriesMetrics {
        let ensureFeedsMs: Double
        let ensureBriefingFeedMs: Double
        let setStoriesMs: Double
        let rebuildStoryLocationsMs: Double
        let refreshAndReloadMs: Double
        let totalMs: Double

        static let zero = ApplyStoriesMetrics(
            ensureFeedsMs: 0,
            ensureBriefingFeedMs: 0,
            setStoriesMs: 0,
            rebuildStoryLocationsMs: 0,
            refreshAndReloadMs: 0,
            totalMs: 0
        )
    }

    struct SectionDefinition: Identifiable, Hashable {
        let key: String
        let name: String
        let subtitle: String

        var id: String { key }
    }

    struct ModelOption: Identifiable, Hashable {
        let key: String
        let displayName: String
        let vendorDisplay: String

        var id: String { key }
    }

    struct Preferences: Equatable {
        var enabled = true
        var frequency = "daily"
        var preferredTime = "morning"
        var preferredDay = "sun"
        var storyCount = 10
        var storySources = "all"
        var readFilter = "unread"
        var summaryStyle = "bullets"
        var includeRead = false
        var builtInSections = Dictionary(uniqueKeysWithValues: dailyBriefingBuiltInSectionKeys.map { ($0, true) })
        var customSectionPrompts = [String]()
        var customSectionEnabled = [Bool]()
        var notificationTypes = Set<String>()
        var briefingFeedId: String?
        var briefingModel = ""
        var briefingModels = [ModelOption]()
        var folders = [String]()

        var selectedFolder: String? {
            get {
                guard storySources.hasPrefix("folder:") else { return nil }
                return String(storySources.dropFirst(7))
            }
            set {
                storySources = newValue.map { "folder:\($0)" } ?? "all"
            }
        }

        mutating func addKeywordSection() {
            guard customSectionPrompts.count < 5 else { return }
            customSectionPrompts.append("")
            customSectionEnabled.append(true)
        }

        mutating func removeKeywordSection(at index: Int) {
            guard customSectionPrompts.indices.contains(index),
                  customSectionEnabled.indices.contains(index) else {
                return
            }

            customSectionPrompts.remove(at: index)
            customSectionEnabled.remove(at: index)
        }

        func sectionsPayload() -> [String: Bool] {
            var sections = builtInSections

            for index in customSectionPrompts.indices {
                let key = "custom_\(index + 1)"
                let enabled = customSectionEnabled.indices.contains(index) ? customSectionEnabled[index] : true
                sections[key] = enabled
            }

            return sections
        }

        func sectionOrderPayload() -> [String] {
            dailyBriefingBuiltInSectionKeys + customSectionPrompts.indices.map { "custom_\($0 + 1)" }
        }
    }

    struct Group: Identifiable, Hashable {
        let id: String
        let title: String
        let storyHashes: [String]
        let summaryHash: String?
        let isPreview: Bool

        var curatedCount: Int {
            max(storyHashes.count - (summaryHash == nil ? 0 : 1), 0)
        }
    }

    static let builtInSections = [
        SectionDefinition(key: "top_stories", name: "Top stories", subtitle: "The most important stories from your feeds"),
        SectionDefinition(key: "infrequent", name: "From infrequent sites", subtitle: "Stories from feeds that rarely publish"),
        SectionDefinition(key: "long_read", name: "Long reads for later", subtitle: "Longer articles worth setting time aside for"),
        SectionDefinition(key: "classifier_match", name: "Based on your interests", subtitle: "Stories matching your trained topics and authors"),
        SectionDefinition(key: "follow_up", name: "Follow-ups", subtitle: "New posts from feeds you recently read"),
        SectionDefinition(key: "widely_covered", name: "Widely covered", subtitle: "Stories covered by 3+ feeds"),
    ]

    static let notificationOptions = [
        DailyBriefingOption(value: "email", title: "Email"),
        DailyBriefingOption(value: "web", title: "Web"),
        DailyBriefingOption(value: "ios", title: "iOS"),
        DailyBriefingOption(value: "android", title: "Android"),
    ]

    weak var controller: FeedDetailViewController?

    let appDelegate = NewsBlurAppDelegate.shared!

    @Published var groups = [Group]()
    @Published var preferences: Preferences?
    @Published var collapsedGroupIDs = Set<String>()
    @Published private(set) var hasLoadedPreferences = false
    @Published private(set) var hasLoadedPreferenceDetails = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSaving = false
    @Published var isGenerating = false
    @Published var progressMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoadingInitialData = false
    @Published private(set) var refreshID = UUID()

    private var hasNextPage = false
    private var currentPage = 1
    private var storyLocations = [String: Int]()
    private var allStories = [AnyDictionary]()
    private var pendingPreferenceCompletions = [() -> Void]()
    private var requestToken = UUID()
    private var isLoadingPreferences = false

    private static func timingNow() -> CFTimeInterval {
        CACurrentMediaTime()
    }

    private static func elapsedMs(since start: CFTimeInterval) -> Double {
        (timingNow() - start) * 1000
    }

    private func logTiming(_ message: String) {
        NSLog("DailyBriefing iOS timing: %@", message)
    }

    init(controller: FeedDetailViewController) {
        self.controller = controller
    }

    var presentationState: DailyBriefingPresentationState {
        DailyBriefingPresentationDecision.presentationState(
            hasLoadedPreferences: hasLoadedPreferences,
            preferencesEnabled: preferences?.enabled ?? false,
            isLoadingInitialData: isLoadingInitialData,
            hasStories: !groups.isEmpty
        )
    }

    var needsSetup: Bool {
        presentationState == .settings
    }

    var shouldShowOverlay: Bool {
        presentationState != .stories
    }

    func story(for hash: String) -> Story? {
        _ = refreshID

        guard let location = storyLocations[hash] else { return nil }

        return Story(index: location)
    }

    func isCollapsed(_ group: Group) -> Bool {
        collapsedGroupIDs.contains(group.id)
    }

    func toggleCollapse(_ group: Group) {
        if collapsedGroupIDs.contains(group.id) {
            collapsedGroupIDs.remove(group.id)
        } else {
            collapsedGroupIDs.insert(group.id)
        }
    }

    func loadPreferencesIfNeeded() {
        if !hasLoadedPreferenceDetails && !isLoadingPreferences {
            loadPreferences(completion: nil)
        }
    }

    func loadMoreIfNeeded(after group: Group) {
        guard groups.last?.id == group.id,
              hasNextPage,
              !isLoadingMore,
              !isGenerating else {
            return
        }

        fetch(page: currentPage + 1, callback: nil)
    }

    func fetch(page: Int, callback: (() -> Void)?) {
        guard let _ = controller else {
            callback?()
            return
        }

        if page > 1 && (!hasNextPage || isLoadingMore) {
            callback?()
            return
        }

        if !DailyBriefingPresentationDecision.shouldFetchStories(
            page: page,
            hasLoadedPreferences: hasLoadedPreferences,
            preferencesEnabled: preferences?.enabled ?? false
        ) {
            callback?()
            return
        }

        fetchStories(page: page, callback: callback)
    }

    private func fetchStories(page: Int, callback: (() -> Void)?) {
        guard let controller else {
            callback?()
            return
        }

        if page == 1 {
            isLoading = true
            isLoadingInitialData = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        controller.pageFetching = true
        controller.pageFinished = false

        let token = UUID()
        requestToken = token
        let requestStartedAt = Self.timingNow()
        guard let url = requestURL(path: "/briefing/stories?page=\(page)") else {
            finishFailedRequest(message: "Unable to load Daily Briefing.", callback: callback)
            return
        }

        appDelegate.get(url, parameters: nil as Any?, success: { [weak self] _, responseObject in
            guard let self else { return }
            guard self.requestToken == token else { return }
            guard self.controller?.storiesCollection.isDailyBriefing == true else { return }
            guard let data = responseObject as? [String: Any] else {
                self.finishFailedRequest(message: "Unable to load Daily Briefing.", callback: callback)
                return
            }

            let responseMs = Self.elapsedMs(since: requestStartedAt)
            self.apply(response: data, page: page)
            let totalMs = Self.elapsedMs(since: requestStartedAt)
            let briefingCount = (data["briefings"] as? [[String: Any]] ?? []).count
            self.logTiming(
                String(
                    format: "page=%ld response=%.1fms total=%.1fms briefings=%ld stories=%ld has_next=%@ state=%@",
                    page,
                    responseMs,
                    totalMs,
                    briefingCount,
                    self.allStories.count,
                    self.hasNextPage ? "yes" : "no",
                    String(describing: self.presentationState)
                )
            )

            self.isLoading = false
            self.isLoadingMore = false
            self.isLoadingInitialData = false
            controller.pageFetching = false
            controller.pageFinished = !self.hasNextPage
            controller.isShowingFetching = false
            controller.isOnline = true
            controller.hideFetchingBanner()
            callback?()
        }, failure: { [weak self] _, error in
            guard let self else { return }
            self.finishFailedRequest(message: Self.errorDescription(error, fallback: "Unable to load Daily Briefing."), callback: callback)
        })
    }

    func save(preferences draft: Preferences, generate: Bool, completion: (() -> Void)? = nil) {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil

        guard let url = requestURL(path: "/briefing/preferences") else {
            isSaving = false
            errorMessage = "Unable to save Daily Briefing settings."
            completion?()
            return
        }
        let parameters = makePreferenceParameters(from: draft, forceEnabled: generate ? true : nil)

        appDelegate.post(url, parameters: parameters, success: { [weak self] _, _ in
            guard let self else { return }

            self.preferences = draft
            self.hasLoadedPreferences = true
            self.hasLoadedPreferenceDetails = true

            self.saveNotifications(for: draft.briefingFeedId, notificationTypes: Array(draft.notificationTypes)) {
                if generate {
                    self.generateBriefing(from: draft, completion: completion)
                } else {
                    self.isSaving = false
                    self.controller?.refreshDailyBriefingPresentation()
                    self.controller?.reload()
                    completion?()
                }
            }
        }, failure: { [weak self] _, error in
            guard let self else { return }

            self.isSaving = false
            self.errorMessage = Self.errorDescription(error, fallback: "Unable to save Daily Briefing settings.")
            completion?()
        })
    }

    private func loadPreferences(completion: (() -> Void)?) {
        if let completion {
            pendingPreferenceCompletions.append(completion)
        }

        guard !isLoadingPreferences else { return }
        isLoadingPreferences = true

        guard let url = requestURL(path: "/briefing/preferences") else {
            isLoadingPreferences = false
            isLoading = false
            isLoadingInitialData = false
            errorMessage = "Unable to load Daily Briefing settings."
            runPendingPreferenceCompletions()
            return
        }

        appDelegate.get(url, parameters: nil as Any?, success: { [weak self] _, responseObject in
            guard let self else { return }
            self.isLoadingPreferences = false

            if let data = responseObject as? [String: Any] {
                self.preferences = self.parsePreferences(data)
                self.hasLoadedPreferences = true
                self.hasLoadedPreferenceDetails = true
                self.controller?.refreshDailyBriefingPresentation()
            }
            self.runPendingPreferenceCompletions()
        }, failure: { [weak self] _, error in
            guard let self else { return }
            self.isLoadingPreferences = false
            self.isLoading = false
            self.isLoadingInitialData = false
            self.controller?.pageFetching = false
            self.controller?.pageFinished = true
            self.controller?.isShowingFetching = false
            self.controller?.hideFetchingBanner()
            self.errorMessage = Self.errorDescription(error, fallback: "Unable to load Daily Briefing settings.")
            self.controller?.refreshDailyBriefingPresentation()
            self.runPendingPreferenceCompletions()
        })
    }

    private func runPendingPreferenceCompletions() {
        let completions = pendingPreferenceCompletions
        pendingPreferenceCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func generateBriefing(from draft: Preferences, completion: (() -> Void)?) {
        isGenerating = true
        progressMessage = "Generating your Daily Briefing..."

        guard let url = requestURL(path: "/briefing/generate") else {
            isSaving = false
            isGenerating = false
            progressMessage = nil
            errorMessage = "Unable to generate Daily Briefing."
            completion?()
            return
        }

        appDelegate.post(url, parameters: [:], success: { [weak self] _, responseObject in
            guard let self else { return }

            var updated = draft
            updated.enabled = true

            if let data = responseObject as? [String: Any],
               let feedId = Self.stringValue(data["briefing_feed_id"]) {
                updated.briefingFeedId = feedId
            }

            self.preferences = updated

            self.saveNotifications(for: updated.briefingFeedId, notificationTypes: Array(updated.notificationTypes)) {
                self.isSaving = false
                completion?()
                self.pollForGeneratedBriefing(remainingAttempts: 20)
            }
        }, failure: { [weak self] _, error in
            guard let self else { return }
            self.isSaving = false
            self.isGenerating = false
            self.progressMessage = nil
            self.errorMessage = Self.errorDescription(error, fallback: "Unable to generate Daily Briefing.")
            completion?()
        })
    }

    private func pollForGeneratedBriefing(remainingAttempts: Int) {
        guard remainingAttempts > 0 else {
            isGenerating = false
            progressMessage = nil
            errorMessage = "Daily Briefing generation timed out. Please try again."
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            guard let self else { return }

            self.fetch(page: 1) {
                if !self.groups.isEmpty {
                    self.isGenerating = false
                    self.progressMessage = nil
                    self.errorMessage = nil
                } else {
                    self.pollForGeneratedBriefing(remainingAttempts: remainingAttempts - 1)
                }
            }
        }
    }

    private func saveNotifications(for feedId: String?, notificationTypes: [String], completion: @escaping () -> Void) {
        guard let feedId, !feedId.isEmpty else {
            completion()
            return
        }

        guard let url = requestURL(path: "/notifications/feed/") else {
            completion()
            return
        }
        let parameters: [String: Any] = [
            "feed_id": feedId,
            "notification_types": notificationTypes,
            "notification_filter": "unread",
        ]

        appDelegate.post(url, parameters: parameters, success: { _, _ in
            completion()
        }, failure: { [weak self] _, error in
            self?.errorMessage = Self.errorDescription(error, fallback: "Unable to save notification settings.")
            completion()
        })
    }

    private func finishFailedRequest(message: String, callback: (() -> Void)?) {
        controller?.pageFetching = false
        controller?.pageFinished = true
        controller?.isShowingFetching = false
        isLoading = false
        isLoadingMore = false
        isLoadingInitialData = false
        progressMessage = nil
        errorMessage = message
        controller?.refreshDailyBriefingPresentation()
        callback?()
    }

    private func finishWithoutStories(callback: (() -> Void)?) {
        groups = []
        allStories = []
        appDelegate.storiesCollection.setStories([])
        rebuildStoryLocations()
        appDelegate.activeStory = nil

        controller?.pageFetching = false
        controller?.pageFinished = true
        controller?.isShowingFetching = false
        controller?.hideFetchingBanner()

        isLoading = false
        isLoadingMore = false
        isLoadingInitialData = false

        controller?.refreshDailyBriefingPresentation()
        controller?.reload()
        callback?()
    }

    private func apply(response: [String: Any], page: Int) {
        let applyStartedAt = Self.timingNow()
        let preferenceStartedAt = Self.timingNow()
        let hadPreferenceDetails = hasLoadedPreferenceDetails

        if let preferencesData = response["preferences"] as? [String: Any] {
            preferences = parsePreferences(preferencesData)
            hasLoadedPreferences = true
            hasLoadedPreferenceDetails = true
        } else if var preferences {
            if let enabled = response["enabled"] as? Bool {
                preferences.enabled = enabled
            }
            if let feedId = Self.stringValue(response["briefing_feed_id"]) {
                preferences.briefingFeedId = feedId
            }
            self.preferences = preferences
            if response["enabled"] != nil {
                hasLoadedPreferences = true
            }
            hasLoadedPreferenceDetails = hadPreferenceDetails
        } else if let enabled = response["enabled"] as? Bool {
            var preferences = Preferences()
            preferences.enabled = enabled
            preferences.briefingFeedId = Self.stringValue(response["briefing_feed_id"])
            self.preferences = preferences
            hasLoadedPreferences = true
            hasLoadedPreferenceDetails = false
        } else {
            hasLoadedPreferenceDetails = hadPreferenceDetails
        }
        let preferenceMs = Self.elapsedMs(since: preferenceStartedAt)

        let ensureBriefingFeedStartedAt = Self.timingNow()
        if let feedId = Self.stringValue(response["briefing_feed_id"]) {
            ensureBriefingFeedExists(feedId: feedId)
        }
        let ensureBriefingFeedMs = Self.elapsedMs(since: ensureBriefingFeedStartedAt)

        let briefings = response["briefings"] as? [[String: Any]] ?? []
        let isPreview = response["is_preview"] as? Bool ?? false
        let parsed = parseGroups(from: briefings, isPreview: isPreview)

        let mergeStartedAt = Self.timingNow()
        if page == 1 {
            groups = parsed.groups
            allStories = parsed.stories
        } else {
            groups.append(contentsOf: parsed.groups)
            allStories.append(contentsOf: parsed.stories)
        }
        let mergeMs = Self.elapsedMs(since: mergeStartedAt)

        hasNextPage = response["has_next_page"] as? Bool ?? false
        currentPage = response["page"] as? Int ?? page

        let applyStoriesMetrics = applyStories()
        logTiming(
            String(
                format: "apply page=%ld preferences=%.1fms ensure_response_feed=%.1fms parse=%.1fms prepare_summary=%.1fms prepare_curated=%.1fms merge=%.1fms ensure_story_feeds=%.1fms ensure_preferences_feed=%.1fms set_stories=%.1fms rebuild_locations=%.1fms refresh_reload=%.1fms apply_stories=%.1fms total=%.1fms groups=%ld summaries=%ld curated=%ld stories=%ld",
                page,
                preferenceMs,
                ensureBriefingFeedMs,
                parsed.totalMs,
                parsed.prepareSummaryMs,
                parsed.prepareCuratedMs,
                mergeMs,
                applyStoriesMetrics.ensureFeedsMs,
                applyStoriesMetrics.ensureBriefingFeedMs,
                applyStoriesMetrics.setStoriesMs,
                applyStoriesMetrics.rebuildStoryLocationsMs,
                applyStoriesMetrics.refreshAndReloadMs,
                applyStoriesMetrics.totalMs,
                Self.elapsedMs(since: applyStartedAt),
                parsed.groups.count,
                parsed.summaryCount,
                parsed.curatedCount,
                allStories.count
            )
        )
    }

    private func applyStories() -> ApplyStoriesMetrics {
        guard let controller else { return .zero }
        let applyStartedAt = Self.timingNow()

        let ensureFeedsStartedAt = Self.timingNow()
        for story in allStories {
            ensureFeedExists(for: story)
        }
        let ensureFeedsMs = Self.elapsedMs(since: ensureFeedsStartedAt)

        let ensureBriefingFeedStartedAt = Self.timingNow()
        if let preferences, let feedId = preferences.briefingFeedId {
            ensureBriefingFeedExists(feedId: feedId)
        }
        let ensureBriefingFeedMs = Self.elapsedMs(since: ensureBriefingFeedStartedAt)

        let setStoriesStartedAt = Self.timingNow()
        appDelegate.storiesCollection.setStories(allStories)
        let setStoriesMs = Self.elapsedMs(since: setStoriesStartedAt)

        let rebuildStartedAt = Self.timingNow()
        rebuildStoryLocations()
        let rebuildStoryLocationsMs = Self.elapsedMs(since: rebuildStartedAt)

        if let activeHash = Self.stringValue(appDelegate.activeStory?["story_hash"]),
           let location = storyLocations[activeHash],
           location < appDelegate.storiesCollection.activeFeedStories.count,
           let story = appDelegate.storiesCollection.activeFeedStories[location] as? AnyDictionary {
            appDelegate.activeStory = story
        } else if groups.isEmpty {
            appDelegate.activeStory = nil
        }

        let refreshStartedAt = Self.timingNow()
        controller.refreshDailyBriefingPresentation()
        controller.reload()
        let refreshAndReloadMs = Self.elapsedMs(since: refreshStartedAt)

        return ApplyStoriesMetrics(
            ensureFeedsMs: ensureFeedsMs,
            ensureBriefingFeedMs: ensureBriefingFeedMs,
            setStoriesMs: setStoriesMs,
            rebuildStoryLocationsMs: rebuildStoryLocationsMs,
            refreshAndReloadMs: refreshAndReloadMs,
            totalMs: Self.elapsedMs(since: applyStartedAt)
        )
    }

    private func rebuildStoryLocations() {
        storyLocations.removeAll()

        guard let activeStories = appDelegate.storiesCollection.activeFeedStories else {
            refreshID = UUID()
            return
        }

        for (index, storyAny) in activeStories.enumerated() {
            if let story = storyAny as? AnyDictionary,
               let hash = Self.stringValue(story["story_hash"]) {
                storyLocations[hash] = index
            }
        }

        refreshID = UUID()
    }

    private func parseGroups(from briefings: [[String: Any]], isPreview: Bool) -> ParseMetrics {
        let parseStartedAt = Self.timingNow()
        var groups = [Group]()
        var stories = [AnyDictionary]()
        let briefingFeedId = preferences?.briefingFeedId
        var summaryCount = 0
        var curatedCount = 0
        var prepareSummaryMs = 0.0
        var prepareCuratedMs = 0.0

        for briefing in briefings {
            let briefingId = Self.stringValue(briefing["briefing_id"]) ?? UUID().uuidString
            var storyHashes = [String]()
            var summaryHash: String?

            if let summaryStory = briefing["summary_story"] as? AnyDictionary {
                let prepareStartedAt = Self.timingNow()
                let prepared = prepareStory(summaryStory, fallbackFeedId: briefingFeedId, fallbackFeedTitle: "Daily Briefing", isDailyBriefingSummary: true)
                prepareSummaryMs += Self.elapsedMs(since: prepareStartedAt)
                stories.append(prepared)
                if let hash = Self.stringValue(prepared["story_hash"]) {
                    storyHashes.append(hash)
                    summaryHash = hash
                }
                summaryCount += 1
            }

            let curatedStories = briefing["curated_stories"] as? [AnyDictionary] ?? []
            for story in curatedStories {
                let prepareStartedAt = Self.timingNow()
                let prepared = prepareStory(story, fallbackFeedId: briefingFeedId, fallbackFeedTitle: story["feed_title"] as? String, isDailyBriefingSummary: false)
                prepareCuratedMs += Self.elapsedMs(since: prepareStartedAt)
                stories.append(prepared)
                if let hash = Self.stringValue(prepared["story_hash"]) {
                    storyHashes.append(hash)
                }
                curatedCount += 1
            }

            groups.append(Group(
                id: briefingId,
                title: Self.formattedDateTitle(from: briefing["briefing_date"] as? String),
                storyHashes: storyHashes,
                summaryHash: summaryHash,
                isPreview: isPreview
            ))
        }

        return ParseMetrics(
            groups: groups,
            stories: stories,
            summaryCount: summaryCount,
            curatedCount: curatedCount,
            prepareSummaryMs: prepareSummaryMs,
            prepareCuratedMs: prepareCuratedMs,
            totalMs: Self.elapsedMs(since: parseStartedAt)
        )
    }

    private func prepareStory(_ story: AnyDictionary, fallbackFeedId: String?, fallbackFeedTitle: String?, isDailyBriefingSummary: Bool) -> AnyDictionary {
        var prepared = story
        prepared["sticky"] = true
        prepared["is_daily_briefing_summary"] = isDailyBriefingSummary

        if prepared["read_status"] == nil {
            prepared["read_status"] = 0
        }

        if prepared["story_feed_id"] == nil {
            if let fallbackFeedId {
                prepared["story_feed_id"] = fallbackFeedId
            } else if let feedId = story["feed_id"] {
                prepared["story_feed_id"] = feedId
            }
        }

        if prepared["feed_title"] == nil, let fallbackFeedTitle {
            prepared["feed_title"] = fallbackFeedTitle
        }

        if prepared["story_content"] == nil {
            prepared["story_content"] = ""
        }

        let previewText = Self.previewText(from: Self.stringValue(prepared["story_content"]) ?? "")
        prepared["daily_briefing_preview_text"] = previewText
        prepared["daily_briefing_preview_length"] = previewText.count

        return prepared
    }

    private func ensureBriefingFeedExists(feedId: String) {
        let feed: AnyDictionary = [
            "id": feedId,
            "feed_title": "Daily Briefing",
            "favicon_color": "95968E",
            "favicon_fade": "C5C6BE",
        ]

        if appDelegate.dictActiveFeeds == nil {
            appDelegate.dictActiveFeeds = NSMutableDictionary()
        }
        if appDelegate.dictFeeds == nil {
            appDelegate.dictFeeds = NSMutableDictionary()
        }

        appDelegate.dictActiveFeeds[feedId] = feed
        appDelegate.dictFeeds[feedId] = feed
    }

    private func ensureFeedExists(for story: AnyDictionary) {
        guard let feedId = Self.stringValue(story["story_feed_id"]) else { return }
        guard appDelegate.dictFeeds[feedId] == nil && appDelegate.dictActiveFeeds[feedId] == nil else { return }

        let feed: AnyDictionary = [
            "id": feedId,
            "feed_title": Self.stringValue(story["feed_title"]) ?? "Daily Briefing",
            "favicon_color": Self.stringValue(story["favicon_color"]) ?? "95968E",
            "favicon_fade": "C5C6BE",
        ]

        appDelegate.dictActiveFeeds[feedId] = feed
        appDelegate.dictFeeds[feedId] = feed
    }

    private func parsePreferences(_ data: [String: Any]) -> Preferences {
        var preferences = Preferences()

        preferences.enabled = Self.boolValue(data["enabled"], default: true)
        preferences.frequency = Self.stringValue(data["frequency"]) ?? preferences.frequency
        preferences.preferredTime = Self.stringValue(data["preferred_time"]) ?? preferences.preferredTime
        preferences.preferredDay = Self.stringValue(data["preferred_day"]) ?? preferences.preferredDay
        preferences.storyCount = Self.intValue(data["story_count"]) ?? preferences.storyCount
        preferences.storySources = Self.stringValue(data["story_sources"]) ?? preferences.storySources
        preferences.readFilter = Self.stringValue(data["read_filter"]) ?? preferences.readFilter
        preferences.summaryStyle = Self.stringValue(data["summary_style"]) ?? preferences.summaryStyle
        preferences.includeRead = Self.boolValue(data["include_read"], default: preferences.includeRead)
        preferences.briefingFeedId = Self.stringValue(data["briefing_feed_id"])
        preferences.briefingModel = Self.stringValue(data["briefing_model"]) ?? preferences.briefingModel
        preferences.folders = data["folders"] as? [String] ?? []
        preferences.notificationTypes = Set(data["notification_types"] as? [String] ?? [])
        preferences.briefingModels = (data["briefing_models"] as? [[String: Any]] ?? []).compactMap {
            guard let key = Self.stringValue($0["key"]),
                  let displayName = Self.stringValue($0["display_name"]) else {
                return nil
            }

            return ModelOption(
                key: key,
                displayName: displayName,
                vendorDisplay: Self.stringValue($0["vendor_display"]) ?? ""
            )
        }

        let sections = data["sections"] as? [String: Any] ?? [:]
        for definition in Self.builtInSections {
            preferences.builtInSections[definition.key] = Self.boolValue(sections[definition.key], default: true)
        }

        preferences.customSectionPrompts = data["custom_section_prompts"] as? [String] ?? []
        preferences.customSectionEnabled = preferences.customSectionPrompts.indices.map { index in
            Self.boolValue(sections["custom_\(index + 1)"], default: true)
        }

        if preferences.briefingModel.isEmpty {
            preferences.briefingModel = preferences.briefingModels.first?.key ?? ""
        }

        return preferences
    }

    private func makePreferenceParameters(from preferences: Preferences, forceEnabled: Bool?) -> [String: Any] {
        let enabled = forceEnabled ?? preferences.enabled

        return [
            "enabled": enabled ? "true" : "false",
            "frequency": preferences.frequency,
            "preferred_time": preferences.preferredTime,
            "preferred_day": preferences.preferredDay,
            "story_count": "\(preferences.storyCount)",
            "story_sources": preferences.storySources,
            "read_filter": preferences.readFilter,
            "summary_style": preferences.summaryStyle,
            "include_read": preferences.includeRead ? "true" : "false",
            "sections": Self.jsonString(from: preferences.sectionsPayload()),
            "custom_section_prompts": Self.jsonString(from: preferences.customSectionPrompts),
            "section_order": Self.jsonString(from: preferences.sectionOrderPayload()),
            "briefing_model": preferences.briefingModel,
        ]
    }

    private static func jsonString(from value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }

    private static func previewText(from html: String) -> String {
        guard !html.isEmpty else { return "" }

        // Daily Briefing only needs a short teaser. Bound the input so opening
        // the folder doesn't parse full article HTML for every story.
        let clippedHTML = html.count > 12_000 ? String(html.prefix(12_000)) : html
        let plainText = clippedHTML
            .convertHTML()
            .decodingXMLEntities()
            .decodingHTMLEntities() ?? clippedHTML

        let squashed = plainText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(squashed.prefix(500))
    }

    private func requestURL(path: String) -> String? {
        guard let baseURL = appDelegate.url else {
            return nil
        }

        return "\(baseURL)\(path)"
    }

    private static func errorDescription(_ error: Error?, fallback: String) -> String {
        error?.localizedDescription ?? fallback
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else {
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        } else if let number = value as? NSNumber {
            return number.intValue
        } else if let string = value as? String {
            return Int(string)
        } else {
            return nil
        }
    }

    private static func boolValue(_ value: Any?, default defaultValue: Bool) -> Bool {
        if let bool = value as? Bool {
            return bool
        } else if let number = value as? NSNumber {
            return number.boolValue
        } else if let string = value as? String {
            return ["true", "1", "yes"].contains(string.lowercased())
        } else {
            return defaultValue
        }
    }

    private static func formattedDateTitle(from isoString: String?) -> String {
        guard let isoString else { return "Today" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        let date = formatter.date(from: isoString) ?? fallbackFormatter.date(from: isoString) ?? Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today, \(Self.absoluteDateString(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(Self.absoluteDateString(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    private static func absoluteDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct DailyBriefingOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}

private struct DailyBriefingRootView: View {
    @ObservedObject var store: DailyBriefingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = store.errorMessage {
                    DailyBriefingStatusCard(title: "Unable to load Daily Briefing", message: errorMessage, isError: true)
                }

                switch store.presentationState {
                case .loading:
                    EmptyView()
                case .settings:
                    DailyBriefingSetupView(store: store)
                case .empty:
                    if let progressMessage = store.progressMessage {
                        DailyBriefingStatusCard(title: "Working…", message: progressMessage, isError: false)
                    }
                    DailyBriefingEmptyView(store: store)
                case .stories:
                    EmptyView()
                }
            }
            .padding(16)
        }
        .background(Color.themed([0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x161618]))
    }
}

private struct DailyBriefingEmptyView: View {
    @ObservedObject var store: DailyBriefingStore

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Image("briefing")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(Color.themed([0x95968E, 0x8B7B6B, 0xAAAAAA, 0xAAAAAA]))

            Text("No briefings yet")
                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 22))
                .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0]))

            Text("Set up Daily Briefing to generate a summary of the stories that matter most to you.")
                .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 15))
                .foregroundColor(Color.themed([0x666666, 0x8B7B6B, 0xA0A0A0, 0xA0A0A0]))
                .multilineTextAlignment(.center)

            if let preferences = store.preferences {
                Button("Generate Daily Briefing") {
                    store.save(preferences: preferences, generate: true)
                }
                .buttonStyle(DailyBriefingPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(DailyBriefingCardBackground())
    }
}

private struct DailyBriefingSetupView: View {
    @ObservedObject var store: DailyBriefingStore

    @State private var draft = DailyBriefingStore.Preferences()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Image("briefing")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .foregroundColor(Color.themed([0x95968E, 0x8B7B6B, 0xAAAAAA, 0xAAAAAA]))

                Text("Daily Briefing")
                    .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 26))
                    .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))

                Text("Get a summary of your top stories, delivered on your schedule.")
                    .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 16))
                    .foregroundColor(Color.themed([0x666666, 0x8B7B6B, 0xA0A0A0, 0xA0A0A0]))
            }

            DailyBriefingSettingsForm(store: store, draft: $draft, showsSaveButton: false)
        }
        .onAppear {
            if let preferences = store.preferences {
                draft = preferences
            }
            if !store.hasLoadedPreferenceDetails {
                store.loadPreferencesIfNeeded()
            }
        }
        .onChange(of: store.preferences) { preferences in
            if let preferences {
                draft = preferences
            }
        }
    }
}

private struct DailyBriefingSettingsPopoverView: View {
    @ObservedObject var store: DailyBriefingStore

    @State private var draft = DailyBriefingStore.Preferences()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily Briefing Settings")
                    .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 24))
                    .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))
                    .padding(.bottom, 4)

                if let errorMessage = store.errorMessage {
                    DailyBriefingStatusCard(title: "Save failed", message: errorMessage, isError: true)
                }

                if store.preferences == nil || !store.hasLoadedPreferenceDetails {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading settings…")
                            .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 14))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(DailyBriefingCardBackground())
                } else {
                    DailyBriefingSettingsForm(store: store, draft: $draft, showsSaveButton: true)
                }
            }
            .padding(16)
        }
        .background(Color.themed([0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x161618]))
        .onAppear {
            if let preferences = store.preferences {
                draft = preferences
            }
            if !store.hasLoadedPreferenceDetails {
                store.loadPreferencesIfNeeded()
            }
        }
        .onChange(of: store.preferences) { preferences in
            if let preferences {
                draft = preferences
            }
        }
    }
}

private struct DailyBriefingSettingsForm: View {
    @ObservedObject var store: DailyBriefingStore
    @Binding var draft: DailyBriefingStore.Preferences

    let showsSaveButton: Bool

    private let frequencyOptions = [
        DailyBriefingOption(value: "thrice_daily", title: "3x daily"),
        DailyBriefingOption(value: "twice_daily", title: "2x daily"),
        DailyBriefingOption(value: "daily", title: "Daily"),
        DailyBriefingOption(value: "weekly", title: "Weekly"),
    ]

    private let timeOptions = [
        DailyBriefingOption(value: "morning", title: "Morning"),
        DailyBriefingOption(value: "afternoon", title: "Afternoon"),
        DailyBriefingOption(value: "evening", title: "Evening"),
    ]

    private let dayOptions = [
        DailyBriefingOption(value: "sun", title: "Sunday"),
        DailyBriefingOption(value: "mon", title: "Monday"),
        DailyBriefingOption(value: "tue", title: "Tuesday"),
        DailyBriefingOption(value: "wed", title: "Wednesday"),
        DailyBriefingOption(value: "thu", title: "Thursday"),
        DailyBriefingOption(value: "fri", title: "Friday"),
        DailyBriefingOption(value: "sat", title: "Saturday"),
    ]

    private let storyCountOptions = [
        DailyBriefingOption(value: 5, title: "5"),
        DailyBriefingOption(value: 10, title: "10"),
        DailyBriefingOption(value: 15, title: "15"),
        DailyBriefingOption(value: 20, title: "20"),
        DailyBriefingOption(value: 25, title: "25"),
    ]

    private let summaryStyleOptions = [
        DailyBriefingOption(value: "bullets", title: "Bullets"),
        DailyBriefingOption(value: "editorial", title: "Editorial"),
        DailyBriefingOption(value: "headlines", title: "Headlines"),
    ]

    private let readFilterOptions = [
        DailyBriefingOption(value: "unread", title: "Unread"),
        DailyBriefingOption(value: "focus", title: "Focus"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DailyBriefingSettingsCard(title: "Auto-generate", subtitle: "Automatically create briefings on your schedule") {
                Toggle("Enabled", isOn: $draft.enabled)
                    .toggleStyle(.switch)
            }

            DailyBriefingSettingsCard(title: "Schedule", subtitle: "Choose how often and when your briefing is generated") {
                DailyBriefingMenuRow(title: "Frequency", selection: $draft.frequency, options: frequencyOptions)
                DailyBriefingMenuRow(title: "Preferred time", selection: $draft.preferredTime, options: timeOptions)
                if draft.frequency == "weekly" {
                    DailyBriefingMenuRow(title: "Preferred day", selection: $draft.preferredDay, options: dayOptions)
                }
            }

            DailyBriefingSettingsCard(title: "Length & Style", subtitle: "Control how much is included and how it is written") {
                DailyBriefingMenuRow(title: "Story count", selection: $draft.storyCount, options: storyCountOptions)
                DailyBriefingMenuRow(title: "Writing style", selection: $draft.summaryStyle, options: summaryStyleOptions)
            }

            DailyBriefingSettingsCard(title: "Sources", subtitle: "Choose which stories are eligible for Daily Briefing") {
                DailyBriefingMenuRow(
                    title: "Feed source",
                    selection: Binding(
                        get: { draft.selectedFolder ?? "__all__" },
                        set: { draft.selectedFolder = $0 == "__all__" ? nil : $0 }
                    ),
                    options: [DailyBriefingOption(value: "__all__", title: "All Site Stories")] + draft.folders.map {
                        DailyBriefingOption(value: $0, title: $0)
                    }
                )
                DailyBriefingMenuRow(title: "Filter", selection: $draft.readFilter, options: readFilterOptions)
                Toggle("Include already-read stories", isOn: $draft.includeRead)
            }

            DailyBriefingSettingsCard(title: "Sections", subtitle: "Only sections with matching stories will be included") {
                ForEach(DailyBriefingStore.builtInSections) { definition in
                    Toggle(isOn: Binding(
                        get: { draft.builtInSections[definition.key] ?? true },
                        set: { draft.builtInSections[definition.key] = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(definition.name)
                                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 15))
                            Text(definition.subtitle)
                                .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 13))
                                .foregroundColor(Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]))
                        }
                    }
                }
            }

            DailyBriefingSettingsCard(title: "Keyword Sections", subtitle: "Add custom keyword filters that become their own briefing sections") {
                ForEach(Array(draft.customSectionPrompts.indices), id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Keyword section \(index + 1)", isOn: Binding(
                                get: { draft.customSectionEnabled.indices.contains(index) ? draft.customSectionEnabled[index] : true },
                                set: { newValue in
                                    if draft.customSectionEnabled.indices.contains(index) {
                                        draft.customSectionEnabled[index] = newValue
                                    }
                                }
                            ))
                            Spacer()
                            Button(role: .destructive) {
                                draft.removeKeywordSection(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }

                        TextField("Keywords", text: Binding(
                            get: { draft.customSectionPrompts[index] },
                            set: { draft.customSectionPrompts[index] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }

                if draft.customSectionPrompts.count < 5 {
                    Button {
                        draft.addKeywordSection()
                    } label: {
                        Label("Add keyword section", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            DailyBriefingSettingsCard(title: "Notifications", subtitle: "Choose where Daily Briefing alerts should go") {
                ForEach(DailyBriefingStore.notificationOptions) { option in
                    Toggle(option.title, isOn: Binding(
                        get: { draft.notificationTypes.contains(option.value) },
                        set: { newValue in
                            if newValue {
                                draft.notificationTypes.insert(option.value)
                            } else {
                                draft.notificationTypes.remove(option.value)
                            }
                        }
                    ))
                }
            }

            if draft.briefingModels.count > 1 {
                DailyBriefingSettingsCard(title: "Model", subtitle: "Pick which model writes your Daily Briefing") {
                    DailyBriefingMenuRow(
                        title: "Model",
                        selection: $draft.briefingModel,
                        options: draft.briefingModels.map { DailyBriefingOption(value: $0.key, title: $0.displayName) }
                    )
                }
            }

            HStack(spacing: 12) {
                if showsSaveButton {
                    Button("Save") {
                        store.save(preferences: draft, generate: false)
                    }
                    .buttonStyle(DailyBriefingSecondaryButtonStyle())
                }

                Button(showsSaveButton ? "Generate Now" : "Generate Daily Briefing") {
                    store.save(preferences: draft, generate: true)
                }
                .buttonStyle(DailyBriefingPrimaryButtonStyle())
                .disabled(store.isSaving || store.isGenerating)
            }

            if store.isSaving || store.isGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(store.progressMessage ?? "Saving Daily Briefing settings…")
                        .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 14))
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct DailyBriefingGroupView: View {
    let group: DailyBriefingStore.Group

    @ObservedObject var store: DailyBriefingStore

    let feedDetailInteraction: FeedDetailInteraction

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                store.toggleCollapse(group)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: store.isCollapsed(group) ? "chevron.right.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(group.title)
                        .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 18))
                    Spacer()
                    Text("\(group.curatedCount) \(group.curatedCount == 1 ? "story" : "stories")")
                        .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 13))
                        .foregroundColor(Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]))
                }
                .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))
                .padding(16)
            }
            .buttonStyle(.plain)

            if !store.isCollapsed(group) {
                VStack(spacing: 10) {
                    ForEach(group.storyHashes, id: \.self) { hash in
                        DailyBriefingStoryRowView(
                            storyHash: hash,
                            isSummary: hash == group.summaryHash,
                            store: store,
                            feedDetailInteraction: feedDetailInteraction
                        )
                    }

                    if group.isPreview {
                        Button {
                            feedDetailInteraction.openPremiumDialog()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Premium Archive")
                                    .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 13))
                                    .foregroundColor(Color.themed([0x2030C0, 0x2030C0, 0x8FB3FF, 0x8FB3FF]))
                                Text("Get Daily Briefing with all of your top stories.")
                                    .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 14))
                                    .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0]))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.themed([0xF8FAFF, 0xF2E7D8, 0x36384A, 0x26283A]))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(DailyBriefingCardBackground())
        .onAppear {
            store.loadMoreIfNeeded(after: group)
        }
    }
}

private struct DailyBriefingStoryRowView: View {
    let storyHash: String
    let isSummary: Bool

    @ObservedObject var store: DailyBriefingStore

    let feedDetailInteraction: FeedDetailInteraction

    var body: some View {
        let _ = store.refreshID

        if let story = store.story(for: storyHash) {
            Button {
                feedDetailInteraction.tapped(story: story, in: nil)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    if isSummary {
                        Text("Daily Briefing")
                            .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 12))
                            .foregroundColor(Color.themed([0x2030C0, 0x7D5A1A, 0x8FB3FF, 0x8FB3FF]))
                    } else if let feedName = story.feed?.name, !feedName.isEmpty {
                        Text(feedName)
                            .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 12))
                            .foregroundColor(Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]))
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(story.isRead ? Color.clear : Color.themed([0x4A89DC, 0x7D5A1A, 0x78A8F0, 0x78A8F0]))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.themed([0xC7CCD6, 0xD4C8B8, 0x555555, 0x555555]), lineWidth: 1)
                            )
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(story.title)
                                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: isSummary ? 18 : 16))
                                .foregroundColor(Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))
                                .multilineTextAlignment(.leading)

                            if isSummary, !story.shortContent.isEmpty {
                                Text(story.shortContent)
                                    .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 14))
                                    .foregroundColor(Color.themed([0x4C4D4A, 0x5C4A3D, 0xC8C8C8, 0xB8B8B8]))
                                    .lineLimit(5)
                            }

                            Text(story.dateAndAuthor)
                                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 12))
                                .foregroundColor(Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(story.isSelected
                              ? Color.themed([0xFFFDEF, 0xEEE0CE, 0x303A40, 0x1E1F22])
                              : Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x2C2C2E]))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.themed([0xD1D1D6, 0xD4C8B8, 0x4C4C4E, 0x3A3A3A]), lineWidth: 1)
                )
                .opacity(story.isRead ? 0.78 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DailyBriefingStatusCard: View {
    let title: String
    let message: String
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 16))
            Text(message)
                .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 14))
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(isError
                         ? Color.themed([0x8C1D18, 0x8C1D18, 0xFFB4AB, 0xFFB4AB])
                         : Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0]))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isError
                      ? Color.themed([0xFDECEA, 0xF8E3D8, 0x482828, 0x3A2222])
                      : Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x2C2C2E]))
        )
    }
}

private struct DailyBriefingSettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 18))
                Text(subtitle)
                    .font(dailyBriefingFont(named: "WhitneySSm-Book", size: 13))
                    .foregroundColor(Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]))
            }

            content
        }
        .foregroundColor(Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))
        .padding(16)
        .background(DailyBriefingCardBackground())
    }
}

private struct DailyBriefingMenuRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [DailyBriefingOption<Value>]

    var body: some View {
        HStack {
            Text(title)
                .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 15))
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct DailyBriefingCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x262628]))
    }
}

private struct DailyBriefingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 15))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.themed([0x4A89DC, 0xA46B2A, 0x4A78B0, 0x375E8A]))
            )
            .opacity(configuration.isPressed ? 0.82 : 1.0)
    }
}

private struct DailyBriefingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(dailyBriefingFont(named: "WhitneySSm-Medium", size: 15))
            .foregroundColor(Color.themed([0x333333, 0x3C3226, 0xF2F2F7, 0xF2F2F7]))
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.themed([0xE7E9E3, 0xEADFD0, 0x4A4A4C, 0x343436]))
            )
            .opacity(configuration.isPressed ? 0.82 : 1.0)
    }
}

private func dailyBriefingFont(named: String, size: CGFloat) -> Font {
    .custom(named, size: size)
}
