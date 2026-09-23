import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedSubscriptionRouting: XCTestCase {
    func test_feedLinkIsAcceptedWhileWaitingForLogin() throws {
        let app = SubscriptionRoutingAppDelegate()
        app.activeUsername = nil
        XCTAssertTrue(app.open(URL(string: "feed:https://ngrislain.github.io/feed.xml")!))
    }
}

@MainActor final class Test_FeedSubscriptionLifecycle: XCTestCase {
    private var sharedSubscriptionDefaultsForTest: UserDefaults?
    private func makeApp() -> SubscriptionRoutingAppDelegate {
        let app = SubscriptionRoutingAppDelegate()
        app.subscriptionDefaults = sharedSubscriptionDefaultsForTest
        app.feedsViewController = FeedsViewController()
        app.feedsViewController.appDelegate = app
        app.detailViewController = DetailViewController()
        app.detailViewController.appDelegate = app
        app.feedDetailViewController.appDelegate = app
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.dictFeeds = [:]
        return app
    }

    func test_waitsForAuthenticatedFeedListThenSubscribesAtTopLevel() {
        let app = makeApp()
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        XCTAssertTrue(coordinator.accept(URL(string: "feed:https://example.com/rss")!))
        XCTAssertNil(app.subscriptionParameters)
        app.activeUsername = "reader"
        coordinator.resume()
        XCTAssertNil(app.subscriptionParameters)
        coordinator.feedsDidLoad()
        XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/rss")
        XCTAssertEqual(app.subscriptionParameters?["folder"] as? String, "")
    }

    func test_emptyAuthenticatedFeedListResumesFirstSubscription() {
        let preferences = UserDefaults.standard
        let previousUsername = preferences.object(forKey: "active_username")
        defer {
            if let previousUsername { preferences.set(previousUsername, forKey: "active_username") }
            else { preferences.removeObject(forKey: "active_username") }
        }
        for (offline, finished, expectedRequests) in [(false, true, 1), (false, false, 0), (true, true, 0)] {
            let app = makeApp()
            let feeds = EmptySubscriptionFeedListController()
            feeds.appDelegate = app
            feeds.isOffline = offline
            app.feedsViewController = feeds
            XCTAssertTrue(app.open(URL(string: "feed:https://example.com/first-feed.xml")!))
            XCTAssertEqual(app.subscriptionRequests, 0)
            let result: NSDictionary = [
                "user": "new-reader", "feeds": [:], "inactive_feeds": [:], "social_feeds": [],
                "flat_folders_with_inactive": [:], "user_profile": [:], "saved_searches": [],
                "starred_count": 0, "categories": NSNull(),
            ]
            // AppDelegateHelperTests.swift exercises the production empty-feed branch, including its first-time-user return.
            let selector = NSSelectorFromString("finishLoadingFeedListWithDict:finished:")
            typealias FinishFeedList = @convention(c) (AnyObject, Selector, NSDictionary, Bool) -> Void
            let finish = unsafeBitCast(feeds.method(for: selector), to: FinishFeedList.self)
            finish(feeds, selector, result, finished)

            XCTAssertEqual(app.activeUsername, "new-reader")
            XCTAssertTrue(app.hasNoSites)
            XCTAssertEqual(app.firstTimeUserPresentations, offline ? 0 : 1)
            XCTAssertEqual(app.subscriptionRequests, expectedRequests,
                           "Only a completed authenticated feed list may resume the queued first subscription")
            if expectedRequests == 1 {
                XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/first-feed.xml")
            }
        }
    }

