import UIKit
import UserNotifications
import XCTest

@testable import NewsBlur

@MainActor final class Test_NotificationNavigation: XCTestCase {
#if targetEnvironment(macCatalyst)
    func test_notificationAfterClosingMacWindowWaitsForReplacementReader() throws {
        for action in [UNNotificationDefaultActionIdentifier, "VIEW_STORY_IDENTIFIER"] {
            let app = makeApp(phone: false)
            let oldReader = DetailViewController()
            app.detailViewController = oldReader
            // NotificationNavigationTests.swift reproduces Command-W retaining the reader after SceneDelegate releases its window.
            app.window = nil
            app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: action)

            XCTAssertNil(app.openedFeed, "The notification must not start a fetch on the disconnected reader")
            XCTAssertEqual(app.pendingNotificationStory?["storyHash"] as? String, "42:older-story")
            XCTAssertEqual(app.completions, 1, "The OS completion must not wait for a window or network response")

            // NotificationNavigationTests.swift delivers the delegate response before a new scene without a connection response.
            _ = try connectColdScene(content: nil, action: action, app: app)
            XCTAssertEqual(app.openedFeed, "42")
            XCTAssertEqual(app.openedHash, "42:older-story")
            XCTAssertEqual(app.navigationPreparationCounts, [1], "Navigation must run once, after replacement views are prepared")
        }
    }

    func test_feedRefreshCannotDrainNotificationWhileMacWindowIsClosed() {
        let app = makeApp(phone: false)
        app.window = nil
        app.setValue(["feedId": "42", "storyHash": "42:older-story"], forKey: "pendingNotificationStory")

        app.backgroundLoadNotificationStory()

        XCTAssertNil(app.openedFeed, "A late feed refresh must not route into the disconnected reader")
        XCTAssertEqual(app.pendingNotificationStory?["storyHash"] as? String, "42:older-story")
    }

    func test_reconnectingNotificationResponseRoutesOnceAndReplacesTheQueuedDestination() throws {
        let app = makeApp(phone: false)
        app.window = nil
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)

        _ = try connectColdScene(content: ["story_feed_id": 42, "story_hash": "42:newer-story"],
                                 action: UNNotificationDefaultActionIdentifier, app: app)

        XCTAssertEqual(app.openedHash, "42:newer-story")
        XCTAssertEqual(app.navigationPreparationCounts, [1])
    }

    func test_closedMacWindowQueuesBriefingAndKeepsBackgroundActionsImmediate() throws {
        let app = makeApp(phone: false)
        app.window = nil
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        app.receive(["story_hash": "briefing:today", "is_daily_briefing": true], action: UNNotificationDefaultActionIdentifier)
        app.backgroundLoadNotificationStory()

        XCTAssertNil(app.openedBriefing)
        XCTAssertNil(app.pendingNotificationStory)
        XCTAssertEqual(app.pendingDailyBriefingStoryHash, "briefing:today")
        XCTAssertEqual(app.completions, 2)
        for action in ["MARK_READ_IDENTIFIER", "STAR_IDENTIFIER", "DISMISS_IDENTIFIER"] {
            app.receive(["story_feed_id": 42, "story_hash": "42:background-story"], action: action)
        }
        XCTAssertEqual(app.markedRead, "42:background-story")
        XCTAssertEqual(app.savedHash, "42:background-story")
        XCTAssertEqual(app.completions, 5)
        XCTAssertNil(app.openedFeed)

        _ = try connectColdScene(content: nil, action: UNNotificationDefaultActionIdentifier, app: app)

        XCTAssertEqual(app.openedBriefing, "briefing:today")
        XCTAssertNil(app.pendingDailyBriefingStoryHash)
        XCTAssertNil(app.openedFeed)
    }
