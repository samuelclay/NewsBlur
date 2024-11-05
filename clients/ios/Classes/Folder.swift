//
//  Folder.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-11-05.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

// The Folder, Feed, Story, and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

/// A folder.
@MainActor class Folder: Identifiable {
    let id: String
    var name = "<deleted>"
    var image: UIImage?
    var feeds = [Feed]()
    
    init(id: String) {
        self.id = id
        
        guard let appDelegate = NewsBlurAppDelegate.shared else {
            return
        }
        
        name = appDelegate.folderTitle(id)
        image = appDelegate.folderIcon(id)
    }
}

extension Folder: Equatable {
    nonisolated static func == (lhs: Folder, rhs: Folder) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Folder: @preconcurrency CustomDebugStringConvertible {
    var debugDescription: String {
        return "Folder \"\(name)\" (\(id))"
    }
}