    func test_expiredSubscriptionSessionResumesLatestURLAfterLogin() {
        for hasNewerURL in [false, true] {
            let app = makeApp()
            app.activeUsername = "reader"
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
            if hasNewerURL { XCTAssertTrue(app.open(URL(string: "feeds://example.com/second")!)) }
            app.failSubscriptionWithExpiredSession()
            XCTAssertEqual(app.loginPresentations, 1)
            XCTAssertEqual(app.subscriptionRequests, 1)
            app.resumeFeedSubscription()
            XCTAssertEqual(app.subscriptionRequests, 1, "An expired session must wait for authenticated feed readiness")

            app.activeUsername = "reader"
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.subscriptionRequests, 2)
            XCTAssertEqual(app.subscriptionParameters?["url"] as? String,
                           hasNewerURL ? "https://example.com/second" : "https://example.com/first")
            app.completeSubscription(["code": 1, "feed": ["id": 123]])
            app.dictFeeds = ["123": ["id": 123]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["123"])
        }
    }

    func test_errorAndMalformedSuccessDoNotNavigateOrReload() {
        for response: [String: Any] in [["code": -1, "message": "No feed found"], ["code": 1]] {
            let app = makeApp()
            app.activeUsername = "reader"
            let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
            coordinator.feedsDidLoad()
            XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/rss")!))
            app.completeSubscription(response)
            XCTAssertEqual(app.feedReloads, 0)
        }
    }

    func test_existingSubscriptionRefreshesBeforeOpening() {
        let app = makeApp()
        app.activeUsername = "reader"
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        coordinator.feedsDidLoad()
        XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/rss")!))
        app.completeSubscription(["code": 1, "feed": ["id": 123]])
        XCTAssertEqual(app.feedReloads, 1)
        XCTAssertTrue(app.openedFeedIDs.isEmpty)
        app.dictFeeds = ["123": ["id": 123]]
        coordinator.feedsDidLoad()
        XCTAssertEqual(app.openedFeedIDs, ["123"])
        coordinator.resume()
        XCTAssertEqual(app.openedFeedIDs, ["123"])
    }

    func test_subscriptionOpensReadFeedWithoutResumingOldRiverOrStoryLookup() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        app.activeUsername = "reader"
        app.storiesCollection.isRiverView = true
        app.storiesCollection.activeFolder = "everything"
        app.storiesCollection.inSearch = true
        app.storiesCollection.searchQuery = "old search"
        app.inFindingStoryMode = true
        app.tryFeedFeedId = "999"
        app.tryFeedStoryId = "999:old"
        app.pendingDailyBriefingStoryHash = "briefing:old"
        app.detailViewController.storyTitlesInDashboard = true
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        coordinator.feedsDidLoad()
        XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/rss")!))
        app.completeSubscription(["code": 1, "feed": ["id": 123]])
        app.dictFeeds = ["123": ["id": 123, "nt": 0, "ps": 0, "ng": 0]]
        coordinator.feedsDidLoad()

        XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "123")
        XCTAssertEqual(app.storiesCollection.activeReadFilter, "all")
        XCTAssertFalse(app.storiesCollection.isRiverView)
        XCTAssertFalse(app.storiesCollection.inSearch)
        XCTAssertFalse(app.detailViewController.storyTitlesInDashboard)
        XCTAssertFalse(app.inFindingStoryMode)
        XCTAssertNil(app.tryFeedFeedId)
        XCTAssertNil(app.tryFeedStoryId)
        XCTAssertNil(app.pendingDailyBriefingStoryHash)
        // AppDelegateHelperTests.swift delivers the real delayed feed-list callback after subscription navigation.
        app.backgroundLoadNotificationStory()
        XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "123")
        XCTAssertEqual(app.openedFeedIDs, ["123"])
        XCTAssertEqual(app.feedReloads, 1)
    }

    func test_accountChangeDiscardsOldSubscriptionResponse() {
        let app = makeApp()
        app.activeUsername = "first"
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        coordinator.feedsDidLoad()
        XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/rss")!))
        coordinator.resetForAccountChange()
        app.activeUsername = "second"
        coordinator.feedsDidLoad()
        app.completeSubscription(["code": 1, "feed": ["id": 123]])
        XCTAssertEqual(app.feedReloads, 0)
    }

    func test_repeatedInFlightLinkDoesNotDuplicateSubscription() {
        let app = makeApp()
        app.activeUsername = "reader"
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        coordinator.feedsDidLoad()
        let url = URL(string: "feeds://example.com/rss")!
        XCTAssertTrue(coordinator.accept(url))
        XCTAssertTrue(coordinator.accept(url))
        XCTAssertEqual(app.subscriptionRequests, 1)
        app.completeSubscription(["code": 1, "feed": ["id": 123]])
        app.dictFeeds = ["123": ["id": 123]]
        coordinator.feedsDidLoad()
        coordinator.resume()
        XCTAssertEqual(app.openedFeedIDs, ["123"])
        XCTAssertEqual(app.subscriptionRequests, 1)
    }

    func test_latestLinkWaitsForCurrentRequestAndOpensItsOwnFeed() {
        let app = makeApp()
        app.activeUsername = "reader"
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: nil)
        coordinator.feedsDidLoad()
        XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/first")!))
        XCTAssertTrue(coordinator.accept(URL(string: "feeds://example.com/second")!))
        XCTAssertEqual(app.subscriptionRequests, 1)
        app.completeSubscription(["code": 1, "feed": ["id": 123]])
        XCTAssertEqual(app.subscriptionRequests, 2)
        XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/second")
        app.completeSubscription(["code": 1, "feed": ["id": 456]])
        app.dictFeeds = ["123": ["id": 123], "456": ["id": 456]]
        coordinator.feedsDidLoad()
        XCTAssertEqual(app.openedFeedIDs, ["456"])
    }

    func test_sharedSubscriptionSurvivesTerminationBeforeRefreshCompletes() {
        let suite = "Test_FeedSubscriptionLifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = makeApp()
        app.activeUsername = "reader"
        defaults.set(["feed_id": "123", "username": "reader", "host": app.url!], forKey: "subscription:pending-feed")
        do {
            let firstLaunch = FeedSubscriptionCoordinator(app: app, defaults: defaults)
            firstLaunch.feedsDidLoad()
            firstLaunch.resume()
            firstLaunch.resume()
            XCTAssertEqual(app.feedReloads, 1)
            XCTAssertTrue(app.openedFeedIDs.isEmpty)
            XCTAssertNotNil(defaults.object(forKey: "subscription:pending-feed"))
        }
        // AppDelegateHelperTests.swift recreates the coordinator after the offline refresh never completes.
        let nextLaunch = FeedSubscriptionCoordinator(app: app, defaults: defaults)
        nextLaunch.feedsDidLoad()
        XCTAssertEqual(app.feedReloads, 2)
        app.dictFeeds = ["123": ["id": 123]]
        nextLaunch.feedsDidLoad()
        nextLaunch.resume()
        XCTAssertEqual(app.openedFeedIDs, ["123"])
        XCTAssertEqual(app.feedReloads, 2)
        XCTAssertNil(defaults.object(forKey: "subscription:pending-feed"))
    }

    func test_failedFeedListRefreshDoesNotBlockNextSubscriptionLink() {
        withSharedSubscriptionDefaults { _ in
            for status in [0, 429, 503] {
                let app = makeApp()
                app.activeUsername = "reader"
                let feeds = EmptySubscriptionFeedListController()
                feeds.appDelegate = app
                app.feedsViewController = feeds
                app.feedSubscriptionsDidLoad()
                XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
                app.completeSubscription(["code": 1, "feed": ["id": 123]])
                XCTAssertEqual(app.feedReloads, 1)

                // AppDelegateHelperTests.swift exercises the production error branches after add_url succeeds.
                feeds.completeFeedListFailure(status: status)
                XCTAssertTrue(app.open(URL(string: "feeds://example.com/second")!))
                XCTAssertEqual(app.subscriptionRequests, 2, "Failed refresh status \(status) must not lock the subscription queue")
                XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/second")
                XCTAssertTrue(app.openedFeedIDs.isEmpty)
            }
        }
    }

    func test_directSubscriptionOpensAfterFailedRefreshRecovers() {
        withSharedSubscriptionDefaults { defaults in
            let app = makeApp()
            app.activeUsername = "reader"
            let feeds = EmptySubscriptionFeedListController()
            feeds.appDelegate = app
            app.feedsViewController = feeds
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
            app.completeSubscription(["code": 1, "feed": ["id": 123]])
            feeds.completeFeedListFailure(status: 0)
            app.resumeFeedSubscription()
            XCTAssertTrue(app.openedFeedIDs.isEmpty)
            XCTAssertEqual(app.feedReloads, 1)
            XCTAssertNil(defaults.object(forKey: "subscription:pending-feed"))

            app.dictFeeds = ["123": ["id": 123]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["123"])
            XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "123")
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["123"], "Recovered direct subscriptions should open only once")
        }
    }

    func test_newLinkQueuedDuringSuccessfulRefreshSupersedesEarlierDestination() {
        withSharedSubscriptionDefaults { _ in
            let app = makeApp()
            app.activeUsername = "reader"
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
            app.completeSubscription(["code": 1, "feed": ["id": 123]])
            XCTAssertEqual(app.feedReloads, 1)
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/second")!))
            XCTAssertEqual(app.subscriptionRequests, 1)

            // AppDelegateHelperTests.swift delivers the earlier successful refresh after the newer URL was queued.
            app.dictFeeds = ["123": ["id": 123]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.subscriptionRequests, 2)
            XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/second")
            XCTAssertTrue(app.openedFeedIDs.isEmpty)

            app.completeSubscription(["code": 1, "feed": ["id": 456]])
            app.dictFeeds = ["123": ["id": 123], "456": ["id": 456]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["456"])
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["456"])
            XCTAssertEqual(app.subscriptionRequests, 2)
        }
    }

    func test_newLinkSupersedesDirectSubscriptionWaitingForRefreshRecovery() {
        withSharedSubscriptionDefaults { _ in
            let app = makeApp()
            app.activeUsername = "reader"
            let feeds = EmptySubscriptionFeedListController()
            feeds.appDelegate = app
            app.feedsViewController = feeds
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
            app.completeSubscription(["code": 1, "feed": ["id": 123]])
            feeds.completeFeedListFailure(status: 0)
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/second")!))
            app.dictFeeds = ["123": ["id": 123]]
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.openedFeedIDs.isEmpty, "A recovered older feed must not replace the newer requested feed")
            app.completeSubscription(["code": 1, "feed": ["id": 456]])
            app.dictFeeds = ["123": ["id": 123], "456": ["id": 456]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["456"])
            XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "456")
            XCTAssertEqual(app.subscriptionRequests, 2)
        }
    }

    func test_sharedSubscriptionSurvivesFailedRefreshAndRestarts() {
        withSharedSubscriptionDefaults { defaults in
            do {
                let app = makeApp()
                app.activeUsername = "reader"
                let feeds = EmptySubscriptionFeedListController()
                feeds.appDelegate = app
                app.feedsViewController = feeds
                defaults.set(["feed_id": "123", "username": "reader", "host": app.url!], forKey: "subscription:pending-feed")
                app.feedSubscriptionsDidLoad()
                XCTAssertEqual(app.feedReloads, 1)
                feeds.completeFeedListFailure(status: 0)
                XCTAssertNotNil(defaults.object(forKey: "subscription:pending-feed"))
            }
            let nextLaunch = makeApp()
            nextLaunch.activeUsername = "reader"
            nextLaunch.feedSubscriptionsDidLoad()
            XCTAssertEqual(nextLaunch.feedReloads, 1)
            XCTAssertNotNil(defaults.object(forKey: "subscription:pending-feed"))
        }
    }

    func test_sharedSubscriptionRecoversAfterTransientRefreshFailure() {
        withSharedSubscriptionDefaults { defaults in
            let app = makeApp()
            app.activeUsername = "reader"
            let feeds = EmptySubscriptionFeedListController()
            feeds.appDelegate = app
            app.feedsViewController = feeds
            defaults.set(["feed_id": "123", "username": "reader", "host": app.url!], forKey: "subscription:pending-feed")
            app.feedSubscriptionsDidLoad()
            feeds.completeFeedListFailure(status: 0)
            app.resumeFeedSubscription()
            XCTAssertEqual(app.feedReloads, 1)
            XCTAssertTrue(app.openedFeedIDs.isEmpty)
            app.dictFeeds = ["123": ["id": 123]]
            app.feedSubscriptionsDidLoad()
            XCTAssertEqual(app.openedFeedIDs, ["123"])
            XCTAssertNil(defaults.object(forKey: "subscription:pending-feed"))
        }
    }

    func test_linkQueuedDuringRefreshStartsWhenRefreshFails() {
        withSharedSubscriptionDefaults { _ in
            let app = makeApp()
            app.activeUsername = "reader"
            let feeds = EmptySubscriptionFeedListController()
            feeds.appDelegate = app
            app.feedsViewController = feeds
            app.feedSubscriptionsDidLoad()
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/first")!))
            app.completeSubscription(["code": 1, "feed": ["id": 123]])
            XCTAssertTrue(app.open(URL(string: "feeds://example.com/second")!))
            XCTAssertEqual(app.subscriptionRequests, 1)
            feeds.completeFeedListFailure(status: 0)
            XCTAssertEqual(app.subscriptionRequests, 2)
            XCTAssertEqual(app.subscriptionParameters?["url"] as? String, "https://example.com/second")
        }
    }

    func test_missingSharedFeedAfterSuccessfulRefreshDoesNotRecurAfterRestart() {
        let suite = "Test_FeedSubscriptionLifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = makeApp()
        app.activeUsername = "reader"
        defaults.set(["feed_id": "123", "username": "reader", "host": app.url!], forKey: "subscription:pending-feed")
        do {
            let firstLaunch = FeedSubscriptionCoordinator(app: app, defaults: defaults)
            firstLaunch.feedsDidLoad()
            XCTAssertNotNil(defaults.object(forKey: "subscription:pending-feed"))
            // AppDelegateHelperTests.swift distinguishes authoritative absence from an unfinished/offline refresh.
            firstLaunch.feedsDidLoad()
            XCTAssertTrue(app.openedFeedIDs.isEmpty)
            XCTAssertNil(defaults.object(forKey: "subscription:pending-feed"))
        }
        let reloads = app.feedReloads
        let nextLaunch = FeedSubscriptionCoordinator(app: app, defaults: defaults)
        nextLaunch.feedsDidLoad()
        XCTAssertEqual(app.feedReloads, reloads, "A deleted subscription must not retry its stale handoff on every launch")
    }

    private func withSharedSubscriptionDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "Test_FeedSubscriptionLifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let previous = sharedSubscriptionDefaultsForTest
        sharedSubscriptionDefaultsForTest = defaults
        defer {
            sharedSubscriptionDefaultsForTest = previous
            defaults.removePersistentDomain(forName: suite)
        }
        body(defaults)
    }

    func test_sharedSubscriptionRequiresMatchingAccountAndHost() {
        let suite = "Test_FeedSubscriptionLifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = makeApp()
        app.activeUsername = "reader"
        let coordinator = FeedSubscriptionCoordinator(app: app, defaults: defaults)
        for pending in [
            ["feed_id": "123", "username": "other", "host": app.url!],
            ["feed_id": "123", "username": "reader", "host": "https://other.example.com"],
            ["feed_id": "123", "host": app.url!]
        ] {
            defaults.set(pending, forKey: "subscription:pending-feed")
            coordinator.feedsDidLoad()
            XCTAssertEqual(app.feedReloads, 0)
        }
        defaults.set(["feed_id": "123", "username": "reader", "host": app.url!], forKey: "subscription:pending-feed")
        coordinator.resume()
        XCTAssertEqual(app.feedReloads, 1)
        XCTAssertNotNil(defaults.object(forKey: "subscription:pending-feed"))
        XCTAssertTrue(app.openedFeedIDs.isEmpty)
        app.dictFeeds = ["123": ["id": 123]]
        coordinator.feedsDidLoad()
        XCTAssertEqual(app.openedFeedIDs, ["123"])
        XCTAssertNil(defaults.object(forKey: "subscription:pending-feed"))

        defaults.set("old-token", forKey: "share:token")
        defaults.set("reader", forKey: "share:username")
        defaults.set(app.url, forKey: "share:host")
        coordinator.resetForAccountChange()
        for key in ["share:token", "share:username", "share:host", "subscription:pending-feed"] {
            XCTAssertNil(defaults.object(forKey: key))
        }
    }
}