#endif

    func test_coldSceneConnectionRoutesTheNotificationAfterPreparingItsViews() throws {
        for action in [UNNotificationDefaultActionIdentifier, "VIEW_STORY_IDENTIFIER"] {
            let app = try connectColdScene(content: ["story_feed_id": 42, "story_hash": "42:older-story"], action: action)
            XCTAssertEqual(app.openedFeed, "42")
            XCTAssertEqual(app.openedHash, "42:older-story")
            XCTAssertNil(app.openedFolder)
            XCTAssertEqual(app.navigationPreparationCounts, [1], "Views must exist before scene notification navigation begins.")
        }
    }

    func test_coldSceneConnectionPreservesBriefingAndBackgroundNotificationActions() throws {
        let briefing = try connectColdScene(content: ["story_hash": "briefing:today", "is_daily_briefing": true],
                                            action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(briefing.openedBriefing, "briefing:today")
        XCTAssertNil(briefing.openedFeed)
        for action in ["MARK_READ_IDENTIFIER", "STAR_IDENTIFIER", "DISMISS_IDENTIFIER"] {
            let app = try connectColdScene(content: ["story_feed_id": 42, "story_hash": "42:older-story"], action: action)
            XCTAssertEqual(app.markedRead, action == "MARK_READ_IDENTIFIER" ? "42:older-story" : nil)
            XCTAssertEqual(app.savedHash, action == "STAR_IDENTIFIER" ? "42:older-story" : nil)
            XCTAssertNil(app.openedFeed)
            XCTAssertNil(app.openedFolder)
        }
    }

    func test_coldSceneConnectionWithoutANotificationOnlyPreparesViews() throws {
        let app = try connectColdScene(content: nil, action: UNNotificationDefaultActionIdentifier)
        XCTAssertNil(app.openedFeed)
        XCTAssertNil(app.openedHash)
        XCTAssertNil(app.openedBriefing)
    }

    func test_tappingANotificationFromAnOpenArticleDoesNotWaitForUnrelatedAnimations() async throws {
        for repeatingAnimation in [false, true] {
            try await checkRealNotificationNavigation(articleIsOpen: true, repeatingAnimation: repeatingAnimation)
        }
    }

    func test_tappingANotificationAlreadyAtTheFeedListCompletesWithoutATransition() async throws {
        try await checkRealNotificationNavigation(articleIsOpen: false, repeatingAnimation: false)
    }

    func test_defaultTapOpensTheExactFeedWhenManyFeedsHaveNotificationsEnabled() {
        for phone in [true, false] {
            let app = makeApp(phone: phone)
            app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
            XCTAssertEqual(app.openedFeed, "42")
            XCTAssertEqual(app.openedHash, "42:older-story")
            XCTAssertNil(app.openedFolder, "A notification must not search the notification river or All Site Stories.")
            XCTAssertEqual(app.completions, 1)
        }
    }

    func test_explicitViewActionUsesTheSameFeedDestination() {
        let app = makeApp()
        app.receive(["story_feed_id": "42", "story_hash": "42:older-story"], action: "VIEW_STORY_IDENTIFIER")
        XCTAssertEqual(app.openedFeed, "42")
        XCTAssertEqual(app.openedHash, "42:older-story")
        XCTAssertNil(app.openedFolder)
        XCTAssertEqual(app.completions, 1)
    }

    func test_notificationStillOpensItsFeedWhenNotificationsHaveSinceBeenDisabled() {
        let app = makeApp()
        app.dictActiveFeeds = NSMutableDictionary()
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(app.openedFeed, "42")
        XCTAssertEqual(app.openedHash, "42:older-story")
        XCTAssertNil(app.openedFolder)
        XCTAssertEqual(app.completions, 1)
    }

    func test_dailyBriefingKeepsItsOwnDestination() {
        let app = makeApp()
        app.receive(["story_hash": "briefing:today", "is_daily_briefing": true], action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(app.openedBriefing, "briefing:today")
        XCTAssertNil(app.openedFeed)
        XCTAssertNil(app.openedFolder)
        XCTAssertEqual(app.completions, 1)
    }

    func test_backgroundReadSaveAndDismissActionsDoNotNavigate() {
        for action in ["MARK_READ_IDENTIFIER", "STAR_IDENTIFIER", "DISMISS_IDENTIFIER"] {
            let app = makeApp()
            app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: action)
            XCTAssertEqual(app.markedRead, action == "MARK_READ_IDENTIFIER" ? "42:older-story" : nil)
            XCTAssertEqual(app.savedHash, action == "STAR_IDENTIFIER" ? "42:older-story" : nil)
            XCTAssertNil(app.openedFeed)
            XCTAssertNil(app.openedFolder)
            XCTAssertEqual(app.completions, 1)
        }
    }

    func test_notificationIncludesReadStoriesForTheVisitWithoutChangingTheSavedFilter() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        let stories = app.storiesCollection!
        stories.activeFeed = app.dictFeeds["42"] as? [AnyHashable: Any]
        let defaults = UserDefaults.standard
        let key = stories.readFilterKey!
        let original = defaults.object(forKey: key)
        defer { if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) } }
        defaults.set("unread", forKey: key)
        app.receive(["story_feed_id": 42, "story_hash": "42:already-read"], action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(stories.activeFeedIdStr, "42")
        XCTAssertFalse(stories.isRiverView)
        XCTAssertEqual(stories.activeReadFilter, "all", "Already-read notification stories must be included in the feed lookup.")
        XCTAssertEqual(defaults.string(forKey: key), "unread")
        app.inFindingStoryMode = false
        app.tryFeedStoryId = nil
        app.tryFeedFeedId = nil
        XCTAssertEqual(stories.activeReadFilter, "all", "Later pages must use the same filter after the requested story is selected.")
        stories.reset()
        stories.activeFeed = app.dictFeeds["42"] as? [AnyHashable: Any]
        XCTAssertEqual(stories.activeReadFilter, "unread", "Opening the feed normally restores its saved setting.")
    }

    func test_repeatedStartupAttemptsKeepTheNotificationUntilItsFeedArrives() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        let feeds = app.dictFeeds
        app.dictFeeds = NSMutableDictionary()
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(app.tryFeedFeedId, "42")
        XCTAssertEqual(app.tryFeedStoryId, "42:older-story")
        app.backgroundLoadNotificationStory()
        XCTAssertEqual(app.tryFeedFeedId, "42")
        XCTAssertEqual(app.tryFeedStoryId, "42:older-story")
        app.dictFeeds = feeds
        app.backgroundLoadNotificationStory()
        XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "42")
        XCTAssertFalse(app.storiesCollection.isRiverView)
        XCTAssertEqual(app.tryFeedStoryId, "42:older-story")
        XCTAssertEqual(app.presentationCount, 1)
    }

    func test_feedRefreshDoesNotRestartAnActiveNotificationLookup() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        app.storiesCollection.feedPage = 7
        let started = app.findingStoryStartDate
        app.backgroundLoadNotificationStory()
        XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "42")
        XCTAssertFalse(app.storiesCollection.isRiverView)
        XCTAssertEqual(app.storiesCollection.feedPage, 7)
        XCTAssertEqual(app.findingStoryStartDate, started)
        XCTAssertEqual(app.presentationCount, 1)
        XCTAssertNil(app.openedFolder)
    }

    func test_newerNotificationReplacesAPendingOlderTarget() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        app.dictFeeds = NSMutableDictionary()
        app.receive(["story_feed_id": 42, "story_hash": "42:old"], action: UNNotificationDefaultActionIdentifier)
        app.receive(["story_feed_id": 99, "story_hash": "99:new"], action: UNNotificationDefaultActionIdentifier)
        app.dictFeeds = ["42": ["id": 42, "feed_title": "Old feed", "active": 1],
                         "99": ["id": 99, "feed_title": "New feed", "active": 1]]
        app.backgroundLoadNotificationStory()
        XCTAssertEqual(app.storiesCollection.activeFeedIdStr, "99")
        XCTAssertEqual(app.tryFeedStoryId, "99:new")
        XCTAssertEqual(app.presentationCount, 1)
        XCTAssertEqual(app.completions, 2)
    }

    func test_leavingPendingNotificationPreventsLaterFeedRefreshFromReopeningIt() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        let feeds = app.dictFeeds
        app.dictFeeds = NSMutableDictionary()
        app.receive(["story_feed_id": 42, "story_hash": "42:old"], action: UNNotificationDefaultActionIdentifier)
        app.cleanUpTryFeed()
        app.dictFeeds = feeds
        app.backgroundLoadNotificationStory()
        XCTAssertNil(app.tryFeedStoryId)
        XCTAssertNil(app.storiesCollection.activeFeed)
        XCTAssertEqual(app.presentationCount, 0)
    }

    func test_normalDeepLinkAfterNotificationUsesTheSavedFilter() {
        let app = makeApp()
        app.useRealFeedNavigation = true
        let stories = app.storiesCollection!
        stories.activeFeed = app.dictFeeds["42"] as? [AnyHashable: Any]
        let key = stories.readFilterKey!
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer { if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) } }
        defaults.set("unread", forKey: key)
        app.receive(["story_feed_id": 42, "story_hash": "42:old"], action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(stories.activeReadFilter, "all")
        app.loadFeed("42", withStory: "42:new", animated: false)
        XCTAssertEqual(stories.activeReadFilter, "unread")
        XCTAssertEqual(app.tryFeedStoryId, "42:new")
    }

    func test_explicitReadFilterChoiceEndsTheNotificationOverride() throws {
        let app = makeApp()
        app.useRealFeedNavigation = true
        app.receive(["story_feed_id": 42, "story_hash": "42:old"], action: UNNotificationDefaultActionIdentifier)
        let key = app.storiesCollection.readFilterKey!
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer { if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) } }
        let reader = NotificationOptionsController()
        reader.appDelegate = app
        reader.storiesCollection = app.storiesCollection
        reader.dashboardIndex = -1
        let navigation = NotificationOptionsNavigation(rootViewController: reader)
        app.feedsNavigationController = navigation
        reader.loadViewIfNeeded()
        reader.perform(NSSelectorFromString("doOpenOptionsMenu:"), with: nil)
        let menu = try XCTUnwrap((navigation.captured as? UINavigationController)?.topViewController as? MenuViewController)
        let items = try XCTUnwrap(menu.value(forKey: "items") as? [[String: Any]])
        let filter = try XCTUnwrap(items.first { ($0["segmentTitles"] as? [String]) == ["All stories", "Unread only"] })
        XCTAssertEqual(filter["segmentIndex"] as? Int, 0)
        let handler = try XCTUnwrap(filter["handler"] as AnyObject?)
        // NotificationNavigationTests.swift invokes the real menu's selection handler after presentation is captured.
        typealias Selection = @convention(block) (UInt) -> Void
        unsafeBitCast(handler, to: Selection.self)(1)
        XCTAssertEqual(app.storiesCollection.activeReadFilter, "unread")
        XCTAssertEqual(defaults.string(forKey: key), "unread")
        XCTAssertEqual(reader.reloadCount, 1)
    }

    private func connectColdScene(content: [String: Any]?, action: String, app existingApp: NotificationNavigationApp? = nil) throws -> NotificationNavigationApp {
        let app = existingApp ?? makeApp()
        app.window = nil
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let delegate = SceneDelegate()
        delegate.appDelegate = app
        let window = UIWindow(windowScene: scene)
        delegate.window = window
        let options = NotificationSceneConnectionOptions()
        if let content {
            let notificationContent = UNMutableNotificationContent()
            notificationContent.userInfo = content
            let request = UNNotificationRequest(identifier: "cold-scene-notification", content: notificationContent, trigger: nil)
            let notificationArchive = NSKeyedArchiver(requiringSecureCoding: true)
            notificationArchive.encode(request, forKey: "request")
            notificationArchive.encode(NSDate(), forKey: "date")
            notificationArchive.finishEncoding()
            let notificationDecoder = try NSKeyedUnarchiver(forReadingFrom: notificationArchive.encodedData)
            let notification = try XCTUnwrap(UNNotification(coder: notificationDecoder))
            notificationDecoder.finishDecoding()
            XCTAssertEqual(notification.request.identifier, request.identifier)

            let responseArchive = NSKeyedArchiver(requiringSecureCoding: true)
            responseArchive.encode(notification, forKey: "notification")
            responseArchive.encode(action, forKey: "actionIdentifier")
            responseArchive.finishEncoding()
            let responseDecoder = try NSKeyedUnarchiver(forReadingFrom: responseArchive.encodedData)
            let response = try XCTUnwrap(UNNotificationResponse(coder: responseDecoder))
            responseDecoder.finishDecoding()
            XCTAssertEqual(response.actionIdentifier, action)
            XCTAssertEqual(response.notification.request.identifier, request.identifier)
            options.notificationResponse = response
        }

        // NotificationNavigationTests.swift supplies UIKit's read-only connection options to the real scene delegate entry point.
        let selector = NSSelectorFromString("scene:willConnectToSession:options:")
        typealias Connect = @convention(c) (AnyObject, Selector, UIScene, UISceneSession, AnyObject) -> Void
        let connect = unsafeBitCast(delegate.method(for: selector), to: Connect.self)
        connect(delegate, selector, scene, scene.session, options)
        XCTAssertTrue(app.window === window)
        XCTAssertEqual(app.preparationCount, 1)
        return app
    }

    private func checkRealNotificationNavigation(articleIsOpen: Bool, repeatingAnimation: Bool) async throws {
        let app = makeApp()
        app.useRealRootNavigation = true
        let feeds = NotificationNavigationScreen()
        let article = NotificationNavigationScreen()
        let navigation = UINavigationController(rootViewController: feeds)
        if articleIsOpen {
            navigation.setViewControllers([feeds, UIViewController(), article], animated: false)
        }
        app.feedsNavigationController = navigation
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = navigation
        let initialAppearance = expectation(description: "Initial navigation destination appeared")
        let initialDestination = articleIsOpen ? article : feeds
        initialDestination.appeared = { initialAppearance.fulfill() }
        window.makeKeyAndVisible()
        defer {
            app.feedOpened = nil
            feeds.view.layer.removeAllAnimations()
            CATransaction.flush()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        await fulfillment(of: [initialAppearance], timeout: SimulatorTestTiming.realWorkTimeout)
        initialDestination.appeared = nil
        feeds.repeatAnimationOnAppearance = repeatingAnimation

        let routed = expectation(description: "Notification opened its feed after returning to the feed list")
        app.feedOpened = {
            XCTAssertTrue(navigation.topViewController === feeds)
            routed.fulfill()
        }
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        // NotificationNavigationTests.swift waits for the real pop transition, which a stalled CI main thread can stretch
        // past a few seconds; the repeating animation never finishes, so waiting on it would still miss any finite budget.
        await fulfillment(of: [routed], timeout: SimulatorTestTiming.realWorkTimeout)
        XCTAssertTrue(navigation.topViewController === feeds)
        XCTAssertEqual(app.openedFeed, "42")
        XCTAssertEqual(app.openedHash, "42:older-story")
        XCTAssertEqual(app.completions, 1)
        if repeatingAnimation {
            XCTAssertNotNil(feeds.view.layer.animation(forKey: "notification-fixture-pulse"),
                            "Unrelated animation should continue independently of notification navigation.")
        }
    }

    private func makeApp(phone: Bool = true) -> NotificationNavigationApp {
        let app = NotificationNavigationApp()
        app.window = UIWindow()
        app.phone = phone
        app.activeUsername = "notification-navigation-fixture"
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.dictFeeds = ["42": ["id": 42, "feed_title": "The notified feed", "active": 1]]
        app.dictFolders = ["Parent folder": [42]]
        app.dictFoldersArray = NSMutableArray(array: ["Parent folder"])
        app.dictActiveFeeds = NSMutableDictionary(dictionary: [
            "42": ["id": 42, "feed_title": "The notified feed", "notification_types": ["ios"]],
            "99": ["id": 99, "feed_title": "Another busy feed", "notification_types": ["ios"]]
        ])
        return app
    }
}

