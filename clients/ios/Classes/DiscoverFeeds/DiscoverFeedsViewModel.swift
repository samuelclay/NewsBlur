//
//  DiscoverFeedsViewModel.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 15.0, *)
@MainActor
class DiscoverFeedsViewModel: ObservableObject {
    @Published var feeds: [DiscoverFeed] = []
    @Published var isLoading = false
    @Published var hasMorePages = true
    @Published var error: String?
    @Published var viewMode: DiscoverFeedsViewMode = .list

    private let feedId: String?
    private let feedIds: [String]?
    private let appDelegate = NewsBlurAppDelegate.shared()!
    private var currentPage = 1
    private let maxPage = 10

    init(feedId: String) {
        self.feedId = feedId
        self.feedIds = nil

        if let savedMode = UserDefaults.standard.string(forKey: "discoverFeedsViewMode"),
           let mode = DiscoverFeedsViewMode(rawValue: savedMode) {
            self.viewMode = mode
        }
    }

    init(feedIds: [String]) {
        self.feedId = nil
        self.feedIds = feedIds

        if let savedMode = UserDefaults.standard.string(forKey: "discoverFeedsViewMode"),
           let mode = DiscoverFeedsViewMode(rawValue: savedMode) {
            self.viewMode = mode
        }
    }

    func loadInitialPage() {
        guard feeds.isEmpty && !isLoading else { return }
        loadPage(1)
    }

    func loadNextPage() {
        guard !isLoading && hasMorePages else { return }
        loadPage(currentPage + 1)
    }

    func setViewMode(_ mode: DiscoverFeedsViewMode) {
        viewMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "discoverFeedsViewMode")
    }

    private func loadPage(_ page: Int) {
        guard page <= maxPage else {
            hasMorePages = false
            return
        }

        isLoading = true
        error = nil

        let baseURL = appDelegate.url ?? "https://www.newsblur.com"

        var request: URLRequest
        if let feedIds = feedIds {
            guard let url = URL(string: "\(baseURL)/rss_feeds/discover/feeds/") else {
                error = "Invalid URL"
                isLoading = false
                return
            }
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var bodyParts = feedIds.map { "feed_ids=\($0)" }
            bodyParts.append("page=\(page)")
            request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)
        } else if let feedId = feedId {
            guard let url = URL(string: "\(baseURL)/rss_feeds/discover/\(feedId)/?page=\(page)") else {
                error = "Invalid URL"
                isLoading = false
                return
            }
            request = URLRequest(url: url)
            request.httpMethod = "GET"
        } else {
            error = "No feed specified"
            isLoading = false
            return
        }

        if let url = request.url, let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    self.error = error.localizedDescription
                    return
                }

                guard let data = data else {
                    self.error = "No response data"
                    return
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.error = "Invalid response format"
                        return
                    }

                    guard let discoverFeeds = json["discover_feeds"] as? [String: Any] else {
                        self.error = json["message"] as? String ?? "No feeds found"
                        self.hasMorePages = false
                        return
                    }

                    var newFeeds: [DiscoverFeed] = []
                    for (feedId, feedData) in discoverFeeds {
                        guard let feedInfo = feedData as? [String: Any],
                              let feedDict = feedInfo["feed"] as? [String: Any] else { continue }
                        let storiesArray = feedInfo["stories"] as? [[String: Any]] ?? []
                        let feed = DiscoverFeed(feedId: feedId, feedDict: feedDict, storiesArray: storiesArray)
                        newFeeds.append(feed)
                    }

                    // Sort by subscriber count descending
                    newFeeds.sort { $0.numSubscribers > $1.numSubscribers }

                    if newFeeds.isEmpty {
                        self.hasMorePages = false
                    } else {
                        self.feeds.append(contentsOf: newFeeds)
                        self.currentPage = page
                        self.hasMorePages = page < self.maxPage
                    }
                } catch {
                    self.error = "Failed to parse response"
                }
            }
        }.resume()
    }
}