@MainActor private final class SubscriptionRoutingAppDelegate: NewsBlurAppDelegate {
    var subscriptionDefaults: UserDefaults?
    private lazy var testSubscriptionCoordinator = FeedSubscriptionCoordinator(app: self, defaults: subscriptionDefaults)
    override func handleFeedSubscriptionURL(_ url: URL) -> Bool { testSubscriptionCoordinator.accept(url) }
    override func feedSubscriptionsDidLoad() { testSubscriptionCoordinator.feedsDidLoad() }
    override func feedSubscriptionsDidFail() { testSubscriptionCoordinator.feedsDidFail() }
    override func resumeFeedSubscription() { testSubscriptionCoordinator.resume() }
    override func resetFeedSubscriptionForAccountChange() { testSubscriptionCoordinator.resetForAccountChange() }
    private let subscriptionFeedDetail = FeedDetailViewController()
    override var feedDetailViewController: FeedDetailViewController! { subscriptionFeedDetail }
    var useRealFeedNavigation = false
    var subscriptionRequests = 0
    var subscriptionParameters: [String: Any]?
    var subscriptionSuccess: ((URLSessionDataTask, Any?) -> Void)?
    var subscriptionFailure: ((URLSessionDataTask?, Error) -> Void)?
    var loginPresentations = 0
    override func showLogin() {
        loginPresentations += 1
        resetFeedSubscriptionForAccountChange()
        activeUsername = nil
    }
    var firstTimeUserPresentations = 0
    override func showFirstTimeUser() { firstTimeUserPresentations += 1 }
    var feedReloads = 0
    var openedFeedIDs: [String] = []

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
        subscriptionRequests += 1
        subscriptionParameters = parameters as? [String: Any]
        subscriptionSuccess = success
        subscriptionFailure = failure
    }

    override func reloadFeedsView(_ showLoader: Bool) { feedReloads += 1 }

    override func popToRoot(completion: (() -> Void)!) { completion?() }

    override func loadFeed(_ feedId: String!, withStory contentId: String!, animated: Bool) {
        openedFeedIDs.append(feedId)
        if useRealFeedNavigation { super.loadFeed(feedId, withStory: contentId, animated: animated) }
    }

    @objc(presentFeedDetailAfterFeedSelection)
    func recordSubscriptionPresentation() {}

    override func loadFolder(_ folder: String!, feedID feedIdStr: String!) {
        openedFeedIDs.append(feedIdStr)
        super.loadFolder(folder, feedID: feedIdStr)
    }

    override func loadFeedDetailView() {}
    override func cleanUpTryFeed() {}
    override func openDailyBriefing(withStoryHash storyHash: String!) {}
    override func loadRiverFeedDetailView(_ feedDetailView: FeedDetailViewController!, withFolder folder: String!) {}

    func failSubscriptionWithExpiredSession() {
        subscriptionFailure?(SubscriptionUnauthorizedTask(), NSError(domain: "Test_Subscription", code: 403))
    }

    func completeSubscription(_ response: [String: Any]) {
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        subscriptionSuccess?(task, response)
        task.cancel()
    }
}

