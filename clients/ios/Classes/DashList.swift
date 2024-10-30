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
    var feed: Feed
    var stories = [Story]()
    
    init(index: Int, feed: Feed, stories: [Story] = [Story]()) {
        self.index = index
        self.feed = feed
        self.stories = stories
    }
}
