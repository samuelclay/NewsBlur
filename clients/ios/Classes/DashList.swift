//
//  DashList.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-10-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

/// A list in the Dashboard.
@MainActor class DashList: Identifiable {
    var index: Int
    
    enum Side: String {
        case left
        case right
    }
    
    var side: Side
    var order: Int
    
    var feedId: String?
    var folder: String
    
    var feed: Feed?
    var stories = [Story]()
    
    var isLoaded: Bool {
        return feed != nil
    }
    
    init(index: Int, side: Side, order: Int, feedId: String?, folder: String) {
        self.index = index
        self.side = side
        self.order = order
        self.feedId = feedId
        self.folder = folder
    }
}

extension DashList: @preconcurrency CustomStringConvertible {
    var description: String {
        return "DashList index: \(index), side: \(side), order: \(order), folder: \(folder), feed: \(feedId ?? "none"); \(feed != nil ? "\(feed?.name ?? "?"), stories: \(stories.count)" : "not loaded")"
    }
}