private final class SubscriptionUnauthorizedTask: URLSessionDataTask, @unchecked Sendable {
    override var response: URLResponse? {
        HTTPURLResponse(url: URL(string: "https://example.com/reader/add_url")!, statusCode: 403, httpVersion: nil, headerFields: nil)
    }
}

@MainActor private final class EmptySubscriptionFeedListController: FeedsViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 780)) }
    override func viewDidLoad() {}
    override func updateSidebarButton() {}
    override func calculateFeedLocations() {}
    override func reloadFeedTitlesTable() {}
    override func refreshHeaderCounts() {}
    override func layoutHeaderCounts(_ orientation: UIInterfaceOrientation) {}
    override func loadNotificationStory() {}
    override func showOfflineNotifier() {}
    override func informError(_ error: Any!) {}
    @objc(finishRefresh) func recordFinishedRefresh() {}

    func completeFeedListFailure(status: Int) {
        let selector = NSSelectorFromString("finishedWithError:statusCode:")
        typealias FinishFailure = @convention(c) (AnyObject, Selector, NSError, Int) -> Void
        let finish = unsafeBitCast(method(for: selector), to: FinishFailure.self)
        finish(self, selector, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet), status)
    }

}

@MainActor final class Test_FeedFilterAccessibility: XCTestCase {
    func test_iPhoneSEWidthKeepsTheLabeledIntelligenceFilters() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        controller.viewDidLayoutSubviews()
        // AppDelegateHelperTests.swift resolves the storyboard's margin-relative constraints without a host window.
        let leading = controller.view.layoutMargins.left + controller.toolbarLeadingConstraint.constant
        let trailing = controller.view.layoutMargins.right + controller.toolbarTrailingConstraint.constant
        controller.feedViewToolbar.frame = CGRect(x: leading, y: 0, width: 375 - leading - trailing, height: 48)
        controller.layout(for: .portrait)
        let control = try XCTUnwrap(controller.intelligenceControl)
        // AppDelegateHelperTests.swift requires the original text-bearing images at iPhone SE width.
        XCTAssertEqual(control.widthForSegment(at: 1), 68)
        XCTAssertEqual(control.widthForSegment(at: 2), 62)
        XCTAssertEqual(control.widthForSegment(at: 3), 60)
    }

    func test_loadingSidebarKeepsImageFiltersAccessible() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)

        // AppDelegateHelperTests.swift exercises the startup path that crashed on newer UIKit segment layouts.
        controller.loadViewIfNeeded()

        let control = try XCTUnwrap(controller.intelligenceControl)
        XCTAssertEqual(control.numberOfSegments, 4)
        for (index, label) in [(1, "Unread"), (2, "Focus"), (3, "Saved")] {
            let image = try XCTUnwrap(control.imageForSegment(at: index))
            XCTAssertEqual(image.accessibilityLabel, label)
            control.selectedSegmentIndex = index
            XCTAssertEqual(control.selectedSegmentIndex, index)
        }
    }
}