@MainActor private final class NotificationSceneConnectionOptions: NSObject {
    @objc var notificationResponse: UNNotificationResponse?
    // NotificationNavigationTests.swift mirrors UIKit's empty URL-context set for notification-only scene connections.
    @objc(URLContexts) var urlContexts: Set<UIOpenURLContext> { [] }
}

@MainActor private final class NotificationNavigationScreen: UIViewController {
    var appeared: (() -> Void)?
    var repeatAnimationOnAppearance = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if repeatAnimationOnAppearance {
            // NotificationNavigationTests.swift keeps a loading animation active after the real navigation pop ends.
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.9
            pulse.toValue = 1
            pulse.duration = 0.5
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            view.layer.add(pulse, forKey: "notification-fixture-pulse")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appeared?()
    }
}

@MainActor private final class NotificationOptionsController: FeedDetailViewController {
    var reloadCount = 0
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 600)) }
    override func viewDidLoad() {}
    override func reloadStories() { reloadCount += 1 }
    override func updateStoryTitlesHeaderPillState() {}
}

@MainActor private final class NotificationOptionsNavigation: UINavigationController {
    var captured: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }
}

@MainActor private final class NotificationNavigationApp: NewsBlurAppDelegate {
    var phone = true
    var openedFeed: String?
    var openedHash: String?
    var openedFolder: String?
    var openedBriefing: String?
    var markedRead: String?
    var savedHash: String?
    var completions = 0
    var useRealFeedNavigation = false
    var useRealRootNavigation = false
    var feedOpened: (() -> Void)?
    var presentationCount = 0
    var preparationCount = 0
    var navigationPreparationCounts: [Int] = []
    override var isPhone: Bool { phone }
    override func prepareViewControllers() { preparationCount += 1 }
    override func popToRoot(completion: (() -> Void)!) {
        if useRealRootNavigation {
            super.popToRoot(completion: completion)
        } else {
            completion?()
        }
    }
    override func loadFeed(_ feedId: String!, withStory contentId: String!, animated: Bool) {
        openedFeed = feedId
        openedHash = contentId
        navigationPreparationCounts.append(preparationCount)
        feedOpened?()
        if useRealFeedNavigation { super.loadFeed(feedId, withStory: contentId, animated: animated) }
    }
    override func loadRiverFeedDetailView(_ feedDetailView: FeedDetailViewController!, withFolder folder: String!) {
        openedFolder = folder
    }
    override func openDailyBriefing(withStoryHash storyHash: String!) { openedBriefing = storyHash }
    override func reloadFeedsView(_ showLoader: Bool) {}
    override func loadFolder(_ folder: String!, feedID feedId: String!) { openedFolder = folder }
    @objc(presentFeedDetailAfterFeedSelection)
    func recordPresentation() { presentationCount += 1 }
    @objc(markStoryAsRead:inFeed:withCallback:)
    func recordRead(_ hash: String, inFeed feed: String, callback: (() -> Void)?) {
        markedRead = hash
        callback?()
    }
    @objc(markStoryAsStarred:withCallback:)
    func recordSave(_ hash: String, callback: (() -> Void)?) {
        savedHash = hash
        callback?()
    }
    func receive(_ content: [String: Any], action: String) {
        // NotificationNavigationTests.swift calls the production entry point used by both cold-launch and notification responses.
        let selector = NSSelectorFromString("processNotification:action:withCompletionHandler:")
        typealias Process = @convention(c) (AnyObject, Selector, NSDictionary, NSString, AnyObject) -> Void
        let implementation = unsafeBitCast(method(for: selector), to: Process.self)
        let completion: @convention(block) () -> Void = { self.completions += 1 }
        implementation(self, selector, content as NSDictionary, action as NSString, completion as AnyObject)
    }
}

