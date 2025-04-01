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
    
    var feedId: String?
    var folderId: String
    
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
    
    var name: String {
        if isFolder {
            return folder?.name ?? "Loading..."
        } else {
            return feed?.name ?? "Loading..."
        }
    }
    
    var image: UIImage? {
        if isFolder {
            return folder?.image ?? UIImage(named: "folder-open")
        } else {
            return feed?.image
        }
    }
    
    var riverId: String {
        if let feedId {
            return "feed:\(feedId)"
        } else if folderId == "everything" {
            return "river:"
        } else if folderId.contains(":") {
            return folderId
        } else {
            return "river:\(folderId)"
        }
    }
    
    var asDictionary: [String: Any] {
        return ["river_id" : riverId,
                "river_side" : side.rawValue,
                "river_order" : order]
    }
    
    init(index: Int, side: Side, order: Int, feedId: String?, folderId: String, oldDash: DashList?) {
        self.index = index
        self.side = side
        self.order = order
        self.feedId = feedId
        self.folderId = folderId
        
        if let oldDash, index == oldDash.index, side == oldDash.side, order == oldDash.order, feedId == oldDash.feedId, folderId == oldDash.folderId {
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
    
    func change(feedId: String?, folderId: String) {
        self.feedId = feedId
        self.folderId = folderId
        
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
            
            print("🏃🏼‍♂️ DashList activeOrder dashboard:\(key):order: \(order)")  // log
            
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
        let base = "DashList index: \(index), side: \(side), order: \(order)"
        
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