final class AppDelegateHelperTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "default_scroll_read_filter",
        "default_mark_read_filter",
        "release",
        "custom_domain",
        "default_feed_read_filter",
        "story_titles_style",
    ]
    private var savedValues: [String: Any] = [:]
    private var bundleID: String { Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? "" }

    /// Read a user-set value from the persistent domain, excluding registered
    /// defaults that Settings.bundle adds at launch. Tests that assert "the
    /// migration did not write" must use this; `defaults.object(forKey:)` also
    /// returns the registered `scroll` default.
    private func userValue(_ key: String) -> Any? {
        return defaults.persistentDomain(forName: bundleID)?[key]
    }

    override func setUp() {
        super.setUp()

        for key in keys {
            if let value = defaults.object(forKey: key) {
                savedValues[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            defaults.removeObject(forKey: key)
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            }
        }

        savedValues.removeAll()
        super.tearDown()
    }

    func test_upgradeSettings_migratesLegacyScrollFalseToSelection() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_fadeSelectionWithNoSelectedRowAfterFoldersAreCleared() {
        let app = NewsBlurAppDelegate()
        app.dictFoldersArray = []
        app.dictFolders = [:]
        let controller = FeedsViewController()
        controller.appDelegate = app
        let table = FeedFadeSelectionTable()
        controller.feedTitlesTable = table

        controller.fadeSelectedCell()

        XCTAssertEqual(table.rowReloads, 0)
    }

    func test_feedToolbarLayoutWaitsForItsOutlets() {
        let controller = FeedsViewController()
        controller.appDelegate = NewsBlurAppDelegate()
        controller.view = UIView()

        controller.layout(for: .portrait)

        XCTAssertNil(controller.feedViewToolbar)
    }

    func test_feedToolbarLayoutPopulatesConnectedOutlets() {
        let controller = FeedsViewController()
        controller.appDelegate = NewsBlurAppDelegate()
        controller.view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let toolbar = UIToolbar()
        let intelligence = UISegmentedControl(items: ["All", "Unread", "Focus", "Saved"])
        let add = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        let settings = UIBarButtonItem(title: "Settings", style: .plain, target: nil, action: nil)
        controller.feedViewToolbar = toolbar
        controller.intelligenceControl = intelligence
        controller.addBarButton = add
        controller.settingsBarButton = settings

        controller.layout(for: .portrait)

        XCTAssertEqual(toolbar.items?.filter { $0 === add }.count, 1)
        XCTAssertEqual(toolbar.items?.filter { $0 === settings }.count, 1)
        XCTAssertEqual(toolbar.items?.filter { $0.customView === intelligence }.count, 1)
        // AppDelegateHelperTests.swift keeps the primary feed actions outside overflow and edge-aligned.
        XCTAssertTrue(toolbar.items?.first === add, "Add must be the leading toolbar item")
        XCTAssertTrue(toolbar.items?.last === settings, "Settings must be the trailing toolbar item")
    }

    func test_feedFilterFitsNarrowToolbarAndRestoresLabelsAfterResize() {
        let controller = FeedsViewController()
        controller.appDelegate = NewsBlurAppDelegate()
        controller.view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let toolbar = UIToolbar()
        let intelligence = UISegmentedControl(items: ["All", "", "", ""])
        controller.feedViewToolbar = toolbar
        controller.intelligenceControl = intelligence
        controller.addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        controller.settingsBarButton = UIBarButtonItem(title: "Settings", style: .plain, target: nil, action: nil)

        // AppDelegateHelperTests.swift covers ClayPad's sidebar, ClayPhone, and a wider phone in both directions.
        for width: CGFloat in [288, 359, 374, 288] {
            toolbar.frame = CGRect(x: 0, y: 0, width: width, height: 48)
            controller.layout(for: .portrait)
            let segmentWidth = (0..<4).reduce(CGFloat.zero) { $0 + intelligence.widthForSegment(at: $1) }
            if #available(iOS 27.0, *) {
                XCTAssertLessThanOrEqual(segmentWidth, width - 144 + 0.01)
                XCTAssertEqual(segmentWidth, width >= 374 ? 230 : min(165, width - 144), accuracy: 0.01)
            } else {
                XCTAssertEqual(segmentWidth, width < 352 ? 165 : 230, accuracy: 0.01)
            }
            XCTAssertEqual(intelligence.numberOfSegments, 4)
            for index in 0..<4 {
                XCTAssertGreaterThanOrEqual(intelligence.widthForSegment(at: index), 34)
            }
        }
    }

    func test_fadeSelectionAfterSelectedFolderIsRemoved() {
        let app = NewsBlurAppDelegate()
        app.dictFoldersArray = ["Feeds"]
        app.dictFolders = ["Feeds": [1]]
        let controller = FeedsViewController()
        controller.appDelegate = app
        let table = FeedFadeSelectionTable()
        table.selectedPath = IndexPath(row: 0, section: 1)
        controller.feedTitlesTable = table

        controller.fadeSelectedCell()

        XCTAssertEqual(table.rowReloads, 0)
    }

    func test_fadeSelectionAfterSelectedRowOrFolderContentsAreRemoved() {
        let app = NewsBlurAppDelegate()
        app.dictFoldersArray = ["Feeds"]
        app.dictFolders = ["Feeds": [1]]
        let controller = FeedsViewController()
        controller.appDelegate = app
        let table = FeedFadeSelectionTable()
        controller.feedTitlesTable = table

        for path in [IndexPath(row: 1, section: 0), IndexPath(row: NSNotFound, section: 0),
                     IndexPath(row: 0, section: NSNotFound)] {
            table.selectedPath = path
            controller.fadeSelectedCell()
        }
        app.dictFolders = [:]
        table.selectedPath = IndexPath(row: 0, section: 0)
        controller.fadeSelectedCell()

        XCTAssertEqual(table.rowReloads, 0)
    }

    func test_upgradeSettings_migratesLegacyScrollTrueToScroll() {
        defaults.set(true, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "scroll")
    }

    func test_upgradeSettings_doesNotWriteMarkReadWhenLegacyKeyAbsent() {
        // Fresh install: no old boolean key. Migration must NOT force "selection",
        // which would override the Settings.bundle default of "scroll".
        AppDelegateHelper.shared.upgradeSettings(from: 0)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_upgradeSettings_doesNotOverwriteExistingMarkReadValue() {
        defaults.set(true, forKey: "default_scroll_read_filter")
        defaults.set("selection", forKey: "default_mark_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_storiesCollectionTitlesGoodReadsRiver() {
        let storiesCollection = StoriesCollection()
        storiesCollection.isRiverView = true
        storiesCollection.activeFolder = "trending:good_reads"

        XCTAssertEqual(storiesCollection.activeTitle, "Good Reads")
    }

    func test_upgradeSettings_doesNotMigrateWhenAlreadyPastMigrationRelease() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 154)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_applyReleaseUpgrade_readsPreviousReleaseBeforeOverwriting() {
        // Simulate a device that last ran an old build (release 120) and is
        // now launching build 328. The migration must see 120 and run.
        defaults.set(120, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
    }

    func test_applyReleaseUpgrade_skipsMigrationWhenStoredReleaseAlreadyPastThreshold() {
        defaults.set(200, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertNil(userValue("default_mark_read_filter"))
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
    }

    func test_appDelegateURL_normalizesCustomDomainToOrigin() {
        defaults.set("  newsblur.local:8443/reader?foo=bar  ", forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, "https://newsblur.local:8443")
        XCTAssertEqual(appDelegate.host, "newsblur.local")
    }

    func test_appDelegateURL_fallsBackToDefaultWhenCustomDomainIsInvalid() {
        defaults.removeObject(forKey: "custom_domain")
        let defaultURL = NewsBlurAppDelegate().url

        defaults.set("https://", forKey: "custom_domain")
        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, defaultURL)
    }

    func test_feedMetadataForStoryFallsBackToActiveFeedsForSupplementalStoryFeeds() {
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.dictFeeds = NSMutableDictionary()
        appDelegate.dictActiveFeeds = NSMutableDictionary(dictionary: [
            "42": [
                "id": "42",
                "feed_title": "Unsubscribed Source",
                "favicon_fade": "707070",
                "favicon_color": "505050",
            ],
        ])

        let feed = appDelegate.feedMetadata(forStory: ["story_feed_id": "42"], preferActiveFeeds: false)

        XCTAssertEqual(feed?["feed_title"] as? String, "Unsubscribed Source")
    }

    func test_feedMetadataForStoryPrefersSubscribedFeedForNormalRiverRows() {
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.dictFeeds = NSMutableDictionary(dictionary: [
            "42": [
                "id": "42",
                "feed_title": "Subscribed Source",
            ],
        ])
        appDelegate.dictActiveFeeds = NSMutableDictionary(dictionary: [
            "42": [
                "id": "42",
                "feed_title": "Supplemental Source",
            ],
        ])

        let feed = appDelegate.feedMetadata(forStory: ["story_feed_id": "42"], preferActiveFeeds: false)

        XCTAssertEqual(feed?["feed_title"] as? String, "Subscribed Source")
    }

    func test_setCustomDomainForTesting_doesNotPersistFakeDomainIntoUserDefaults() {
        defaults.removeObject(forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()
        appDelegate.setCustomDomainForTesting("https://ui-test.newsblur.example")

        XCTAssertEqual(appDelegate.url, "https://ui-test.newsblur.example")
        let bundleIdentifier = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persistedValue = defaults.persistentDomain(forName: bundleIdentifier)?["custom_domain"]
        XCTAssertNil(persistedValue)
    }

    func test_extractFolderName_treatsMissingActiveFolderAsTopLevel() {
        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.extractFolderName(nil), "")
    }

    func test_feedIdsForTopLevelRiverWithReadFilter_unread_usesModelUnreadCountsInsteadOfSidebarVisibility() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.selectedIntelligence = 0
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
            "saved_stories",
            "read_stories",
        ]
        // dictFolders["everything"] is the iOS-renamed bucket for top-level unfoldered feeds
        // (server's flat_folders_with_inactive[" "]). The river must include them.
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11, 99],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 4],
            "News": [2, 3, "saved:query"],
            "saved_stories": ["saved:1"],
            "read_stories": ["read_stories"],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 1, "nt": 0, "ng": 0],
            "3": ["ps": 0, "nt": 0, "ng": 0],
            "4": ["ps": 0, "nt": 1, "ng": 0],
            "10": ["ps": 1, "nt": 0, "ng": 0],
            "11": ["ps": 0, "nt": 0, "ng": 0],
        ]
        appDelegate.dictInactiveFeeds = [
            "4": ["id": 4],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
            "News": [0],
        ]
        feedsViewController.viewShowingAllFeeds = false

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "unread") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "1", "2"])
    }

    func test_feedIdsForTopLevelRiverWithReadFilter_all_returnsFullSubscribedFeedIds() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
        ]
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 99],
            "News": [2, 3, 4],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
        ]

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "all") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "11", "1", "2", "3", "4"])
    }

    func test_nextUnreadNavigationTitleForFeedUsesUnreadMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationKind(), "site")
        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Neutral Site")
    }

    func test_nextUnreadNavigationTitleForFeedIncludesNegativeInAllMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.viewShowingAllFeeds = true
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Negative Site")
    }

    func test_nextUnreadNavigationTitleForFeedUsesFocusMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation(selectedIntelligence: 1)
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Focus Site")
    }

    func test_nextUnreadNavigationTitleForFolderUsesAdjacentUnreadFolder() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.setValue(nil, forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(3, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationKind(), "folder")
        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "News")
    }

    func test_returningFromFeedDetailRecalculatesFeedListAfterReadingAcrossFeeds() {
        let feedsViewController = FeedListReturnTrackingViewController()
        _ = makeFeedsViewControllerForNextUnreadNavigation(feedViewController: feedsViewController)
        feedsViewController.calculateFeedLocations()
        feedsViewController.calculateFeedLocationsCount = 0
        feedsViewController.reloadFeedTitlesTableCount = 0
        feedsViewController.appDelegate.inFeedDetail = true
        feedsViewController.currentRowAtIndexPath = IndexPath(row: 0, section: 3)

        feedsViewController.viewWillAppear(false)

        XCTAssertEqual(feedsViewController.calculateFeedLocationsCount, 1)
        XCTAssertEqual(feedsViewController.reloadFeedTitlesTableCount, 1)
    }

    func test_canPullToNextUnreadListWaitsUntilPageFinishedEvenWhenKnownUnreadStoriesAreLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )

        XCTAssertFalse(feedDetailViewController.canPullToNextUnreadList())
    }

    func test_canPullToNextUnreadListAfterPageFinished() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )

        XCTAssertTrue(feedDetailViewController.canPullToNextUnreadList())
    }

    func test_checkScrollContinuesFetchingUntilPageFinishedEvenWhenKnownUnreadStoriesAreLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedDetailViewController: BottomNextFeedPagingViewController()
        ) as! BottomNextFeedPagingViewController
        setBottomScrollPosition(feedDetailViewController)

        feedDetailViewController.checkScroll()

        XCTAssertEqual(feedDetailViewController.fetchedFeedPages, [2])
        XCTAssertTrue(feedDetailViewController.pageFetching)
    }

    func test_checkScrollStillFetchesWhenKnownUnreadStoriesAreNotLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 2, "ng": 0],
            feedDetailViewController: BottomNextFeedPagingViewController()
        ) as! BottomNextFeedPagingViewController
        setBottomScrollPosition(feedDetailViewController)

        feedDetailViewController.checkScroll()

        XCTAssertEqual(feedDetailViewController.fetchedFeedPages, [2])
        XCTAssertTrue(feedDetailViewController.pageFetching)
    }

    func test_bottomNextFeedStartsWhenEndRowCrossesScrollReadProbe() throws {
        defaults.set("scroll", forKey: "default_mark_read_filter")
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )
        prepareBottomNextFeedTable(feedDetailViewController)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 59)

        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)

        let control = try XCTUnwrap(feedDetailViewController.value(forKey: "bottomNextFeedControl") as? UIView)
        XCTAssertFalse(control.isHidden)
        XCTAssertGreaterThan(control.alpha, 0)
        XCTAssertLessThan(control.alpha, 1)
        XCTAssertTrue(feedDetailViewController.view.bounds.intersects(control.frame))
    }

    func test_bottomNextFeedOpensWhenReleasedWhileActivelyReady() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 112)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 1)
    }

    func test_bottomNextFeedDoesNotOpenBeforeLowerActivationPoint() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 48)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_bottomNextFeedDoesNotOpenWhenMomentumCrossesThreshold() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 90)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: false)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 48)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDecelerating(feedDetailViewController.storyTitlesTable)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_bottomNextFeedStaysVisibleButInactiveDuringMomentum() throws {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        setBottomNextFeedActiveDrag(feedDetailViewController, active: false)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 48)

        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDecelerating(feedDetailViewController.storyTitlesTable)

        let control = try XCTUnwrap(feedDetailViewController.value(forKey: "bottomNextFeedControl") as? UIView)
        XCTAssertFalse(control.isHidden)
        // AppDelegateHelperTests.swift separates a fully revealed control from one armed by an active drag.
        XCTAssertEqual(control.alpha, 1)
        XCTAssertEqual(feedDetailViewController.value(forKey: "bottomNextFeedReady") as? Bool, false)
        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_bottomNextFeedPressOpensVisibleTargetOnReleaseInside() throws {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 48)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)

        let control = try XCTUnwrap(feedDetailViewController.value(forKey: "bottomNextFeedControl") as? UIControl)
        XCTAssertFalse(control.isHidden)

        control.sendActions(for: .touchDown)

        XCTAssertEqual(feedDetailViewController.value(forKey: "bottomNextFeedReady") as? Bool, true)
        XCTAssertEqual(control.alpha, 1)
        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)

        control.sendActions(for: .touchUpInside)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 1)
    }

    func test_bottomNextFeedPressCancelsWhenReleasedOutside() throws {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 48)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)

        let control = try XCTUnwrap(feedDetailViewController.value(forKey: "bottomNextFeedControl") as? UIControl)
        XCTAssertFalse(control.isHidden)

        control.sendActions(for: .touchDown)
        XCTAssertEqual(feedDetailViewController.value(forKey: "bottomNextFeedReady") as? Bool, true)

        control.sendActions(for: .touchDragExit)
        control.sendActions(for: .touchUpOutside)

        XCTAssertEqual(feedDetailViewController.value(forKey: "bottomNextFeedReady") as? Bool, false)
        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_bottomNextFeedStartsEngagementFromActiveDragAfterMomentum() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 20,
            unreadCounts: ["ps": 0, "nt": 20, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)
        feedDetailViewController.storyTitlesTable.contentInset.bottom = 1_200

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        let momentumEndOffset = endRowTop + 80

        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: momentumEndOffset)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: momentumEndOffset + 24)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        let activeDragStartOffset = feedDetailViewController.value(forKey: "bottomNextFeedActiveDragStartOffsetY") as? NSNumber
        let hasActiveDragStartOffset = feedDetailViewController.value(forKey: "hasBottomNextFeedActiveDragStartOffset") as? Bool
        let bottomNextFeedReady = feedDetailViewController.value(forKey: "bottomNextFeedReady") as? Bool
        XCTAssertEqual(feedDetailViewController.storyTitlesTable.contentOffset.y, momentumEndOffset + 24, accuracy: 0.5)
        XCTAssertEqual(activeDragStartOffset?.doubleValue ?? -1, momentumEndOffset, accuracy: 0.5)
        XCTAssertEqual(hasActiveDragStartOffset, true)
        XCTAssertEqual(bottomNextFeedReady, false)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)

        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: momentumEndOffset)
        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: momentumEndOffset + 112)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 1)
    }

    func test_bottomNextFeedCanBeDisarmedBeforeRelease() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        prepareBottomNextFeedTable(feedDetailViewController)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 112)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 90)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_toggleAuthorClassifierFromStoryDetail_cyclesPositiveNegativeNeutral() {
        let appDelegate = ClassifierToggleAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "authors": [
                    "Jane": 1,
                ],
            ],
        ]

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), -1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["dislike_author"] as? String, "Jane")

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_author"] as? String, "Jane")

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["like_author"] as? String, "Jane")

        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "authors": [
                    "Jane": -2,
                ],
            ],
        ]
        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_author"] as? String, "Jane")
    }

    func test_toggleTagClassifierFromStoryDetail_cyclesPositiveNegativeNeutral() {
        let appDelegate = ClassifierToggleAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "tags": [
                    "swift": 1,
                ],
            ],
        ]

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), -1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["dislike_tag"] as? String, "swift")

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_tag"] as? String, "swift")

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["like_tag"] as? String, "swift")

        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "tags": [
                    "swift": -2,
                ],
            ],
        ]
        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_tag"] as? String, "swift")
    }

    private func classifierScore(_ appDelegate: NewsBlurAppDelegate, feedId: String, key: String, value: String) -> Int? {
        let feedClassifiers = appDelegate.storiesCollection.activeClassifiers[feedId] as? [String: Any]
        let classifiers = feedClassifiers?[key] as? [String: Any]
        return classifiers?[value] as? Int
    }

    private func makeFeedsViewControllerForNextUnreadNavigation(
        selectedIntelligence: Int = 0,
        feedViewController: FeedsViewController = FeedsViewController()
    ) -> FeedsViewController {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = feedViewController
        let tableView = UITableView(frame: .zero, style: .plain)

        appDelegate.feedsViewController = feedsViewController
        appDelegate.selectedIntelligence = selectedIntelligence
        appDelegate.dictFoldersArray = [
            "dashboard",
            "daily_briefing",
            "infrequent",
            "Tech",
            "News",
        ]
        appDelegate.dictFolders = [
            "dashboard": [],
            "daily_briefing": [],
            "infrequent": [],
            "Tech": [1, 2, 3, 4],
            "News": [5],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1, "feed_title": "Current Site", "active": 1],
            "2": ["id": 2, "feed_title": "Negative Site", "active": 1],
            "3": ["id": 3, "feed_title": "Neutral Site", "active": 1],
            "4": ["id": 4, "feed_title": "Focus Site", "active": 1],
            "5": ["id": 5, "feed_title": "News Site", "active": 1],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 0, "nt": 0, "ng": 1],
            "3": ["ps": 0, "nt": 1, "ng": 0],
            "4": ["ps": 1, "nt": 0, "ng": 0],
            "5": ["ps": 0, "nt": 1, "ng": 0],
        ]
        appDelegate.dictInactiveFeeds = [:]
        appDelegate.collapsedFolders = [:]
        appDelegate.folderCountCache = nil

        feedsViewController.appDelegate = appDelegate
        feedsViewController.feedTitlesTable = tableView
        feedsViewController.visibleFolders = NSMutableDictionary(dictionary: [
            "Tech": true,
            "News": true,
        ])
        feedsViewController.viewShowingAllFeeds = false
        tableView.dataSource = feedsViewController
        tableView.delegate = feedsViewController
        tableView.reloadData()

        return feedsViewController
    }

    private func makeFeedDetailViewControllerForBottomNextFeed(
        pageFinished: Bool,
        activeStoriesCount: Int,
        unreadCounts: [String: Int],
        feedsViewController: FeedsViewController = FeedsViewController(),
        feedDetailViewController: FeedDetailViewController = FeedDetailViewController()
    ) -> FeedDetailViewController {
        defaults.set("unread", forKey: "default_feed_read_filter")
        defaults.set("standard", forKey: DetailViewController.Key.style)

        let appDelegate = NewsBlurAppDelegate()
        let detailViewController = DetailViewController()
        let storiesCollection = StoriesCollection()

        appDelegate.detailViewController = detailViewController
        appDelegate.feedsViewController = feedsViewController
        appDelegate.storiesCollection = storiesCollection
        appDelegate.dictFeeds = ["1": ["id": 1, "active": 1, "feed_title": "Low Count Site"]]
        appDelegate.dictUnreadCounts = ["1": unreadCounts]
        appDelegate.selectedIntelligence = 0

        detailViewController.appDelegate = appDelegate
        feedsViewController.appDelegate = appDelegate
        feedsViewController.viewShowingAllFeeds = false

        storiesCollection.appDelegate = appDelegate
        storiesCollection.activeFeed = ["id": 1, "active": 1, "feed_title": "Low Count Site"]
        storiesCollection.activeFolder = "Tech"
        storiesCollection.feedPage = 1
        storiesCollection.setStories((0..<activeStoriesCount).map { index in
            [
                "story_hash": "story-\(index)",
                "story_feed_id": 1,
                "read_status": 0,
            ]
        })

        feedDetailViewController.appDelegate = appDelegate
        feedDetailViewController.storiesCollection = storiesCollection
        feedDetailViewController.storyTitlesTable = BottomNextFeedTestTableView(frame: .zero, style: .plain)
        feedDetailViewController.messageView = UIView()
        feedDetailViewController.messageView.isHidden = true
        feedDetailViewController.pageFetching = false
        feedDetailViewController.pageFinished = pageFinished

        return feedDetailViewController
    }

    private func setBottomScrollPosition(_ feedDetailViewController: FeedDetailViewController) {
        feedDetailViewController.storyTitlesTable.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.contentSize = CGSize(width: 320, height: 900)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: 260)
    }

    private func prepareBottomNextFeedTable(_ feedDetailViewController: FeedDetailViewController) {
        feedDetailViewController.view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        feedDetailViewController.storyTitlesTable.frame = feedDetailViewController.view.bounds
        feedDetailViewController.storyTitlesTable.dataSource = feedDetailViewController
        feedDetailViewController.storyTitlesTable.delegate = feedDetailViewController
        feedDetailViewController.view.addSubview(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.storyTitlesTable.reloadData()
        feedDetailViewController.storyTitlesTable.layoutIfNeeded()
    }

    private func setBottomNextFeedActiveDrag(_ feedDetailViewController: FeedDetailViewController, active: Bool) {
        let tableView = feedDetailViewController.storyTitlesTable as? BottomNextFeedTestTableView
        tableView?.trackingForTest = active
        tableView?.draggingForTest = active
    }
}

