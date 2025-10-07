//
//  Feed.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-04.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

// The Feed, Story, and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

/// A dictionary with the most broad key and value types, common in ObjC code.
typealias AnyDictionary = [AnyHashable : Any]

/// A feed, wrapping the dictionary representation.
class Feed: Identifiable {
    let id: String
    var name = "<deleted>"
    var subscribers = 0
    
    var dictionary = AnyDictionary()
    
    var isRiverOrSocial = false
    
    var colorBarLeft: UIColor?
    var colorBarRight: UIColor?
    
    lazy var image: UIImage? = {
        guard let appDelegate = NewsBlurAppDelegate.shared else {
            return nil
        }
        
        if let image = appDelegate.getFavicon(id) {
            return Utilities.roundCorneredImage(image, radius: 4, convertTo: CGSizeMake(16, 16))
        } else {
            return nil
        }
    }()
    
    var classifiers: AnyDictionary? {
        guard let appDelegate = NewsBlurAppDelegate.shared else {
            return nil
        }
        
        return appDelegate.storiesCollection.activeClassifiers[id] as? AnyDictionary
    }
    
    func classifiers(for kind: String) -> AnyDictionary? {
        return classifiers?[kind] as? AnyDictionary
    }
    
    enum Score: Int {
        case none = 0
        case like = 1
        case dislike = -1
        
        var imageName: String {
            switch self {
                case .none:
                    return "hand.thumbsup"
                case .like:
                    return "hand.thumbsup.fill"
                case .dislike:
                    return "hand.thumbsdown.fill"
            }
        }
    }
    
    struct Training: Identifiable {
        let name: String
        let count: Int
        let score: Score
        
        var id: String {
            return name
        }
    }
    
    lazy var titles: [Training] = {
        guard let appDelegate = NewsBlurAppDelegate.shared,
              let classifierTitles = self.classifiers(for: "titles") else {
            return []
        }
        
        let userTitles = classifierTitles.map { Training(name: $0.key as! String, count: 0, score: Score(rawValue: $0.value as? Int ?? 0) ?? .none) }
        
        return userTitles.sorted()
    }()
    
    lazy var authors: [Training] = {
        guard let appDelegate = NewsBlurAppDelegate.shared,
              let classifierAuthors = self.classifiers(for: "authors"),
              let activeAuthors = appDelegate.storiesCollection.activePopularAuthors as? [[AnyHashable]] else {
            return []
        }
        
        var userAuthors = [Training]()
        
        for (someName, someScore) in classifierAuthors {
            if let name = someName as? String, let score = someScore as? Int, !activeAuthors.contains(where: { $0[0] == someName }) {
                userAuthors.append(Training(name: name, count: 0, score: Score(rawValue: score) ?? .none))
            }
        }
        
        let otherAuthors: [Training] = activeAuthors.map { Training(name: $0[0] as! String, count: $0[1] as! Int, score: Score(rawValue: classifierAuthors[$0[0] as! String] as? Int ?? 0) ?? .none) }
        
        return userAuthors.sorted() + otherAuthors
    }()
    
    lazy var tags: [Training] = {
        guard let appDelegate = NewsBlurAppDelegate.shared,
              let classifierTags = self.classifiers(for: "tags"),
              let activeTags = appDelegate.storiesCollection.activePopularTags as? [[AnyHashable]] else {
            return []
        }
        
        var userTags = [Training]()
        
        for (someName, someScore) in classifierTags {
            if let name = someName as? String, let score = someScore as? Int, !activeTags.contains(where: { $0[0] == someName }) {
                userTags.append(Training(name: name, count: 0, score: Score(rawValue: score) ?? .none))
            }
        }
        
        let otherTags: [Training] = activeTags.map { Training(name: $0[0] as! String, count: $0[1] as! Int, score: Score(rawValue: classifierTags[$0[0] as! String] as? Int ?? 0) ?? .none) }
        
        return userTags.sorted() + otherTags
    }()
    
    init(id: String) {
        self.id = id
        
        guard let appDelegate = NewsBlurAppDelegate.shared else {
            return
        }
        
        var feed: [String : Any]? = appDelegate.dictActiveFeeds[id] as? [String : Any]
        
        if feed == nil, appDelegate.dictFeeds != nil {
            feed = appDelegate.dictFeeds[id] as? [String : Any]
        }
        
        guard let feed else {
            return
        }
        
        dictionary = feed
        
        load()
    }
    
    init(dictionary: AnyDictionary) {
        id = "\(dictionary["id"] ?? "<invalid>")"
        
        self.dictionary = dictionary
        
        load()
    }
    
    private func load() {
        guard let appDelegate = NewsBlurAppDelegate.shared, let storiesCollection = appDelegate.storiesCollection else {
            return
        }
        
        name = dictionary["feed_title"] as? String ?? "<invalid>"
        subscribers = dictionary["num_subscribers"] as? Int ?? 0
        
        colorBarLeft = color(for: "favicon_fade", from: dictionary, default: "707070")
        colorBarRight = color(for: "favicon_color", from: dictionary, default: "505050")
        
        isRiverOrSocial = storiesCollection.isRiverOrSocial
    }
    
    func color(for key: String, from feed: AnyDictionary, default defaultHex: String) -> UIColor {
        let hex = feed[key] as? String ?? defaultHex
        let scanner = Scanner(string: hex)
        var color: Int64 = 0
        scanner.scanHexInt64(&color)
        let value = Int(color)
        
        return ThemeManager.shared.fixedColor(fromRGB: value) ?? UIColor.gray
    }
}

extension Feed: Equatable {
    static func == (lhs: Feed, rhs: Feed) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Feed: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Feed \"\(name)\" (\(id))"
    }
}

extension Feed.Training: Hashable {
    static func == (lhs: Feed.Training, rhs: Feed.Training) -> Bool {
        return lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Feed.Training: Comparable {
    static func < (lhs: Feed.Training, rhs: Feed.Training) -> Bool {
        return lhs.name < rhs.name
    }
}
