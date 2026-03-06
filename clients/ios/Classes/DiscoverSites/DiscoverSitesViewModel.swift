//
//  DiscoverSitesViewModel.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import Foundation
import Combine

@available(iOS 15.0, *)
@MainActor
class DiscoverSitesViewModel: ObservableObject {
    // MARK: - Published State

    @Published var activeTab: DiscoverTab = .search
    @Published var selectedFolder: String = ""

    @Published var searchState = SearchTabState()
    @Published var webFeedState = WebFeedTabState()
    @Published var popularState = CategoryTabState()
    @Published var youtubeState = CategoryTabState()
    @Published var redditState = CategoryTabState()
    @Published var newslettersState = CategoryTabState()
    @Published var podcastsState = CategoryTabState()
    @Published var googleNewsState = GoogleNewsTabState()

    @Published var addedFeedUrl: String?
    @Published var addedSuccess: Bool = false
    @Published var addErrorMessage: String?

    // MARK: - Private Properties

    private let appDelegate = NewsBlurAppDelegate.shared()!
    private var searchDebounceTimer: Timer?
    private var searchCache: [String: [AutocompleteResult]] = [:]
    private var pollingTimer: Timer?

    private var baseURL: String {
        appDelegate.url ?? "https://www.newsblur.com"
    }

    // MARK: - Computed Properties

    var folders: [String] {
        guard let allFolders = appDelegate.dictFoldersArray as? [String] else { return [] }
        let excluded: Set<String> = [
            "saved_searches", "saved_stories", "read_stories", "widget_stories",
            "river_blurblogs", "river_global", "dashboard", "infrequent", "everything",
            "discover_sites"
        ]
        return allFolders.filter { !excluded.contains($0) }
    }

    // MARK: - Helpers

    func folderDisplayName(_ folder: String) -> String {
        let components = folder.components(separatedBy: " \u{25B8} ")
        let name = components.last ?? folder
        let indent = String(repeating: "    ", count: components.count - 1)
        return indent + name
    }

    private func extractFolderName(_ folder: String) -> String {
        if let range = folder.range(of: " \u{25B8} ", options: .backwards) {
            return String(folder[range.upperBound...])
        }
        return folder
    }

    var displayFolder: String {
        selectedFolder.isEmpty ? "— Top Level —" : extractFolderName(selectedFolder)
    }

    private var resolvedFolder: String {
        if let range = selectedFolder.range(of: " \u{25B8} ", options: .backwards) {
            return String(selectedFolder[range.upperBound...])
        } else if selectedFolder.contains("Top Level") || selectedFolder.isEmpty {
            return ""
        }
        return selectedFolder
    }

    // MARK: - Tab Lifecycle

    func onTabSelected(_ tab: DiscoverTab) {
        if tab != .webFeed {
            stopPolling()
        }

        switch tab {
        case .search:
            if !searchState.isTrendingLoaded {
                loadTrendingFeeds()
            }
        case .popular:
            if !popularState.isCategoriesLoaded {
                loadPopularFeeds(type: "all", category: nil, subcategory: nil, offset: 0)
            }
        case .youtube:
            if !youtubeState.isCategoriesLoaded {
                loadPopularFeeds(type: "youtube", category: nil, subcategory: nil, offset: 0)
            }
        case .reddit:
            if !redditState.isCategoriesLoaded {
                loadPopularFeeds(type: "reddit", category: nil, subcategory: nil, offset: 0)
            }
        case .newsletters:
            if !newslettersState.isCategoriesLoaded {
                loadPopularFeeds(type: "newsletter", category: nil, subcategory: nil, offset: 0)
            }
        case .podcasts:
            if !podcastsState.isCategoriesLoaded {
                loadPopularFeeds(type: "podcast", category: nil, subcategory: nil, offset: 0)
            }
        case .googleNews:
            if !googleNewsState.isDataLoaded {
                loadGoogleNewsData()
            }
        case .webFeed:
            break
        }
    }

    // MARK: - Network Helper