final class ActivityModulesLayoutTests: XCTestCase {
    func test_refreshInteractionsLoadsViewBeforeFetching() {
        let controller = makeActivitiesViewController()

        XCTAssertFalse(controller.isViewLoaded)

        controller.perform(NSSelectorFromString("refreshInteractions"))

        XCTAssertTrue(controller.isViewLoaded)
        XCTAssertNotNil(activityModule(named: "interactionsModule", tableName: "interactionsTable", on: controller))
    }

    func test_refreshActivityLoadsViewBeforeFetching() {
        let controller = makeActivitiesViewController()

        XCTAssertFalse(controller.isViewLoaded)

        controller.perform(NSSelectorFromString("refreshActivity"))

        XCTAssertTrue(controller.isViewLoaded)
        XCTAssertNotNil(activityModule(named: "activitiesModule", tableName: "activitiesTable", on: controller))
    }

    func test_interactionsModuleReusesTableAcrossLayoutPasses() {
        let module = makeModule(named: "InteractionsModule")

        module.layoutSubviews()
        module.layoutSubviews()

        XCTAssertEqual(module.subviews.compactMap { $0 as? UITableView }.count, 1)
    }

    func test_activityModuleReusesTableAcrossLayoutPasses() {
        let module = makeModule(named: "ActivityModule")

        module.layoutSubviews()
        module.layoutSubviews()

        XCTAssertEqual(module.subviews.compactMap { $0 as? UITableView }.count, 1)
    }