@MainActor final class Test_MacWindowMenu: XCTestCase {
#if targetEnvironment(macCatalyst)
    func test_closingMainWindowSavesSizeAndPositionBeforeReleasingIt() throws {
        let defaults = UserDefaults.standard
        let key = "mac_main_window_frame"
        let previous = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        defer { defaults.set(previous, forKey: key) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let frame = scene.effectiveGeometry.systemFrame
        XCTAssertGreaterThan(frame.width, 0)
        let delegate = SceneDelegate()
        let app = NewsBlurAppDelegate()
        let window = UIWindow(windowScene: scene)
        delegate.appDelegate = app
        delegate.window = window
        app.window = window

        // NotificationNavigationTests.swift exercises the actual close callback without closing the test host window.
        delegate.sceneDidDisconnect(scene)

        let saved = try XCTUnwrap(defaults.string(forKey: key), "Closing must persist the frame for the next scene and app launch")
        XCTAssertEqual(NSCoder.cgRect(for: saved), frame)
        XCTAssertNil(app.window)
    }

    func test_freshSceneRestoresSavedFrameBeforeStartupGeometryCanOverwriteIt() throws {
        let saved = CGRect(x: -240, y: 90, width: 1180, height: 780)
        try withSavedWindowFrame(NSCoder.string(for: saved)) {
            let (delegate, scene, app) = try makeWindowSceneProbe()
            app.window = nil
            let oldToolbar = scene.titlebar?.toolbar
            defer { scene.titlebar?.toolbar = oldToolbar }

            connectWindowScene(delegate, scene: scene)

            XCTAssertEqual(delegate.requestedFrames, [saved])
            XCTAssertEqual(app.preparationCount, 1)
            delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
            delegate.sceneWillResignActive(scene)
            XCTAssertEqual(savedWindowFrame(), saved, "The launch frame must not overwrite the pending restoration")

            // NotificationNavigationTests.swift simulates the native geometry result, including display constraints.
            let constrained = CGRect(x: 30, y: 90, width: 1180, height: 780)
            delegate.currentFrame = constrained
            delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
            XCTAssertEqual(savedWindowFrame(), constrained)
            delegate.sceneDidDisconnect(scene)
            XCTAssertNil(app.window)

            // NotificationNavigationTests.swift also covers UIKit reconnecting the existing scene delegate.
            delegate.currentFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
            connectWindowScene(delegate, scene: scene)
            XCTAssertEqual(delegate.requestedFrames, [saved, constrained])
            delegate.sceneDidDisconnect(scene)

            // NotificationNavigationTests.swift creates a fresh delegate, as both Dock reopening and relaunch do.
            let (reopened, _, reopenedApp) = try makeWindowSceneProbe()
            reopenedApp.window = nil
            connectWindowScene(reopened, scene: scene)
            XCTAssertEqual(reopened.requestedFrames, [constrained])
        }
    }

    func test_windowMovesAndResizesPersistWithoutClosing() throws {
        try withSavedWindowFrame(nil) {
            let (delegate, scene, _) = try makeWindowSceneProbe()
            for frame in [CGRect(x: 75, y: 130, width: 900, height: 700),
                          CGRect(x: 200, y: 50, width: 1350, height: 850)] {
                delegate.currentFrame = frame
                delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
                XCTAssertEqual(savedWindowFrame(), frame)
            }
            delegate.currentFrame = CGRect(x: 20, y: 40, width: 1000, height: 800)
            delegate.sceneWillResignActive(scene)
            XCTAssertEqual(savedWindowFrame(), delegate.currentFrame)
            delegate.currentFrame = CGRect(x: 25, y: 45, width: 1100, height: 900)
            delegate.sceneDidEnterBackground(scene)
            XCTAssertEqual(savedWindowFrame(), delegate.currentFrame)
        }
    }

    func test_disconnectAfterWindowDetachesStillAllowsDockReopening() throws {
        let normal = CGRect(x: 100, y: 80, width: 1100, height: 750)
        try withSavedWindowFrame(NSCoder.string(for: normal)) {
            let (delegate, scene, app) = try makeWindowSceneProbe()
            app.window = nil
            let oldToolbar = scene.titlebar?.toolbar
            defer { scene.titlebar?.toolbar = oldToolbar }
            connectWindowScene(delegate, scene: scene)
            delegate.currentFrame = normal
            delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
            delegate.window?.windowScene = nil
            delegate.currentFrame = .zero

            delegate.sceneDidDisconnect(scene)

            XCTAssertNil(app.window)
            XCTAssertEqual(savedWindowFrame(), normal)
        }
    }

    func test_fullScreenAndInvalidGeometryPreserveNormalWindowFrame() throws {
        let normal = CGRect(x: 100, y: 80, width: 1100, height: 750)
        try withSavedWindowFrame(NSCoder.string(for: normal)) {
            let (delegate, scene, app) = try makeWindowSceneProbe()
            delegate.fullScreen = true
            delegate.currentFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
            delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
            delegate.sceneWillResignActive(scene)
            XCTAssertEqual(savedWindowFrame(), normal)
            delegate.fullScreen = false
            for invalid in [CGRect.zero, CGRect(x: 0, y: 0, width: -1, height: 600),
                            CGRect(x: CGFloat.infinity, y: 0, width: 900, height: 600)] {
                delegate.currentFrame = invalid
                delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
                XCTAssertEqual(savedWindowFrame(), normal)
            }
            delegate.fullScreen = true
            delegate.sceneDidDisconnect(scene)
            XCTAssertEqual(savedWindowFrame(), normal)
            XCTAssertNil(app.window)
        }
    }

    func test_unownedSceneDoesNotOverwriteMainWindowFrameOrReleaseItsWindow() throws {
        let normal = CGRect(x: 100, y: 80, width: 1100, height: 750)
        try withSavedWindowFrame(NSCoder.string(for: normal)) {
            let (delegate, scene, app) = try makeWindowSceneProbe()
            let otherWindow = UIWindow(windowScene: scene)
            app.window = otherWindow
            delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
            delegate.sceneDidDisconnect(scene)
            XCTAssertEqual(savedWindowFrame(), normal)
            XCTAssertTrue(app.window === otherWindow)
        }
    }

    func test_corruptSavedFrameDoesNotRequestInvalidGeometry() throws {
        for saved in ["not a rectangle", NSCoder.string(for: CGRect.zero), "{{0, 0}, {nan, 800}}"] {
            try withSavedWindowFrame(saved) {
                let (delegate, scene, app) = try makeWindowSceneProbe()
                app.window = nil
                let oldToolbar = scene.titlebar?.toolbar
                defer { scene.titlebar?.toolbar = oldToolbar }
                connectWindowScene(delegate, scene: scene)
                XCTAssertTrue(delegate.requestedFrames.isEmpty)
            }
        }
    }

    private func withSavedWindowFrame(_ value: String?, body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let key = "mac_main_window_frame"
        let previous = defaults.object(forKey: key)
        defaults.set(value, forKey: key)
        defer { defaults.set(previous, forKey: key) }
        try body()
    }

    private func savedWindowFrame() -> CGRect? {
        UserDefaults.standard.string(forKey: "mac_main_window_frame").map { NSCoder.cgRect(for: $0) }
    }

    private func makeWindowSceneProbe() throws -> (MacWindowSceneProbe, UIWindowScene, NotificationNavigationApp) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let delegate = MacWindowSceneProbe()
        let app = NotificationNavigationApp()
        delegate.appDelegate = app
        delegate.window = UIWindow(windowScene: scene)
        app.window = delegate.window
        return (delegate, scene, app)
    }

