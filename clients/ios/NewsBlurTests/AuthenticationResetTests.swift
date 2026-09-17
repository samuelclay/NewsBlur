import XCTest
import WebKit

@testable import NewsBlur

@MainActor final class Test_AuthenticationReset: XCTestCase {
    func test_showLoginClearsMountedDiscoveryBeforeAnotherAccountSignsIn() async throws {
        try await assertDiscoveryCleared(showLogin: true, preview: false)
    }

    func test_successfulLoginClearsRetainedDiscoveryPreview() async throws {
        try await assertDiscoveryCleared(showLogin: false, preview: true)
    }

    private func assertDiscoveryCleared(showLogin: Bool, preview: Bool) async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close(); DiscoverSitesViewController.viewModelFactory = nil }
        let model = DiscoverSitesViewModel()
        var createdModel = false
        DiscoverSitesViewController.viewModelFactory = { createdModel = true; return model }
        let discovery = DiscoverSitesViewController()
        discovery.initialTab = .googleNews
        fixture.detail.showDiscoverSites(discovery)
        // AuthenticationResetTests.swift explicitly loads the child of its offscreen navigation fixture.
        discovery.loadViewIfNeeded()
        XCTAssertTrue(createdModel, "The state below must belong to the controller being reset")
        model.searchState.query = "previous account private query"
        model.selectedFolder = "Previous account folder"
        model.webFeedState.analyzedURL = "https://private.example.invalid/articles"
        model.webFeedState.feedTitle = "Previous analysis"
        model.webFeedState.requestId = "previous-analysis"
        model.webFeedState.isAnalyzing = true
        if preview { fixture.detail.beginDiscoverPreview() }
        XCTAssertTrue(preview ? fixture.detail.canReturnToDiscoverSites : fixture.detail.isDiscoverSitesVisible)
        attach(fixture, name: "Discovery retained before account change")

        if showLogin { fixture.app.showLogin() }
        else {
            fixture.login.checkPassword()
            try fixture.app.completePOST(["code": 1])
        }

        XCTAssertFalse(fixture.detail.isDiscoverSitesVisible)
        XCTAssertFalse(fixture.detail.canReturnToDiscoverSites)
        XCTAssertNil(discovery.parent)
        XCTAssertTrue(model.searchState.query.isEmpty)
        XCTAssertTrue(model.selectedFolder.isEmpty)
        XCTAssertTrue(model.webFeedState.analyzedURL.isEmpty)
        XCTAssertTrue(model.webFeedState.feedTitle.isEmpty)
        XCTAssertNil(model.webFeedState.requestId)
        XCTAssertFalse(model.webFeedState.isAnalyzing)
        fixture.detail.returnToDiscoverSites()
        XCTAssertFalse(fixture.detail.isDiscoverSitesVisible, "The next account cannot reopen the retained pane")
    }

    func test_successfulLoginClearsCompactBrowsingBeforeDismissalAndBeforeSubscriptionsReturn() async throws {
        try await assertSuccessfulAuthentication(signup: false, compact: true)
    }

    func test_successfulLoginClearsRegularWidthTitlesAndArticleBeforeDismissal() async throws {
        try await assertSuccessfulAuthentication(signup: false, compact: false)
    }

    func test_successfulSignupClearsAnonymousBrowsingBeforeDismissal() async throws {
        try await assertSuccessfulAuthentication(signup: true, compact: false)
    }

    func test_rejectedLoginPreservesAnonymousBrowsingAndDoesNotFetchSubscriptions() async throws {
        let fixture = try await makeFixture(compact: true)
        defer { fixture.close() }
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": -1, "errors": ["__all__": ["Fixture credentials rejected"]]])
        XCTAssertEqual(fixture.login.dismissals, 0)
        XCTAssertTrue(fixture.app.getRequests.isEmpty)
        assertAnonymousBrowsing(fixture)
        XCTAssertEqual(fixture.login.errorLabel.text, "Fixture credentials rejected")
    }

    func test_failedLoginTransportPreservesAnonymousBrowsing() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.login.checkPassword()
        let request = try XCTUnwrap(fixture.app.postRequests.first)
        request.failure(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertEqual(fixture.login.dismissals, 0)
        XCTAssertTrue(fixture.app.getRequests.isEmpty)
        assertAnonymousBrowsing(fixture)
    }

    func test_ordinarySubscriptionRefreshPreservesTheSelectedArticle() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.app.reloadFeedsView(true)
        XCTAssertEqual(fixture.app.getRequests.filter { $0.url.contains("/reader/feeds?") }.count, 1)
        assertAnonymousBrowsing(fixture)
    }

    func test_oldSubscriptionResponseCannotRestoreAnEarlierIdentityAfterSuccessfulLogin() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.app.reloadFeedsView(false)
        let oldRequest = try XCTUnwrap(fixture.app.getRequests.first)
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        let newRequest = try XCTUnwrap(fixture.app.getRequests.last)
        XCTAssertEqual(fixture.app.getRequests.count, 2)
        newRequest.success(nil, feedResponse(username: "authenticated-fixture", feedID: "2"))
        await settle()
        XCTAssertEqual(fixture.app.activeUsername, "authenticated-fixture", "The newer subscription response must be applied first")
        oldRequest.success(nil, feedResponse(username: "earlier-anonymous-fixture", feedID: "1"))
        await settle()
        XCTAssertEqual(fixture.app.activeUsername, "authenticated-fixture", "A completed older GET must not change the authenticated identity")
        XCTAssertNotNil(fixture.app.dictFeeds["2"])
        XCTAssertNil(fixture.app.dictFeeds["1"])
        XCTAssertNil(fixture.app.activeStory)
        attach(fixture, name: "Late old subscription response after login")
    }

    func test_queuedOfflineSubscriptionPublicationCannotReopenAnonymousSelectionAfterLogin() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.app.database = try offlineAccounts()
        fixture.app.activeUsername = "earlier-offline-fixture"
        UserDefaults.standard.set("earlier-offline-fixture", forKey: "active_username")
        // AuthenticationResetTests.swift uses the real synchronous SQLite query, whose UI publication is queued on main.
        fixture.feeds.loadOfflineFeeds(false)
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        await settle()
        XCTAssertNil(fixture.app.activeUsername)
        XCTAssertTrue((fixture.app.dictFeeds?.count ?? 0) == 0)
        XCTAssertEqual(fixture.app.getRequests.filter { $0.url.contains("/reader/feeds?") }.count, 1,
                       "The old offline callback must not publish or start another subscription request")
        assertClearedBrowsing(fixture)
    }

    func test_relaunchBeforeSubscriptionsReturnDoesNotRestoreEarlierOfflineAccount() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        let database = try offlineAccounts()
        fixture.app.database = database
        fixture.app.activeUsername = "earlier-offline-fixture"
        UserDefaults.standard.set("earlier-offline-fixture", forKey: "active_username")
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        XCTAssertNil(UserDefaults.standard.string(forKey: "active_username"), "Do not select an earlier SQLite account on the next launch")

        let relaunchedApp = AuthenticationAppDelegate()
        let relaunchedFeeds = AuthenticationFeedsController()
        relaunchedApp.database = database
        relaunchedApp.feedsViewController = relaunchedFeeds
        relaunchedFeeds.appDelegate = relaunchedApp
        relaunchedFeeds.loadOfflineFeeds(false)
        await settle()
        XCTAssertNil(relaunchedApp.activeUsername)
        XCTAssertTrue((relaunchedApp.dictFeeds?.count ?? 0) == 0)
        XCTAssertEqual(relaunchedApp.getRequests.filter { $0.url.contains("/reader/feeds?") }.count, 1)
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &connection), SQLITE_OK)
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(connection, "SELECT COUNT(*) FROM accounts", -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 1, "Preserve account-owned snapshots and queued edits")
        sqlite3_finalize(statement)
        sqlite3_close(connection)
        relaunchedFeeds.loadWorkItem?.cancel()
        relaunchedFeeds.reloadWorkItem?.cancel()
        relaunchedApp.getRequests.removeAll()
    }

    func test_loginKeepsClearedTitlesEmptyAfterTheOldOfflineTimerDeadline() async throws {
        let fixture = try await makeFixture(compact: true)
        defer { fixture.close() }
        fixture.titles.perform(NSSelectorFromString("beginOfflineTimer"))
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        await settle(1.2)
        assertClearedBrowsing(fixture)
        XCTAssertFalse(fixture.titles.isShowingFetching)
        XCTAssertEqual(fixture.app.getRequests.count, 1)
    }

    func test_priorAccountUnreadRefreshCannotReplaceCurrentAccountCounts() async throws {
        for feedID: String? in [nil, "1"] {
            let fixture = try await makeFixture(compact: false)
            defer { fixture.close() }
            fixture.feeds.refreshFeedList(feedID)
            let oldRequest = try XCTUnwrap(fixture.app.getRequests.last)
            fixture.login.checkPassword()
            try fixture.app.completePOST(["code": 1])
            seedNewAccountCounts(fixture)
            oldRequest.success(nil, ["feeds": ["1": ["ps": 0, "nt": 99, "ng": 0]]])
            await settle()
            XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? NSDictionary)?["nt"] as? Int, 7)
        }
    }

    func test_priorAccountUnreadRefreshFailureCannotShowAnErrorInTheNewAccount() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.feeds.refreshFeedList()
        let oldRequest = try XCTUnwrap(fixture.app.getRequests.last)
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        oldRequest.failure(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertEqual(fixture.feeds.requestFailures, 0)
    }

    func test_queuedUnreadRefreshPublicationCannotReloadOrRestartOfflineWorkAfterAuthentication() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        let queued = expectation(description: "Real count-refresh worker reached its main publication boundary")
        fixture.feeds.refreshPublication.hold(until: queued)
        fixture.feeds.refreshFeedList()
        try XCTUnwrap(fixture.app.getRequests.last).success(nil, ["feeds": ["1": ["ps": 0, "nt": 99, "ng": 0]]])
        await fulfillment(of: [queued], timeout: 2)
        fixture.login.checkPassword()
        try fixture.app.completePOST(["code": 1])
        seedNewAccountCounts(fixture)
        let reloads = fixture.feeds.tableReloads
        let offlineStarts = fixture.app.offlineStarts
        fixture.feeds.refreshPublication.release()
        await settle()
        XCTAssertEqual(fixture.feeds.tableReloads, reloads)
        XCTAssertEqual(fixture.app.offlineStarts, offlineStarts)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? NSDictionary)?["nt"] as? Int, 7)
    }

    func test_currentAccountUnreadRefreshStillAppliesCountsAndReportsFailure() async throws {
        for feedID: String? in [nil, "1"] {
            let fixture = try await makeFixture(compact: false)
            defer { fixture.close() }
            fixture.feeds.refreshFeedList(feedID)
            let request = try XCTUnwrap(fixture.app.getRequests.last)
            request.success(nil, ["feeds": ["1": ["ps": 0, "nt": 17, "ng": 0]]])
            await settle()
            XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? NSDictionary)?["nt"] as? Int, 17)
            XCTAssertEqual(fixture.app.offlineStarts, feedID == nil ? 1 : 0)
            fixture.feeds.refreshFeedList(feedID)
            try XCTUnwrap(fixture.app.getRequests.last).failure(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
            XCTAssertEqual(fixture.feeds.requestFailures, 1)
        }
    }

    func test_emptyAuthenticatedAccountRebuildsItsOwnHeaderBeforeOnboarding() async throws {
        let fixture = try await makeFixture(compact: false)
        defer { fixture.close() }
        fixture.login.registerAccount()
        try fixture.app.completePOST(["code": 1])
        var response = feedResponse(username: "new-empty-fixture", feedID: "1")
        response["feeds"] = [String: Any]()
        response["flat_folders_with_inactive"] = [String: Any]()
        try XCTUnwrap(fixture.app.getRequests.last).success(nil, response)
        await settle()
        XCTAssertEqual(fixture.app.firstTimeUserPresentations, 1)
        XCTAssertEqual(fixture.feeds.userLabel.text, "new-empty-fixture")
        XCTAssertFalse(fixture.feeds.userLabel.isHidden)
        XCTAssertFalse(fixture.feeds.neutralCount.isHidden)
        XCTAssertNotNil(fixture.feeds.userAvatarButton?.image(for: .normal))
        XCTAssertNil(fixture.app.activeStory)
        XCTAssertTrue((fixture.stories.activeFeedStories ?? []).isEmpty)
        attach(fixture, name: "Empty authenticated account before onboarding", committed: true)
    }

    private func seedNewAccountCounts(_ fixture: AuthenticationFixture) {
        fixture.app.activeUsername = "authenticated-fixture"
        fixture.app.dictFeeds = ["1": ["id": 1, "feed_title": "New account subscription", "active": 1]]
        fixture.app.dictUnreadCounts = NSMutableDictionary(dictionary: ["1": ["ps": 0, "nt": 7, "ng": 0]])
    }

    private func offlineAccounts() throws -> FMDatabaseQueue {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("authentication-\(UUID().uuidString).sqlite")
        let json = String(data: try JSONSerialization.data(withJSONObject: feedResponse(username: "earlier-offline-fixture", feedID: "1")), encoding: .utf8)!.replacingOccurrences(of: "'", with: "''")
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path.path, &connection), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(connection, "CREATE TABLE accounts (username TEXT, download_date REAL, feeds_json TEXT)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(connection, "INSERT INTO accounts (username, feeds_json) VALUES ('earlier-offline-fixture', '\(json)')", nil, nil, nil), SQLITE_OK)
        sqlite3_close(connection)
        let queue = try XCTUnwrap(FMDatabaseQueue(path: path.path))
        addTeardownBlock { queue.close(); try? FileManager.default.removeItem(at: path) }
        return queue
    }

    private func assertSuccessfulAuthentication(signup: Bool, compact: Bool) async throws {
        let fixture = try await makeFixture(compact: compact)
        defer { fixture.close() }
        let name = "\(signup ? "Signup" : "Login") \(compact ? "compact" : "regular")"
        assertAnonymousBrowsing(fixture)
        attach(fixture, name: "\(name) before authentication")
        let imageGeneration = fixture.app.value(forKey: "storyImageCacheGeneration") as? UInt ?? 0
        fixture.login.beforeDismissal = { [unowned self, unowned fixture] in
            // AuthenticationResetTests.swift inspects the production callback before UIKit dismisses the form.
            self.attach(fixture, name: "\(name) successful callback before dismissal; subscriptions held")
            self.assertClearedBrowsing(fixture)
        }
        if signup { fixture.login.registerAccount() } else { fixture.login.checkPassword() }
        XCTAssertEqual(fixture.app.postRequests.first?.url.hasSuffix(signup ? "/api/signup" : "/api/login"), true)
        try fixture.app.completePOST(["code": 1])
        XCTAssertGreaterThan(fixture.app.value(forKey: "storyImageCacheGeneration") as? UInt ?? 0, imageGeneration)
        XCTAssertEqual(fixture.login.dismissals, 1)
        XCTAssertEqual(fixture.login.passwordInput.text, "")
        XCTAssertEqual(fixture.app.getRequests.filter { $0.url.contains("/reader/feeds?") }.count, 1,
                       "Start the new subscription request, but do not wait for it to clear the old UI")
        XCTAssertTrue(fixture.app.getRequests.allSatisfy { $0.url.contains("/reader/feeds?") }, "No anonymous feed/article should reopen")
        await settle()
        assertClearedBrowsing(fixture)
        attach(fixture, name: "\(name) displayed after authentication; subscriptions still held", committed: true)
    }

    private func assertAnonymousBrowsing(_ fixture: AuthenticationFixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "anonymous-story", file: file, line: line)
        XCTAssertEqual(fixture.stories.activeFeedStories?.count, 1, file: file, line: line)
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "anonymous-story", file: file, line: line)
        XCTAssertFalse(fixture.pages.currentPage.webView.isHidden, file: file, line: line)
        XCTAssertEqual(fixture.titles.storyTitlesTable.numberOfRows(inSection: 0), 2, "One actual story and the loading row", file: file, line: line)
        XCTAssertEqual(fixture.stories.activeFeed?["id"] as? Int, 1, file: file, line: line)
        XCTAssertTrue(fixture.app.isTryFeedView, file: file, line: line)
    }

    private func assertClearedBrowsing(_ fixture: AuthenticationFixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(fixture.app.activeStory, file: file, line: line)
        XCTAssertTrue((fixture.stories.activeFeedStories ?? []).isEmpty, file: file, line: line)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 0, file: file, line: line)
        XCTAssertNil(fixture.stories.activeFeed, file: file, line: line)
        XCTAssertNil(fixture.stories.activeFolder, file: file, line: line)
        XCTAssertFalse(fixture.stories.inSearch, file: file, line: line)
        XCTAssertNil(fixture.stories.searchQuery, file: file, line: line)
        XCTAssertFalse(fixture.titles.messageView.isHidden, "The unselected title pane uses its normal empty state", file: file, line: line)
        XCTAssertEqual(fixture.titles.messageLabel.text, "Select a feed to read", file: file, line: line)
        XCTAssertEqual(fixture.titles.storyTitlesTable.numberOfSections, 0, "Do not display the finished-feed mark-all footer without a selected feed", file: file, line: line)
        XCTAssertTrue((fixture.app.dictFeeds?.count ?? 0) == 0, "Old subscriptions must disappear while loading", file: file, line: line)
        XCTAssertNil(fixture.app.tryFeedFeedId, file: file, line: line)
        XCTAssertNil(fixture.app.tryFeedStoryId, file: file, line: line)
        XCTAssertFalse(fixture.app.isTryFeedView, file: file, line: line)
        XCTAssertFalse(fixture.app.inFindingStoryMode, file: file, line: line)
        XCTAssertNil(fixture.app.pendingFolder, file: file, line: line)
        XCTAssertNil(fixture.app.pendingDailyBriefingStoryHash, file: file, line: line)
        for label in [fixture.feeds.userLabel, fixture.feeds.neutralCount, fixture.feeds.positiveCount].compactMap({ $0 }) {
            XCTAssertTrue((label.text ?? "").isEmpty, "Remove earlier header identity and counts", file: file, line: line)
            XCTAssertTrue(label.isHidden, file: file, line: line)
        }
        XCTAssertTrue(fixture.feeds.yellowIcon.isHidden, file: file, line: line)
        XCTAssertTrue(fixture.feeds.greenIcon.isHidden, file: file, line: line)
        XCTAssertFalse(fixture.titles.pageFetching, file: file, line: line)
        for page in [fixture.pages.currentPage, fixture.pages.nextPage, fixture.pages.previousPage].compactMap({ $0 }) {
            XCTAssertNil(page.activeStory, file: file, line: line)
            XCTAssertNil(page.activeStoryId, file: file, line: line)
            XCTAssertFalse(page.hasStory, file: file, line: line)
            XCTAssertTrue(page.webView.isHidden, file: file, line: line)
        }
        let visibleRows = fixture.titles.value(forKey: "visibleStoryRows") as? [[String: Any]] ?? []
        XCTAssertTrue(visibleRows.isEmpty, "Rendered title rows must be invalidated too", file: file, line: line)
        if fixture.compact {
            XCTAssertTrue(fixture.navigation.topViewController === fixture.feeds, "Successful authentication returns to the feeds list", file: file, line: line)
        }
    }

    private func makeFixture(compact: Bool) async throws -> AuthenticationFixture {
        let fixture = AuthenticationFixture(compact: compact)
        try fixture.configure()
        fixture.pages.currentPage.webView.loadHTMLString("""
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="font:20px -apple-system;padding:20px;background:#fff;color:#222">
            <h1>Anonymous article remains visible</h1><p>This is synthetic content opened before signing in.</p>
            <p>Successful login must clear this article and the old title list before new subscriptions arrive.</p></body></html>
            """, baseURL: nil)
        for _ in 0..<80 {
            if let text = try? await fixture.pages.currentPage.webView.evaluateJavaScript("document.body.innerText") as? String,
               text.contains("Anonymous article remains visible") { break }
            await settle(0.025)
        }
        let text = try await fixture.pages.currentPage.webView.evaluateJavaScript("document.body.innerText") as? String
        XCTAssertTrue(text?.contains("Anonymous article remains visible") == true, "Real WKWebView content must exist before exercising auth")
        await settle(0.05)
        return fixture
    }

    private func feedResponse(username: String, feedID: String) -> [String: Any] {
        ["user": username, "feeds": [feedID: ["id": Int(feedID)!, "feed_title": "Subscription \(feedID)", "active": 1, "ps": 0, "nt": 1, "ng": 0]],
         "flat_folders_with_inactive": [" ": [Int(feedID)!]], "inactive_feeds": [:], "social_feeds": [],
         "social_profile": [:], "social_services": [:], "user_profile": ["preferences": [:]],
         "starred_counts": [], "saved_searches": [], "activities": [], "dashboard_rivers": [], "categories": NSNull()]
    }

    private func attach(_ fixture: AuthenticationFixture, name: String, committed: Bool = false) {
        if committed { fixture.window.layoutIfNeeded(); CATransaction.flush() }
        for (label, view) in [("browsing", fixture.window.rootViewController!.view!), ("native title layer", fixture.titles.storyTitlesTable!)] {
            view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
                if label == "native title layer" { view.layer.render(in: context.cgContext) }
                else { view.drawHierarchy(in: view.bounds, afterScreenUpdates: committed) }
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(name) - \(label)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func settle(_ seconds: Double = 0.15) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { continuation.resume() }
        }
    }
}

