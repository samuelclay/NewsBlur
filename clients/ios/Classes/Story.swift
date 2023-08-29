//
//  Story.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import Foundation

// The Story and StoryCache classes could be quite useful going forward; Rather than calling getStory() to get the dictionary, could have a variation that returns a Story instance. Could fetch from the cache if available, or make and cache one from the dictionary. Would need to remove it from the cache when changing anything about a story. Could perhaps make the cache part of StoriesCollection.

/// A story, wrapping the dictionary representation.
class Story: Identifiable {
    let id = UUID()
    let index: Int
    
    var dictionary = [String : Any]()
    
    var feedID = ""
    var feedName = ""
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
    
    var isRiverOrSocial = true
    var feedColorBarLeft: UIColor?
    var feedColorBarRight: UIColor?
    
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
    
    private func load() {
        guard let appDelegate = NewsBlurAppDelegate.shared, let storiesCollection = appDelegate.storiesCollection,
              index < storiesCollection.activeFeedStoryLocations.count,
              let row = storiesCollection.activeFeedStoryLocations[index] as? Int,
              let story = storiesCollection.activeFeedStories[row] as? [String : Any] else {
            return
        }
        
        dictionary = story
        
        if let id = dictionary["story_feed_id"] {
            feedID = appDelegate.feedIdWithoutSearchQuery("\(id)")
        }
        
        var feed: [String : Any]?
        
        if storiesCollection.isRiverOrSocial {
            feed = appDelegate.dictActiveFeeds[feedID] as? [String : Any]
        }
        
        if feed == nil {
            feed = appDelegate.dictFeeds[feedID] as? [String : Any]
        }
        
        if let feed {
            feedName = feed["feed_title"] as? String ?? ""
            feedColorBarLeft = color(for: "favicon_fade", from: feed, default: "707070")
            feedColorBarRight = color(for: "favicon_color", from: feed, default: "505050")
        }
        
        title = (string(for: "story_title") as NSString).decodingHTMLEntities()
        content = String(string(for: "story_content").convertHTML().decodingXMLEntities().decodingHTMLEntities().replacingOccurrences(of: "\n", with: " ").prefix(500))
        author = string(for: "story_authors").replacingOccurrences(of: "\"", with: "")
        timestamp = dictionary["story_timestamp"] as? Int ?? 0
        dateString = Utilities.formatShortDate(fromTimestamp: timestamp) ?? ""
        isSaved = dictionary["starred"] as? Bool ?? false
        isShared = dictionary["shared"] as? Bool ?? false
        hash = string(for: "story_hash")
        
        if let intelligence = dictionary["intelligence"] as? [String : Any] {
            score = Int(NewsBlurAppDelegate.computeStoryScore(intelligence))
        }
        
        isRead = !storiesCollection .isStoryUnread(dictionary)
        isReadAvailable = storiesCollection.activeFolder != "saved_stories"
        isRiverOrSocial = storiesCollection.isRiverOrSocial
    }
    
    func color(for key: String, from feed: [String : Any], default defaultHex: String) -> UIColor {
        let hex = feed[key] as? String ?? defaultHex
        let scanner = Scanner(string: hex)
        var color: Int64 = 0
        scanner.scanHexInt64(&color)
        let value = Int(color)
        
        return ThemeManager.shared.fixedColor(fromRGB: value) ?? UIColor.gray
    }
}

extension Story: Equatable {
    static func == (lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Story: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Story #\(index) \"\(title)\" in \(feedName)"
    }
}

/// A cache of stories for the feed detail grid view.
class StoryCache: ObservableObject {
    let appDelegate = NewsBlurAppDelegate.shared!
    
    let settings = StorySettings()
    
    var isDarkTheme: Bool {
        return ThemeManager.shared.isDarkTheme
    }
    
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid
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
    
    func reload() {
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
        
        before = beforeSelection.map { Story(index: $0) }
        selected = selectedIndex >= 0 ? Story(index: selectedIndex) : nil
        after = afterSelection.map { Story(index: $0) }
        
        print("🪿 Reload: \(before.count) before, \(selected == nil ? "none" : selected!.debugTitle) selected, \(after.count) after")
        
        
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
}

class StorySettings {
    let defaults = UserDefaults.standard
    
    enum Content: String, RawRepresentable {
        case title
        case short
        case medium
        case long
        
        static let titleLimit = 6
        
        static let contentLimit = 10
        
        var limit: Int {
            switch self {
                case .title:
                    return 6
                case .short:
                    return 2
                case .medium:
                    return 4
                case .long:
                    return 6
            }
        }
    }
    
    var content: Content {
        if let string = defaults.string(forKey: "story_list_preview_text_size"), let value = Content(rawValue: string) {
            return value
        } else {
            return .short
        }
    }
    
    enum Preview: String, RawRepresentable {
        case none
        case smallLeft = "small_left"
        case largeLeft = "large_left"
        case largeRight = "large_right"
        case smallRight = "small_right"
        
        var isLeft: Bool {
            return [.smallLeft, .largeLeft].contains(self)
        }
        
        var isSmall: Bool {
            return [.smallLeft, .smallRight].contains(self)
        }
    }
    
    var preview: Preview {
        if let string = defaults.string(forKey: "story_list_preview_images_size"), let value = Preview(rawValue: string) {
            return value
        } else {
            return .smallRight
        }
    }
    
    enum FontSize: String, RawRepresentable {
        case xs
        case small
        case medium
        case large
        case xl
        
        var offset: CGFloat {
            switch self {
                case .xs:
                    return -2
                case .small:
                    return -1
                case .medium:
                    return 0
                case .large:
                    return 1
                case .xl:
                    return 2
            }
        }
    }
    
    var fontSize: FontSize {
        if let string = defaults.string(forKey: "feed_list_font_size"), let value = FontSize(rawValue: string) {
            return value
        } else {
            return .medium
        }
    }
    
    enum Spacing: String, RawRepresentable {
        case compact
        case comfortable
    }
    
    var spacing: Spacing {
        if let string = defaults.string(forKey: "feed_list_spacing"), let value = Spacing(rawValue: string) {
            return value
        } else {
            return .comfortable
        }
    }
    
    var gridColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            if NewsBlurAppDelegate.shared.isCompactWidth {
                return 1
            } else if NewsBlurAppDelegate.shared.isPortrait() {
                return 2
            } else {
                return 4
            }
        }
        
        if NewsBlurAppDelegate.shared.isPortrait(), columns > 3 {
            return 3
        }
        
        return columns
    }
    
    var gridHeight: CGFloat {
        guard let pref = UserDefaults.standard.string(forKey: "grid_height") else {
            return 400
        }
        
        switch pref {
        case "xs":
            return 250
        case "short":
            return 300
        case "tall":
            return 500
        case "xl":
            return 600
        default:
            return 400
        }
    }
}
