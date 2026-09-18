import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_RowActionMenus: XCTestCase {
    func test_goToFeedFromUnsubscribedSharedStoryOpensFeedPreview() throws {
        let app = GoToFeedMenuApp()
        app.dictFeeds = [:]
        app.dictFolders = ["Tech": [42]]
        app.dictFoldersArray = ["Tech"]
        app.dictActiveFeeds = ["77": ["id": 77, "feed_title": "Shared source", "feed_link": "https://example.com/"]]
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.isSocialRiverView = true
        app.storiesCollection.isSocialView = true
        app.storiesCollection.isRiverView = true
        app.activeStory = ["story_feed_id": 77, "story_hash": "77:shared"]
        let controllerType = try XCTUnwrap(NSClassFromString("FontSettingsViewController") as? UIViewController.Type)
        let controller = controllerType.init(nibName: nil, bundle: nil)
        controller.setValue(app, forKey: "appDelegate")
        XCTAssertEqual(controller.value(forKey: "isGoToFeedEnabled") as? Bool, true)

        // RowActionMenuTests.swift invokes the same selector as the enabled Story Options menu row.
        controller.perform(NSSelectorFromString("goToFeed"))

        XCTAssertEqual(app.previewFeedID, "77", "A social story's unsubscribed source still needs a destination")
        XCTAssertEqual(app.previewFeed?["feed_title"] as? String, "Shared source")
        XCTAssertEqual(app.previewFeed?["id"] as? Int, 77)
        XCTAssertFalse(app.previewIsSocial ?? true, "Open the source website, not its social feed")
        XCTAssertNil(app.previewStoryID, "Go to feed opens the story list rather than reopening the shared story")
        XCTAssertNil(app.openedFolder)
        XCTAssertNil(app.activeStory)
        XCTAssertFalse(app.storiesCollection.isSocialRiverView)
        XCTAssertFalse(app.storiesCollection.isSocialView)
        XCTAssertFalse(app.storiesCollection.isRiverView)
        XCTAssertTrue(app.isTryFeedView)
        XCTAssertTrue(app.didPresentFeed)
        XCTAssertEqual((app.dictFeeds["77"] as? [String: Any])?["temp"] as? Bool, true)
        XCTAssertEqual(app.dictFolders["Tech"] as? [Int], [42], "Preview must not subscribe the source")
        app.cleanUpTryFeed()
        XCTAssertNil(app.dictFeeds["77"], "Leaving the preview removes its temporary source")
    }

    func test_goToFeedWithoutSourceMetadataIsUnavailable() throws {
        let app = GoToFeedMenuApp()
        app.dictFeeds = [:]
        app.dictActiveFeeds = [:]
        app.dictFolders = [:]
        app.dictFoldersArray = []
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.isSocialRiverView = true
        app.activeStory = ["story_feed_id": 77, "story_hash": "77:shared"]
        let controllerType = try XCTUnwrap(NSClassFromString("FontSettingsViewController") as? UIViewController.Type)
        let controller = controllerType.init(nibName: nil, bundle: nil)
        controller.setValue(app, forKey: "appDelegate")

        XCTAssertEqual(controller.value(forKey: "isGoToFeedEnabled") as? Bool, false)
        controller.perform(NSSelectorFromString("goToFeed"))
        XCTAssertNil(app.previewFeedID)
        XCTAssertFalse(app.didPresentFeed)
        XCTAssertNotNil(app.activeStory)
    }

    func test_goToFeedFromSubscribedSharedStoryKeepsFolderNavigation() throws {
        let app = GoToFeedMenuApp()
        app.dictFeeds = ["42": ["id": 42, "feed_title": "Subscribed source"]]
        app.dictFolders = ["Tech": [42]]
        app.dictFoldersArray = ["Tech"]
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.isSocialRiverView = true
        app.activeStory = ["story_feed_id": 42, "story_hash": "42:shared"]
        let controllerType = try XCTUnwrap(NSClassFromString("FontSettingsViewController") as? UIViewController.Type)
        let controller = controllerType.init(nibName: nil, bundle: nil)
        controller.setValue(app, forKey: "appDelegate")

        controller.perform(NSSelectorFromString("goToFeed"))

        XCTAssertEqual(app.openedFolder, "Tech")
        XCTAssertEqual(app.openedFeedID, "42")
        XCTAssertNil(app.previewFeedID)
        XCTAssertNil(app.activeStory)
        XCTAssertFalse(app.storiesCollection.isSocialRiverView)
    }

    func test_authoritativeBulkReadCountIsPersistedForOfflineFeedAndFolder() async throws {
        try await verifyAuthoritativeCountPersistence(replaceAccount: false)
    }

    func test_oldAccountCountResponseCannotOverwriteOfflineCount() async throws {
        try await verifyAuthoritativeCountPersistence(replaceAccount: true)
    }

    private func verifyAuthoritativeCountPersistence(replaceAccount: Bool) async throws {
        let (app, _) = feedFixture()
        app.activeUsername = "bulk-refresh-" + UUID().uuidString
        app.selectedIntelligence = 0
        app.dictFoldersArray = ["Tech"]
        app.dictFeeds = ["42": ["id": "42", "active": true], "43": ["id": "43", "active": true]]
        app.dictUnreadCounts = ["42": ["ps": 0, "nt": 60, "ng": 0], "43": ["ps": 0, "nt": 5, "ng": 0]]
        let database = try XCTUnwrap(FMDatabaseQueue(path: ":memory:"))
        app.database = database
        defer { database.close() }
        database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("CREATE TABLE unread_counts (feed_id TEXT PRIMARY KEY, ps INTEGER, nt INTEGER, ng INTEGER)", withArgumentsIn: []))
            XCTAssertTrue(db!.executeUpdate("INSERT INTO unread_counts VALUES ('42', 0, 60, 0)", withArgumentsIn: []))
        }
        let feeds = PersistedReadMenuFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        let refreshed = replaceAccount ? nil : expectation(description: "Authoritative count published")
        feeds.didReload = { refreshed?.fulfill() }
        feeds.refreshFeedList("42")
        if replaceAccount {
            app.activeUsername = "replacement-account"
            let generation = (feeds.value(forKey: "feedListAccountGeneration") as? NSNumber)?.uintValue ?? 0
            feeds.setValue(NSNumber(value: generation + 1), forKey: "feedListAccountGeneration")
        }
        app.succeedGET?(["feeds": ["42": ["ps": 0, "nt": 2, "ng": 0]]])
        if let refreshed { await fulfillment(of: [refreshed], timeout: 3) }
        XCTAssertEqual(app.unreadCount(forFeed: "42"), replaceAccount ? 60 : 2)
        XCTAssertEqual(app.splitUnreadCount(forFolder: "Tech").nt, replaceAccount ? 65 : 7)
        database.inDatabase { db in
            let counts = db!.executeQuery("SELECT nt FROM unread_counts WHERE feed_id = '42'", withArgumentsIn: [])!
            XCTAssertTrue(counts.next())
            XCTAssertEqual(counts.int(forColumn: "nt"), replaceAccount ? 60 : 2,
                           "The authoritative result must replace the provisional partial-cache count on disk")
            counts.close()
        }
    }

    func test_successfulFullFeedMarkReadInvalidatesCachedFeedAndRiver() async throws {
        try await verifyFullFeedSnapshotInvalidation(replaceAccount: false)
    }

    func test_lateFullFeedMarkReadInvalidatesOriginalAccountOnly() async throws {
        try await verifyFullFeedSnapshotInvalidation(replaceAccount: true)
    }

    private func verifyFullFeedSnapshotInvalidation(replaceAccount: Bool) async throws {
        let (app, _) = feedFixture()
        let account = "bulk-full-read-test-" + UUID().uuidString
        app.activeUsername = account
        app.dictUnreadCounts = ["42": ["ps": 0, "nt": 70, "ng": 0]]
        let host = try XCTUnwrap(app.url)
        let cache = StoryFirstPageCache.shared
        let feed = try XCTUnwrap(StoryFirstPageRequest(account: account, host: host, url: host + "/reader/feed/42?page=1"))
        let river = try XCTUnwrap(StoryFirstPageRequest(account: account, host: host, url: host + "/reader/river_stories?page=1"))
        let replacement = try XCTUnwrap(StoryFirstPageRequest(account: account + "-replacement", host: host, url: feed.url))
        let response: NSDictionary = ["stories": [["story_hash": "42:old-unread", "story_feed_id": 42,
                                                    "story_title": "Cached story", "story_content": "<p>Cached body</p>", "read_status": 0]]]
        for request in [feed, river, replacement] {
            cache.store(response, request: request, revision: cache.newRevision())
        }
        let storedFeed = await snapshot(cache, request: feed)
        let storedRiver = await snapshot(cache, request: river)
        let heldFeed = try XCTUnwrap(storedFeed)
        let heldRiver = try XCTUnwrap(storedRiver)
        let feeds = BulkReadMenuFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        feeds.markFeedsRead(["42"], cutoffDays: 0)
        if replaceAccount { app.activeUsername = account + "-replacement" }
        app.succeedPOST?()

        // RowActionMenuTests.swift leaves the reload unanswered, as when the server refresh fails after Mark Read succeeds.
        XCTAssertNil(cache.response(for: heldFeed, provisional: true))
        XCTAssertNil(cache.response(for: heldRiver, provisional: true))
        let cachedFeed = await snapshot(cache, request: feed)
        let cachedRiver = await snapshot(cache, request: river)
        let otherAccount = await snapshot(cache, request: replacement)
        XCTAssertNil(cachedFeed, "Reopening an offline feed must not resurrect its unread snapshot")
        XCTAssertNil(cachedRiver, "Folder snapshots contain the same marked stories")
        XCTAssertNotNil(otherAccount)
    }

    private func snapshot(_ cache: StoryFirstPageCache, request: StoryFirstPageRequest) async -> StoryFirstPageSnapshot? {
        await withCheckedContinuation { continuation in
            cache.lookup(request) { continuation.resume(returning: $0) }
        }
    }

    func test_markOlderFromFourthStoryUpdatesFeedAndFolderUnreadCounts() throws {
        try verifyBulkRead(older: true)
    }

    func test_bulkReadFixtureWorksWithColdLoggedOutApplicationState() throws {
        let shared = try XCTUnwrap(NewsBlurAppDelegate.shared)
        let savedActiveFeeds = shared.dictActiveFeeds
        let savedFeeds = shared.dictFeeds
        let savedFeedModels = StoryCache.feeds
        defer {
            shared.dictActiveFeeds = savedActiveFeeds
            shared.dictFeeds = savedFeeds
            StoryCache.feeds = savedFeedModels
        }
        shared.dictActiveFeeds = nil
        shared.dictFeeds = nil
        StoryCache.feeds = [:]
        try verifyBulkRead(older: true)
        XCTAssertNil(shared.dictActiveFeeds)
        XCTAssertNil(shared.dictFeeds)
        XCTAssertTrue(StoryCache.feeds.isEmpty)
    }

    func test_markNewerFromFourthStoryLeavesOlderHashesUnread() throws {
        try verifyBulkRead(older: false)
    }

    func test_markOlderRefreshesServerCountsWhenOnlyFirstPageIsCached() throws {
        try verifyBulkRead(older: true, cachedCount: 12)
    }

    func test_failedMarkOlderKeepsFeedFolderAndOfflineUnreadCounts() throws {
        try verifyBulkRead(older: true, succeeds: false)
    }

    func test_markOlderResponseDoesNotChangeReplacementAccount() throws {
        try verifyBulkRead(older: true, replaceAccount: true)
    }

    private func verifyBulkRead(older: Bool, cachedCount: Int = 70, succeeds: Bool = true, replaceAccount: Bool = false) throws {
        let (app, _) = feedFixture()
        app.activeUsername = "bulk-read-test-" + UUID().uuidString
        app.selectedIntelligence = 0
        app.dictFeeds = ["42": ["id": "42", "feed_title": "Target site", "active": true],
                         "43": ["id": "43", "feed_title": "Other site", "active": true]]
        app.dictUnreadCounts = ["42": ["ps": 0, "nt": 69, "ng": 0], "43": ["ps": 0, "nt": 5, "ng": 0]]
        app.storiesCollection.appDelegate = app
        app.storiesCollection.activeFeed = app.dictFeeds["42"] as? [AnyHashable: Any]
        app.storiesCollection.activeFolder = "Tech"
        let stories: [[String: Any]] = (0..<70).map { index in
            ["story_hash": "42:bulk-\(index)", "story_feed_id": 42, "story_title": "Story \(index + 1)",
             "story_timestamp": 1_800_000_000 - index, "read_status": index == 0 ? 1 : 0,
             "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]]
        }
        app.storiesCollection.activeFeedStories = stories
        let database = try XCTUnwrap(FMDatabaseQueue(path: ":memory:"))
        app.database = database
        defer { database.close() }
        database.inDatabase { db in
            guard let db else { XCTFail("Missing fixture database"); return }
            let schema = """
                CREATE TABLE stories (story_hash TEXT PRIMARY KEY, story_feed_id INTEGER, story_timestamp INTEGER, story_json TEXT);
                CREATE TABLE unread_hashes (story_hash TEXT PRIMARY KEY, story_feed_id INTEGER, story_timestamp INTEGER);
                CREATE TABLE unread_counts (feed_id INTEGER PRIMARY KEY, ps INTEGER, nt INTEGER, ng INTEGER);
                INSERT INTO unread_counts VALUES (42, 0, 69, 0);
                """
            for statement in schema.split(separator: ";") {
                XCTAssertTrue(db.executeUpdate(String(statement), withArgumentsIn: []))
            }
            for (index, story) in stories.prefix(cachedCount).enumerated() {
                let json = String(data: try! JSONSerialization.data(withJSONObject: story), encoding: .utf8)!
                XCTAssertTrue(db.executeUpdate("INSERT INTO stories VALUES (?, ?, ?, ?)", withArgumentsIn: [story["story_hash"]!, 42, story["story_timestamp"]!, json]))
                if index > 0 {
                    XCTAssertTrue(db.executeUpdate("INSERT INTO unread_hashes VALUES (?, ?, ?)", withArgumentsIn: [story["story_hash"]!, 42, story["story_timestamp"]!]))
                }
            }
        }
        let feeds = BulkReadMenuFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        let controller = BulkReadMenuStories()
        controller.appDelegate = app
        controller.storiesCollection = app.storiesCollection
        // RowActionMenuTests.swift seeds the collapsed-folder cache before the action.
        XCTAssertEqual(app.splitUnreadCount(forFolder: "Tech").nt, 74)
        let fourth = try makeStory(index: 3, dictionary: stories[3], app: app)
        XCTAssertEqual(fourth.feed?.name, "Target site")
        XCTAssertEqual(fourth.timestamp, 1_800_000_000 - 3)
        fourth.isRead = false
        let action = try XCTUnwrap(RowActionMenus.story(fourth, controller: controller, source: UIView())
            .flatMap { $0 }.first { $0.id == (older ? "older" : "newer") })
        action.perform()
        XCTAssertEqual(app.lastParameters?["direction"] as? String, older ? "older" : "newest")
        if replaceAccount { app.activeUsername = "replacement-account" }
        if succeeds { app.succeedPOST?() } else { app.failPOST?() }
        // RowActionMenuTests.swift models opening story one, then marking story four and everything older read.
        let applied = succeeds && !replaceAccount
        let marked = applied ? (older ? cachedCount - 3 : 3) : 0
        XCTAssertEqual(app.unreadCount(forFeed: "42"), 69 - marked)
        XCTAssertEqual(app.unreadCount(forFolder: "Tech"), 74 - marked, "The folder retains five unread stories in its other feed")
        XCTAssertEqual(app.splitUnreadCount(forFolder: "Tech").nt, Int32(74 - marked))
        XCTAssertEqual(feeds.reloads, applied ? 1 : 0, "Feed and folder badges must refresh after the bulk action")
        XCTAssertEqual(feeds.headerRefreshes, applied ? 1 : 0)
        XCTAssertEqual(feeds.refreshedFeedIDs, applied ? ["42"] : [], "Server counts cover unread stories absent from the offline cache")
        XCTAssertEqual(controller.reloads, applied ? 1 : 0)
        XCTAssertEqual(controller.failures, succeeds ? 0 : 1)
        database.inDatabase { db in
            guard let remaining = db?.executeQuery("SELECT story_hash FROM unread_hashes ORDER BY story_timestamp DESC", withArgumentsIn: []) else { XCTFail("Missing fixture unread rows"); return }
            var hashes: [String] = []
            while remaining.next() { hashes.append(remaining.string(forColumn: "story_hash")!) }
            remaining.close()
            let expectedIndexes = (1..<cachedCount).filter { !applied || (older ? $0 < 3 : $0 > 3) }
            XCTAssertEqual(hashes, expectedIndexes.map { "42:bulk-\($0)" })
            guard let storedCounts = db?.executeQuery("SELECT nt FROM unread_counts WHERE feed_id = 42", withArgumentsIn: []) else { XCTFail("Missing cached count"); return }
            XCTAssertTrue(storedCounts.next())
            XCTAssertEqual(storedCounts.int(forColumn: "nt"), Int32(69 - marked))
            storedCounts.close()
            guard let storedStories = db?.executeQuery("SELECT story_json FROM stories ORDER BY story_timestamp DESC", withArgumentsIn: []) else { XCTFail("Missing cached stories"); return }
            var index = 0
            while storedStories.next() {
                let data = storedStories.string(forColumn: "story_json")!.data(using: .utf8)!
                let story = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
                let isRead = index == 0 || (applied && (older ? index >= 3 : index <= 3))
                XCTAssertEqual(story["read_status"] as? Int, isRead ? 1 : 0)
                index += 1
            }
            storedStories.close()
        }
    }

    func test_menuDefaultPreservesExplicitShortcuts() {
        let defaults = UserDefaults.standard
        let keys = ["long_press_feed_title", "long_press_story_title"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        XCTAssertTrue(GesturePreferences.feedLongPressShowsMenu)
        XCTAssertTrue(GesturePreferences.storyLongPressShowsMenu)
        defaults.set("mark_read_immediate", forKey: keys[0])
        defaults.set("save_story", forKey: keys[1])
        XCTAssertFalse(GesturePreferences.feedLongPressShowsMenu)
        XCTAssertFalse(GesturePreferences.storyLongPressShowsMenu)
        defaults.set("nothing", forKey: keys[1])
        XCTAssertFalse(GesturePreferences.storyLongPressShowsMenu)
    }

    func test_feedActionsCaptureThePressedSubscriptionWithoutChangingReader() throws {
        let (app, controller) = feedFixture()
        let groups = controller.feedActions(feedID: "42", folder: "Tech", source: UIView())
        XCTAssertEqual(groups.map { $0.map(\.id) }, [
            ["mark-read", "refresh"], ["statistics", "notifications", "train", "related"],
            ["rename", "mute"], ["delete"]
        ])
        XCTAssertEqual(app.storiesCollection.activeFeed["id"] as? String, "99")
        XCTAssertEqual(app.storiesCollection.activeFolder, "Other")
        for action in groups.flatMap({ $0 }) { XCTAssertNotNil(action.native.image, action.symbol) }
        XCTAssertTrue(try XCTUnwrap(groups.last?.first).native.attributes.contains(.destructive))

        // RowActionMenuTests.swift changes the reader before invoking the captured menu action.
        app.storiesCollection.activeFeed = ["id": "100"]
        try XCTUnwrap(groups.flatMap { $0 }.first { $0.id == "mute" }).perform()
        XCTAssertTrue(app.lastURL?.hasSuffix("/reader/set_feed_mute") == true)
        XCTAssertEqual(app.lastParameters?["feed_id"] as? String, "42")
        XCTAssertEqual(app.lastParameters?["mute"] as? String, "true")
        XCTAssertEqual(app.storiesCollection.activeFeed["id"] as? String, "100")
    }

    func test_foldersAcceptNumericFeedIDsAndSpecialRowsCannotBeDeleted() {
        let (_, controller) = feedFixture()
        let folder = controller.feedActions(feedID: nil, folder: "Tech", source: UIView())
        XCTAssertEqual(folder.first?.first?.id, "mark-read")
        XCTAssertEqual(folder.last?.first?.id, "delete")
        for name in ["everything", "infrequent", "dashboard", "discover_sites", "daily_briefing",
                     "try_feed", "saved_searches", "saved_stories", "read_stories", "widget_stories",
                     "river_global", "river_blurblogs", "trending:good_reads", ""] {
            XCTAssertFalse(RowActionMenus.isUserFolder(name), name)
            let actions = controller.feedActions(feedID: nil, folder: name, source: UIView()).flatMap { $0 }
            XCTAssertFalse(actions.contains { $0.destructive || $0.id == "rename" }, name)
        }
        XCTAssertTrue(RowActionMenus.isUserFolder("Tech ▸ Swift"))
    }

    func test_storyMenuGroupsReadSaveAndShareWithoutSelectingStory() throws {
        let (app, _) = feedFixture()
        let controller = FeedDetailViewController()
        controller.appDelegate = app
        controller.storiesCollection = app.storiesCollection
        let story = try makeStory(index: 0, dictionary: ["story_hash": "42:test", "story_title": "Test",
                                                        "story_permalink": "https://example.com/test"], app: app)
        story.isRead = false
        story.isSaved = false
        let groups = RowActionMenus.story(story, controller: controller, source: UIView())
        XCTAssertEqual(groups.map { $0.map(\.id) }, [["read", "newer", "older"], ["save"], ["share-link", "share-story"], ["train"]])
        XCTAssertNil(app.activeStory)
        for action in groups.flatMap({ $0 }) { XCTAssertNotNil(action.native.image, action.symbol) }
        app.storiesCollection.isSavedView = true
        story.isReadAvailable = false
        story.isSaved = true
        let saved = RowActionMenus.story(story, controller: controller, source: UIView()).flatMap { $0 }
        XCTAssertFalse(saved.contains { ["read", "newer", "older", "open-feed"].contains($0.id) })
        XCTAssertEqual(saved.first { $0.id == "save" }?.title, "Unsave story")
    }

    private func makeStory(index: Int, dictionary: [String: Any], app: RowMenuTestApp) throws -> Story {
        let shared = try XCTUnwrap(NewsBlurAppDelegate.shared)
        let savedActiveFeeds = shared.dictActiveFeeds
        let savedFeeds = shared.dictFeeds
        let savedCollection = shared.storiesCollection
        let savedFeedModels = StoryCache.feeds
        defer {
            shared.dictActiveFeeds = savedActiveFeeds
            shared.dictFeeds = savedFeeds
            shared.storiesCollection = savedCollection
            StoryCache.feeds = savedFeedModels
        }
        // RowActionMenuTests.swift scopes Story.swift and Feed.swift's singleton dependencies to this fixture, even before login.
        shared.dictActiveFeeds = app.dictFeeds.mutableCopy() as? NSMutableDictionary
        shared.dictFeeds = app.dictFeeds.mutableCopy() as? NSMutableDictionary
        shared.storiesCollection = app.storiesCollection
        StoryCache.feeds = [:]
        return Story(index: index, dictionary: dictionary)
    }

    private func feedFixture() -> (RowMenuTestApp, FeedsViewController) {
        let app = RowMenuTestApp()
        app.dictFeeds = ["42": ["id": "42", "feed_title": "Target site"]]
        app.dictFolders = ["Tech": [42, 43]]
        app.dictInactiveFeeds = [:]
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.activeFeed = ["id": "99"]
        app.storiesCollection.activeFolder = "Other"
        let controller = FeedsViewController()
        controller.appDelegate = app
        return (app, controller)
    }
}

@MainActor private final class GoToFeedMenuApp: NewsBlurAppDelegate {
    var openedFolder: String?
    var openedFeedID: String?
    var previewFeedID: String?
    var previewStoryID: String?
    var previewIsSocial: Bool?
    var previewFeed: [AnyHashable: Any]?
    var didPresentFeed = false

    @objc(presentFeedDetailAfterFeedSelection) func captureFeedPresentation() { didPresentFeed = true }

    override func loadFolder(_ folder: String!, feedID feedId: String!) {
        openedFolder = folder
        openedFeedID = feedId
    }

    override func loadTryFeedDetailView(_ feedId: String!, withStory contentId: String!, isSocial social: Bool,
                                        withUser user: [AnyHashable: Any]!, showFindingStory showHUD: Bool) {
        previewFeedID = feedId
        previewStoryID = contentId
        previewIsSocial = social
        previewFeed = user
        XCTAssertFalse(storiesCollection.isSocialRiverView)
        XCTAssertFalse(storiesCollection.isSocialView)
        XCTAssertFalse(storiesCollection.isRiverView)
        super.loadTryFeedDetailView(feedId, withStory: contentId, isSocial: social, withUser: user, showFindingStory: showHUD)
    }
}

@MainActor private final class RowMenuTestApp: NewsBlurAppDelegate {
    var lastURL: String?
    var lastParameters: [String: Any]?
    var succeedPOST: (() -> Void)?
    var failPOST: (() -> Void)?
    var succeedGET: (([String: Any]) -> Void)?
    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        succeedGET = { response in success?(nil, response) }
    }
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        lastURL = urlString
        lastParameters = parameters as? [String: Any]
        succeedPOST = { success?(nil, ["code": 1]) }
        failPOST = { failure?(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) }
    }
}

@MainActor private final class BulkReadMenuStories: FeedDetailViewController {
    var reloads = 0
    var failures = 0
    override func reloadStories() { reloads += 1 }
    @objc(requestFailed:) func captureRequestFailure(_ error: NSError) { failures += 1 }
}

@MainActor private final class BulkReadMenuFeeds: FeedsViewController {
    var reloads = 0
    var headerRefreshes = 0
    var refreshedFeedIDs: [String] = []
    override func reloadFeedTitlesTable() { reloads += 1 }
    override func deferredReloadFeedTitlesTable() { reloads += 1 }
    override func refreshHeaderCounts() { headerRefreshes += 1 }
    override func refreshFeedList(_ feedID: Any!) { refreshedFeedIDs.append(String(describing: feedID!)) }
}

@MainActor private final class PersistedReadMenuFeeds: FeedsViewController {
    var didReload: (() -> Void)?
    override func reloadFeedTitlesTable() { didReload?() }
    override func refreshHeaderCounts() {}
    override func loadFavicons() {}
}
