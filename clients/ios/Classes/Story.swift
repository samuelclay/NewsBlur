//
//  Story.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import Foundation

/// A story, wrapping the dictionary representation.
class Story: Identifiable {
    let id = UUID()
    let index: Int
//    lazy var title: String = {
//       return "lazy story #\(index)"
//    }()
    
    var dictionary = [String : Any]()
    
    var feedID = ""
    var feedName = ""
    var title = ""
    var content = ""
    var dateString = ""
    var timestamp = 0
    var isRead = false
    var isSaved = false
    var isShared = false
    var score = 0
    var hash = ""
    var author = ""
    
    var dateAndAuthor: String {
        let date = Utilities.formatShortDate(fromTimestamp: timestamp) ?? ""
        
        return author.isEmpty ? date : "\(date) · \(author)"
    }
    
    var isRiverOrSocial = true
    var feedColorBarLeft: UIColor?
    var feedColorBarRight: UIColor?
    
    var isSelected: Bool {
        return index == NewsBlurAppDelegate.shared!.storiesCollection.indexOfActiveStory()
    }
    
    var isLoaded: Bool {
        return !dictionary.isEmpty
    }
    
    init(index: Int) {
        self.index = index
    }
    
    private func string(for key: String) -> String {
        return dictionary[key] as? String ?? ""
    }
    
    func load() {
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
        dateString = string(for: "short_parsed_date")
        timestamp = dictionary["story_timestamp"] as? Int ?? 0
        isSaved = dictionary["starred"] as? Bool ?? false
        isShared = dictionary["shared"] as? Bool ?? false
        hash = string(for: "story_hash")
        
        if let intelligence = dictionary["intelligence"] as? [String : Any] {
            score = Int(NewsBlurAppDelegate.computeStoryScore(intelligence))
        }
        
        isRead = score < 0
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
        return "Story \"\(title)\" in \(feedName)"
    }
}

/// A cache of stories for the feed detail grid view.
class StoryCache: ObservableObject {
    let appDelegate = NewsBlurAppDelegate.shared!
    
    let settings = StorySettings()
    
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid
    }
    
    @Published var before = [Story]()
    @Published var selected: Story?
    @Published var after = [Story]()
    
    func appendStories(beforeSelection: [Int], selectedIndex: Int, afterSelection: [Int]) {
        before = beforeSelection.map { Story(index: $0) }
        selected = selectedIndex >= 0 ? Story(index: selectedIndex) : nil
        after = afterSelection.map { Story(index: $0) }
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
    
//    enum GridColumns: String {
//        case auto = "auto"
//        case two = "2"
//        case three = "3"
//        case four = "4"
//
//        var number: Int {
//            switch self {
//            case .two:
//                return 2
//            case .three:
//                return 3
//            case .four:
//                return 4
//            default:
//                if NewsBlurAppDelegate.shared.isCompactWidth {
//                    return 1
//                } else {
//                    return 4
//                }
//            }
//        }
//    }
    
    var gridColumns: Int {
        if NewsBlurAppDelegate.shared.isCompactWidth {
            return 1
        }
        
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            //TODO: 🚧 could have extra logic to determine the ideal number of columns
            return 4
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
