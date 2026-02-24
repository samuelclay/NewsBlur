//
//  DiscoverFeedsModels.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import Foundation

struct DiscoverFeed: Identifiable {
    let id: String
    let feedTitle: String
    let feedAddress: String
    let feedLink: String
    let numSubscribers: Int
    let averageStoriesPerMonth: Int
    let faviconUrl: String?
    let faviconColor: String?
    let faviconFade: String?
    let stories: [DiscoverStory]
    let rawFeedDict: [String: Any]

    init(feedId: String, feedDict: [String: Any], storiesArray: [[String: Any]]) {
        self.id = feedId
        self.feedTitle = feedDict["feed_title"] as? String ?? ""
        self.feedAddress = feedDict["feed_address"] as? String ?? ""
        self.feedLink = feedDict["feed_link"] as? String ?? ""
        self.numSubscribers = feedDict["num_subscribers"] as? Int ?? feedDict["subs"] as? Int ?? 0
        self.averageStoriesPerMonth = feedDict["average_stories_per_month"] as? Int ?? 0
        self.faviconUrl = feedDict["favicon_url"] as? String
        self.faviconColor = feedDict["favicon_color"] as? String
        self.faviconFade = feedDict["favicon_fade"] as? String
        self.rawFeedDict = feedDict

        self.stories = storiesArray.compactMap { DiscoverStory(dict: $0) }
    }
}

struct DiscoverStory: Identifiable {
    let id: String
    let title: String
    let authors: String
    let date: Date?
    let permalink: String
    let imageUrls: [String]

    init?(dict: [String: Any]) {
        guard let hash = dict["story_hash"] as? String else { return nil }
        self.id = hash
        self.title = dict["story_title"] as? String ?? ""
        self.authors = dict["story_authors"] as? String ?? ""
        self.permalink = dict["story_permalink"] as? String ?? ""

        if let dateString = dict["story_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            self.date = formatter.date(from: dateString)
        } else {
            self.date = nil
        }

        if let images = dict["image_urls"] as? [String] {
            self.imageUrls = images
        } else {
            self.imageUrls = []
        }
    }
}

enum DiscoverFeedsViewMode: String, CaseIterable {
    case grid
    case list
}
