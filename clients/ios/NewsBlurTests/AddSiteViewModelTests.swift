import XCTest

@testable import NewsBlur

@MainActor
final class AddSiteViewModelTests: XCTestCase {
    private final class MockAppEnvironment: AddSiteViewModelAppEnvironment {
        var url: String?
        var dictFoldersArray: Any?

        init(url: String?, folders: [String]) {
            self.url = url
            self.dictFoldersArray = folders
        }
    }

    private final class MockURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func test_foldersFiltersSystemFolders() {
        let environment = MockAppEnvironment(
            url: "https://www.newsblur.com",
            folders: ["everything", "saved_stories", "Tech", "Top \u{25B8} iOS"]
        )
        let viewModel = AddSiteViewModel(appEnvironment: environment)

        XCTAssertEqual(viewModel.folders, ["Tech", "Top \u{25B8} iOS"])
        XCTAssertEqual(viewModel.displayFolder, "— Top Level —")
    }

    func test_addSiteMarksSuccessAndBuildsExpectedRequest() async throws {
        let environment = MockAppEnvironment(url: "https://example.com", folders: [])
        let viewModel = AddSiteViewModel(
            appEnvironment: environment,
            session: makeSession()
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/reader/add_url")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try XCTUnwrap(Self.requestBody(for: request))
            let fields = Self.formFields(from: body)
            XCTAssertEqual(fields["folder"], "Tech")
            XCTAssertEqual(fields["url"], "https://example.com/feed")
            XCTAssertEqual(fields["new_folder"], "Swift")

            let response = try XCTUnwrap(
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = try JSONSerialization.data(withJSONObject: ["code": 1])
            return (response, data)
        }

        viewModel.searchText = "https://example.com/feed"
        viewModel.selectedFolder = "Tech"
        viewModel.showAddFolder = true
        viewModel.newFolderName = "Swift"

        viewModel.addSite()

        await waitUntil { viewModel.addedSuccess && !viewModel.isAdding }
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_addSiteSurfacesServerErrors() async {
        let environment = MockAppEnvironment(url: "https://example.com", folders: [])
        let viewModel = AddSiteViewModel(
            appEnvironment: environment,
            session: makeSession()
        )

        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = try JSONSerialization.data(withJSONObject: ["code": -1, "message": "Already subscribed"])
            return (response, data)
        }

        viewModel.searchText = "https://example.com/feed"
        viewModel.addSite()

        await waitUntil { viewModel.errorMessage == "Already subscribed" && !viewModel.isAdding }
        XCTAssertFalse(viewModel.addedSuccess)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func requestBody(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)
            guard readCount > 0 else { break }
            data.append(buffer, count: readCount)
        }

        return data.isEmpty ? nil : data
    }

    private static func formFields(from body: Data) -> [String: String] {
        let bodyString = String(decoding: body, as: UTF8.self)
        return bodyString
            .split(separator: "&")
            .reduce(into: [:]) { result, pair in
                let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard let key = components.first else { return }
                let value = components.count > 1 ? components[1] : ""
                let decodedValue = value.removingPercentEncoding ?? value
                result[key] = decodedValue
            }
    }

    private func waitUntil(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition")
    }
}

@MainActor
final class DiscoverSitesViewModelTests: XCTestCase {
    private final class Environment: AddSiteViewModelAppEnvironment {
        var url: String? = "https://example.com"
        var dictFoldersArray: Any? = ["Tech", "daily_briefing", "trending:good_reads", "everything"]
    }

    private final class ResponseProtocol: URLProtocol {
        static var handler: ((URLRequest) throws -> (Int, [String: Any]))?
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            do {
                let (status, json) = try Self.handler!(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        override func stopLoading() {}
    }

    private func model() -> DiscoverSitesViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ResponseProtocol.self]
        return DiscoverSitesViewModel(appEnvironment: Environment(), session: URLSession(configuration: configuration))
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for discovery request")
    }

    private static func body(_ request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(decoding: data, as: UTF8.self)
    }

