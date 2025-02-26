//
//  DashList.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-10-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

/// A list in the Dashboard.
@MainActor class DashList: @preconcurrency Identifiable {
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
        if isFolder {
            folder = Folder(id: folderId)
        } else if let feedId {
            feeds = [Feed(id: feedId)]
        }
    }
}

extension DashList: @preconcurrency CustomStringConvertible {
    var description: String {
        let base = "DashList index: \(index), side: \(side), order: \(order)"
        
        if let stories {
            if isFolder {
                return "\(base), folder: `\(folder?.name ?? "none")` (\(folderId)) contains \(feeds.count) feeds with \(stories.count) stories"
            } else {
                return "\(base), feed: `\(feed?.name ?? "none")` (\(feedId ?? "none")) in folder: `\(folder?.name ?? "none")` (\(folderId)) contains \(stories.count) stories"
            }
        } else {
            if isFolder {
                return "\(base), folder ID: \(folderId); not loaded"
            } else {
                return "\(base), feed ID: \(feedId ?? "none") in folder ID: \(folderId); not loaded"
            }
        }
    }
}
