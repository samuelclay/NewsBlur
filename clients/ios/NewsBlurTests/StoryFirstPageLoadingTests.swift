import ObjectiveC.runtime
import UIKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryFirstPageLoading: XCTestCase {
    func test_reopenedFeedShowsCachedRowsBeforeQueuedReadAndSaveFlushesFinish() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.app.requests.removeAll()

        fixture.open()
        await settle()

        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
        XCTAssertEqual(fixture.app.readFlushes.count, 1)
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertFalse(fixture.controller.pageFinished)
        XCTAssertTrue(fixture.controller.isOnline)
        XCTAssertEqual(fixture.stories.feedPage, 1)

        fixture.controller.fetchNextPage(nil)
        fixture.controller.fetchFeedDetail(2, withCallback: nil)
        fixture.controller.checkScroll()
        XCTAssertTrue(fixture.app.requests.isEmpty, "Provisional rows must not start page two before authoritative page one")

        fixture.app.releaseReadFlush()
        XCTAssertEqual(fixture.app.savedFlushes.count, 1)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_emptyCachedFirstPageStillRequestsAuthoritativePageOne() async throws {
        let fixture = makeFixture()
        try await prime(fixture, stories: [])
        fixture.app.requests.removeAll()
        fixture.open()
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)
        XCTAssertFalse(fixture.controller.pageFinished)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_laterPagesDoNotReplaceCachedFirstPage() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.controller.fetchNextPage(nil)
        fixture.app.reply(to: 1, with: response(stories: makeStories(12..<24)))
        XCTAssertEqual(fixture.hashes.count, 24)
        fixture.open()
        await settle()
        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
    }

    func test_accountHostAndReadFilterCannotReuseAnotherSnapshot() async throws {
        for changedKey in ["account", "host", "filter", "order"] {
            let fixture = makeFixture()
            try await prime(fixture)
            if changedKey == "account" { fixture.app.activeUsername = "different-" + UUID().uuidString }
            if changedKey == "host" { fixture.app.testURL = "https://other.example.test" }
            if changedKey == "filter" { fixture.stories.readFilter = "unread" }
            if changedKey == "order" { fixture.stories.order = "oldest" }
            fixture.open()
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty, changedKey)
        }
    }

    func test_oldQueuedFlushCannotLaunchARequestForNewNavigation() async throws {
        let fixture = makeFixture()
        fixture.open()
        fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
        fixture.open()
        fixture.app.releaseReadFlush()
        await settle()
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("/feed/2/") == true)
    }

    func test_lateAuthoritativeResponseCannotReplaceNewFeedOrAccount() async throws {
        for changeAccount in [false, true] {
            let fixture = makeFixture()
            fixture.open()
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            if changeAccount { fixture.app.activeUsername = "different-" + UUID().uuidString }
            fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
            fixture.open()
            fixture.app.reply(to: 0, with: response())
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty)
        }
    }

    func test_localReadAndSaveWhileFlushingSurviveOlderServerResponse() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        let readStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(readStory, asSaved: true)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 1)
        XCTAssertEqual(refreshed["starred"] as? Bool, true)
        XCTAssertNotNil(refreshed["starred_date"])
    }

    func test_localUnreadAndUnsavePreserveReversalAndRemovedDate() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        stories[0]["starred"] = true
        stories[0]["starred_date"] = "Yesterday"
        try await prime(fixture, stories: stories)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryUnread(story, feed: nil)
        let unreadStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(unreadStory, asSaved: false)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: stories))
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 0)
        XCTAssertEqual(refreshed["starred"] as? Bool, false)
        XCTAssertNil(refreshed["starred_date"])
    }

    func test_provisionalReadStateDoesNotTrustUnownedGlobalReadTables() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        try await prime(fixture, stories: stories)
        fixture.app.unreadStoryHashes["first-page-0"] = true
        fixture.app.recentlyReadStories["first-page-1"] = true
        fixture.open()
        await settle()
        let first = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        let second = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.dropFirst().first)
        XCTAssertFalse(fixture.stories.isStoryUnread(first))
        XCTAssertTrue(fixture.stories.isStoryUnread(second))
    }

    func test_authoritativeInsertionPreservesVisibleStoryPixelOffsetAndSelection() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        fixture.table.contentOffset.y = fixture.table.rectForRow(at: path).minY + 13
        fixture.table.selectRow(at: path, animated: false, scrollPosition: .none)
        fixture.controller.markedHashes.removeAll()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + makeStories(0..<12)))
        await settle()

        let moved = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 7))
        XCTAssertEqual(fixture.table.contentOffset.y - fixture.table.rectForRow(at: moved).minY, 13, accuracy: 0.5)
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, moved)
        XCTAssertTrue(fixture.controller.markedHashes.isEmpty, "Programmatic restoration must not mark passed rows read")
    }

    private func prime(_ fixture: FirstPageFixture, stories: [[String: Any]]? = nil) async throws {
        fixture.open()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        fixture.app.reply(to: 0, with: response(stories: stories))
        await settle()
    }

    private func settle() async {
        // StoryFirstPageLoadingTests.swift leaves queued POST callbacks withheld; this only drains rendering/cache callbacks.
        let drained = expectation(description: "main queue and cache callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
    }

    private func makeFixture() -> FirstPageFixture {
        let app = FirstPageLoadingAppDelegate()
        app.activeUsername = "first-page-test-" + UUID().uuidString
        app.testURL = "https://example.test"
        app.interceptRequests()
        app.isPremium = true
        app.isPremiumArchive = true
        app.selectedIntelligence = 0
        app.recentlyReadStories = NSMutableDictionary()
        app.unreadStoryHashes = NSMutableDictionary()
        app.unsavedStoryHashes = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "First feed", "active": 1]]
        app.dictActiveFeeds = NSMutableDictionary()
        app.dictFolders = [:]
        app.dictFoldersArray = NSMutableArray()
        let stories = FirstPageLoadingStories()
        stories.appDelegate = app
        stories.feedPage = 1
        stories.activeFeed = app.dictFeeds["1"] as? [AnyHashable: Any]
        app.storiesCollection = stories
        let controller = FirstPageLoadingController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.dashboardIndex = -1
        app.testController = controller
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 320), style: .plain)
        table.estimatedRowHeight = 0
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.setValue(NSCache<NSString, NSString>(), forKey: "storyPreviewTextCache")
        controller.setValue(NSCache<NSString, NSNumber>(), forKey: "storyHeightCache")
        table.dataSource = controller
        table.delegate = controller
        return FirstPageFixture(app: app, stories: stories, controller: controller, table: table)
    }

    private func response(stories: [[String: Any]]? = nil) -> [String: Any] {
        ["feed_id": 1, "stories": stories ?? makeStories(0..<12), "classifiers": [:],
         "feed_authors": [], "feed_tags": [], "user_profiles": []]
    }

    private func makeStories(_ indices: Range<Int>) -> [[String: Any]] {
        indices.map { ["story_hash": "first-page-\($0)", "story_feed_id": 1,
                       "story_title": "Story \($0)", "story_content": "<p>Body \($0)</p>",
                       "story_timestamp": 1_800_000_000 - $0, "read_status": 0,
                       "starred": false, "user_tags": [], "image_urls": [],
                       "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]] }
    }
}

@MainActor private struct FirstPageFixture {
    let app: FirstPageLoadingAppDelegate
    let stories: FirstPageLoadingStories
    let controller: FirstPageLoadingController
    let table: UITableView
    var hashes: [String] { (stories.activeFeedStories as? [[String: Any]] ?? []).compactMap { $0["story_hash"] as? String } }

    func open() {
        let selector = NSSelectorFromString("loadFeedDetailView:")
        typealias Load = @convention(c) (AnyObject, Selector, Bool) -> Void
        let implementation = unsafeBitCast(app.method(for: selector), to: Load.self)
        implementation(app, selector, false)
    }
}

private final class FirstPageLoadingStories: StoriesCollection {
    var readFilter = "all"
    var order = "newest"
    override var activeReadFilter: String! { readFilter }
    override var activeOrder: String! { order }
}

@MainActor private final class FirstPageLoadingController: FeedDetailViewController {
    var markedHashes: [String] = []
    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    override func reload() { reloadTable() }
    override func loadingFeed() {}
    override func updateStoryTitlesHeaderPillState() {}
    override func loadFaviconsFromActiveFeed() {}
    override func showFetchingBanner(_ title: String!, isOffline: Bool) {}
    override func hideFetchingBanner() {}
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        if isScrolling, let hash = story["story_hash"] as? String { markedHashes.append(hash) }
        return false
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 80 }
    @objc(beginOfflineTimer) func suppressUnownedSQLiteFallback() {}
    @objc(cacheImagesForStories:) func suppressImageDownloads(_ stories: Any?) {}
    @objc(warmStoryPreviewCacheAroundLocation:) func suppressWarmup(_ location: Int) {}
    @objc(updateBottomNextFeedControlForScroll:) func suppressNavigationControls(_ scroll: UIScrollView) {}
}