    private func connectWindowScene(_ delegate: SceneDelegate, scene: UIWindowScene) {
        let selector = NSSelectorFromString("scene:willConnectToSession:options:")
        typealias Connect = @convention(c) (AnyObject, Selector, UIScene, UISceneSession, AnyObject) -> Void
        let connect = unsafeBitCast(delegate.method(for: selector), to: Connect.self)
        connect(delegate, selector, scene, scene.session, NotificationSceneConnectionOptions())
    }
#endif
    func test_fileMenuKeepsSystemCloseCommandsThroughRebuilds() throws {
        // NotificationNavigationTests.swift checks the real menu transformation preserves native responder routing.
        let closeCommand = UIKeyCommand(title: "Close Window", action: NSSelectorFromString("performClose:"),
                                        input: "w", modifierFlags: .command)
        let closeMenu = UIMenu(title: "", identifier: .close, options: .displayInline, children: [closeCommand])
        let oldAppMenu = UIMenu(title: "Old App Commands", children: [])
        var children: [UIMenuElement] = [oldAppMenu, closeMenu]
        for _ in 0..<2 {
            children = AppMenuHelper.fileMenuChildren(children)
            let retainedClose = try XCTUnwrap(children.compactMap { $0 as? UIMenu }.first { $0.identifier == .close })
            XCTAssertTrue(retainedClose === closeMenu)
            XCTAssertTrue(retainedClose.children.first === closeCommand)
            XCTAssertEqual(children.compactMap { $0 as? UIMenu }.filter { $0.identifier == .close }.count, 1)
            XCTAssertFalse(children.contains { $0 === oldAppMenu })
        }
    }
}

