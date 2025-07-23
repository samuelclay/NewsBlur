//
//  DashList.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-10-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

/// A list in the Dashboard.
@MainActor class DashList: ObservableObject, @preconcurrency Identifiable {
    var id = UUID()
    var index: Int
    
    enum Side: String {
        case left
        case right
    }
    
    var side: Side
    var order: Int
    
    var riverId: String {
        didSet {
            feedId = nil
            feedIdWithoutSearch = nil
            folderId = "everything"
            searchQuery = nil
            
            guard let appDelegate = NewsBlurAppDelegate.shared else {
                return
            }
            
            var localRiverId = riverId
            
            if localRiverId.hasPrefix("search:") {
                localRiverId = localRiverId.deletingPrefix("search:")
                searchQuery = localRiverId.components(separatedBy: ":").last
                
                if let searchQuery {
                    localRiverId = localRiverId.deletingSuffix(":\(searchQuery)")
                }
            }
            
            if localRiverId.hasPrefix("feed:") {
                feedId = localRiverId.deletingPrefix("feed:")
            } else if localRiverId.hasPrefix("starred:") {
                feedId = localRiverId.replacingOccurrences(of: "starred:", with: "saved:")
            } else if appDelegate.isSocialFeed(localRiverId) || appDelegate.isSavedFeed(localRiverId) {
                feedId = localRiverId
            } else {
                feedId = nil
            }
            
            feedIdWithoutSearch = feedId
            
            if localRiverId == "river:" {
                folderId = "everything"
            } else if localRiverId == "river:global" {
                folderId = "river_global"
            } else if localRiverId == "river:blurblogs" {
                folderId = "river_blurblogs"
            } else if localRiverId.hasPrefix("river:") {
                folderId = localRiverId.deletingPrefix("river:")
            } else if localRiverId.hasPrefix("starred:") {
                folderId = "saved_stories"
            } else if let parentFolder = appDelegate.parentFolders(forFeed: feedId).first as? String {
                folderId = parentFolder
            } else {
                folderId = "everything"
            }
            
            if !appDelegate.dictFoldersArray.contains(folderId) {
                folderId = appDelegate.feedsViewController.fullFolderPath(for: folderId) ?? "everything"
            }
            
            if let searchQuery {
                if let hasFeedId = feedId {
                    feedId = "\(hasFeedId)?\(searchQuery)"
                } else {
                    folderId = "\(folderId)?\(searchQuery)"
                }
            }
        }
    }
    
    func set(riverId: String) {
        self.riverId = riverId
    }
    
    private(set) var feedId: String?
    private(set) var feedIdWithoutSearch: String?
    private(set) var folderId = "everything"
    private(set) var searchQuery: String?
    
    var key: String {
        if let feedId {
            return feedId
        } else {
            return "folder:\(folderId)"
        }
    }
    
    var folder: Folder?
    var feeds = [Feed]()
    var stories: [Story]?
    
    var isFetching = true
    
    var isFolder: Bool {
        return feedId == nil
    }
    
    var feed: Feed? {
        return feeds.first
    }
    
    var baseName: String {
        if isFolder {
            return folder?.name ?? "Loading..."
        } else {
            return feed?.name ?? "Loading..."
        }
    }
    
    var name: String {
        if let searchQuery {
            return "\"\(searchQuery)\" in \(baseName)"
        } else if let feedId, riverId.hasPrefix("starred:") {
            return "Saved Stories — \(feedId.deletingPrefix("saved:"))"
        } else if baseName == "global" {
            return "Global Shared Stories"
        } else {
            return baseName
        }
    }
    
    var image: UIImage? {
        if riverId.hasPrefix("starred:") {
            return UIImage(named: "tag")
        } else if riverId == "river:global" {
            return UIImage(named: "global-shares")
        } else if isFolder {
            return folder?.image ?? UIImage(named: "folder-open")
        } else {
            return feed?.image
        }
    }
    
//    var riverId: String {
//        var result: String
//        
//        if let feedId {
//            result = "feed:\(feedId)"
//        } else if folderId == "everything" {
//            result = "river:"
//        } else if folderId.contains(":") {
//            result = folderId
//        } else {
//            result = "river:\(folderId)"
//        }
//        
//        if let searchQuery {
//            result = "search:\(result):\(searchQuery)"
//        }
//        
//        return result
//    }
    
    var asDictionary: [String: Any] {
        return ["river_id" : riverId,
                "river_side" : side.rawValue,
                "river_order" : order]
    }
    
    init(index: Int, side: Side, order: Int, riverId: String, oldDash: DashList?) {
        self.index = index
        self.side = side
        self.order = order
        self.riverId = ""
        
        // This strange behavior is to make the riverId.didSet handler trigger.
        set(riverId: riverId)
        
        if let oldDash, index == oldDash.index, side == oldDash.side, order == oldDash.order, riverId == oldDash.riverId {
            folder = oldDash.folder
            feeds = oldDash.feeds
            stories = oldDash.stories
        } else {
            load()
        }
    }
    
    func load() {
        if let feedId {
            feeds = [Feed(id: feedId)]
        } else {
            folder = Folder(id: folderId)
        }
    }
    
    func change(riverId: String) {
        self.riverId = riverId
        
        id = UUID()
        folder = nil
        feeds.removeAll()
        stories = nil
        
        load()
    }
    
    private let defaults = UserDefaults.standard
    
    var numberOfStories: Int {
        get {
            defaults.object(forKey: "dashboard:\(key):count") as? Int ?? 5
        }
        set {
            defaults.set(newValue, forKey: "dashboard:\(key):count")
        }
    }
    
    var activeOrder: String {
        get {
            let order = defaults.object(forKey: "dashboard:\(key):order") as? String ?? "newest"
            
            NSLog("DashList activeOrder dashboard:\(key):order: \(order)")  // log
            
            return order
        }
        set {
            defaults.set(newValue, forKey: "dashboard:\(key):order")
        }
    }
    
    var activeReadFilter: String {
        get {
            defaults.object(forKey: "dashboard:\(key):read_filter") as? String ?? "unread"
        }
        set {
            defaults.set(newValue, forKey: "dashboard:\(key):read_filter")
        }
    }
}

extension DashList: @preconcurrency CustomStringConvertible {
    var description: String {
        let base = "DashList index: \(index), side: \(side), order: \(order), riverId: \(riverId)"
        
        if let stories {
            if let feedId {
                return "\(base), feed: `\(feed?.name ?? "none")` (\(feedId)) in folder: `\(folder?.name ?? "none")` (\(folderId)) contains \(stories.count) stories"
            } else {
                return "\(base), folder: `\(folder?.name ?? "none")` (\(folderId)) contains \(feeds.count) feeds with \(stories.count) stories"
            }
        } else {
            if let feedId {
                return "\(base), feed ID: \(feedId) in folder ID: \(folderId); not loaded"
            } else {
                return "\(base), folder ID: \(folderId); not loaded"
            }
        }
    }
}