    private func makeModule(named className: String) -> UIView {
        let type = NSClassFromString(className) as? UIView.Type
            ?? NSClassFromString("NewsBlur.\(className)") as? UIView.Type
        guard let type else {
            XCTFail("Missing \(className)")
            return UIView(frame: .zero)
        }

        return type.init(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    private func makeActivitiesViewController() -> UIViewController {
        let type = NSClassFromString("ActivitiesViewController") as? UIViewController.Type
            ?? NSClassFromString("NewsBlur.ActivitiesViewController") as? UIViewController.Type
        guard let type else {
            XCTFail("Missing ActivitiesViewController")
            return UIViewController()
        }

        return type.init(nibName: nil, bundle: nil)
    }

    private func activityModule(named name: String, tableName: String, on controller: UIViewController) -> UIView? {
        let module = controller.value(forKey: name) as? UIView
        let table = module?.value(forKey: tableName) as? UITableView
        XCTAssertNotNil(table)
        XCTAssertEqual(module?.subviews.compactMap { $0 as? UITableView }.count, 1)
        return module
    }
}

private final class ClassifierToggleAppDelegate: NewsBlurAppDelegate {
    var savedClassifierParameters: [String: Any]?

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
        savedClassifierParameters = parameters as? [String: Any]
    }

    override func recalculateIntelligenceScores(_ feedId: Any!) {
    }
}

private final class BottomNextFeedPagingViewController: FeedDetailViewController {
    var fetchedFeedPages: [Int32] = []

