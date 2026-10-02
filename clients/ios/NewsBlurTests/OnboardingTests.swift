import XCTest
import MetalKit
@testable import NewsBlur

@MainActor final class Test_Onboarding: XCTestCase {
    func test_loginRetainsAnimatedMetalBackground() throws {
        let controller = OnboardingAccountViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.viewWillAppear(false)
        controller.view.layoutIfNeeded()
        func metalView(in view: UIView) -> MTKView? {
            if let metal = view as? MTKView { return metal }
            return view.subviews.lazy.compactMap { metalView(in: $0) }.first
        }
        let background = try XCTUnwrap(metalView(in: controller.view), "The login redesign must preserve the original animated background.")
        XCTAssertNotNil(background.device)
        XCTAssertNotNil(background.delegate)
        XCTAssertFalse(background.isPaused)
        controller.viewDidDisappear(false)
        XCTAssertTrue(background.isPaused, "The login animation must stop when the screen closes.")
    }

    func test_olderPartialFeedResponseCannotReplaceLatestRefresh() {
        let app = OnboardingRefreshAppDelegate()
        let feeds = OnboardingRefreshFeedsController()
        feeds.appDelegate = app
        feeds.fetchFeedList(false)
        feeds.fetchFeedList(false)
        XCTAssertEqual(app.responses.count, 2)
        app.responses[1](nil, ["marker": "complete"])
        app.responses[0](nil, ["marker": "partial"])
        XCTAssertEqual(feeds.appliedMarkers, ["complete"], "A slow partial response must not overwrite the final feed list.")
    }

    func test_failedFinalRefreshEndsLoadingBeforeShowingOfflineError() {
        let app = OnboardingRefreshAppDelegate()
        let feeds = OnboardingRefreshFeedsController()
        feeds.appDelegate = app
        OnboardingFeedLoading.shared.requestRefresh()
        feeds.fetchFeedList(false)
        app.failures[0](nil, URLError(.notConnectedToInternet))
        XCTAssertEqual(feeds.loadingWhenShowingError, [false], "The final error must be allowed to show Offline instead of being replaced by Loading.")
    }

    override func tearDown() {
        OnboardingFeedLoading.shared.reset()
        OnboardingAPI.session = .shared
        OnboardingURLProtocol.handler = nil
        super.tearDown()
    }