#if targetEnvironment(macCatalyst)
@MainActor private final class MacWindowSceneProbe: SceneDelegate {
    var currentFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
    var fullScreen = false
    var requestedFrames: [CGRect] = []

    override func macWindowFrame(in scene: UIWindowScene) -> CGRect { currentFrame }
    override func macWindowIsFullScreen(in scene: UIWindowScene) -> Bool { fullScreen }
    override func requestMacWindowFrame(_ frame: CGRect, in scene: UIWindowScene, errorHandler: @escaping (Error) -> Void) {
        requestedFrames.append(frame)
    }
}
#endif

@MainActor final class Test_StoryTraversalCompletion: XCTestCase {
    func test_doneTapDoesNotStartPagingWhenUnreadCountChangesBeforeChromeRefreshes() {
        let (app, pages, bar, feed) = makeTraversal(unreadCount: 0, filter: "all", loadedUnread: false)
        pages.setNextPreviousButtons()
        XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Done with stories"))
        app.dictUnreadCounts = ["42": ["nt": 0, "ps": 1, "ng": 0]]

        pages.doNextUnreadStory(bar.nextButton)

        XCTAssertEqual(app.finishedReading, 1)
        XCTAssertEqual(feed.requestedPages, 0)
        XCTAssertFalse(pages.waitingForNextUnreadFromServer)
        XCTAssertFalse(bar.loadingIndicator.isAnimating)
    }