    private func makeRequest(path: String, method: String = "GET", params: [String: String]? = nil, body: [String: String]? = nil) -> URLRequest? {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else { return nil }

        if let params = params, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body = body {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var bodyComponents = URLComponents()
            bodyComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = bodyComponents.query?.data(using: .utf8)
        }

        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> [String: Any] {
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "DiscoverSites", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        return json
    }

    // MARK: - 1. Search Autocomplete

    func searchAutocomplete(query: String) {
        searchDebounceTimer?.invalidate()

        guard !query.isEmpty else {
            searchState.results = []
            searchState.isSearching = false
            return
        }

        if let cached = searchCache[query] {
            searchState.results = cached
            return
        }

        searchState.isSearching = true

        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSearchAutocomplete(query: query)
            }
        }
    }

    private func performSearchAutocomplete(query: String) async {
        guard let request = makeRequest(
            path: "/discover/autocomplete",
            params: ["term": query, "v": "2", "format": "full", "limit": "20"]
        ) else {
            searchState.isSearching = false
            return
        }

        do {
            let json = try await performRequest(request)
            let feeds = json["feeds"] as? [[String: Any]] ?? []
            let results = feeds.map { AutocompleteResult(dict: $0) }

            let queryTerm = json["term"] as? String ?? query
            searchCache[queryTerm] = results

            if searchState.query == query || searchState.query == queryTerm {
                searchState.results = results
            }
            searchState.isSearching = false
        } catch {
            searchState.isSearching = false
        }
    }

    // MARK: - 2. Trending Feeds

    func loadTrendingFeeds() {
        guard let request = makeRequest(
            path: "/discover/trending",
            params: ["page": "1", "days": "7", "limit": "20"]
        ) else { return }

        searchState.isTrendingLoading = true

        Task {
            do {
                let json = try await performRequest(request)
                let trendingDict = json["trending_feeds"] as? [String: [String: Any]] ?? [:]
                let feeds = trendingDict.compactMap { (key, entry) -> DiscoverPopularFeed? in
                    guard let feedDict = entry["feed"] as? [String: Any] else { return nil }
                    let feedId = feedDict["id"] as? String
                        ?? (feedDict["id"] as? Int).map(String.init)
                        ?? key
                    let storiesArray = entry["stories"] as? [[String: Any]] ?? []
                    return DiscoverPopularFeed(feedId: feedId, feedDict: feedDict, storiesArray: storiesArray)
                }.sorted { $0.numSubscribers > $1.numSubscribers }
                searchState.trendingFeeds = feeds
                searchState.isTrendingLoading = false
                searchState.isTrendingLoaded = true
            } catch {
                searchState.isTrendingLoading = false
            }
        }
    }

    // MARK: - 3. Popular Feeds

    func loadPopularFeeds(type: String, category: String?, subcategory: String?, offset: Int) {
        var params: [String: String] = [
            "type": type,
            "offset": String(offset),
            "limit": "20"
        ]
        if let category = category, !category.isEmpty {
            params["category"] = category
        }
        if let subcategory = subcategory, !subcategory.isEmpty {
            params["subcategory"] = subcategory
        }

        guard let request = makeRequest(path: "/discover/popular_feeds", params: params) else { return }

        updateCategoryTabState(type: type) { state in
            state.isLoading = true
            if offset == 0 {
                state.feeds = []
            }
        }

        Task {
            do {
                let json = try await performRequest(request)
                let feedsArray = json["feeds"] as? [[String: Any]] ?? []
                let feeds = feedsArray.compactMap { entry -> DiscoverPopularFeed? in
                    Self.parsePopularFeedEntry(entry)
                }

                let groupedCategories = json["grouped_categories"] as? [[String: Any]] ?? []
                let categories = groupedCategories.map { catDict -> DiscoverCategory in
                    let name = catDict["name"] as? String ?? ""
                    let feedCount = catDict["feed_count"] as? Int ?? 0
                    let subsArray = catDict["subcategories"] as? [[String: Any]] ?? []
                    let subcats = subsArray.map { subDict -> DiscoverSubcategory in
                        let subName = subDict["name"] as? String ?? ""
                        let subCount = subDict["feed_count"] as? Int ?? 0
                        return DiscoverSubcategory(id: "\(name)-\(subName)", name: subName, feedCount: subCount)
                    }
                    return DiscoverCategory(id: name, name: name, feedCount: feedCount, subcategories: subcats)
                }

                let platformCounts = json["platform_counts"] as? [String: Int] ?? [:]

                updateCategoryTabState(type: type) { state in
                    if offset == 0 {
                        state.feeds = feeds
                    } else {
                        state.feeds.append(contentsOf: feeds)
                    }
                    if !categories.isEmpty {
                        state.categories = categories
                    }
                    if !platformCounts.isEmpty {
                        state.platformCounts = platformCounts
                    }
                    state.offset = offset + feeds.count
                    state.hasMore = feeds.count >= 20
                    state.isLoading = false
                    state.isCategoriesLoaded = true
                }
            } catch {
                updateCategoryTabLoading(type: type, isLoading: false)
            }
        }
    }

    // MARK: - 4. Search Feeds (YouTube, Reddit, Podcasts, Newsletters)

    func searchFeeds(type: String, query: String) {
        guard !query.isEmpty else { return }

        updateCategoryTabSearching(type: type, isSearching: true)

        let path: String
        var params: [String: String]

        switch type {
        case "youtube":
            path = "/discover/youtube/search"
            params = ["query": query]
        case "reddit":
            path = "/discover/reddit/search"
            params = ["query": query]
        case "podcast":
            path = "/discover/podcast/search"
            params = ["query": query]
        default:
            path = "/discover/popular_feeds"
            params = ["type": type, "query": query]
        }

        guard let request = makeRequest(path: path, params: params) else {
            updateCategoryTabSearching(type: type, isSearching: false)
            return
        }

        Task {
            do {
                let json = try await performRequest(request)
                let feedsArray = json["feeds"] as? [[String: Any]] ?? []
                let feeds = feedsArray.compactMap { entry -> DiscoverPopularFeed? in
                    Self.parsePopularFeedEntry(entry)
                }

                updateCategoryTabState(type: type) { state in
                    state.searchResults = feeds
                    state.isSearching = false
                }
            } catch {
                updateCategoryTabSearching(type: type, isSearching: false)
            }
        }
    }

    // MARK: - 5. Analyze Web Feed

    func analyzeWebFeed(url: String) {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }

        let requestId = UUID().uuidString
        webFeedState.requestId = requestId
        webFeedState.isAnalyzing = true
        webFeedState.progressMessage = "Analyzing web page..."
        webFeedState.errorMessage = nil
        webFeedState.variants = []
        webFeedState.selectedVariantIndex = nil

        guard let request = makeRequest(
            path: "/webfeed/analyze",
            method: "POST",
            body: ["url": trimmedUrl, "request_id": requestId]
        ) else {
            webFeedState.isAnalyzing = false
            webFeedState.errorMessage = "Invalid URL"
            return
        }

        Task {
            do {
                let _ = try await performRequest(request)
                startPolling()
            } catch {
                webFeedState.isAnalyzing = false
                webFeedState.errorMessage = "Failed to start analysis: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 6. Poll Web Feed Status

    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollWebFeedStatus()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollWebFeedStatus() {
        guard let requestId = webFeedState.requestId else {
            stopPolling()
            return
        }

        guard let request = makeRequest(
            path: "/webfeed/status",
            params: ["request_id": requestId]
        ) else { return }

        Task {
            do {
                let json = try await performRequest(request)
                let eventType = json["type"] as? String ?? json["status"] as? String ?? ""
                let message = json["message"] as? String

                switch eventType {
                case "start", "progress":
                    webFeedState.progressMessage = message ?? "Analyzing..."

                case "variants", "complete":
                    stopPolling()
                    webFeedState.isAnalyzing = false

                    let variantsData = json["variants_data"] as? [String: Any] ?? json
                    let variantsArray = variantsData["variants"] as? [[String: Any]] ?? json["variants"] as? [[String: Any]] ?? []
                    webFeedState.variants = variantsArray.enumerated().map { index, dict in
                        WebFeedVariant(index: index, dict: dict)
                    }
                    webFeedState.htmlHash = variantsData["html_hash"] as? String ?? json["html_hash"] as? String ?? ""
                    webFeedState.faviconUrl = variantsData["favicon_url"] as? String ?? json["favicon_url"] as? String ?? ""
                    webFeedState.feedTitle = variantsData["feed_title"] as? String ?? json["feed_title"] as? String ?? ""

                    if !webFeedState.variants.isEmpty {
                        webFeedState.selectedVariantIndex = 0
                    }

                    webFeedState.progressMessage = ""

                case "error":
                    stopPolling()
                    webFeedState.isAnalyzing = false
                    webFeedState.errorMessage = message ?? "Analysis failed"
                    webFeedState.progressMessage = ""

                default:
                    webFeedState.progressMessage = message ?? eventType
                }
            } catch {
                // Polling request failed; keep trying
            }
        }
    }

    // MARK: - 7. Subscribe Web Feed

    func subscribeWebFeed() {
        guard let variantIndex = webFeedState.selectedVariantIndex,
              variantIndex < webFeedState.variants.count else { return }

        let variant = webFeedState.variants[variantIndex]
        webFeedState.isSubscribing = true

        var bodyParams: [String: String] = [
            "url": webFeedState.url,
            "variant_index": String(variantIndex),
            "feed_title": webFeedState.feedTitle,
            "story_container_xpath": variant.storyContainerXpath,
            "title_xpath": variant.titleXpath,
            "link_xpath": variant.linkXpath,
            "content_xpath": variant.contentXpath,
            "image_xpath": variant.imageXpath,
            "author_xpath": variant.authorXpath,
            "date_xpath": variant.dateXpath,
            "html_hash": webFeedState.htmlHash,
            "favicon_url": webFeedState.faviconUrl,
            "staleness_days": String(Int(webFeedState.stalenessDays)),
            "mark_unread_on_change": webFeedState.markUnreadOnChange ? "true" : "false",
            "folder": resolvedFolder
        ]

        if let requestId = webFeedState.requestId {
            bodyParams["request_id"] = requestId
        }

        guard let request = makeRequest(
            path: "/webfeed/subscribe",
            method: "POST",
            body: bodyParams
        ) else {
            webFeedState.isSubscribing = false
            return
        }

        Task {
            do {
                let json = try await performRequest(request)
                webFeedState.isSubscribing = false

                let code = json["code"] as? Int ?? 0
                if code == -1 {
                    webFeedState.errorMessage = json["message"] as? String ?? "Subscription failed"
                } else {
                    addedSuccess = true
                    addedFeedUrl = webFeedState.url
                }
            } catch {
                webFeedState.isSubscribing = false
                webFeedState.errorMessage = "Subscription failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 8. Google News Data

    func loadGoogleNewsData() {
        guard let request = makeRequest(path: "/discover/google-news/categories") else { return }

        googleNewsState.isLoading = true

        Task {
            do {
                let json = try await performRequest(request)

                let topicsArray = json["topics"] as? [[String: Any]] ?? []
                let topics = topicsArray.map { dict -> GoogleNewsTopic in
                    GoogleNewsTopic(
                        id: dict["id"] as? String ?? "",
                        name: dict["name"] as? String ?? ""
                    )
                }

                let categoriesArray = json["categories"] as? [[String: Any]] ?? []
                let categories = categoriesArray.map { dict -> GoogleNewsCategory in
                    let subsArray = dict["subcategories"] as? [[String: Any]] ?? []
                    let subNames = subsArray.compactMap { $0["name"] as? String }
                    return GoogleNewsCategory(
                        id: dict["id"] as? String ?? dict["name"] as? String ?? "",
                        name: dict["name"] as? String ?? "",
                        subcategories: subNames
                    )
                }

                googleNewsState.topics = topics
                googleNewsState.categories = categories
                googleNewsState.isLoading = false
                googleNewsState.isDataLoaded = true
            } catch {
                googleNewsState.isLoading = false
                googleNewsState.errorMessage = "Failed to load Google News data"
            }
        }
    }

    // MARK: - 9. Subscribe Google News

    func subscribeGoogleNews(query: String?, topic: String?, language: String) {
        var params: [String: String] = ["language": language]
        if let query = query, !query.isEmpty {
            params["query"] = query
        }
        if let topic = topic, !topic.isEmpty {
            params["topic"] = topic
        }

        guard let feedRequest = makeRequest(path: "/discover/google-news/feed", params: params) else { return }

        googleNewsState.isSubscribing = true
        googleNewsState.errorMessage = nil

        Task {
            do {
                let json = try await performRequest(feedRequest)
                guard let feedUrl = json["feed_url"] as? String, !feedUrl.isEmpty else {
                    googleNewsState.isSubscribing = false
                    googleNewsState.errorMessage = json["message"] as? String ?? "No feed URL returned"
                    return
                }

                guard let addRequest = makeRequest(
                    path: "/reader/add_url",
                    method: "POST",
                    body: ["url": feedUrl, "folder": resolvedFolder]
                ) else {
                    googleNewsState.isSubscribing = false
                    googleNewsState.errorMessage = "Failed to build request"
                    return
                }

                let addJson = try await performRequest(addRequest)
                googleNewsState.isSubscribing = false

                let code = addJson["code"] as? Int ?? 0
                if code == -1 {
                    googleNewsState.errorMessage = addJson["message"] as? String ?? "Failed to subscribe"
                } else {
                    addedSuccess = true
                    addedFeedUrl = feedUrl
                }
            } catch {
                googleNewsState.isSubscribing = false
                googleNewsState.errorMessage = "Failed to subscribe: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 10. Add Feed

    func addFeed(url feedUrl: String) {
        let trimmedUrl = feedUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }

        addErrorMessage = nil

        guard let request = makeRequest(
            path: "/reader/add_url",
            method: "POST",
            body: ["url": trimmedUrl, "folder": resolvedFolder]
        ) else {
            addErrorMessage = "Invalid URL"
            return
        }

        Task {
            do {
                let json = try await performRequest(request)
                let code = json["code"] as? Int ?? 0
                if code == -1 {
                    addErrorMessage = json["message"] as? String ?? "Failed to add site"
                } else {
                    addedSuccess = true
                    addedFeedUrl = trimmedUrl
                }
            } catch {
                addErrorMessage = "Failed to add site: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Feed Parsing Helper

    static func parsePopularFeedEntry(_ entry: [String: Any]) -> DiscoverPopularFeed? {
        var feedDict = entry["feed"] as? [String: Any] ?? [:]
        // Merge top-level PopularFeed fields into the feed dict
        if feedDict["feed_title"] == nil || (feedDict["feed_title"] as? String)?.isEmpty == true {
            feedDict["feed_title"] = entry["title"] as? String ?? ""
        }
        if feedDict["feed_address"] == nil {
            feedDict["feed_address"] = entry["feed_url"] as? String ?? ""
        }
        if feedDict["num_subscribers"] == nil || (feedDict["num_subscribers"] as? Int) == 0 {
            feedDict["num_subscribers"] = entry["subscriber_count"] as? Int ?? 0
        }
        if feedDict["favicon_url"] == nil {
            feedDict["favicon_url"] = entry["thumbnail_url"] as? String
        }
        let feedId = feedDict["id"] as? String
            ?? (feedDict["id"] as? Int).map(String.init)
            ?? (entry["feed_id"] as? Int).map(String.init)
            ?? feedDict["feed_address"] as? String
            ?? UUID().uuidString
        let storiesArray = entry["stories"] as? [[String: Any]] ?? []
        return DiscoverPopularFeed(feedId: feedId, feedDict: feedDict, storiesArray: storiesArray)
    }

    // MARK: - Category Tab State Helpers

    private func categoryTabState(for type: String) -> CategoryTabState {
        switch type {
        case "youtube": return youtubeState
        case "reddit": return redditState
        case "newsletter": return newslettersState
        case "podcast": return podcastsState
        default: return popularState
        }
    }

    private func updateCategoryTabState(type: String, update: (inout CategoryTabState) -> Void) {
        switch type {
        case "youtube": update(&youtubeState)
        case "reddit": update(&redditState)
        case "newsletter": update(&newslettersState)
        case "podcast": update(&podcastsState)
        default: update(&popularState)
        }
    }

    private func updateCategoryTabLoading(type: String, isLoading: Bool) {
        updateCategoryTabState(type: type) { state in
            state.isLoading = isLoading
        }
    }

    private func updateCategoryTabSearching(type: String, isSearching: Bool) {
        updateCategoryTabState(type: type) { state in
            state.isSearching = isSearching
        }
    }

    // MARK: - Reset

    func reset() {
        stopPolling()
        searchDebounceTimer?.invalidate()
        searchCache = [:]

        activeTab = .search
        selectedFolder = ""

        searchState = SearchTabState()
        webFeedState = WebFeedTabState()
        popularState = CategoryTabState()
        youtubeState = CategoryTabState()
        redditState = CategoryTabState()
        newslettersState = CategoryTabState()
        podcastsState = CategoryTabState()
        googleNewsState = GoogleNewsTabState()

        addedFeedUrl = nil
        addedSuccess = false
        addErrorMessage = nil
    }
}