    private func network(_ handler: @escaping (URLRequest) throws -> (Int, [String: Any])) {
        OnboardingURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OnboardingURLProtocol.self]
        OnboardingAPI.session = URLSession(configuration: configuration)
    }

    func test_bundlesMixSourcesAndRetryOnlyFailedSubscriptions() async throws {
        var attempted: [String] = []
        var failYouTube = true
        network { request in
            if request.url?.path == "/reader/add_url" {
                let body = Self.body(request)
                attempted.append(body)
                if body.contains("youtube"), failYouTube { return (200, ["code": -1, "message": "Temporary failure"]) }
                return (200, ["code": 1])
            }
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let source = items.first { $0.name == "type" }!.value!
            XCTAssertEqual(items.first { $0.name == "include_stories" }?.value, "true")
            return (200, ["categories": ["Science"], "feeds": [["title": source, "feed_url": "https://example.com/\(source)", "feed_type": source,
                "thumbnail_url": "https://example.com/icon.png", "stories": [["story_hash": source + "-1", "story_title": "A real preview",
                    "image_urls": ["https://example.com/story.jpg"]]]]]])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        await bundles.load("Science")
        XCTAssertEqual(Set(bundles.feeds.map(\.source)), ["rss", "newsletter", "youtube", "reddit", "podcast"])
        XCTAssertEqual(bundles.selection.count, 5)
        XCTAssertEqual(bundles.feeds.first?.preview.stories.first?.title, "A real preview")
        XCTAssertEqual(bundles.feeds.first?.preview.stories.first?.imageUrls, ["https://example.com/story.jpg"])
        XCTAssertEqual(bundles.feeds.first?.preview.faviconUrl, "https://example.com/icon.png")
        await bundles.subscribe()
        XCTAssertEqual(bundles.added.count, 4)
        XCTAssertEqual(bundles.selection, ["https://example.com/youtube"])
        XCTAssertTrue(attempted.allSatisfy { $0.contains("new_folder=Science") && $0.removingPercentEncoding!.contains("folder_path=[]") })
        failYouTube = false
        await bundles.subscribe()
        XCTAssertEqual(attempted.count, 6)
        XCTAssertEqual(bundles.added.count, 5)
        XCTAssertTrue(bundles.selection.isEmpty)
    }

    func test_queueReturnsImmediatelyKeepsFolderAndRefreshesAfterCompletion() async throws {
        var attempted: [String] = []
        var refreshes = 0
        network { request in
            if request.url?.path == "/reader/add_url" {
                attempted.append(Self.body(request))
                return (200, ["code": 1])
            }
            let source = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "type" }!.value!
            return (200, ["feeds": [["title": source, "feed_url": "https://example.com/\(source)", "feed_type": source]]])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: { refreshes += 1 })
        await bundles.load("Science")
        let task = try XCTUnwrap(bundles.queueSubscriptions())
        XCTAssertEqual(bundles.queued.count, 5)
        XCTAssertFalse(bundles.busy, "Queued additions must not block navigation or new previews.")
        bundles.folder = "Another folder"
        bundles.prepareToRead()
        XCTAssertEqual(refreshes, 1, "Entering completion refreshes immediately while additions are pending.")
        OnboardingFeedLoading.shared.refreshDidFinish()
        XCTAssertTrue(OnboardingFeedLoading.shared.isLoading, "An early partial refresh must not clear progress while additions are pending.")
        await task.value
        XCTAssertTrue(bundles.queued.isEmpty)
        XCTAssertEqual(attempted.count, 5)
        XCTAssertTrue(attempted.allSatisfy { $0.contains("new_folder=Science") })
        XCTAssertEqual(refreshes, 2, "Finishing the queue refreshes the newly added feeds.")
        XCTAssertTrue(OnboardingFeedLoading.shared.isLoading, "The spinner must survive the final add response until the feed list is rendered.")
        OnboardingFeedLoading.shared.refreshDidFinish()
        XCTAssertFalse(OnboardingFeedLoading.shared.isLoading)
        bundles.prepareToRead()
        XCTAssertEqual(refreshes, 3, "Start Reading refreshes again.")
    }

    func test_failedAdditionsStillRefreshAndStopLoading() async {
        network { request in
            if request.url?.path == "/reader/add_url" { return (503, ["message": "Unavailable"]) }
            return (200, ["feeds": [["feed_url": "https://example.com/rss", "title": "Example"]]])
        }
        var refreshes = 0
        let bundles = OnboardingBundles(onSubscriptionsChanged: {
            refreshes += 1
            OnboardingFeedLoading.shared.refreshDidFinish()
        })
        await bundles.load("Science")
        await bundles.subscribe()
        XCTAssertEqual(refreshes, 1)
        XCTAssertFalse(OnboardingFeedLoading.shared.isLoading)
        XCTAssertEqual(bundles.failedBundles.count, 1)
    }

    func test_opmlUploadPreservesDocumentAndHandlesQueuedResponse() async throws {
        let xml = "<?xml version=\"1.0\"?><opml version=\"2.0\"><body><outline text=\"Science\"><outline xmlUrl=\"https://example.com/rss\"/></outline></body></opml>"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".opml")
        try Data(xml.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        network { request in
            XCTAssertEqual(request.url?.path, "/import/opml_upload")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = Self.body(request)
            XCTAssertTrue(body.contains("name=\"file\""))
            XCTAssertTrue(body.contains(xml))
            return (200, ["code": 2, "payload": ["delayed": true, "feed_count": 1]])
        }
        let count = try await OnboardingAPI.importOPML(url)
        XCTAssertEqual(count, 1)
    }

    func test_invalidOPMLNeverUploads() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xml")
        try Data("<html>Not an export</html>".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        network { _ in XCTFail("Invalid files must not be uploaded"); return (200, [:]) }
        do { _ = try await OnboardingAPI.importOPML(url); XCTFail("Expected rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("OPML")) }
    }

    func test_authenticationContinuationRetainsTicketButOtherErrorsThrow() async throws {
        network { _ in (400, ["code": -1, "link_required": true, "ticket": "replacement-ticket"]) }
        let result = try await OnboardingAPI.request("/api/social/complete", body: [:])
        XCTAssertEqual(result["ticket"] as? String, "replacement-ticket")
        network { _ in (503, ["code": -1, "message": "Unavailable"]) }
        do { _ = try await OnboardingAPI.request("/api/social/start", body: [:]); XCTFail("Expected server error") }
        catch { XCTAssertEqual(error.localizedDescription, "Unavailable") }
    }

    nonisolated private static func body(_ request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private final class OnboardingURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: Any]))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, json) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class OnboardingRefreshAppDelegate: NewsBlurAppDelegate {
    var responses: [(URLSessionDataTask?, Any?) -> Void] = []
    var failures: [(URLSessionDataTask?, Error?) -> Void] = []
    override func cancelOfflineQueue() {}
    override var url: String! { "https://onboarding-refresh.invalid" }
    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        responses.append(success)
        failures.append(failure)
    }
}

private final class OnboardingRefreshFeedsController: FeedsObjCViewController {
    var appliedMarkers: [String] = []
    var loadingWhenShowingError: [Bool] = []
    @objc(finishedWithError:statusCode:) func finishedWithError(_ error: NSError, statusCode: Int) {
        loadingWhenShowingError.append(OnboardingFeedLoading.shared.isLoading)
    }
    // OnboardingTests.swift observes the real fetchFeedList callback without unrelated feed rendering setup.
    @objc func finishLoadingFeedList(_ results: NSDictionary) {
        appliedMarkers.append(results["marker"] as! String)
    }
}
