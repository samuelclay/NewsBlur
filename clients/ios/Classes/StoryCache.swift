//
//  StoryCache.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-04.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

// The Feed, Story, and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

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
        return appDelegate.detailViewController.layout == .magazine
    }
    
    /// Using a grid-style grid view layout for the story titles and story pages.
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid
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
    
    @Published var dashboard = [DashList]()
    
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
    
    static var feeds = [String : Feed]()
    
    var currentFeed: Feed?
    
    func reload() {
        let debug = Date()
        let storyCount = Int(appDelegate.storiesCollection.storyLocationsCount)
        var beforeSelection = [Int]()
        var selectedIndex = -999
        var afterSelection = [Int]()
        
        if storyCount > 0 {
            selectedIndex = appDelegate.storiesCollection.locationOfActiveStory()
            
            if selectedIndex < 0 {
                beforeSelection = Array(0..<storyCount)
            } else {
                beforeSelection = Array(0..<selectedIndex)
                
                if selectedIndex + 1 < storyCount {
                    afterSelection = Array(selectedIndex + 1..<storyCount)
                }
            }
        }
        
        Self.feeds.removeAll()
        
        if let dictionary = appDelegate.storiesCollection.activeFeed {
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
    
    func reloadDashboard(for index: Int) {
        if index == 0 {
            dashboard.removeAll()
        }
        
        reload()
        
        guard let currentFeed, index >= 0, index <= dashboard.count else {
            return
        }
        
        let dash = DashList(index: index, feed: currentFeed, stories: before)
        
        dashboard.append(dash)
    }
}
