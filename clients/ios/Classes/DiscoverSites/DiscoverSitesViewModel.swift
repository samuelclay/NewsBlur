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
    @Published var feedViewMode: DiscoverSitesFeedViewMode = .grid

    @Published var searchState = SearchTabState()
    @Published var webFeedState = WebFeedTabState()
    @Published var popularState = CategoryTabState()
    @Published var youtubeState = CategoryTabState()
    @Published var redditState = CategoryTabState()
    @Published var newslettersState = CategoryTabState()
    @Published var podcastsState = CategoryTabState()
    @Published var googleNewsState = GoogleNewsTabState()

    @Published var addedFeedURLs: Set<String> = []
    @Published var addedFeedUrl: String?
    @Published var addedSuccess: Bool = false
    @Published var addErrorMessage: String?

    // MARK: - Private Properties

    private let appEnvironment: AddSiteViewModelAppEnvironment
    private let session: URLSession
    private var categoryRequests: [String: UUID] = [:]
    private var searchRequests: [String: UUID] = [:]
    private var autocompleteRequest = UUID()
    private var analysisStartedAt: Date?
    private var pollingRequest: String?
    private var pollingGeneration = UUID()
    private var pollingSuspended = false
    private var lifecycleGeneration = UUID()
    @Published var isAdding = false
    @Published var isPreparingPreview = false

    init(appEnvironment: AddSiteViewModelAppEnvironment = DefaultAddSiteViewModelAppEnvironment(),
         session: URLSession = .shared) {
        self.appEnvironment = appEnvironment
        self.session = session
    }
    private var searchDebounceTimer: Timer?
    private var searchCache: [String: [AutocompleteResult]] = [:]
    private var pollingTimer: Timer?

    private var baseURL: String {
        appEnvironment.url ?? "https://www.newsblur.com"
    }

    // MARK: - Computed Properties

    var folders: [String] {
        guard let allFolders = appEnvironment.dictFoldersArray as? [String] else { return [] }
        let excluded: Set<String> = [
            "saved_searches", "saved_stories", "read_stories", "widget_stories",
            "river_blurblogs", "river_global", "dashboard", "infrequent", "everything",
            "discover_sites", "daily_briefing"
        ]
        return allFolders.filter { !excluded.contains($0) && !$0.hasPrefix("trending:") }
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
        } else if selectedFolder == "— Top Level —" || selectedFolder.isEmpty {
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
            if webFeedState.isAnalyzing { startPolling() }
        }
    }

    // MARK: - Network Helper

    private func makeRequest(path: String, method: String = "GET", params: [String: String]? = nil, body: [String: String]? = nil) -> URLRequest? {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else { return nil }

        if let params = params, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body = body {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var bodyComponents = URLComponents()
            bodyComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = bodyComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
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
        let (data, response) = try await session.data(for: request)
        let decoded = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
            let fallback = response.statusCode == 404
                ? "This feature is not available on this server yet."
                : "The server could not complete the request (\(response.statusCode))."
            throw NSError(domain: "DiscoverSites", code: response.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: decoded?["message"] as? String ?? fallback])
        }
        guard let json = decoded else {
            throw NSError(domain: "DiscoverSites", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        if let code = json["code"] as? Int, code < 0,
           !(request.url?.path == "/webfeed/status" && json["status"] as? String == "unknown") {
            throw NSError(domain: "DiscoverSites", code: code,
                          userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? json["error"] as? String ?? "The request could not be completed. Please try again."])
        }
        return json
    }

    // MARK: - 1. Search Autocomplete

    func searchAutocomplete(query: String) {
        searchDebounceTimer?.invalidate()
        autocompleteRequest = UUID()
        searchState.query = query
        searchState.errorMessage = nil

        guard !query.isEmpty else {
            searchState.results = []
            searchState.isSearching = false
            return
        }

        if let cached = searchCache[query] {
            searchState.results = cached
            searchState.isSearching = false
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
        let token = autocompleteRequest
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

            guard token == autocompleteRequest else { return }
            let queryTerm = json["term"] as? String ?? query
            searchCache[queryTerm] = results

            if searchState.query == query || searchState.query == queryTerm {
                searchState.results = results
            }
            searchState.isSearching = false
        } catch {
            guard token == autocompleteRequest else { return }
            searchState.errorMessage = error.localizedDescription
            searchState.isSearching = false
        }
    }

    // MARK: - 2. Trending Feeds

    func loadTrendingFeeds() {
        guard let request = makeRequest(
            path: "/discover/trending",
            params: ["page": "1", "days": "7", "limit": "20"]
        ) else { return }

        guard !searchState.isTrendingLoading else { return }
        searchState.trendingErrorMessage = nil
        searchState.isTrendingLoading = true

        let generation = lifecycleGeneration
        Task {
            do {
                let json = try await performRequest(request)
                guard lifecycleGeneration == generation else { return }
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
                guard lifecycleGeneration == generation else { return }
                searchState.trendingErrorMessage = error.localizedDescription
                searchState.isTrendingLoading = false
            }
        }
    }

    // MARK: - 3. Popular Feeds

    func loadPopularFeeds(type: String, category: String?, subcategory: String?, offset: Int) {
        if offset > 0 && categoryTabState(for: type).isLoading { return }
        let token = UUID()
        categoryRequests[type] = token
        let includesStories = feedViewMode == .list
        var params: [String: String] = [
            "type": type,
            "offset": String(offset),
            "limit": "20"
        ]
        if includesStories {
            params["include_stories"] = "true"
        }
        if let category = category, !category.isEmpty {
            params["category"] = category
        }
        if let subcategory = subcategory, !subcategory.isEmpty {
            params["subcategory"] = subcategory
        }

        if let platform = categoryTabState(for: type).platformFilter { params["platform"] = platform }
        guard let request = makeRequest(path: "/discover/popular_feeds", params: params) else { return }

        updateCategoryTabState(type: type) { state in
            state.isLoading = true
            state.errorMessage = nil
            if offset == 0 {
                state.feeds = []
                state.hasLoadedStories = false
            }
        }

        Task {
            do {
                let json = try await performRequest(request)
                guard categoryRequests[type] == token else { return }
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
                        state.hasLoadedStories = includesStories
                    } else {
                        var seen = Set(state.feeds.map(\.id))
                        state.feeds.append(contentsOf: feeds.filter { seen.insert($0.id).inserted })
                    }
                    if !categories.isEmpty {
                        state.categories = categories
                    }
                    if !platformCounts.isEmpty {
                        state.platformCounts = platformCounts
                    }
                    state.offset = offset + feedsArray.count
                    state.hasMore = json["has_more"] as? Bool ?? (feedsArray.count >= 20)
                    state.isLoading = false
                    state.isCategoriesLoaded = true
                    if includesStories {
                        state.hasLoadedStories = true
                    }
                }
            } catch {
                guard categoryRequests[type] == token else { return }
                updateCategoryTabState(type: type) { $0.isLoading = false; $0.errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - 4. Search Feeds (YouTube, Reddit, Podcasts, Newsletters)

    func searchFeeds(type: String, query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = UUID()
        searchRequests[type] = token
        updateCategoryTabState(type: type) {
            $0.submittedQuery = query
            $0.hasSearched = !query.isEmpty
            $0.searchResults = []
            $0.errorMessage = nil
            $0.isSearching = !query.isEmpty
        }
        guard !query.isEmpty else { return }
        let isNewsletterURL = type == "newsletter" && (query.contains("://") || (!query.contains(" ") && query.contains(".")))
        let path: String
        var params = ["query": query]
        switch type {
        case "youtube": path = "/discover/youtube/search"
        case "reddit": path = "/discover/reddit/search"
        case "podcast": path = "/discover/podcast/search"
        default:
            path = isNewsletterURL ? "/discover/newsletter/convert" : "/discover/popular_feeds"
            params = isNewsletterURL ? ["url": query] : ["type": type, "query": query]
            if !isNewsletterURL, let platform = categoryTabState(for: type).platformFilter { params["platform"] = platform }
        }
        guard let request = makeRequest(path: path, params: params) else { return }
        if ["youtube", "reddit", "podcast"].contains(type) {
            var catalogParams = ["type": type, "query": query, "limit": "20"]
            if feedViewMode == .list { catalogParams["include_stories"] = "true" }
            guard let catalogRequest = makeRequest(path: "/discover/popular_feeds", params: catalogParams) else { return }
            searchCatalogAndSource(type: type, token: token, catalogRequest: catalogRequest, sourceRequest: request)
            return
        }
        Task {
            do {
                let json = try await performRequest(request)
                guard searchRequests[type] == token else { return }
                let entries: [[String: Any]]
                if isNewsletterURL {
                    var entry = json
                    entry["title"] = query
                    entries = [entry]
                } else {
                    entries = json["results"] as? [[String: Any]] ?? json["feeds"] as? [[String: Any]] ?? []
                }
                var seen = Set<String>()
                let feeds = entries.compactMap(Self.parsePopularFeedEntry).filter { seen.insert($0.id).inserted }
                updateCategoryTabState(type: type) { $0.searchResults = feeds; $0.isSearching = false }
            } catch {
                guard searchRequests[type] == token else { return }
                updateCategoryTabState(type: type) { $0.isSearching = false; $0.errorMessage = error.localizedDescription }
            }
        }
    }

    private func searchCatalogAndSource(type: String, token: UUID, catalogRequest: URLRequest, sourceRequest: URLRequest) {
        // DiscoverSitesViewModel.swift: publish either source immediately, keeping linked catalog feeds first.
        var results: [[DiscoverPopularFeed]] = [[], []]
        var errors: [String?] = [nil, nil]
        var remainingRequests = 2
        for (index, request) in [catalogRequest, sourceRequest].enumerated() {
            Task { @MainActor in
                do {
                    let json = try await performRequest(request)
                    guard searchRequests[type] == token else { return }
                    let entries = json["feeds"] as? [[String: Any]] ?? json["results"] as? [[String: Any]] ?? []
                    results[index] = entries.compactMap(Self.parsePopularFeedEntry)
                } catch {
                    guard searchRequests[type] == token else { return }
                    errors[index] = error.localizedDescription
                }
                remainingRequests -= 1
                var seen = Set<String>()
                let feeds = results.flatMap { $0 }.filter { seen.insert($0.feedAddress).inserted }
                updateCategoryTabState(type: type) { state in
                    state.searchResults = feeds
                    state.isSearching = remainingRequests > 0
                    state.errorMessage = remainingRequests == 0 && feeds.isEmpty ? errors.compactMap { $0 }.last : nil
                }
            }
        }
    }

    // MARK: - 5. Analyze Web Feed

    func analyzeWebFeed(url: String, hint: String = "") {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }

        stopPolling()
        pollingSuspended = false
        analysisStartedAt = Date()
        webFeedState.analyzedURL = trimmedUrl
        webFeedState.detectedFeedURL = nil
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
            body: ["url": trimmedUrl, "request_id": requestId, "story_hint": String(hint.prefix(200))]
        ) else {
            webFeedState.isAnalyzing = false
            webFeedState.errorMessage = "Invalid URL"
            return
        }

        Task {
            do {
                let json = try await performRequest(request)
                guard webFeedState.requestId == requestId else { return }
                if json["code"] as? Int == 2 {
                    webFeedState.isAnalyzing = false
                    webFeedState.progressMessage = "This URL is already an RSS feed."
                    webFeedState.detectedFeedURL = json["feed_address"] as? String ?? trimmedUrl
                    return
                }
                if !pollingSuspended { startPolling() }
            } catch {
                guard webFeedState.requestId == requestId else { return }
                webFeedState.isAnalyzing = false
                webFeedState.errorMessage = "Failed to start analysis: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 6. Poll Web Feed Status

    private func startPolling() {
        stopPolling()
        pollingSuspended = false
        pollWebFeedStatus()
        guard webFeedState.isAnalyzing else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollWebFeedStatus()
            }
        }
    }

    func stopPolling() {
        pollingGeneration = UUID()
        pollingSuspended = true
        pollingRequest = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func pollWebFeedStatus() {
        guard webFeedState.isAnalyzing else { stopPolling(); return }
        if let started = analysisStartedAt, Date().timeIntervalSince(started) >= 120 {
            stopPolling()
            webFeedState.isAnalyzing = false
            webFeedState.errorMessage = "Analysis timed out. Please try again."
            return
        }
        guard let requestId = webFeedState.requestId else {
            stopPolling()
            return
        }

        guard pollingRequest != requestId else { return }
        guard let request = makeRequest(
            path: "/webfeed/status",
            params: ["request_id": requestId]
        ) else { return }

        pollingRequest = requestId
        let generation = pollingGeneration
        Task {
            defer { if pollingRequest == requestId && pollingGeneration == generation { pollingRequest = nil } }
            do {
                let json = try await performRequest(request)
                guard webFeedState.requestId == requestId, webFeedState.isAnalyzing, pollingGeneration == generation else { return }
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
                    webFeedState.feedTitle = variantsData["page_title"] as? String ?? variantsData["feed_title"] as? String ?? json["page_title"] as? String ?? json["feed_title"] as? String ?? ""

                    if !webFeedState.variants.isEmpty {
                        webFeedState.selectedVariantIndex = 0
                    }

                    if webFeedState.variants.isEmpty { webFeedState.errorMessage = "No story patterns were found. Try a page that lists articles." }
                    webFeedState.progressMessage = ""

                case "error":
                    stopPolling()
                    webFeedState.isAnalyzing = false
                    webFeedState.errorMessage = json["error"] as? String ?? message ?? "Analysis failed"
                    webFeedState.progressMessage = ""

                default:
                    webFeedState.progressMessage = message ?? (eventType == "unknown" ? "Waiting for analysis to start..." : "Analyzing page...")
                }
            } catch {
                guard webFeedState.requestId == requestId, webFeedState.isAnalyzing, pollingGeneration == generation else { return }
                let failure = error as NSError
                if failure.domain == "DiscoverSites" {
                    stopPolling()
                    webFeedState.isAnalyzing = false
                    webFeedState.errorMessage = error.localizedDescription
                } else {
                    webFeedState.progressMessage = "Connection interrupted. Retrying..."
                }
            }
        }
    }

    // MARK: - 7. Subscribe Web Feed

    func subscribeWebFeed() {
        guard !webFeedState.isSubscribing, !isAdding, let variantIndex = webFeedState.selectedVariantIndex,
              variantIndex >= 0,
              variantIndex < webFeedState.variants.count else { return }

        let variant = webFeedState.variants[variantIndex]
        let feedURL = webFeedState.analyzedURL
        webFeedState.errorMessage = nil
        addedSuccess = false
        webFeedState.isSubscribing = true

        var bodyParams: [String: String] = [
            "url": feedURL,
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

        let generation = lifecycleGeneration
        Task {
            guard lifecycleGeneration == generation else { return }
            do {
                let json = try await performRequest(request)
                guard lifecycleGeneration == generation else { return }
                webFeedState.isSubscribing = false

                let code = json["code"] as? Int ?? 0
                if code <= 0 {
                    webFeedState.errorMessage = json["message"] as? String ?? "Subscription failed"
                } else {
                    addedFeedURLs.insert(feedURL)
                    addedFeedUrl = feedURL
                    addedSuccess = true
                }
            } catch {
                guard lifecycleGeneration == generation else { return }
                webFeedState.isSubscribing = false
                webFeedState.errorMessage = "Subscription failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 8. Google News Data

    func loadGoogleNewsData() {
        googleNewsState.topics = DiscoverGoogleNewsCatalog.topics
        googleNewsState.categories = DiscoverGoogleNewsCatalog.categories
        googleNewsState.isLoading = false
        googleNewsState.isDataLoaded = true
        googleNewsState.errorMessage = nil
    }

    func selectGoogleNewsTopic(_ topic: GoogleNewsTopic?) {
        googleNewsState.selectedTopic = topic
        googleNewsState.selectedCategory = nil
        googleNewsState.selectedSubcategory = nil
        googleNewsState.searchQuery = ""
        googleNewsState.errorMessage = nil
        addedSuccess = false
    }

    func selectGoogleNewsCategory(_ category: GoogleNewsCategory?) {
        googleNewsState.selectedCategory = category
        googleNewsState.selectedSubcategory = nil
        googleNewsState.searchQuery = category?.name ?? ""
        googleNewsState.errorMessage = nil
        addedSuccess = false
    }

    func selectGoogleNewsSubcategory(_ subcategory: String?) {
        googleNewsState.selectedSubcategory = subcategory
        googleNewsState.searchQuery = subcategory ?? googleNewsState.selectedCategory?.name ?? ""
        googleNewsState.errorMessage = nil
        addedSuccess = false
    }

    var canSubscribeGoogleNews: Bool {
        !googleNewsState.isSubscribing && !isAdding &&
        (!googleNewsState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         DiscoverGoogleNewsCatalog.topics.contains { $0.id == googleNewsState.selectedTopic?.id })
    }

    func subscribeSelectedGoogleNews() {
        subscribeGoogleNews(query: googleNewsState.searchQuery,
                            topic: googleNewsState.selectedTopic?.id,
                            language: googleNewsState.language)
    }

    // MARK: - 9. Subscribe Google News

    func subscribeGoogleNews(query: String?, topic: String?, language: String) {
        guard !googleNewsState.isSubscribing, !isAdding else { return }
        addedSuccess = false
        let folder = resolvedFolder
        var params: [String: String] = ["language": language]
        let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !query.isEmpty {
            params["query"] = query
        } else if let topic = topic, DiscoverGoogleNewsCatalog.topics.contains(where: { $0.id == topic }) {
            params["topic"] = topic
        } else {
            googleNewsState.errorMessage = "Choose a topic or enter a search query."
            return
        }

        guard let feedRequest = makeRequest(path: "/discover/google-news/feed", params: params) else { return }

        googleNewsState.isSubscribing = true
        googleNewsState.errorMessage = nil

        let generation = lifecycleGeneration
        Task {
            guard lifecycleGeneration == generation else { return }
            do {
                let json = try await performRequest(feedRequest)
                guard lifecycleGeneration == generation else { return }
                guard let feedUrl = json["feed_url"] as? String, !feedUrl.isEmpty else {
                    googleNewsState.isSubscribing = false
                    googleNewsState.errorMessage = json["message"] as? String ?? "No feed URL returned"
                    return
                }

                guard let addRequest = makeRequest(
                    path: "/reader/add_url",
                    method: "POST",
                    body: ["url": feedUrl, "folder": folder]
                ) else {
                    googleNewsState.isSubscribing = false
                    googleNewsState.errorMessage = "Failed to build request"
                    return
                }

                let addJson = try await performRequest(addRequest)
                guard lifecycleGeneration == generation else { return }
                googleNewsState.isSubscribing = false

                let code = addJson["code"] as? Int ?? 0
                if code <= 0 {
                    googleNewsState.errorMessage = addJson["message"] as? String ?? "Failed to subscribe"
                } else {
                    addedFeedURLs.insert(feedUrl)
                    addedFeedUrl = feedUrl
                    addedSuccess = true
                }
            } catch {
                guard lifecycleGeneration == generation else { return }
                googleNewsState.isSubscribing = false
                googleNewsState.errorMessage = "Failed to subscribe: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 10. Add Feed

    func addFeed(url feedUrl: String) {
        let trimmedUrl = feedUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty, !isAdding else { return }

        addedSuccess = false
        addErrorMessage = nil

        guard let request = makeRequest(
            path: "/reader/add_url",
            method: "POST",
            body: ["url": trimmedUrl, "folder": resolvedFolder]
        ) else {
            addErrorMessage = "Invalid URL"
            return
        }

        isAdding = true
        let generation = lifecycleGeneration
        Task {
            guard lifecycleGeneration == generation else { return }
            defer { if lifecycleGeneration == generation { isAdding = false } }
            do {
                let json = try await performRequest(request)
                guard lifecycleGeneration == generation else { return }
                let code = json["code"] as? Int ?? 0
                if code <= 0 {
                    addErrorMessage = json["message"] as? String ?? "Failed to add site"
                } else {
                    addedFeedURLs.insert(trimmedUrl)
                    addedFeedUrl = trimmedUrl
                    addedSuccess = true
                }
            } catch {
                guard lifecycleGeneration == generation else { return }
                addErrorMessage = "Failed to add site: \(error.localizedDescription)"
            }
        }
    }

    func resolvePreviewFeed(_ feed: DiscoverPopularFeed) async -> DiscoverPopularFeed? {
        if let id = Int(feed.id), id > 0 { return feed }
        guard !isPreparingPreview else { return nil }
        isPreparingPreview = true
        addErrorMessage = nil
        let generation = lifecycleGeneration
        defer { if lifecycleGeneration == generation { isPreparingPreview = false } }
        guard let request = makeRequest(path: "/discover/link_popular_feed", params: ["feed_url": feed.feedAddress]) else { return nil }
        do {
            let json = try await performRequest(request)
            guard lifecycleGeneration == generation else { return nil }
            guard let id = json["feed_id"] as? Int, id > 0 else { throw URLError(.badServerResponse) }
            return DiscoverPopularFeed(feedId: String(id), feedDict: feed.rawFeedDict)
        } catch {
            guard lifecycleGeneration == generation else { return nil }
            addErrorMessage = "Unable to preview this feed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Feed Parsing Helper

    static func parsePopularFeedEntry(_ entry: [String: Any]) -> DiscoverPopularFeed? {
        var feedDict = entry["feed"] as? [String: Any] ?? entry
        func firstString(_ keys: [String]) -> String? {
            for key in keys {
                if let value = feedDict[key] as? String, !value.isEmpty { return value }
                if let value = entry[key] as? String, !value.isEmpty { return value }
            }
            return nil
        }
        guard let address = firstString(["feed_address", "feed_url"]) else { return nil }
        feedDict["feed_address"] = address
        feedDict["feed_title"] = firstString(["feed_title", "title", "name"]) ?? address
        feedDict["feed_link"] = firstString(["feed_link", "link", "itunes_url"]) ?? address
        feedDict["favicon_url"] = firstString(["favicon_url", "thumbnail_url", "thumbnail", "icon", "artwork"])
        feedDict["num_subscribers"] = feedDict["num_subscribers"] as? Int ?? entry["subscriber_count"] as? Int ?? entry["subscribers"] as? Int ?? 0
        // DiscoverSitesViewModel.swift: source IDs and PopularFeed IDs are not NewsBlur Feed IDs.
        let linked = entry["feed"] as? [String: Any]
        let numericID = (linked?["id"] as? Int) ?? (entry["feed_id"] as? Int)
        let stringID = linked?["id"] as? String
        let feedId = numericID.flatMap { $0 > 0 ? String($0) : nil } ?? stringID ?? address
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
        categoryRequests = [:]
        searchRequests = [:]
        autocompleteRequest = UUID()
        lifecycleGeneration = UUID()
        analysisStartedAt = nil
        isAdding = false
        isPreparingPreview = false

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

        addedFeedURLs = []
        addedFeedUrl = nil
        addedSuccess = false
        addErrorMessage = nil
    }
}
