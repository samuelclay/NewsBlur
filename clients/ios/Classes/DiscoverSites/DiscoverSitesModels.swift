//
//  DiscoverSitesModels.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import Foundation

enum DiscoverTab: String, CaseIterable, Identifiable {
    case search
    case webFeed
    case popular
    case youtube
    case reddit
    case newsletters
    case podcasts
    case googleNews

    var id: String { rawValue }

    var label: String {
        switch self {
        case .search: return "Search"
        case .webFeed: return "Web Feed"
        case .popular: return "Popular"
        case .youtube: return "YouTube"
        case .reddit: return "Reddit"
        case .newsletters: return "Newsletters"
        case .podcasts: return "Podcasts"
        case .googleNews: return "Google News"
        }
    }

    var sfSymbol: String {
        switch self {
        case .search: return "magnifyingglass"
        case .webFeed: return "globe"
        case .popular: return "flame.fill"
        case .youtube: return "play.rectangle.fill"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .newsletters: return "envelope.fill"
        case .podcasts: return "mic.fill"
        case .googleNews: return "newspaper.fill"
        }
    }

    var feedType: String {
        switch self {
        case .youtube: return "youtube"
        case .reddit: return "reddit"
        case .newsletters: return "newsletter"
        case .podcasts: return "podcast"
        case .popular: return "all"
        default: return "all"
        }
    }
}

struct DiscoverPopularFeed: Identifiable {
    let id: String
    let feedTitle: String
    let feedAddress: String
    let feedLink: String
    let numSubscribers: Int
    let averageStoriesPerMonth: Int
    let faviconUrl: String?
    let stories: [DiscoverStory]
    let rawFeedDict: [String: Any]

    init(feedId: String, feedDict: [String: Any], storiesArray: [[String: Any]] = []) {
        self.id = feedId
        self.feedTitle = feedDict["feed_title"] as? String ?? ""
        self.feedAddress = feedDict["feed_address"] as? String ?? ""
        self.feedLink = feedDict["feed_link"] as? String ?? ""
        self.numSubscribers = feedDict["num_subscribers"] as? Int ?? feedDict["subs"] as? Int ?? 0
        self.averageStoriesPerMonth = feedDict["average_stories_per_month"] as? Int ?? 0
        self.faviconUrl = feedDict["favicon_url"] as? String
        self.rawFeedDict = feedDict
        self.stories = storiesArray.compactMap { DiscoverStory(dict: $0) }
    }
}

struct DiscoverCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let feedCount: Int
    let subcategories: [DiscoverSubcategory]

    static func == (lhs: DiscoverCategory, rhs: DiscoverCategory) -> Bool {
        lhs.id == rhs.id
    }
}

struct DiscoverSubcategory: Identifiable, Equatable {
    let id: String
    let name: String
    let feedCount: Int

    static func == (lhs: DiscoverSubcategory, rhs: DiscoverSubcategory) -> Bool {
        lhs.id == rhs.id
    }
}

struct GoogleNewsTopic: Identifiable {
    let id: String
    let name: String

    var sfSymbol: String {
        switch id {
        case "WORLD": return "globe.americas.fill"
        case "NATION": return "building.columns.fill"
        case "BUSINESS": return "briefcase.fill"
        case "TECHNOLOGY": return "cpu.fill"
        case "ENTERTAINMENT": return "film.fill"
        case "SPORTS": return "trophy.fill"
        case "SCIENCE": return "flask.fill"
        case "HEALTH": return "heart.fill"
        default: return "newspaper.fill"
        }
    }
}

struct GoogleNewsCategory: Identifiable {
    let id: String
    let name: String
    let subcategories: [String]
}

struct WebFeedVariant: Identifiable {
    let id: Int
    let label: String
    let storyContainerXpath: String
    let titleXpath: String
    let linkXpath: String
    let contentXpath: String
    let imageXpath: String
    let authorXpath: String
    let dateXpath: String
    let stories: [WebFeedPreviewStory]

    init(index: Int, dict: [String: Any]) {
        self.id = index
        self.label = dict["label"] as? String ?? "Variant \(index + 1)"
        self.storyContainerXpath = dict["story_container_xpath"] as? String ?? ""
        self.titleXpath = dict["title_xpath"] as? String ?? ""
        self.linkXpath = dict["link_xpath"] as? String ?? ""
        self.contentXpath = dict["content_xpath"] as? String ?? ""
        self.imageXpath = dict["image_xpath"] as? String ?? ""
        self.authorXpath = dict["author_xpath"] as? String ?? ""
        self.dateXpath = dict["date_xpath"] as? String ?? ""
        let storiesArray = dict["stories"] as? [[String: Any]] ?? []
        self.stories = storiesArray.enumerated().map { WebFeedPreviewStory(index: $0, dict: $1) }
    }
}

struct WebFeedPreviewStory: Identifiable {
    let id: Int
    let title: String
    let link: String
    let imageUrl: String?

    init(index: Int, dict: [String: Any]) {
        self.id = index
        self.title = dict["title"] as? String ?? ""
        self.link = dict["link"] as? String ?? ""
        self.imageUrl = dict["image"] as? String
    }
}

struct SearchTabState {
    var query: String = ""
    var results: [AutocompleteResult] = []
    var trendingFeeds: [DiscoverPopularFeed] = []
    var isSearching: Bool = false
    var isTrendingLoading: Bool = false
    var isTrendingLoaded: Bool = false
}

struct WebFeedTabState {
    var url: String = ""
    var isAnalyzing: Bool = false
    var progressMessage: String = ""
    var errorMessage: String?
    var requestId: String?
    var variants: [WebFeedVariant] = []
    var selectedVariantIndex: Int?
    var htmlHash: String = ""
    var faviconUrl: String = ""
    var stalenessDays: Double = 30
    var markUnreadOnChange: Bool = false
    var feedTitle: String = ""
    var isSubscribing: Bool = false
}

struct CategoryTabState {
    var feeds: [DiscoverPopularFeed] = []
    var categories: [DiscoverCategory] = []
    var selectedCategory: DiscoverCategory?
    var selectedSubcategory: DiscoverSubcategory?
    var searchQuery: String = ""
    var searchResults: [DiscoverPopularFeed] = []
    var isLoading: Bool = false
    var isSearching: Bool = false
    var offset: Int = 0
    var hasMore: Bool = true
    var isCategoriesLoaded: Bool = false
    var platformFilter: String?
    var platformCounts: [String: Int] = [:]
}

struct GoogleNewsTabState {
    var topics: [GoogleNewsTopic] = []
    var categories: [GoogleNewsCategory] = []
    var selectedTopic: GoogleNewsTopic?
    var selectedCategory: GoogleNewsCategory?
    var selectedSubcategory: String?
    var searchQuery: String = ""
    var language: String = "en"
    var isLoading: Bool = false
    var isDataLoaded: Bool = false
    var isSubscribing: Bool = false
    var errorMessage: String?
}