    override func fetchFeedDetail(_ page: Int32, withCallback callback: (() -> Void)!) {
        fetchedFeedPages.append(page)
        pageFetching = true
        callback?()
    }
}

private final class BottomNextFeedTestTableView: UITableView {
    var trackingForTest = false
    var draggingForTest = false

    override var isTracking: Bool {
        trackingForTest
    }

    override var isDragging: Bool {
        draggingForTest
    }
}

private final class BottomNextFeedSelectionViewController: FeedsViewController {
    var selectNextUnreadFolderOrFeedCount = 0

    override func selectNextUnreadFolderOrFeed() -> Bool {
        selectNextUnreadFolderOrFeedCount += 1
        return true
    }

    override func nextUnreadNavigationKind() -> String! {
        "site"
    }

    override func nextUnreadNavigationTitle() -> String! {
        "Next Test Site"
    }

    override func nextUnreadNavigationIcon() -> UIImage! {
        nil
    }
}

private final class FeedListReturnTrackingViewController: FeedsViewController {
    var calculateFeedLocationsCount = 0
    var reloadFeedTitlesTableCount = 0

    override func calculateFeedLocations() {
        calculateFeedLocationsCount += 1
        super.calculateFeedLocations()
    }

    override func reloadFeedTitlesTable() {
        reloadFeedTitlesTableCount += 1
        super.reloadFeedTitlesTable()
    }
}

private final class FeedFadeSelectionTable: UITableView {
    var selectedPath: IndexPath?
    var rowReloads = 0
    override var indexPathForSelectedRow: IndexPath? { selectedPath }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloads += 1
    }
}
