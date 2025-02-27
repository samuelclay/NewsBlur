//
//  StoryCache.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-04.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

// The Folder, Feed, Story, and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

/// A cache of stories for the feed detail grid-based view.
@MainActor class StoryCache: ObservableObject {
    let appDelegate = NewsBlurAppDelegate.shared!
    
    let settings = StorySettings()
    
    var isDarkTheme: Bool {
        return ThemeManager.shared.isDarkTheme
    }
    
    /// Using a list-style grid view layout for the story titles and story pages.
    var isList: Bool {
        return appDelegate.detailViewController.layout == .list || isDashboard
    }
    
    /// Using a magazine-style grid view layout for the story titles and story pages.
    var isMagazine: Bool {
        return appDelegate.detailViewController.layout == .magazine && !isDashboard
    }
    
    /// Using a grid-style grid view layout for the story titles and story pages.
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid && !isDashboard
    }
    
    /// Using the list, magazine, or grid layout based on the grid view.
    var isGridView: Bool {
        return appDelegate.detailViewController.storyTitlesInGridView
    }
    
    /// Using the dashboard layout based on the grid view.
    var isDashboard: Bool {
        return appDelegate.detailViewController.storyTitlesInDashboard
    }
    
    var isPhone: Bool {
        return appDelegate.detailViewController.isPhone
    }
    
    var canPullToRefresh: Bool {
        return appDelegate.feedDetailViewController.canPullToRefresh
    }
    
    @Published var before = [Story]()
    @Published var selected: Story?
    @Published var after = [Story]()
    
    static private(set) var cachedDashboard = [DashList]()
    
    @Published var dashboardLeft = [DashList]()
    @Published var dashboardRight = [DashList]()
    
    var all: [Story] {
        if let selected {
            return before + [selected] + after
        } else {
            return before + after
        }
    }
    
    func story(with index: Int) -> Story? {
        return all.first(where: { $0.index == index } )
    }
    
    static var folder: Folder?
    
    static var feeds = [String : Feed]()
    
    var currentFeed: Feed?
    
    func reload() {
        guard let storiesCollection = appDelegate.storiesCollection else {
            return
        }
        
        let debug = Date()
        let storyCount = Int(storiesCollection.storyLocationsCount)
        var beforeSelection = [Int]()
        var selectedIndex = -999
        var afterSelection = [Int]()
        
        if storyCount > 0 {
            selectedIndex = storiesCollection.locationOfActiveStory()
            
            if selectedIndex < 0 {
                beforeSelection = Array(0..<storyCount)
            } else {
                beforeSelection = Array(0..<selectedIndex)
                
                if selectedIndex + 1 < storyCount {
                    afterSelection = Array(selectedIndex + 1..<storyCount)
                }
            }
        }
        
        if let folderId = storiesCollection.activeFolder {
            Self.folder = Folder(id: folderId)
        } else {
            Self.folder = nil
        }
        
        Self.feeds.removeAll()
        
        if let dictionary = storiesCollection.activeFeed {
            let feed = Feed(dictionary: dictionary)
            Self.feeds[feed.id] = feed
            currentFeed = feed
        } else {
            currentFeed = nil
        }
        
        before = beforeSelection.map { Story(index: $0) }
        selected = selectedIndex >= 0 ? Story(index: selectedIndex) : nil
        after = afterSelection.map { Story(index: $0) }
        
        print("🪿 Reload: \(before.count) before, \(selected == nil ? "none" : selected!.debugTitle) selected, \(after.count) after, took \(-debug.timeIntervalSinceNow) seconds")
        
        
        //
        //        #warning("hack")
        //
        //        print("🪿 ... count: \(storyCount), index: \(selectedIndex)")
        //        print("🪿 ... before: \(before)")
        //        print("🪿 ... selection: \(selected == nil ? "none" : selected!.debugTitle)")
        //        print("🪿 ... after: \(after)")
        
        
        
    }
    
    func reload(story: Story) {
        if story == selected {
            selected = Story(index: story.index)
        } else if let index = before.firstIndex(of: story) {
            before[index] = Story(index: story.index)
        } else if let index = after.firstIndex(of: story) {
            after[index] = Story(index: story.index)
        }
    }
    
    func prepareDashboard() {
        let oldDashes = Self.cachedDashboard
        
        var localDashboard = [DashList]()
        
        dashboardLeft.removeAll()
        dashboardRight.removeAll()
        
        guard let dashboardArray = appDelegate.dashboardArray as? [[String : Any]] else {
            return
        }
        
        for (index, dashInfo) in dashboardArray.enumerated() {
            guard let dashId = dashInfo["river_id"] as? String,
                  let order = dashInfo["river_order"] as? Int,
                  let sideString = dashInfo["river_side"] as? String, let side = DashList.Side(rawValue: sideString) else {
                continue
            }
            
            let feedId = dashId.hasPrefix("feed:") ? dashId.deletingPrefix("feed:") : nil
            
            guard let folderId = dashId == "river:" ? "everything" : dashId.hasPrefix("river:") ? dashId.deletingPrefix("river:") : appDelegate.parentFolders(forFeed: feedId).first as? String else {
                continue
            }
            
            let oldDash = index < oldDashes.count ? oldDashes[index] : nil
            let dash = DashList(index: index, side: side, order: order, feedId: feedId, folderId: folderId, oldDash: oldDash)
            
            localDashboard.append(dash)
            
            if side == .left {
                dashboardLeft.append(dash)
            } else {
                dashboardRight.append(dash)
            }
        }
        
        if localDashboard.count > dashboardArray.count {
            localDashboard.removeLast(localDashboard.count - dashboardArray.count)
        }
        
        dashboardLeft.sort { $0.order < $1.order }
        dashboardRight.sort { $0.order < $1.order }
        
        Self.cachedDashboard = localDashboard
    }
    
    func reloadDashboard(for index: Int) {
        guard index >= 0, index < Self.cachedDashboard.count else {
            return
        }
        
        let dash = Self.cachedDashboard[index]
        
        dash.id = UUID()
        dash.folder = Self.folder
        dash.feeds = Array(Self.feeds.values)
        
//        if let feed = currentFeed, !dash.feeds.contains(feed) {
//            dash.feeds.append(feed)
//        }
        
        dash.stories = Array(before.prefix(dash.numberOfStories))
        
        print("Reloaded dashboard for \(index); folder: \(dash.folder?.name ?? "?"); feeds: \(dash.feeds); stories: \(dash.stories ?? [])")
    }
    
    func redrawDashboard() {
        for dash in Self.cachedDashboard {
            dash.id = UUID()
        }
    }
}