// AuthenticationResetTests.swift bypasses storyboard/lifecycle wiring that otherwise adopts UIApplication's real account.
// Authentication callbacks, reloadFeedsView, fetchFeedList, row rendering, page clearing and navigation all remain production code.
@MainActor private final class AuthenticationFixture {
    let compact: Bool
    let app = AuthenticationAppDelegate()
    let stories = StoriesCollection()
    let login = AuthenticationLoginController()
    let feeds = AuthenticationFeedsController()
    let titles = AuthenticationTitlesController()
    let detail = AuthenticationDetailController()
    let pages = AuthenticationPagesController()
    let navigation: UINavigationController
    let window: UIWindow
    private let preferenceDomain = Bundle.main.bundleIdentifier!
    private let preferences: [String: Any]
    private let sharedPreferences: [String: Any]

    init(compact: Bool) {
        self.compact = compact
        navigation = UINavigationController(rootViewController: feeds)
        window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        preferences = UserDefaults.standard.persistentDomain(forName: preferenceDomain) ?? [:]
        sharedPreferences = UserDefaults(suiteName: "group.com.newsblur.NewsBlur-Group")?.persistentDomain(forName: "group.com.newsblur.NewsBlur-Group") ?? [:]
    }

    func configure() throws {
        app.storiesCollection = stories
        stories.appDelegate = app
        app.feedsViewController = feeds
        app.feedsNavigationController = navigation
        app.detailViewController = detail
        detail.appDelegate = app
        detail.isCompact = compact
        detail.feedDetailViewController = titles
        detail.storyPagesViewController = pages
        feeds.appDelegate = app
        titles.appDelegate = app
        titles.storiesCollection = stories
        pages.appDelegate = app
        login.appDelegate = app
        login.loadViewIfNeeded()
        login.usernameInput.text = "synthetic-authentication-fixture"
        login.passwordInput.text = "synthetic-password"
        login.emailInput.text = "fixture@example.invalid"
        app.selectedIntelligence = 0
        app.isPremium = true
        app.recentlyReadStories = NSMutableDictionary()
        app.unreadStoryHashes = NSMutableDictionary()
        app.unsavedStoryHashes = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Anonymous subscription", "active": 1, "ps": 0, "nt": 1, "ng": 0]]
        app.dictFolders = ["everything": [1]]
        app.dictFoldersArray = NSMutableArray(array: ["everything"])
        app.dictUnreadCounts = NSMutableDictionary(dictionary: ["1": ["ps": 0, "nt": 1, "ng": 0]])
        stories.activeFeed = app.dictFeeds["1"] as? [AnyHashable: Any]
        stories.activeFolder = "everything"
        stories.inSearch = true
        stories.searchQuery = "anonymous query"
        let story: [String: Any] = ["story_hash": "anonymous-story", "story_feed_id": 1, "story_title": "Anonymous article remains visible",
                                   "story_content": "This synthetic preview belongs to anonymous browsing.", "short_parsed_date": "1m", "read_status": 0,
                                   "image_urls": [], "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]]
        stories.setStories([story])
        app.activeStory = story
        app.isTryFeedView = true
        app.tryFeedFeedId = "1"
        app.tryFeedStoryId = "anonymous-story"
        app.inFindingStoryMode = true
        app.pendingFolder = "old-folder"
        app.pendingDailyBriefingStoryHash = "old-briefing-story"
        feeds.loadViewIfNeeded()
        feeds.title = "Feeds"
        feeds.userInfoView = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 60))
        feeds.userLabel = UILabel(frame: CGRect(x: 12, y: 0, width: 310, height: 22))
        feeds.userLabel.text = "Earlier browsing identity"
        feeds.neutralCount = UILabel(frame: CGRect(x: 12, y: 25, width: 100, height: 20))
        feeds.neutralCount.text = "999"
        feeds.positiveCount = UILabel(frame: CGRect(x: 130, y: 25, width: 100, height: 20))
        feeds.positiveCount.text = "123"
        feeds.yellowIcon = UIImageView(image: UIImage(systemName: "circle.fill"))
        feeds.greenIcon = UIImageView(image: UIImage(systemName: "circle.fill"))
        for item in [feeds.userLabel as UIView, feeds.neutralCount, feeds.positiveCount, feeds.yellowIcon, feeds.greenIcon] {
            feeds.userInfoView.addSubview(item!)
        }
        feeds.view.addSubview(feeds.userInfoView)
        feeds.feedTitlesTable = UITableView(frame: feeds.view.bounds)
        feeds.feedTitlesTable.tableHeaderView = feeds.userInfoView
        feeds.feedTitlesTable.dataSource = feeds
        feeds.feedTitlesTable.delegate = feeds
        feeds.view.addSubview(feeds.feedTitlesTable)
        feeds.calculateFeedLocations()
        feeds.feedTitlesTable.reloadData()
        titles.loadViewIfNeeded()
        titles.title = "Anonymous subscription"
        titles.messageView = UIView(frame: titles.view.bounds)
        titles.messageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        titles.messageLabel = UILabel(frame: titles.messageView.bounds)
        titles.messageLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        titles.messageLabel.textAlignment = .center
        titles.messageView.addSubview(titles.messageLabel)
        titles.messageView.isHidden = true
        titles.pageFetching = true
        titles.textSize = .long
        titles.storyTitlesTable = UITableView(frame: titles.view.bounds)
        titles.storyTitlesTable.dataSource = titles
        titles.storyTitlesTable.delegate = titles
        titles.view.addSubview(titles.storyTitlesTable)
        titles.view.addSubview(titles.messageView)
        let rows = try XCTUnwrap(titles.perform(NSSelectorFromString("buildVisibleStoryRows"))?.takeUnretainedValue())
        titles.setValue(rows, forKey: "visibleStoryRows")
        titles.storyTitlesTable.reloadData()
        titles.storyTitlesTable.layoutIfNeeded()
        pages.loadViewIfNeeded()
        pages.scrollView = UIScrollView(frame: pages.view.bounds)
        pages.view.addSubview(pages.scrollView)
        let children = (0..<3).map { _ -> AuthenticationStoryController in
            let page = AuthenticationStoryController()
            page.appDelegate = app
            page.loadViewIfNeeded()
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            page.webView = WKWebView(frame: page.view.bounds, configuration: configuration)
            page.view.addSubview(page.webView)
            page.noStoryMessage = UILabel(frame: page.view.bounds)
            (page.noStoryMessage as? UILabel)?.text = "Select a story"
            page.view.addSubview(page.noStoryMessage)
            page.noStoryMessage.isHidden = true
            page.setValue(true, forKey: "preparedWebViewFonts")
            page.webView.isHidden = true
            pages.addChild(page)
            pages.scrollView.addSubview(page.view)
            page.didMove(toParent: pages)
            return page
        }
        pages.currentPage = children[0]
        pages.nextPage = children[1]
        pages.previousPage = children[2]
        pages.scrollView.bringSubviewToFront(children[0].view)
        children[0].activeStory = NSMutableDictionary(dictionary: story)
        children[0].activeStoryId = "anonymous-story"
        children[0].hasStory = true
        children[0].pageIndex = 0
        children[0].webView.isHidden = false
        if compact {
            navigation.setViewControllers([feeds, titles, pages], animated: false)
            window.rootViewController = navigation
        } else {
            let host = UIViewController()
            host.view = UIView(frame: window.bounds)
            for (index, child) in [feeds as UIViewController, titles, pages].enumerated() {
                host.addChild(child)
                let columnWidth = window.bounds.width / 3
                child.view.frame = CGRect(x: CGFloat(index) * columnWidth, y: 0, width: columnWidth, height: window.bounds.height)
                host.view.addSubview(child.view)
                child.didMove(toParent: host)
            }
            window.rootViewController = host
        }
        if !compact {
            feeds.feedTitlesTable.frame = feeds.view.bounds
            titles.storyTitlesTable.frame = titles.view.bounds
            pages.scrollView.frame = pages.view.bounds
            for page in children {
                page.view.frame = pages.view.bounds
                page.webView.frame = page.view.bounds
                page.noStoryMessage.frame = page.view.bounds
            }
        }
        window.isHidden = false
        window.layoutIfNeeded()
        titles.storyTitlesTable.layoutIfNeeded()
    }

    func close() {
        // AuthenticationResetTests.swift rejects queued fixture responses before restoring shared preference domains.
        let generation = (feeds.value(forKey: "feedListAccountGeneration") as? NSNumber)?.uintValue ?? 0
        feeds.setValue(NSNumber(value: generation &+ 1), forKey: "feedListAccountGeneration")
        login.beforeDismissal = nil
        feeds.loadWorkItem?.cancel()
        feeds.reloadWorkItem?.cancel()
        titles.resetPendingReloadsForFeedChange()
        NSObject.cancelPreviousPerformRequests(withTarget: titles)
        for page in [pages.currentPage, pages.nextPage, pages.previousPage].compactMap({ $0 }) {
            page.webView.stopLoading()
        }
        window.isHidden = true
        window.rootViewController = nil
        app.getRequests.removeAll()
        app.postRequests.removeAll()
        UserDefaults.standard.setPersistentDomain(preferences, forName: preferenceDomain)
        UserDefaults(suiteName: "group.com.newsblur.NewsBlur-Group")?.setPersistentDomain(sharedPreferences, forName: "group.com.newsblur.NewsBlur-Group")
    }
}

