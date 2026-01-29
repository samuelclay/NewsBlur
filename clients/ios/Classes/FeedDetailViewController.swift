//
//  FeedDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import SwiftUI

/// List of stories for a feed.
class FeedDetailViewController: FeedDetailObjCViewController {
    private var gridViewController: UIHostingController<FeedDetailGridView>?
    
    private var dashboardViewController: UIHostingController<FeedDetailDashboardView>?
    
    lazy var storyCache = StoryCache()
    
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
    
    private func add(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changedLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if view.frame.origin.y == 0, let navigationController, navigationController.navigationBar.frame.origin.y < 0 {
            NSLog("FeedDetailViewController: viewWillAppear in the wrong place: frame: \(view.frame), nav frame: \(navigationController.navigationBar.frame); this is a bug that started with iOS 18; working around it")
            
            view.frame.origin.y = -navigationController.navigationBar.frame.origin.y
            
            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()
            view.setNeedsDisplay()
        }
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
    }
    
    @objc override func changedLayout() {
        // Make sure the view has loaded.
        _ = view
        
        storyTitlesTable.isHidden = !isLegacyTable || isDashboard
        
        if let gridViewController {
            gridViewController.view.isHidden = isLegacyTable || isDashboard
        } else if !isLegacyTable && !isDashboard {
            let viewController = makeGridViewController()
            add(viewController: viewController)
            gridViewController = viewController
        }
        
        if let dashboardViewController {
            dashboardViewController.view.isHidden = !isDashboard
        } else if isDashboard {
            let viewController = makeDashboardViewController()
            add(viewController: viewController)
            dashboardViewController = viewController
        }
        
        NSLog("🪿🎛️ changedLayout for \(isLegacyTable ? "legacy table" : "SwiftUI grid layout")")
        
        deferredReload()
    }
    
    var reloadWorkItem: DispatchWorkItem?
    
    var pendingStories = [Story.ID : Story]()
    
    @objc var suppressMarkAsRead = false
    
    var scrollingDate = Date.distantPast
    
//    var findingStory: Story?
    
    func deferredReload(story: Story? = nil) {
        if let story {
            NSLog("🪿🎛️ queuing deferred reload for \(story)")
        } else {
            NSLog("🪿🎛️ queuing deferred reload")
        }
        
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
                NSLog("🪿🎛️ starting deferred reload")
                
                let secondsSinceScroll = -scrollingDate.timeIntervalSinceNow
                
                if secondsSinceScroll < 0.5 {
                    NSLog("🪿🎛️ too soon to reload; \(secondsSinceScroll) seconds since scroll")
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
}

extension FeedDetailViewController {
    func configureDataSource(story: Story? = nil) {
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
        
        NSLog("🪿🎛️ Scrolled story \(story.debugTitle) to offset \(offset ?? 0), story height: \(storyHeight), feed detail height: \(feedDetailHeight)")
        
        if offset == nil {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = storyHeight - feedDetailHeight
        } else if let offset, offset - storyHeight + skipHeader < feedDetailHeight, offset > feedDetailHeight {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = offset - feedDetailHeight
        } else {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = 0
        }
    }

    func openPremiumDialog() {
        appDelegate.showPremiumDialog()
    }
}
