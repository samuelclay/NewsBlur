// DescribeSearchTests.swift: parsing of the /discover/describe/* payloads (apps/describe/models.py to_payload and
// usage.py snapshot) and the Describe tab's start, poll and reconcile cycle in DiscoverSitesViewModel.swift.
import XCTest

@testable import NewsBlur

final class Test_DescribeSearchParsing: XCTestCase {
    static func feedDict(id: Int, title: String, subscribers: Int) -> [String: Any] {
        [
            "id": id, "feed_title": title, "feed_address": "https://\(title.lowercased()).example/feed",
            "feed_link": "https://\(title.lowercased()).example", "num_subscribers": subscribers,
            "average_stories_per_month": 60, "last_story_date": "2026-11-03T18:00:00", "favicon_color": "ffffff"
        ]
    }

    static func judgedRow(feedId: Int = 42, score: Int = 9) -> [String: Any] {
        [
            "feed_id": feedId, "feed_title": "MacStories", "feed_address": "https://macstories.example/feed",
            "feed_link": "https://macstories.example", "source": "index", "matched_query": "iOS app reviews",
            "similarity": 0.8123, "score": score, "reason": "Long-form iOS app reviews with screenshots.", "judged": true,
            "stories": [
                ["story_title": "Review: Things 4", "story_permalink": "https://macstories.example/things-4",
                 "story_date": "2026-11-03T18:00:00"],
                ["story_title": "", "story_permalink": "https://macstories.example/empty", "story_date": NSNull()],
            ],
            "feed": feedDict(id: feedId, title: "MacStories", subscribers: 1240),
        ]
    }

    static func pendingRow(feedId: Int = 77) -> [String: Any] {
        [
            "feed_id": feedId, "feed_title": "AppAdvice", "feed_address": "https://appadvice.example/feed",
            "feed_link": "https://appadvice.example", "source": "web", "matched_query": "", "similarity": NSNull(),
            "score": NSNull(), "reason": NSNull(), "judged": false, "stories": [],
            "feed": feedDict(id: feedId, title: "AppAdvice", subscribers: 3),
        ]
    }

    static func payload(status: String = "running", phase: String = "judging", results: [[String: Any]]) -> [String: Any] {
        [
            "id": "6720f0c1c3b2a4d5e6f70001", "prompt": "reviews of iOS App Store apps with lots of screenshots",
            "status": status, "phase": phase, "phase_message": status == "complete" ? "" : "Judging 12 feeds…",
            "created_date": "2026-11-04T09:15:00.123456", "completed_date": NSNull(), "result_count": results.count,
            "request_id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301", "sub_queries": ["iOS app reviews", "App Store screenshots"],
            "error": NSNull(), "stats": ["note": "Searched the web twice."], "results": results,
        ]
    }