private final class AuthenticationAppDelegate: NewsBlurAppDelegate {
    struct Request {
        let url: String
        let success: (URLSessionDataTask?, Any?) -> Void
        let failure: (URLSessionDataTask?, Error?) -> Void
    }
    var getRequests: [Request] = []
    var postRequests: [Request] = []
    var offlineStarts = 0
    var firstTimeUserPresentations = 0
    override func startOfflineQueue() { offlineStarts += 1 }
    override func showFirstTimeUser() { firstTimeUserPresentations += 1 }
    override var url: String! { "https://authentication-fixture.invalid" }
    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        getRequests.append(Request(url: urlString, success: success, failure: failure))
    }
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        postRequests.append(Request(url: urlString, success: success, failure: failure))
    }
    func completePOST(_ response: [String: Any]) throws { try XCTUnwrap(postRequests.first).success(nil, response) }
}

@MainActor private final class AuthenticationLoginController: LoginViewController {
    var beforeDismissal: (() -> Void)?
    var dismissals = 0
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 780))
        usernameInput = UITextField()
        passwordInput = UITextField()
        emailInput = UITextField()
        errorLabel = UILabel()
        loginControl = UISegmentedControl(items: ["Login", "Signup"])
    }
    override func viewDidLoad() {}
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        beforeDismissal?()
        dismissals += 1
        completion?()
    }
}