    func test_reachingDoneStopsPendingUnreadTraversal() {
        let (_, pages, bar, feed) = makeTraversal(unreadCount: 1, filter: "all", loadedUnread: false)
        pages.setNextPreviousButtons()
        pages.doNextUnreadStory(nil)
        XCTAssertTrue(pages.waitingForNextUnreadFromServer)
        XCTAssertTrue(bar.loadingIndicator.isAnimating)

        feed.pageFinished = true
        pages.setNextPreviousButtons()

        XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Done with stories"))
        XCTAssertFalse(pages.waitingForNextUnreadFromServer)
        XCTAssertFalse(bar.loadingIndicator.isAnimating)
        XCTAssertFalse(bar.circularProgressView.isHidden)
        XCTAssertTrue(bar.nextButton.isEnabled)
    }

    #if targetEnvironment(macCatalyst)
    func test_macDoneButtonHasNoNativeTitleToReappearWhenDisabled() {
        let (_, pages, bar, _) = makeTraversal(unreadCount: 0, filter: "all")
        pages.setNextPreviousButtons()
        bar.nextButton.isEnabled = false
        bar.nextButton.updateConfiguration()
        XCTAssertNil(bar.nextButton.configuration?.title)
        XCTAssertNil(bar.nextButton.title(for: .disabled))
        XCTAssertEqual(bar.rightGroupView.subviews.compactMap { ($0 as? UILabel)?.text }, [NBLocalization.text("Done")])
    }
    #endif