    func test_payloadParsesSummaryResultsAndStories() throws {
        let search = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow(), Self.pendingRow()])))

        XCTAssertEqual(search.id, "6720f0c1c3b2a4d5e6f70001")
        XCTAssertEqual(search.prompt, "reviews of iOS App Store apps with lots of screenshots")
        XCTAssertEqual(search.status, "running")
        XCTAssertEqual(search.phase, "judging")
        XCTAssertTrue(search.isRunning)
        XCTAssertFalse(search.isFinished)
        XCTAssertNotNil(search.summary.createdDate)
        XCTAssertNil(search.summary.completedDate)
        XCTAssertEqual(search.summary.resultCount, 2)
        XCTAssertEqual(search.subQueries, ["iOS app reviews", "App Store screenshots"])
        XCTAssertEqual(search.statsNote, "Searched the web twice.")
        XCTAssertEqual(search.statusMessage, "Judging 12 feeds…")
        XCTAssertEqual(search.results.map(\.feedId), [42, 77])

        let judged = search.results[0]
        XCTAssertEqual(judged.feed.id, "42")
        XCTAssertEqual(judged.feed.rawFeedDict["id"] as? Int, 42)
        XCTAssertEqual(judged.feed.feedTitle, "MacStories")
        XCTAssertEqual(judged.feed.numSubscribers, 1240)
        XCTAssertEqual(judged.feed.freshness()?.status, .active)
        XCTAssertEqual(judged.score, 9)
        XCTAssertEqual(judged.similarity ?? 0, 0.8123, accuracy: 0.0001)
        XCTAssertTrue(judged.judged)
        XCTAssertEqual(judged.scoreTone, .high)
        XCTAssertEqual(judged.scoreLabel, "9/10")
        XCTAssertFalse(judged.isFromWeb)
        XCTAssertEqual(judged.reasonLabel, "Long-form iOS app reviews with screenshots.")
        XCTAssertEqual(judged.stories.count, 1, "Stories without a title are dropped")
        XCTAssertEqual(judged.stories.first?.title, "Review: Things 4")
        XCTAssertNotNil(judged.stories.first?.date)

        let pending = search.results[1]
        XCTAssertEqual(pending.scoreTone, .pending)
        XCTAssertEqual(pending.scoreLabel, NBLocalization.text("Judging…"))
        XCTAssertTrue(pending.isFromWeb)
        XCTAssertNil(pending.score)
        XCTAssertNil(pending.reason)
        XCTAssertEqual(pending.reasonLabel, NBLocalization.text("Waiting for a verdict…"))
        XCTAssertTrue(pending.stories.isEmpty)
    }

    func test_resultsWithoutHydratedFeedsAndDuplicatesAreHandled() throws {
        var bare = Self.pendingRow(feedId: 5)
        bare["feed"] = nil
        let search = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [bare, Self.pendingRow(feedId: 5), ["feed_id": 0]])))

        XCTAssertEqual(search.results.map(\.feedId), [5], "One card per feed, and rows without a feed id are skipped")
        XCTAssertEqual(search.results.first?.feed.feedTitle, "AppAdvice")
        XCTAssertEqual(search.results.first?.feed.feedAddress, "https://appadvice.example/feed")
    }

    // DescribeSearchTests.swift: a feed found on the web is not saved until someone subscribes, so its row carries a
    // negative key in feed_id and a feed dictionary without an id (make_result_row in apps/describe/models.py).
    static func unsavedWebRow(rowKey: Int = -1, title: String = "Pixel Envy") -> [String: Any] {
        let address = "https://\(title.lowercased().replacingOccurrences(of: " ", with: "")).example/feed.xml"
        let link = "https://\(title.lowercased().replacingOccurrences(of: " ", with: "")).example"
        return [
            "feed_id": rowKey, "feed_title": title, "feed_address": address, "feed_link": link, "source": "web",
            "matched_query": "", "similarity": NSNull(), "score": NSNull(), "reason": NSNull(), "judged": false,
            "stories": [["story_title": "A week with the new iPad", "story_permalink": "\(link)/ipad", "story_date": NSNull()]],
            "feed": ["feed_title": title, "feed_address": address, "feed_link": link, "num_subscribers": 0,
                     "tagline": "Design and technology commentary."] as [String: Any],
        ]
    }

    func test_unsavedWebRowParsesAndIsKeyedByItsAddress() throws {
        let result = try XCTUnwrap(DescribeResult(dict: Self.unsavedWebRow()), "A negative row key is not a missing feed")

        XCTAssertEqual(result.feedId, -1, "The row keeps the server's key for this search")
        XCTAssertEqual(result.id, -1)
        XCTAssertTrue(result.isFromWeb)
        XCTAssertEqual(result.feed.feedTitle, "Pixel Envy")
        XCTAssertEqual(result.feed.feedAddress, "https://pixelenvy.example/feed.xml")
        XCTAssertEqual(result.feed.feedLink, "https://pixelenvy.example")
        XCTAssertEqual(result.feed.numSubscribers, 0)
        XCTAssertEqual(result.stories.map(\.title), ["A week with the new iPad"])
        XCTAssertEqual(result.feed.id, "https://pixelenvy.example/feed.xml", "An unsaved feed is keyed by its address")
        XCTAssertNil(Int(result.feed.id), "The row key must never pass for a NewsBlur feed id")
        XCTAssertEqual(result.feed.rawFeedDict["id"] as? String, "https://pixelenvy.example/feed.xml")
        XCTAssertNil(result.feed.rawFeedDict["id"] as? Int)
    }

    func test_unsavedWebRowUsesTheRealFeedIdOnceTheFeedExists() throws {
        var row = Self.unsavedWebRow(rowKey: -3)
        var feed = try XCTUnwrap(row["feed"] as? [String: Any])
        feed["id"] = 9001
        row["feed"] = feed
        let result = try XCTUnwrap(DescribeResult(dict: row))

        XCTAssertEqual(result.feedId, -3, "The row key stays negative for the life of the search")
        XCTAssertEqual(result.feed.id, "9001")
        XCTAssertEqual(result.feed.rawFeedDict["id"] as? Int, 9001)
        XCTAssertEqual(result.feed.feedAddress, "https://pixelenvy.example/feed.xml")
    }

    func test_rowsWithoutAKeyOrAnyWayToReachTheFeedAreRejected() throws {
        XCTAssertNil(DescribeResult(dict: ["feed_id": 0, "feed_address": "https://zero.example/feed"]))
        XCTAssertNil(DescribeResult(dict: ["feed_address": "https://missing.example/feed", "feed": ["id": 12]]))
        XCTAssertNil(DescribeResult(dict: ["feed_id": NSNull(), "feed_address": "https://null.example/feed"]))
        XCTAssertNil(DescribeResult(dict: ["feed_id": -4, "feed_title": "No address", "feed": ["feed_title": "No address"]]),
                     "An unsaved feed without an address can be neither previewed nor subscribed to")

        var bare = Self.unsavedWebRow(rowKey: -5)
        bare["feed"] = nil
        let result = try XCTUnwrap(DescribeResult(dict: bare), "The row's own address is enough")
        XCTAssertEqual(result.feed.id, "https://pixelenvy.example/feed.xml")
    }

    func test_negativeRowKeysKeepOrderIdentityVerdictsAndRemovals() throws {
        let first = Self.unsavedWebRow(rowKey: -1, title: "Pixel Envy")
        let second = Self.unsavedWebRow(rowKey: -2, title: "Six Colors")
        let running = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [first, Self.judgedRow(), second, first])))

        XCTAssertEqual(running.results.map(\.feedId), [-1, 42, -2], "Server order is kept, with one card per row key")
        XCTAssertEqual(running.results.map(\.feed.id),
                       ["https://pixelenvy.example/feed.xml", "42", "https://sixcolors.example/feed.xml"])
        XCTAssertEqual(running.resultsSignature, "-1:-,42:9,-2:-")

        var verdict = second
        verdict["judged"] = true
        verdict["score"] = 8
        verdict["reason"] = "Daily Apple coverage with hands-on reviews."
        let judged = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [first, Self.judgedRow(), verdict])))
        XCTAssertTrue(judged.differs(from: running), "A verdict on a negative key is a change")
        XCTAssertEqual(judged.results.map(\.feedId), [-1, 42, -2], "The verdict lands on the same card")
        XCTAssertEqual(judged.results[2].scoreTone, .high)
        XCTAssertEqual(judged.resultsSignature, "-1:-,42:9,-2:8")

        let pruned = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow(), verdict])))
        XCTAssertTrue(pruned.differs(from: judged))
        XCTAssertEqual(pruned.results.map(\.feedId), [42, -2], "Removing a negative key drops only that card")
    }

    func test_signatureTracksVerdictsPhasesAndPrunedFeeds() throws {
        let running = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow(), Self.pendingRow()])))
        let unchanged = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow(), Self.pendingRow()])))
        XCTAssertFalse(unchanged.differs(from: running), "An identical poll must not rebuild the list")

        var verdict = Self.pendingRow()
        verdict["judged"] = true
        verdict["score"] = 4
        verdict["reason"] = "Mostly deals, few reviews."
        let judged = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow(), verdict])))
        XCTAssertTrue(judged.differs(from: running))
        XCTAssertEqual(judged.results[1].scoreTone, .low)

        let pruned = try XCTUnwrap(DescribeSearch(dict: Self.payload(results: [Self.judgedRow()])))
        XCTAssertTrue(pruned.differs(from: running))

        let complete = try XCTUnwrap(DescribeSearch(dict: Self.payload(status: "complete", phase: "complete",
                                                                        results: [Self.judgedRow(), verdict])))
        XCTAssertTrue(complete.isFinished)
        XCTAssertEqual(complete.statusMessage, NBLocalization.plural("Found %@ feeds that match your description", groupedCount: 2))
        XCTAssertEqual(complete.statusMessage, "Found 2 feeds that match your description")
        let single = try XCTUnwrap(DescribeSearch(dict: Self.payload(status: "complete", phase: "complete",
                                                                      results: [Self.judgedRow()])))
        XCTAssertEqual(single.statusMessage, "Found 1 feed that matches your description")

        var failed = Self.payload(status: "error", phase: "error", results: [])
        failed["error"] = "The judge timed out."
        let errored = try XCTUnwrap(DescribeSearch(dict: failed))
        XCTAssertEqual(errored.statusMessage, "The judge timed out.")
        XCTAssertEqual(errored.summary.metaLabel, NBLocalization.text("Failed"))
    }

    func test_scoreTonesFollowTheWebThresholds() throws {
        for (score, tone) in [(10, DescribeResult.ScoreTone.high), (8, .high), (7, .medium), (5, .medium), (4, .low), (0, .low)] {
            let result = try XCTUnwrap(DescribeResult(dict: Self.judgedRow(score: score)))
            XCTAssertEqual(result.scoreTone, tone, "score \(score)")
        }
    }

    func test_historySummaryLabelsAndRelativeDates() throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
        var dict: [String: Any] = ["id": "abc", "prompt": "indie games", "status": "complete", "phase": "complete",
                                   "created_date": "2026-11-04T09:00:00Z", "result_count": 1]
        var summary = try XCTUnwrap(DescribeSearchSummary(dict: dict))
        XCTAssertEqual(summary.metaLabel, "1 feed")
        XCTAssertEqual(summary.relativeDateLabel(now: now), NBLocalization.text("Today"))

        dict["created_date"] = "2026-11-01T09:00:00Z"
        dict["result_count"] = 12
        summary = try XCTUnwrap(DescribeSearchSummary(dict: dict))
        XCTAssertEqual(summary.metaLabel, "12 feeds")
        XCTAssertEqual(summary.relativeDateLabel(now: now), "3d ago")

        dict["created_date"] = "2026-10-20T09:00:00Z"
        summary = try XCTUnwrap(DescribeSearchSummary(dict: dict))
        XCTAssertEqual(summary.relativeDateLabel(now: now), "2w ago")

        dict["status"] = "running"
        dict["phase"] = "searching"
        summary = try XCTUnwrap(DescribeSearchSummary(dict: dict))
        XCTAssertTrue(summary.isRunning)
        XCTAssertEqual(summary.metaLabel, NBLocalization.text("Searching…"))
        XCTAssertNil(DescribeSearchSummary(dict: ["prompt": "no id"]))
    }

    func test_usageSnapshotLabelsAndLock() throws {
        let unlimited = try XCTUnwrap(DescribeUsage(dict: ["tier": "pro", "limit": NSNull(), "used": 3, "remaining": NSNull(), "resets_in": NSNull()]))
        XCTAssertNil(unlimited.limit)
        XCTAssertFalse(unlimited.isLocked)
        XCTAssertEqual(unlimited.label, NBLocalization.text("Unlimited searches"))

        let premium = try XCTUnwrap(DescribeUsage(dict: ["tier": "premium", "limit": 10, "used": 3, "remaining": 7, "resets_in": "4 hours"]))
        XCTAssertEqual(premium.label, "7 of 10 searches left today")
        XCTAssertEqual(premium.resetsIn, "4 hours")

        let free = try XCTUnwrap(DescribeUsage(dict: ["tier": "free", "limit": 0, "used": 0, "remaining": 0]))
        XCTAssertTrue(free.isLocked)
        XCTAssertEqual(free.label, NBLocalization.text("Premium feature"))
        XCTAssertNil(DescribeUsage(dict: nil))
        XCTAssertNil(DescribeUsage(dict: "usage"))
    }

    @MainActor
    func test_addSiteOffersDescribeForDescriptionsOnly() {
        XCTAssertEqual(AddSiteViewModel.describePrompt(for: "  reviews of iOS apps  "), "reviews of iOS apps")
        XCTAssertEqual(AddSiteViewModel.describePrompt(for: "a b"), "a b")
        XCTAssertNil(AddSiteViewModel.describePrompt(for: "ab"), "Too short")
        XCTAssertNil(AddSiteViewModel.describePrompt(for: "macstories.net"), "An address has no spaces")
        XCTAssertNil(AddSiteViewModel.describePrompt(for: "https://example.com/some feed"), "A URL is still a URL")
        XCTAssertNil(AddSiteViewModel.describePrompt(for: "HTTP: my feed"), "A scheme is an address")
        XCTAssertNil(AddSiteViewModel.describePrompt(for: "   "))
        let model = AddSiteViewModel(appEnvironment: DescribeTestEnvironment())
        model.searchText = "long essays about cities"
        XCTAssertEqual(model.describePrompt, "long essays about cities")
    }
}