@MainActor private final class AuthenticationFeedsController: FeedsViewController {
    nonisolated let refreshPublication = AuthenticationRefreshPublication()
    var tableReloads = 0
    var requestFailures = 0
    override func reloadFeedTitlesTable() { tableReloads += 1; super.reloadFeedTitlesTable() }
    @objc(dispatchFeedRefreshPublication:) nonisolated func scheduleRefreshPublication(_ block: @escaping () -> Void) {
        refreshPublication.schedule(block)
    }
    @objc(requestFailed:) func observeRequestFailure(_ error: NSError) {
        requestFailures += 1
        let selector = NSSelectorFromString("requestFailed:")
        typealias Call = @convention(c) (AnyObject, Selector, NSError) -> Void
        let implementation = class_getMethodImplementation(FeedsObjCViewController.self, selector)!
        unsafeBitCast(implementation, to: Call.self)(self, selector, error)
    }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 780)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
}

@MainActor private final class AuthenticationTitlesController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { false }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 780)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func scrollViewDidScroll(_ scrollView: UIScrollView!) {}
}

@MainActor private final class AuthenticationDetailController: DetailViewController {
    override var isPhoneOrCompact: Bool { isCompact }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 1024, height: 780)) }
    override func viewDidLoad() {}
}

@MainActor private final class AuthenticationPagesController: StoryPagesViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 780)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func updateStoryTitleNavigationButtons() {}
    override func setTextButton() {}
}

@MainActor private final class AuthenticationStoryController: StoryDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 780)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    deinit { webView = nil }
}

// AuthenticationResetTests.swift holds only the scheduler boundary; the response parsing and publication remain production code.
private final class AuthenticationRefreshPublication: @unchecked Sendable {
    private let lock = NSLock()
    private var queued: XCTestExpectation?
    private var pending: [() -> Void] = []
    func hold(until expectation: XCTestExpectation) { lock.lock(); queued = expectation; lock.unlock() }
    func schedule(_ publication: @escaping () -> Void) {
        lock.lock()
        let expectation = queued
        if expectation != nil { pending.append(publication) }
        lock.unlock()
        if let expectation { expectation.fulfill() }
        else { DispatchQueue.main.async(execute: publication) }
    }
    func release() {
        lock.lock()
        let callbacks = pending
        pending.removeAll()
        queued = nil
        lock.unlock()
        callbacks.forEach { $0() }
    }
}