    func test_sourceSearchReadsResultsAndKeepsLiteralPlus() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/popular_feeds" { return (200, ["code": 1, "feeds": []]) }
            XCTAssertEqual(request.url?.path, "/discover/youtube/search")
            XCTAssertTrue(request.url!.absoluteString.contains("C%2B%2B"))
            return (200, ["code": 1, "results": [["title": "C++ videos", "feed_url": "https://example.com/cpp.xml", "thumbnail": "https://example.com/icon.png"]]])
        }
        viewModel.searchFeeds(type: "youtube", query: "C++")
        await waitUntil { !viewModel.youtubeState.isSearching }
        XCTAssertEqual(viewModel.youtubeState.searchResults.first?.feedTitle, "C++ videos")
        XCTAssertNil(viewModel.youtubeState.errorMessage)
    }

    func test_addFeedFormPreservesAmpersandsPlusAndFolder() async {
        let viewModel = model()
        viewModel.selectedFolder = "Work ▸ Research & Development"
        ResponseProtocol.handler = { request in
            let body = Self.body(request)
            XCTAssertTrue(body.contains("%26"))
            XCTAssertTrue(body.contains("%2B"))
            let pairs = body.split(separator: "&")
            XCTAssertEqual(pairs.count, 2)
            XCTAssertTrue(pairs.contains { $0.removingPercentEncoding == "url=https://example.com/feed?q=C++&lang=en" })
            XCTAssertTrue(pairs.contains { $0.removingPercentEncoding == "folder=Research & Development" })
            return (200, ["code": 1])
        }
        viewModel.addFeed(url: "https://example.com/feed?q=C++&lang=en")
        XCTAssertTrue(viewModel.isAdding)
        await waitUntil { !viewModel.isAdding }
        XCTAssertTrue(viewModel.addedSuccess)
        XCTAssertEqual(viewModel.folders, ["Tech"])
    }

    func test_sourceErrorsAreNotSuccessfulEmptyResults() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in (200, ["code": -1, "message": "Reddit API request failed.", "results": []]) }
        viewModel.searchFeeds(type: "reddit", query: "space")
        await waitUntil { !viewModel.redditState.isSearching }
        XCTAssertEqual(viewModel.redditState.errorMessage, "Reddit API request failed.")
        viewModel.searchFeeds(type: "reddit", query: "")
        XCTAssertFalse(viewModel.redditState.hasSearched)
        XCTAssertNil(viewModel.redditState.errorMessage)
    }

    func test_HTTPFailureDoesNotMarkSubscriptionSuccessful() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in (503, ["message": "Temporarily unavailable"]) }
        viewModel.addFeed(url: "https://example.com/feed")
        await waitUntil { !viewModel.isAdding }
        XCTAssertFalse(viewModel.addedSuccess)
        XCTAssertTrue(viewModel.addErrorMessage?.contains("Temporarily unavailable") == true)
    }

    func test_popularPaginationUsesServerHasMoreAndDeduplicates() async {
        let viewModel = model()
        viewModel.newslettersState.platformFilter = "substack"
        ResponseProtocol.handler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("platform=substack"))
            return (200, ["code": 1, "has_more": false, "feeds": [["title": "Newsletter", "feed_url": "https://example.com/feed"]]])
        }
        viewModel.loadPopularFeeds(type: "newsletter", category: nil, subcategory: nil, offset: 0)
        await waitUntil { !viewModel.newslettersState.isLoading }
        viewModel.loadPopularFeeds(type: "newsletter", category: nil, subcategory: nil, offset: 1)
        await waitUntil { !viewModel.newslettersState.isLoading }
        XCTAssertEqual(viewModel.newslettersState.feeds.count, 1)
        XCTAssertEqual(viewModel.newslettersState.offset, 2)
        XCTAssertFalse(viewModel.newslettersState.hasMore)
    }

    func test_newsletterURLConversionProducesSubscribableCard() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/discover/newsletter/convert")
            return (200, ["code": 1, "feed_url": "https://example.substack.com/feed"])
        }
        viewModel.searchFeeds(type: "newsletter", query: "https://example.substack.com")
        await waitUntil { !viewModel.newslettersState.isSearching }
        XCTAssertEqual(viewModel.newslettersState.searchResults.first?.feedAddress, "https://example.substack.com/feed")
    }

    func test_webFeedRejectedAnalysisStopsAndSurfacesError() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in (200, ["code": -1, "message": "Please enter a valid URL"] ) }
        viewModel.analyzeWebFeed(url: "invalid")
        await waitUntil { !viewModel.webFeedState.isAnalyzing }
        XCTAssertTrue(viewModel.webFeedState.errorMessage?.contains("Please enter a valid URL") == true)
        XCTAssertTrue(viewModel.webFeedState.variants.isEmpty)
    }

    func test_webFeedRSSDetectionRequiresExplicitSubscription() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/webfeed/analyze")
            return (200, ["code": 2, "feed_address": "https://example.com/rss"])
        }
        viewModel.analyzeWebFeed(url: "https://example.com/rss")
        await waitUntil { !viewModel.webFeedState.isAnalyzing }
        XCTAssertEqual(viewModel.webFeedState.detectedFeedURL, "https://example.com/rss")
        XCTAssertFalse(viewModel.addedSuccess)
    }

    func test_previewResolvesSourceURLToNumericFeedID() async throws {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/discover/link_popular_feed")
            XCTAssertTrue(request.url!.absoluteString.contains("feed_url="))
            return (200, ["code": 1, "feed_id": 123])
        }
        let feed = try XCTUnwrap(DiscoverSitesViewModel.parsePopularFeedEntry(["id": "channel-id", "title": "Channel", "feed_url": "https://example.com/rss"]))
        let resolved = await viewModel.resolvePreviewFeed(feed)
        XCTAssertEqual(resolved?.id, "123")
        XCTAssertEqual(resolved?.rawFeedDict["id"] as? Int, 123)
        XCTAssertEqual(resolved?.feedTitle, "Channel")
        XCTAssertFalse(viewModel.isPreparingPreview)
    }

    func test_clearingQueryDiscardsAlreadyStartedSearch() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in
            (200, ["code": 1, "results": [["title": "Old result", "feed_url": "https://example.com/old"]]])
        }
        viewModel.searchFeeds(type: "youtube", query: "old")
        viewModel.searchFeeds(type: "youtube", query: "")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.youtubeState.searchResults.isEmpty)
        XCTAssertFalse(viewModel.youtubeState.isSearching)
        XCTAssertFalse(viewModel.youtubeState.hasSearched)
    }

    func test_webFeedSubscriptionUsesAnalyzedURLAfterTextIsEdited() async {
        let viewModel = model()
        viewModel.webFeedState.analyzedURL = "https://example.com/analyzed"
        viewModel.webFeedState.url = "https://example.com/edited"
        viewModel.webFeedState.variants = [WebFeedVariant(index: 0, dict: ["title_xpath": "//h2"])]
        viewModel.webFeedState.selectedVariantIndex = 0
        ResponseProtocol.handler = { request in
            let pairs = Self.body(request).split(separator: "&")
            XCTAssertTrue(pairs.contains { $0.removingPercentEncoding == "url=https://example.com/analyzed" })
            return (200, ["code": 1])
        }
        viewModel.subscribeWebFeed()
        await waitUntil { !viewModel.webFeedState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
        XCTAssertEqual(viewModel.addedFeedUrl, "https://example.com/analyzed")
        XCTAssertTrue(viewModel.addedFeedURLs.contains("https://example.com/analyzed"))
    }

    func test_webFeedPollingResumesWhenReturningToTab() async {
        let viewModel = model()
        viewModel.webFeedState.isAnalyzing = true
        viewModel.webFeedState.requestId = UUID().uuidString
        ResponseProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/webfeed/status")
            return (200, ["code": 1, "type": "complete", "variants_data": ["variants": [["label": "Articles", "title_xpath": "//h2"]]]])
        }
        viewModel.stopPolling()
        viewModel.onTabSelected(.webFeed)
        await waitUntil { !viewModel.webFeedState.isAnalyzing }
        XCTAssertEqual(viewModel.webFeedState.variants.first?.label, "Articles")
        XCTAssertNil(viewModel.webFeedState.errorMessage)
        viewModel.stopPolling()
    }

    func test_webFeedRefinementSendsHint() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            XCTAssertTrue(Self.body(request).split(separator: "&").contains {
                $0.removingPercentEncoding == "story_hint=Only articles & announcements"
            })
            return (200, ["code": -1, "message": "No matching articles"])
        }
        viewModel.analyzeWebFeed(url: "https://example.com", hint: "Only articles & announcements")
        await waitUntil { !viewModel.webFeedState.isAnalyzing }
        XCTAssertTrue(viewModel.webFeedState.errorMessage?.contains("No matching articles") == true)
    }

    func test_googleNewsCatalogWorksWithoutNetwork() {
        let viewModel = model()
        ResponseProtocol.handler = { _ in
            XCTFail("Bundled Google News catalog should not require a server endpoint")
            return (404, [:])
        }
        viewModel.loadGoogleNewsData()
        XCTAssertEqual(viewModel.googleNewsState.topics.count, 8)
        XCTAssertEqual(viewModel.googleNewsState.topics.first?.id, "WORLD")
        XCTAssertTrue(viewModel.googleNewsState.categories.contains { $0.name == "Technology" && $0.subcategories.contains("Artificial Intelligence") })
        XCTAssertTrue(viewModel.googleNewsState.isDataLoaded)
    }

    func test_webFeedAnalysisContractPreservesPreviewAndSubscriptionXPaths() async {
        let viewModel = model()
        viewModel.webFeedState.isAnalyzing = true
        viewModel.webFeedState.requestId = UUID().uuidString
        viewModel.webFeedState.analyzedURL = "https://example.com/articles"
        let variant: [String: Any] = [
            "label": "Articles", "story_container": "//article", "title": ".//h2/text()",
            "link": ".//a/@href", "content": ".//p/text()", "image": ".//img/@src",
            "author": ".//span[@class='author']/text()", "date": ".//time/@datetime",
            "preview_stories": [["title": "First article", "link": "https://example.com/articles/first",
                                 "content": "Article summary", "image": "https://example.com/first.jpg"]]
        ]
        ResponseProtocol.handler = { request in
            if request.url?.path == "/webfeed/status" {
                return (200, ["code": 1, "type": "complete", "variants_data": [
                    "variants": [variant], "page_title": "Example articles", "html_hash": "hash"
                ]])
            }
            XCTAssertEqual(request.url?.path, "/webfeed/subscribe")
            let pairs = Self.body(request).split(separator: "&").compactMap { $0.removingPercentEncoding }
            XCTAssertTrue(pairs.contains("story_container_xpath=//article"))
            XCTAssertTrue(pairs.contains("title_xpath=.//h2/text()"))
            XCTAssertTrue(pairs.contains("link_xpath=.//a/@href"))
            XCTAssertTrue(pairs.contains("feed_title=Example articles"))
            return (200, ["code": 1])
        }
        viewModel.onTabSelected(.webFeed)
        await waitUntil { !viewModel.webFeedState.isAnalyzing }
        XCTAssertEqual(viewModel.webFeedState.feedTitle, "Example articles")
        XCTAssertEqual(viewModel.webFeedState.variants.first?.stories.first?.title, "First article")
        XCTAssertEqual(viewModel.webFeedState.variants.first?.stories.first?.imageUrl, "https://example.com/first.jpg")
        viewModel.subscribeWebFeed()
        await waitUntil { !viewModel.webFeedState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
        viewModel.stopPolling()
    }

    func test_addedFeedURLsRecordConfirmedSubscriptionsAndReset() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in (200, ["code": 1]) }
        viewModel.addFeed(url: "https://example.com/first")
        await waitUntil { !viewModel.isAdding }
        XCTAssertEqual(viewModel.addedFeedURLs, ["https://example.com/first"])
        viewModel.addFeed(url: "https://example.com/second")
        await waitUntil { !viewModel.isAdding }
        XCTAssertEqual(viewModel.addedFeedURLs, ["https://example.com/first", "https://example.com/second"])
        viewModel.reset()
        XCTAssertTrue(viewModel.addedFeedURLs.isEmpty)
    }

    func test_unconfirmedSubscriptionDoesNotMarkFeedAdded() async {
        let viewModel = model()
        ResponseProtocol.handler = { _ in (200, ["code": 0]) }
        viewModel.addFeed(url: "https://example.com/feed")
        await waitUntil { !viewModel.isAdding }
        XCTAssertFalse(viewModel.addedSuccess)
        XCTAssertTrue(viewModel.addedFeedURLs.isEmpty)
        XCTAssertNotNil(viewModel.addErrorMessage)
    }

    func test_googleNewsSubscriptionRecordsResolvedFeedURL() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/google-news/feed" {
                return (200, ["code": 1, "feed_url": "https://news.google.com/rss/search?q=space"])
            }
            XCTAssertEqual(request.url?.path, "/reader/add_url")
            return (200, ["code": 1])
        }
        viewModel.subscribeGoogleNews(query: "space", topic: nil, language: "en")
        await waitUntil { !viewModel.googleNewsState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
        XCTAssertTrue(viewModel.addedFeedURLs.contains("https://news.google.com/rss/search?q=space"))
    }

    func test_googleNewsCategoriesAndSubcategoriesBecomeQueries() async {
        let viewModel = model()
        let category = GoogleNewsCategory(id: "Technology", name: "Technology", subcategories: ["Artificial Intelligence"])
        viewModel.selectGoogleNewsTopic(GoogleNewsTopic(id: "SCIENCE", name: "Science"))
        viewModel.selectGoogleNewsCategory(category)
        XCTAssertEqual(viewModel.googleNewsState.searchQuery, "Technology")
        viewModel.selectGoogleNewsSubcategory("Artificial Intelligence")
        XCTAssertEqual(viewModel.googleNewsState.searchQuery, "Artificial Intelligence")
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/google-news/feed" {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(items.first { $0.name == "query" }?.value, "Artificial Intelligence")
                XCTAssertNil(items.first { $0.name == "topic" })
                return (200, ["code": 1, "feed_url": "https://news.google.com/rss/search?q=AI"])
            }
            return (200, ["code": 1])
        }
        viewModel.subscribeSelectedGoogleNews()
        await waitUntil { !viewModel.googleNewsState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
        viewModel.selectGoogleNewsSubcategory(nil)
        XCTAssertEqual(viewModel.googleNewsState.searchQuery, "Technology")
        viewModel.selectGoogleNewsCategory(nil)
        XCTAssertEqual(viewModel.googleNewsState.searchQuery, "")
    }

    func test_googleNewsCustomQueryTakesPrecedenceOverOfficialTopic() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/google-news/feed" {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(items.first { $0.name == "query" }?.value, "space exploration")
                XCTAssertNil(items.first { $0.name == "topic" })
                return (200, ["code": 1, "feed_url": "https://news.google.com/rss/search?q=space"])
            }
            return (200, ["code": 1])
        }
        viewModel.subscribeGoogleNews(query: "  space exploration  ", topic: "SCIENCE", language: "en")
        await waitUntil { !viewModel.googleNewsState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
    }

    func test_googleNewsOfficialTopicUsesTopicParameterWithoutQuery() async {
        let viewModel = model()
        viewModel.googleNewsState.searchQuery = "Previous query"
        viewModel.selectGoogleNewsTopic(GoogleNewsTopic(id: "WORLD", name: "World"))
        XCTAssertEqual(viewModel.googleNewsState.searchQuery, "")
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/google-news/feed" {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(items.first { $0.name == "topic" }?.value, "WORLD")
                XCTAssertNil(items.first { $0.name == "query" })
                return (200, ["code": 1, "feed_url": "https://news.google.com/rss/topics/world"])
            }
            return (200, ["code": 1])
        }
        viewModel.subscribeSelectedGoogleNews()
        await waitUntil { !viewModel.googleNewsState.isSubscribing }
        XCTAssertTrue(viewModel.addedSuccess)
    }

    func test_redditSearchKeepsCatalogResultsWhenRedditAPIUnavailable() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/popular_feeds" {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(items.first { $0.name == "type" }?.value, "reddit")
                XCTAssertEqual(items.first { $0.name == "query" }?.value, "science")
                return (200, ["code": 1, "feeds": [["title": "Science", "feed_url": "https://reddit.com/r/science/.rss", "feed_id": 123]]])
            }
            return (200, ["code": -1, "message": "Reddit API request failed.", "results": []])
        }
        viewModel.searchFeeds(type: "reddit", query: "science")
        await waitUntil { !viewModel.redditState.isSearching }
        XCTAssertEqual(viewModel.redditState.searchResults.map(\.feedTitle), ["Science"])
        XCTAssertNil(viewModel.redditState.errorMessage)
    }

    func test_sourceSearchCombinesCatalogAndUpstreamAndDeduplicatesURLs() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/popular_feeds" {
                return (200, ["code": 1, "feeds": [["title": "Linked podcast", "feed_url": "https://example.com/shared", "feed_id": 123]]])
            }
            return (200, ["code": 1, "results": [
                ["name": "Unlinked duplicate", "feed_url": "https://example.com/shared"],
                ["name": "New podcast", "feed_url": "https://example.com/new"]
            ]])
        }
        viewModel.searchFeeds(type: "podcast", query: "science")
        await waitUntil { !viewModel.podcastsState.isSearching }
        XCTAssertEqual(viewModel.podcastsState.searchResults.map(\.feedTitle), ["Linked podcast", "New podcast"])
        XCTAssertEqual(viewModel.podcastsState.searchResults.first?.id, "123")
        XCTAssertNil(viewModel.podcastsState.errorMessage)
    }

    func test_sourceSearchKeepsUpstreamResultsWhenCatalogUnavailable() async {
        let viewModel = model()
        ResponseProtocol.handler = { request in
            if request.url?.path == "/discover/popular_feeds" { return (503, ["message": "Catalog unavailable"]) }
            return (200, ["code": 1, "results": [["title": "Channel", "feed_url": "https://example.com/channel"]]])
        }
        viewModel.searchFeeds(type: "youtube", query: "science")
        await waitUntil { !viewModel.youtubeState.isSearching }
        XCTAssertEqual(viewModel.youtubeState.searchResults.first?.feedTitle, "Channel")
        XCTAssertNil(viewModel.youtubeState.errorMessage)
    }

    func test_sourceSearchCardsPreserveAPIFields() throws {
        let fixtures: [[String: Any]] = [
            ["title": "NASA", "thumbnail": "https://example.com/youtube.png", "feed_url": "https://youtube.com/feed", "link": "https://youtube.com/nasa"],
            ["title": "Space", "icon": "https://example.com/reddit.png", "feed_url": "https://reddit.com/r/space/.rss", "subscribers": 42],
            ["name": "Science Friday", "artwork": "https://example.com/podcast.png", "feed_url": "https://example.com/podcast.xml"]
        ]
        for entry in fixtures {
            let feed = try XCTUnwrap(DiscoverSitesViewModel.parsePopularFeedEntry(entry))
            XCTAssertFalse(feed.feedTitle.isEmpty)
            XCTAssertFalse(feed.id.isEmpty)
            XCTAssertEqual(feed.feedAddress, entry["feed_url"] as? String)
            XCTAssertNotNil(feed.faviconUrl)
        }
        XCTAssertEqual(DiscoverSitesViewModel.parsePopularFeedEntry(fixtures[1])?.numSubscribers, 42)
        XCTAssertNil(DiscoverSitesViewModel.parsePopularFeedEntry(["title": "No subscribable URL"]))
    }
}
