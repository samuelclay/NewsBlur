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
    lazy var gridViewController = makeGridViewController()
    
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
    
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid
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
    
    private func makeGridViewController() -> UIHostingController<FeedDetailGridView> {
        let gridView = FeedDetailGridView(feedDetailInteraction: self, cache: storyCache)
        let gridViewController = UIHostingController(rootView: gridView)
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return gridViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(gridViewController)
        view.addSubview(gridViewController.view)
        gridViewController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            gridViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            gridViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        changedLayout()
    }
    
    @objc override func loadingFeed() {
        // Make sure the view has loaded.
        _ = view
        
        if appDelegate.detailViewController.isPhone {
            changedLayout()
        } else {
            DispatchQueue.main.async {
                self.appDelegate.detailViewController.updateLayout(reload: true, fetchFeeds: false)
            }
        }
    }
    
    @objc override func changedLayout() {
        // Make sure the view has loaded.
        _ = view
        
        storyTitlesTable.isHidden = !isLegacyTable
        gridViewController.view.isHidden = isLegacyTable
        
        deferredReload()
    }
    
    var reloadWorkItem: DispatchWorkItem?
    
    func deferredReload(story: Story? = nil) {
        reloadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            
            configureDataSource(story: story)
            reloadWorkItem = nil
        }
        
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: workItem)
    }
    
    @objc override func reload() {
        deferredReload()
    }
    
    func reload(story: Story) {
        deferredReload(story: story)
    }
    
    @objc override func reload(_ indexPath: IndexPath, with rowAnimation: UITableView.RowAnimation = .none) {
        if !isLegacyTable {
            deferredReload()
        } else if reloadWorkItem == nil {
            // Only do this if a deferred reload isn't pending; otherwise no point in doing a partial reload, plus the table may be stale.
            storyTitlesTable.reloadRows(at: [indexPath], with: rowAnimation)
        }
    }
}

extension FeedDetailViewController {
    func configureDataSource(story: Story? = nil) {
        if let story {
            storyCache.reload(story: story)
        } else {
            storyCache.reload()
        }
        
        if isLegacyTable {
            reloadTable()
        }
    }
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
    
    func visible(story: Story) {
        print("\(story.title) appeared")
        
        if story.index >= storyCache.before.count + storyCache.after.count - 5 {
            if storiesCollection.isRiverView, storiesCollection.activeFolder != nil {
                fetchRiverPage(storiesCollection.feedPage + 1, withCallback: nil)
            } else {
                fetchFeedDetail(storiesCollection.feedPage + 1, withCallback: nil)
            }
        }
    }
    
    func tapped(story: Story) {
        if presentedViewController != nil {
            return
        }
        
        print("tapped \(story.title)")
        
        let indexPath = IndexPath(row: story.index, section: 0)
        
        didSelectItem(at: indexPath)
    }
    
    func reading(story: Story) {
        print("reading \(story.title)")
    }
    
    func read(story: Story) {
        let dict = story.dictionary
        
        if storiesCollection.isStoryUnread(dict) {
            print("marking as read '\(story.title)'")
            
            storiesCollection.markStoryRead(dict)
            storiesCollection.syncStory(asRead: dict)
            
            story.load()
            
            deferredReload(story: story)
        }
    }
    
    func unread(story: Story) {
        let dict = story.dictionary
        
        if !storiesCollection.isStoryUnread(dict) {
            print("marking as unread '\(story.title)'")
            
            storiesCollection.markStoryUnread(dict)
            storiesCollection.syncStory(asRead: dict)
            
            story.load()
            
            deferredReload(story: story)
        }
    }
    
    func hid(story: Story) {
        print("hiding \(story.title)")
        
        appDelegate.activeStory = nil
        reload()
    }
}
