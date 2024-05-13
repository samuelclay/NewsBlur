//
//  Story.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import Foundation

// The Feed, Story, and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

/// A story, wrapping the dictionary representation.
class Story: Identifiable {
    let id = UUID()
    let index: Int
    
    var dictionary = AnyDictionary()
    
    var feed: Feed?
    
    var title = ""
    var content = ""
    var dateString = ""
    var timestamp = 0
    var isRead = false
    var isReadAvailable = true
    var isSaved = false
    var isShared = false
    var score = 0
    var hash = ""
    var author = ""
    
    var dateAndAuthor: String {
        return author.isEmpty ? dateString : "\(dateString) · \(author)"
    }
    
    var titles: [Feed.Training] {
        guard let classifiers = feed?.classifiers(for: "titles") else {
            return []
        }
        
        let lowercasedTitle = title.lowercased()
        let keys = classifiers.keys.compactMap { $0 as? String }
        let words = keys.filter { lowercasedTitle.contains($0.lowercased()) }
        let sorted = words.sorted()
        
        return sorted.map { Feed.Training(name: $0, count: 0, score: Feed.Score(rawValue: classifiers[$0] as? Int ?? 0) ?? .none) }
    }
    
    var authors: [Feed.Training] {
        guard let classifiers = feed?.classifiers(for: "authors") else {
            return []
        }
        
        return [Feed.Training(name: author, count: 0, score: Feed.Score(rawValue: classifiers[author] as? Int ?? 0) ?? .none)]
    }
    
    var tags: [Feed.Training] {
        guard let tags = dictionary["story_tags"] as? [String], let classifiers = feed?.classifiers(for: "tags") else {
            return []
        }
        
        return tags.map { Feed.Training(name: $0, count: 0, score: Feed.Score(rawValue: classifiers[$0] as? Int ?? 0) ?? .none) }
    }
    
    var isSelected: Bool {
        return index == NewsBlurAppDelegate.shared!.storiesCollection.locationOfActiveStory()
    }
    
    var debugTitle: String {
        if title.count > 75 {
            return "#\(index) '\(title.prefix(75))...'"
        } else {
            return "#\(index) '\(title)'"
        }
    }
    
    init(index: Int) {
        self.index = index
        
        load()
    }
    
    private func string(for key: String) -> String {
        return dictionary[key] as? String ?? ""
    }
    
    private func int(for key: String) -> Int {
        if let value = dictionary[key] as? Int {
            return value
        } else {
            return Int(string(for: key)) ?? 0
        }
    }
    
    private func load() {
        guard let appDelegate = NewsBlurAppDelegate.shared, let storiesCollection = appDelegate.storiesCollection,
              index < storiesCollection.activeFeedStoryLocations.count,
              let row = storiesCollection.activeFeedStoryLocations[index] as? Int,
              let story = storiesCollection.activeFeedStories[row] as? [String : Any] else {
            return
        }
        
        dictionary = story
        
        if let dictID = dictionary["story_feed_id"], let id = appDelegate.feedIdWithoutSearchQuery("\(dictID)") {
            if let cachedFeed = StoryCache.feeds[id] {
                feed = cachedFeed
            } else {
                feed = Feed(id: id)
                StoryCache.feeds[id] = feed
            }
        }
        
        title = (string(for: "story_title") as NSString).decodingHTMLEntities()
        content = String(string(for: "story_content").convertHTML().decodingXMLEntities().decodingHTMLEntities().replacingOccurrences(of: "\n", with: " ").prefix(500))
        author = string(for: "story_authors").replacingOccurrences(of: "\"", with: "")
        timestamp = int(for:"story_timestamp")
        dateString = Utilities.formatShortDate(fromTimestamp: timestamp) ?? ""
        isSaved = dictionary["starred"] as? Bool ?? false
        isShared = dictionary["shared"] as? Bool ?? false
        hash = string(for: "story_hash")
        
        if let intelligence = dictionary["intelligence"] as? [String : Any] {
            score = Int(NewsBlurAppDelegate.computeStoryScore(intelligence))
        }
        
        isRead = !storiesCollection .isStoryUnread(dictionary)
        isReadAvailable = storiesCollection.activeFolder != "saved_stories"
    }
}

extension Story: Equatable {
    static func == (lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Story: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Story #\(index) \"\(title)\" in \(feed?.name ?? "<none>")"
    }
}