    func test_markingLastUnreadStoryReadImmediatelyUpdatesDoneButton() {
        let (app, pages, bar, _) = makeTraversal(unreadCount: 1, filter: "all")
        let stories = app.storiesCollection!
        app.activeStory = stories.activeFeedStories.last as? [AnyHashable: Any]
        pages.setNextPreviousButtons()
        XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Next story"))

        stories.markStoryRead(app.activeStory, feed: stories.activeFeed)

        XCTAssertEqual(app.unreadCount(), 0)
        XCTAssertEqual(stories.locationOfNextUnreadStory(), -1)
        XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Done with stories"))
        pages.doNextUnreadStory(nil)
        XCTAssertEqual(app.finishedReading, 1)
    }

    func test_zeroUnreadCountFinishesAllStoriesEvenWhenALoadedStoryHasStaleUnreadState() {
        for filter in ["all", "unread"] {
            let (app, pages, bar, feed) = makeTraversal(unreadCount: 0, filter: filter)
            XCTAssertEqual(app.storiesCollection.locationOfNextUnreadStory(), 1,
                           "NotificationNavigationTests.swift reproduces a loaded unread flag that outlives the feed count.")
            pages.setNextPreviousButtons()
            XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Done with stories"))
            pages.doNextUnreadStory(nil)
            XCTAssertEqual(app.finishedReading, 1)
            XCTAssertTrue(pages.changedPages.isEmpty)
            XCTAssertEqual(feed.requestedPages, 0)
        }
    }

    func test_remainingUnreadStillAdvancesToLoadedStoryOrFetchesItsPage() {
        for loadedUnread in [true, false] {
            let (app, pages, bar, feed) = makeTraversal(unreadCount: 1, filter: "all", loadedUnread: loadedUnread)
            pages.setNextPreviousButtons()
            XCTAssertEqual(bar.nextButton.accessibilityLabel, NBLocalization.text("Next story"))
            pages.doNextUnreadStory(nil)
            XCTAssertEqual(app.finishedReading, 0)
            XCTAssertEqual(pages.changedPages, loadedUnread ? [1] : [])
            XCTAssertEqual(feed.requestedPages, loadedUnread ? 0 : 1)
        }
    }

    private func makeTraversal(unreadCount: Int, filter: String, loadedUnread: Bool = true)
        -> (TraversalCompletionApp, TraversalCompletionPages, StoryTraverseBar, TraversalCompletionFeed) {
        let app = TraversalCompletionApp()
        app.selectedIntelligence = 0
        app.dictUnreadCounts = ["42": ["nt": unreadCount, "ps": 0, "ng": 0]]
        app.originalStoryCount = 1
        app.readStories = NSMutableArray(array: ["42:selected"])
        app.recentlyReadStories = NSMutableDictionary()
        app.unreadStoryHashes = NSMutableDictionary()
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.activeFeed = ["id": 42]
        stories.readFilterOverride = filter
        stories.feedPage = 1
        stories.setStories([
            ["story_hash": "42:selected", "story_feed_id": 42, "read_status": 1],
            ["story_hash": "42:older", "story_feed_id": 42, "read_status": loadedUnread ? 0 : 1]
        ])
        stories.activeFeedStoryLocations = [0, 1]
        stories.activeFeedStoryLocationIds = ["42:selected", "42:older"]
        stories.storyLocationsCount = 2
        app.storiesCollection = stories
        app.activeStory = stories.activeFeedStories.first as? [AnyHashable: Any]
        let feed = TraversalCompletionFeed()
        feed.appDelegate = app
        feed.pageFinished = false
        app.testFeed = feed
        let pages = TraversalCompletionPages()
        pages.appDelegate = app
        app.testPages = pages
        let bar = StoryTraverseBar()
        bar.setup(in: pages.view)
        pages.setValue(bar, forKey: "traverseBar")
        pages.buttonNext = bar.nextButton
        pages.loadingIndicator = bar.loadingIndicator
        pages.circularProgressView = bar.circularProgressView
        return (app, pages, bar, feed)
    }
}

@MainActor private final class TraversalCompletionApp: NewsBlurAppDelegate {
    var finishedReading = 0
    var testFeed: FeedDetailViewController!
    var testPages: StoryPagesViewController!
    override var feedDetailViewController: FeedDetailViewController! { testFeed }
    override var storyPagesViewController: StoryPagesViewController! { testPages }
    override func hideStoryDetailView() { finishedReading += 1 }
}

@MainActor private final class TraversalCompletionPages: StoryPagesViewController {
    var changedPages: [Int] = []
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func changePage(_ pageIndex: Int, animated: Bool) { changedPages.append(pageIndex) }
    override func reloadWidget() {}
}

@MainActor private final class TraversalCompletionFeed: FeedDetailViewController {
    var requestedPages = 0
    override func hasRetainedFirstPageStory() -> Bool { false }
    override func fetchNextPage(_ callback: (() -> Void)!) { requestedPages += 1 }
}