private final class FirstPageLoadingAppDelegate: NewsBlurAppDelegate {
    struct CapturedRequest {
        let url: String
        let success: (URLSessionDataTask?, Any?) -> Void
    }
    var requests: [CapturedRequest] = []
    var readFlushes: [() -> Void] = []
    var savedFlushes: [() -> Void] = []
    weak var testController: FeedDetailViewController?
    override var feedDetailViewController: FeedDetailViewController! {
        get { testController }
        set { testController = newValue }
    }
    override func cleanUpTryFeed() {}
    @objc(updateFeedDetailTitleView) func suppressTitleView() {}

    var testURL = "https://example.test"
    override var url: String! { testURL }
    func interceptRequests() { _ = Self.installInterceptors }

    func releaseReadFlush() { if !readFlushes.isEmpty { readFlushes.removeFirst()() } }
    func releaseSavedFlush() { if !savedFlushes.isEmpty { savedFlushes.removeFirst()() } }
    func reply(to index: Int, with response: [String: Any]) {
        guard requests.indices.contains(index) else { XCTFail("Missing intercepted page request \(index)"); return }
        requests[index].success(nil, response)
    }

    // StoryFirstPageLoadingTests.swift installs selectors only on this synthetic delegate, never on the logged-in app.
    private static let installInterceptors: Void = {
        for (original, replacement) in [
            ("GETreturningTask:parameters:success:failure:", "nb_test_GET:parameters:success:failure:"),
            ("flushQueuedReadStories:withCallback:", "nb_test_readFlush:callback:"),
            ("flushQueuedSavedStories:withCallback:", "nb_test_savedFlush:callback:")
        ] {
            let method = class_getInstanceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(replacement))!
            class_replaceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(original),
                                method_getImplementation(method), method_getTypeEncoding(method))
        }
    }()

    @objc(nb_test_GET:parameters:success:failure:)
    func captureGET(_ url: String, parameters: Any?, success: @escaping (URLSessionDataTask?, Any?) -> Void,
                    failure: @escaping (URLSessionDataTask?, NSError?) -> Void) -> URLSessionDataTask? {
        requests.append(CapturedRequest(url: url, success: success))
        return nil
    }
    @objc(nb_test_readFlush:callback:)
    func holdReadFlush(_ force: Bool, callback: @escaping () -> Void) { readFlushes.append(callback) }
    @objc(nb_test_savedFlush:callback:)
    func holdSavedFlush(_ force: Bool, callback: @escaping () -> Void) { savedFlushes.append(callback) }
}
