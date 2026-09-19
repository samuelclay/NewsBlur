import UIKit
import UserNotifications
import XCTest

@testable import NewsBlur

@MainActor final class Test_NotificationNavigation: XCTestCase {
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

    private func connectColdScene(content: [String: Any]?, action: String) throws -> NotificationNavigationApp {
        let app = makeApp()
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
        await fulfillment(of: [initialAppearance], timeout: 5)
        initialDestination.appeared = nil
        feeds.repeatAnimationOnAppearance = repeatingAnimation

        let routed = expectation(description: "Notification opened its feed after returning to the feed list")
        app.feedOpened = {
            XCTAssertTrue(navigation.topViewController === feeds)
            routed.fulfill()
        }
        app.receive(["story_feed_id": 42, "story_hash": "42:older-story"], action: UNNotificationDefaultActionIdentifier)
        await fulfillment(of: [routed], timeout: 2)
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