@MainActor
final class Test_DescribeSearchPolling: XCTestCase {
    private var previousInterval: TimeInterval = 2.5

    override func setUp() {
        super.setUp()
        previousInterval = DiscoverSitesViewModel.describePollInterval
        DiscoverSitesViewModel.describePollInterval = 0.05
    }

    override func tearDown() {
        DiscoverSitesViewModel.describePollInterval = previousInterval
        DescribeURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeModel() -> DiscoverSitesViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DescribeURLProtocol.self]
        return DiscoverSitesViewModel(appEnvironment: DescribeTestEnvironment(), session: URLSession(configuration: configuration))
    }

    private func respond(_ request: URLRequest, _ json: [String: Any]) throws -> (HTTPURLResponse, Data) {
        let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil))
        return (response, try JSONSerialization.data(withJSONObject: json))
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func test_startPollsUntilCompleteAndReconcilesResultsByFeedId() async throws {
        let model = makeModel()
        var statusCalls = 0
        var startBody = ""
        DescribeURLProtocol.handler = { [self] request in
            switch request.url?.path {
            case "/discover/describe/start":
                startBody = String(data: DescribeURLProtocol.body(of: request) ?? Data(), encoding: .utf8) ?? ""
                let search = Test_DescribeSearchParsing.payload(status: "queued", phase: "queued",
                                                                results: [Test_DescribeSearchParsing.pendingRow(feedId: 42)])
                return try respond(request, ["code": 1, "search": search,
                                             "usage": ["tier": "premium", "limit": 10, "used": 1, "remaining": 9, "resets_in": "20 hours"]])
            case "/discover/describe/status":
                statusCalls += 1
                XCTAssertEqual(request.url?.query, "search_id=6720f0c1c3b2a4d5e6f70001")
                if statusCalls == 1 {
                    let search = Test_DescribeSearchParsing.payload(results: [
                        Test_DescribeSearchParsing.judgedRow(feedId: 42), Test_DescribeSearchParsing.pendingRow(feedId: 77)
                    ])
                    return try respond(request, ["code": 1, "search": search])
                }
                let search = Test_DescribeSearchParsing.payload(status: "complete", phase: "complete",
                                                                results: [Test_DescribeSearchParsing.judgedRow(feedId: 77, score: 6)])
                return try respond(request, ["code": 1, "search": search])
            default:
                XCTFail("Unexpected request \(request.url?.absoluteString ?? "")")
                return try respond(request, ["code": -1])
            }
        }

        model.startDescribeSearch(prompt: "  reviews of iOS App Store apps with lots of screenshots  ")
        XCTAssertTrue(model.describeState.isStarting)
        await waitUntil { model.describeState.search != nil }

        XCTAssertTrue(startBody.contains("prompt=reviews%20of%20iOS%20App%20Store%20apps%20with%20lots%20of%20screenshots"))
        XCTAssertTrue(startBody.contains("request_id="))
        XCTAssertFalse(startBody.contains("search_id="))
        XCTAssertFalse(model.describeState.isStarting)
        XCTAssertEqual(model.describeState.prompt, "reviews of iOS App Store apps with lots of screenshots")
        XCTAssertEqual(model.describeState.usage?.label, "9 of 10 searches left today")
        XCTAssertEqual(model.describeState.search?.results.map(\.feedId), [42])
        XCTAssertEqual(model.describeState.history.map(\.id), ["6720f0c1c3b2a4d5e6f70001"])
        XCTAssertTrue(model.describeState.history[0].isRunning)

        await waitUntil { model.describeState.search?.results.count == 2 }
        XCTAssertEqual(model.describeState.search?.results[0].score, 9, "The first poll fills in the verdict in place")
        XCTAssertEqual(model.describeState.search?.phase, "judging")

        await waitUntil { model.describeState.search?.isFinished == true }
        XCTAssertEqual(model.describeState.search?.status, "complete")
        XCTAssertEqual(model.describeState.search?.results.map(\.feedId), [77], "Pruned feeds leave the list")
        XCTAssertEqual(model.describeState.search?.results.first?.scoreTone, .medium)
        XCTAssertEqual(model.describeState.history.first?.status, "complete")
        XCTAssertEqual(model.describeState.history.first?.resultCount, 1)

        let callsAfterCompletion = statusCalls
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(statusCalls, callsAfterCompletion, "Polling stops once the search is finished")

        model.searchDescribeAgain()
        await waitUntil { startBody.contains("search_id=") }
        XCTAssertTrue(startBody.contains("search_id=6720f0c1c3b2a4d5e6f70001"), "Search again re-runs the same history entry")
        model.stopDescribePolling()
    }

    // DescribeSearchTests.swift: the negative row key of an unsaved web find never reaches the server. Previewing links
    // the feed by its address (/discover/link_popular_feed) and subscribing posts the address to /reader/add_url.
    func test_unsavedWebResultPreviewsAndSubscribesByAddress() async throws {
        let model = makeModel()
        let address = "https://pixelenvy.example/feed.xml"
        var requests: [String] = []
        var linkedURL: String?
        var addBody = ""
        DescribeURLProtocol.handler = { [self] request in
            let body = String(data: DescribeURLProtocol.body(of: request) ?? Data(), encoding: .utf8) ?? ""
            requests.append("\(request.url?.absoluteString ?? "") \(body)")
            switch request.url?.path {
            case "/discover/link_popular_feed":
                let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
                XCTAssertEqual(items.map(\.name), ["feed_url"])
                linkedURL = items.first?.value
                return try respond(request, ["code": 1, "feed_id": 9001])
            case "/reader/add_url":
                addBody = body
                return try respond(request, ["code": 1])
            default:
                XCTFail("Unexpected request \(request.url?.absoluteString ?? "")")
                return try respond(request, ["code": -1])
            }
        }
        let result = try XCTUnwrap(DescribeResult(dict: Test_DescribeSearchParsing.unsavedWebRow()))

        let resolved = await model.resolvePreviewFeed(result.feed)
        XCTAssertEqual(linkedURL, address, "An unsaved feed is linked by its address before it can be previewed")
        XCTAssertEqual(resolved?.id, "9001")
        XCTAssertEqual(resolved?.rawFeedDict["id"] as? Int, 9001)
        XCTAssertEqual(resolved?.feedTitle, "Pixel Envy")

        model.addFeed(url: result.feed.feedAddress)
        await waitUntil { model.addedSuccess }
        XCTAssertTrue(model.addedSuccess)
        XCTAssertTrue(model.addedFeedURLs.contains(address), "The card shows as subscribed by its address")
        let addItems = URLComponents(string: "?\(addBody)")?.queryItems ?? []
        XCTAssertEqual(addItems.first { $0.name == "url" }?.value, address)
        XCTAssertEqual(requests.count, 2)
        XCTAssertFalse(requests.contains { $0.contains("-1") || $0.contains("feed_id") }, "The row key is never sent: \(requests)")
    }

    func test_freeAccountsSeeTheUpgradeStateInsteadOfAnError() async throws {
        let model = makeModel()
        DescribeURLProtocol.handler = { [self] request in
            try respond(request, ["code": -1, "message": "Describe is a premium feature.", "upgrade": true,
                                  "usage": ["tier": "free", "limit": 0, "used": 0, "remaining": 0, "resets_in": NSNull()]])
        }

        model.startDescribeSearch(prompt: "indie game developers")
        await waitUntil { !model.describeState.isStarting }

        XCTAssertEqual(model.describeState.upgradeMessage, "Describe is a premium feature.")
        XCTAssertTrue(model.describeState.showsUpgrade)
        XCTAssertNil(model.describeState.errorMessage)
        XCTAssertNil(model.describeState.search)
        XCTAssertTrue(model.describeState.usage?.isLocked == true)
    }

    func test_historyLoadsReplaysAndDeletes() async throws {
        let model = makeModel()
        var history: [[String: Any]] = [
            ["id": "a1", "prompt": "older", "status": "complete", "phase": "complete", "created_date": "2026-11-01T09:00:00", "result_count": 3],
            ["id": "b2", "prompt": "oldest", "status": "error", "phase": "error", "created_date": "2026-10-30T09:00:00", "result_count": 0],
        ]
        DescribeURLProtocol.handler = { [self] request in
            switch request.url?.path {
            case "/discover/describe/history":
                return try respond(request, ["code": 1, "searches": history,
                                             "usage": ["tier": "pro", "limit": NSNull(), "used": 0, "remaining": NSNull()]])
            case "/discover/describe/status":
                var search = Test_DescribeSearchParsing.payload(status: "complete", phase: "complete",
                                                                results: [Test_DescribeSearchParsing.judgedRow()])
                search["id"] = "a1"
                search["prompt"] = "older"
                return try respond(request, ["code": 1, "search": search])
            case "/discover/describe/delete":
                let body = String(data: DescribeURLProtocol.body(of: request) ?? Data(), encoding: .utf8) ?? ""
                XCTAssertEqual(body, "search_id=a1")
                history.removeAll { ($0["id"] as? String) == "a1" }
                return try respond(request, ["code": 1, "searches": history])
            default:
                XCTFail("Unexpected request \(request.url?.absoluteString ?? "")")
                return try respond(request, ["code": -1])
            }
        }

        model.onTabSelected(.describe)
        await waitUntil { model.describeState.isHistoryLoaded }
        XCTAssertEqual(model.describeState.history.map(\.id), ["a1", "b2"])
        XCTAssertEqual(model.describeState.usage?.label, NBLocalization.text("Unlimited searches"))

        model.openDescribeSearch(id: "a1")
        XCTAssertTrue(model.describeState.isOpening)
        await waitUntil { model.describeState.search != nil }
        XCTAssertFalse(model.describeState.isOpening)
        XCTAssertEqual(model.describeState.search?.id, "a1")
        XCTAssertEqual(model.describeState.prompt, "older")
        XCTAssertEqual(model.describeState.search?.results.map(\.feedId), [42])

        model.deleteDescribeSearch(id: "a1")
        await waitUntil { model.describeState.history.map(\.id) == ["b2"] }
        XCTAssertNil(model.describeState.search, "Deleting the open search starts a new one")
        XCTAssertEqual(model.describeState.prompt, "")
        XCTAssertTrue(model.describeState.deletingSearchIDs.isEmpty)
    }
}

private final class DescribeTestEnvironment: AddSiteViewModelAppEnvironment {
    var url: String? { "https://example.com" }
    var dictFoldersArray: Any? { ["Tech"] }
}

private final class DescribeURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
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
