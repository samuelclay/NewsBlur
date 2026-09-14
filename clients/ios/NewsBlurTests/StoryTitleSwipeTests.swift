import XCTest
import ObjectiveC.runtime

@testable import NewsBlur

@MainActor final class Test_StoryTitleSwipe: XCTestCase {
    func test_onlyRecognizedPanDefersReloadAndCancellationReleasesIt() async throws {
        selectActions()
        let controller = StorySwipeReloadController()
        let table = StoryListSwipeReloadTable()
        controller.storyTitlesTable = table
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 80)
        cell.storyHash = "recognized-pan-story"
        cell.setupGestures()
        cell.delegate = controller

        // MCSwipeTableViewCell.m checks UIPanGestureRecognizer's exact class; scope the velocity stub to this synchronous query.
        do {
            let method = try XCTUnwrap(class_getInstanceMethod(UIPanGestureRecognizer.self,
                                                               #selector(UIPanGestureRecognizer.velocity(in:))))
            let original = method_getImplementation(method)
            let velocity: @convention(block) (UIPanGestureRecognizer, UIView?) -> CGPoint = { _, _ in
                CGPoint(x: 100, y: 0)
            }
            let replacement = imp_implementationWithBlock(velocity)
            method_setImplementation(method, replacement)
            defer {
                method_setImplementation(method, original)
                imp_removeBlock(replacement)
            }
            let possiblePan = UIPanGestureRecognizer()
            XCTAssertEqual(possiblePan.state, .possible)
            XCTAssertTrue(cell.gestureRecognizerShouldBegin(possiblePan))
        }
        XCTAssertNil(controller.swipingStoryHash)
        controller.configureDataSource()
        XCTAssertEqual(controller.tableReloadCount, 1, "A permission query may still lose to edge navigation")

        controller.resetPendingReloadsForFeedChange()
        controller.tableReloadCount = 0
        let pan = StorySwipeLifecyclePan()
        pan.testState = .began
        cell.perform(NSSelectorFromString("handlePanGestureRecognizer:"), with: pan)
        XCTAssertEqual(controller.swipingStoryHash, "recognized-pan-story")
        controller.configureDataSource()
        XCTAssertEqual(controller.tableReloadCount, 0)
        let reload = expectation(description: "Reload after the cancelled pan finishes bouncing")
        controller.onReload = { reload.fulfill() }
        pan.testState = .cancelled
        cell.perform(NSSelectorFromString("handlePanGestureRecognizer:"), with: pan)
        await fulfillment(of: [reload], timeout: 2)
        XCTAssertNil(controller.swipingStoryHash)
        XCTAssertEqual(controller.tableReloadCount, 1)
    }

    func test_nativeFullReloadWaitsForSwipeActionOrCancellation() async throws {
        let preferences = UserDefaults.standard
        let previousAction = preferences.object(forKey: "story_title_swipe_right")
        preferences.set("save", forKey: "story_title_swipe_right")
        defer {
            if let previousAction { preferences.set(previousAction, forKey: "story_title_swipe_right") }
            else { preferences.removeObject(forKey: "story_title_swipe_right") }
        }

        for percentage in [0.0, 0.4] {
            let controller = StorySwipeReloadController()
            let table = StoryListSwipeReloadTable()
            let stories = StoryListSwipeReloadStories()
            let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
            stories.activeFeedStories = [["story_hash": "reload-swiped-story"]]
            stories.activeFeedStoryLocations = NSMutableArray(array: [0])
            stories.storyLocationsCount = 1
            controller.storiesCollection = stories
            controller.storyTitlesTable = table
            cell.storyHash = "reload-swiped-story"
            cell.setupGestures()
            cell.delegate = controller
            cell.mode = .switch
            controller.swipeTableViewCellDidStartSwiping(cell)

            // StoryTitleSwipeTests.swift covers both immediate and coalesced page-response reloads.
            controller.configureDataSource()
            controller.reload()
            try await Task.sleep(nanoseconds: 250_000_000)
            XCTAssertEqual(controller.tableReloadCount, 0, "A full reload must not recycle a cell while its pan is active")

            // MCSwipeTableViewCell.m calls notifyDelegate after the bounce for both ended and cancelled pans.
            let reload = expectation(description: "Reload after the original story swipe finishes")
            controller.onReload = { reload.fulfill() }
            cell.setValue(percentage, forKey: "currentPercentage")
            cell.perform(NSSelectorFromString("notifyDelegate"))
            XCTAssertNil(controller.swipingStoryHash, "A short or reversed swipe must also release the reload")
            XCTAssertNil(controller.swipingIndexPath)
            XCTAssertEqual(stories.savedHashes, percentage == 0 ? [] : ["reload-swiped-story"])
            await fulfillment(of: [reload], timeout: 2)
            XCTAssertEqual(controller.tableReloadCount, 1, "Coalesce the pending refreshes after the original story action")
        }
    }

    func test_feedChangeDiscardsReloadDeferredByPreviousSwipe() async throws {
        let controller = StorySwipeReloadController()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.storyHash = "previous-feed-story"
        cell.delegate = controller
        controller.swipeTableViewCellDidStartSwiping(cell)
        controller.configureDataSource()
        XCTAssertEqual(controller.tableReloadCount, 0)

        controller.resetPendingReloadsForFeedChange()
        XCTAssertNil(controller.swipingStoryHash)
        XCTAssertNil(controller.swipingIndexPath)
        cell.perform(NSSelectorFromString("notifyDelegate"))
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(controller.tableReloadCount, 0, "Finishing an obsolete gesture must not refresh the new feed")
    }

    func test_obsoleteSwipeCompletionPreservesNewCellsActionAndPendingReload() async throws {
        selectActions()
        let controller = StorySwipeReloadController()
        let table = StoryListSwipeReloadTable()
        let stories = StoryListSwipeReloadStories()
        stories.activeFeedStories = [["story_hash": "current-feed-story"]]
        stories.activeFeedStoryLocations = NSMutableArray(array: [0])
        stories.storyLocationsCount = 1
        controller.storiesCollection = stories
        controller.storyTitlesTable = table
        let oldCell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        oldCell.storyHash = "previous-feed-story"
        let currentCell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        currentCell.storyHash = "current-feed-story"
        for cell in [oldCell, currentCell] {
            cell.setupGestures()
            cell.delegate = controller
            cell.setValue(0.4, forKey: "currentPercentage")
        }

        controller.swipeTableViewCellDidStartSwiping(oldCell)
        controller.configureDataSource()
        controller.resetPendingReloadsForFeedChange()
        controller.swipeTableViewCellDidStartSwiping(currentCell)
        controller.configureDataSource()
        oldCell.perform(NSSelectorFromString("notifyDelegate"))
        XCTAssertEqual(controller.swipingStoryHash, "current-feed-story")
        XCTAssertEqual(controller.swipingIndexPath, IndexPath(row: 0, section: 0))
        XCTAssertEqual(controller.tableReloadCount, 0)
        XCTAssertTrue(stories.savedHashes.isEmpty)

        let reload = expectation(description: "Reload after the current cell finishes")
        controller.onReload = { reload.fulfill() }
        currentCell.perform(NSSelectorFromString("notifyDelegate"))
        XCTAssertEqual(stories.savedHashes, ["current-feed-story"])
        await fulfillment(of: [reload], timeout: 2)
        XCTAssertEqual(controller.tableReloadCount, 1)
    }

    private let keys = ["story_title_swipe_right", "story_title_swipe_left", "enable_story_swipes",
                        "enable_feed_swipes", "feed_title_swipe_left", "feed_title_swipe_right"]
    private var previous: [Any?] = []

    override func setUp() {
        super.setUp()
        previous = keys.map { UserDefaults.standard.object(forKey: $0) }
        UserDefaults.standard.removeObject(forKey: keys[0])
        UserDefaults.standard.removeObject(forKey: keys[1])
        UserDefaults.standard.set(true, forKey: keys[2])
        UserDefaults.standard.set(true, forKey: keys[3])
        UserDefaults.standard.removeObject(forKey: keys[4])
        UserDefaults.standard.removeObject(forKey: keys[5])
    }

    override func tearDown() {
        for (key, value) in zip(keys, previous) {
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        super.tearDown()
    }

    func test_defaultsUseReadOnLeftAndBackOnRight() {
        XCTAssertTrue(GesturePreferences.feedsEnabled)
        XCTAssertTrue(GesturePreferences.storiesEnabled)
        XCTAssertEqual(GesturePreferences.feedLeftAction, "read")
        XCTAssertEqual(GesturePreferences.feedRightAction, "notifications")
        XCTAssertEqual(StoryTitleSwipePreference.leftAction, .read)
        XCTAssertEqual(StoryTitleSwipePreference.rightAction, .back)
        XCTAssertTrue(StoryTitleSwipePreference.usesFullScreenBack)
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.isReadAvailable = true
        cell.setupGestures()
        XCTAssertTrue(cell.shouldDrag)
        XCTAssertEqual(cell.thirdIconName, "indicator-unread")
    }

    func test_feedAndStorySwipesCanBeDisabledIndependentlyAndReenabled() {
        selectActions()
        let feed = FeedTableCell(style: .default, reuseIdentifier: nil)
        let story = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        story.isReadAvailable = true
        for (feeds, stories) in [(true, true), (false, true), (true, false), (false, false), (true, true)] {
            UserDefaults.standard.set(feeds, forKey: "enable_feed_swipes")
            UserDefaults.standard.set(stories, forKey: "enable_story_swipes")
            feed.setupGestures()
            story.setupGestures()
            XCTAssertEqual(feed.shouldDrag, feeds)
            XCTAssertEqual(story.shouldDrag, stories)
        }
        UserDefaults.standard.set("back", forKey: keys[0])
        UserDefaults.standard.set(false, forKey: "enable_story_swipes")
        XCTAssertFalse(StoryTitleSwipePreference.usesFullScreenBack)
    }

    func test_swipeEnablementAcceptsBooleansAndStringLaunchArguments() {
        let defaults = UserDefaults.standard
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let registration = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        defer {
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            defaults.setVolatileDomain(registration, forName: UserDefaults.registrationDomain)
        }
        var testArguments = arguments
        var testRegistration = registration
        for key in ["enable_feed_swipes", "enable_story_swipes"] {
            testArguments.removeValue(forKey: key)
            testRegistration.removeValue(forKey: key)
        }
        defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
        defaults.setVolatileDomain(testRegistration, forName: UserDefaults.registrationDomain)

        for (value, expected) in [(NSNumber(value: true), true), (NSNumber(value: false), false)] {
            defaults.set(value, forKey: "enable_feed_swipes")
            defaults.set(value, forKey: "enable_story_swipes")
            XCTAssertEqual(GesturePreferences.feedsEnabled, expected)
            XCTAssertEqual(GesturePreferences.storiesEnabled, expected)
        }

        for (feeds, stories) in [("NO", "YES"), ("YES", "NO")] {
            testArguments["enable_feed_swipes"] = feeds as NSString
            testArguments["enable_story_swipes"] = stories as NSString
            defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
            XCTAssertEqual(GesturePreferences.feedsEnabled, feeds == "YES")
            XCTAssertEqual(GesturePreferences.storiesEnabled, stories == "YES")
        }

        for key in ["enable_feed_swipes", "enable_story_swipes"] {
            defaults.removeObject(forKey: key)
            testArguments.removeValue(forKey: key)
        }
        defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
        XCTAssertNil(defaults.object(forKey: "enable_feed_swipes"))
        XCTAssertNil(defaults.object(forKey: "enable_story_swipes"))
        XCTAssertTrue(GesturePreferences.feedsEnabled)
        XCTAssertTrue(GesturePreferences.storiesEnabled)
    }

    func test_disabledNativeSwipesConsumeHorizontalDragsAndPreserveScrollingAndEdgeBack() {
        UserDefaults.standard.set(false, forKey: "enable_feed_swipes")
        UserDefaults.standard.set(false, forKey: "enable_story_swipes")
        let feed = FeedTableCell(style: .default, reuseIdentifier: nil)
        let story = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        feed.setupGestures()
        story.setupGestures()
        let pan = DisabledSwipeTestPan()

        for cell in [feed as MCSwipeTableViewCell, story] {
            XCTAssertFalse(cell.shouldDrag)
            for horizontal in [-100.0, 100.0] {
                pan.testVelocity = CGPoint(x: horizontal, y: 2)
                XCTAssertTrue(cell.gestureRecognizerShouldBegin(pan))
                let originalFrame = cell.contentView.frame
                cell.perform(NSSelectorFromString("handlePanGestureRecognizer:"), with: pan)
                XCTAssertEqual(cell.contentView.frame, originalFrame)
            }
            pan.testVelocity = CGPoint(x: 2, y: 100)
            XCTAssertFalse(cell.gestureRecognizerShouldBegin(pan))
            XCTAssertFalse(cell.gestureRecognizerShouldBegin(UITapGestureRecognizer()))
        }

        pan.testVelocity = CGPoint(x: 100, y: 2)
        pan.startX = 2
        XCTAssertFalse(story.gestureRecognizerShouldBegin(pan))
        pan.startX = 80
        XCTAssertTrue(story.gestureRecognizerShouldBegin(pan))

        UserDefaults.standard.set(true, forKey: "enable_story_swipes")
        UserDefaults.standard.set("back", forKey: keys[0])
        story.setupGestures()
        XCTAssertFalse(story.gestureRecognizerShouldBegin(pan))
    }

    func test_feedSwipeDirectionsKeepDefaultsAndCanBeReversed() {
        let feed = FeedTableCell(style: .default, reuseIdentifier: nil)
        feed.setupGestures()
        XCTAssertEqual(feed.firstIconName, "menu_icn_notifications.png")
        XCTAssertEqual(feed.thirdIconName, "indicator-unread")
        UserDefaults.standard.set("read", forKey: "feed_title_swipe_right")
        UserDefaults.standard.set("statistics", forKey: "feed_title_swipe_left")
        feed.setupGestures()
        XCTAssertEqual(feed.firstIconName, "indicator-unread")
        XCTAssertEqual(feed.thirdIconName, "menu_icn_statistics.png")
        feed.isSaved = true
        feed.setupGestures()
        XCTAssertFalse(feed.shouldDrag)
        feed.isSaved = false
        feed.setupGestures()
        XCTAssertTrue(feed.shouldDrag)
    }

    func test_gestureSettingsHideOnlyTheDisabledSwipeChoices() {
        let model = PreferencesViewModel()
        for (feeds, stories) in [(true, true), (false, true), (true, false), (false, false)] {
            UserDefaults.standard.set(feeds, forKey: "enable_feed_swipes")
            UserDefaults.standard.set(stories, forKey: "enable_story_swipes")
            model.updateHiddenKeys()
            for key in ["feed_title_swipe_left", "feed_title_swipe_right"] { XCTAssertEqual(model.shouldShow(key: key), feeds) }
            for key in ["story_title_swipe_left", "story_title_swipe_right"] { XCTAssertEqual(model.shouldShow(key: key), stories) }
            for key in ["long_press_feed_title", "long_press_story_title", "double_tap_story", "two_finger_double_tap", "story_detail_swipe_left_edge"] {
                XCTAssertTrue(model.shouldShow(key: key))
            }
        }
        XCTAssertEqual(model.sections.first { $0.title == "Gestures" }?.groups.map { $0.title },
                       ["Feed list", "Story titles", "Reading a story"])
    }

    func test_sharedSwipeMigrationPreservesDisabledStateAndActualFeedDirection() {
        let suite = "GesturePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.setPersistentDomain(["enable_feed_cell_swipe": false, "feed_swipe_left": "statistics"], forName: suite)
        GesturePreferences.migrateLegacyPreferences(in: defaults, domain: suite)
        XCTAssertEqual(defaults.object(forKey: "enable_feed_swipes") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "enable_story_swipes") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "feed_title_swipe_right"), "statistics")
        XCTAssertNil(defaults.object(forKey: "enable_feed_cell_swipe"))
        defaults.setPersistentDomain(["enable_feed_cell_swipe": false, "enable_story_swipes": true,
                                      "feed_swipe_left": "trainer", "feed_title_swipe_right": "read"], forName: suite)
        GesturePreferences.migrateLegacyPreferences(in: defaults, domain: suite)
        XCTAssertEqual(defaults.object(forKey: "enable_story_swipes") as? Bool, true)
        XCTAssertEqual(defaults.string(forKey: "feed_title_swipe_right"), "read")
        GesturePreferences.migrateLegacyPreferences(in: defaults, domain: suite)
        XCTAssertEqual(defaults.object(forKey: "enable_story_swipes") as? Bool, true)
    }

    private func selectActions() {
        UserDefaults.standard.set("save", forKey: keys[0])
        UserDefaults.standard.set("read", forKey: keys[1])
    }

    func test_directSaveAndReadSwipes() {
        selectActions()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.isReadAvailable = true
        cell.setupGestures()
        XCTAssertTrue(cell.shouldDrag)
        XCTAssertEqual(cell.mode, .switch)
        XCTAssertNotNil(cell.delegate)
        XCTAssertEqual(cell.firstIconName, "saved-stories")
        XCTAssertEqual(cell.thirdIconName, "indicator-unread")
    }

    func test_reusedCellFollowsPreferenceInBothDirections() {
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        // StoryTitleSwipeTests.swift isolates right-swipe changes from the default left read action.
        UserDefaults.standard.set("menu", forKey: keys[1])
        for style in ["save", "back", "share", "unknown"] {
            UserDefaults.standard.set(style, forKey: keys[0])
            cell.setupGestures()
            XCTAssertEqual(cell.shouldDrag, ["save", "share"].contains(style))
        }
    }

    func test_disabledSwipesAndClusterRowsNeverPerformClassicActions() {
        selectActions()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.isClusterStory = true
        cell.setupGestures()
        XCTAssertFalse(cell.shouldDrag)
        cell.isClusterStory = false
        UserDefaults.standard.set(false, forKey: keys[2])
        cell.setupGestures()
        XCTAssertFalse(cell.shouldDrag)
    }

    func test_savedStoriesKeepSaveActionWithoutReadAction() {
        selectActions()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.isReadAvailable = false
        cell.setupGestures()
        XCTAssertEqual(cell.firstIconName, "saved-stories")
        XCTAssertNil(cell.thirdIconName)
    }

    func test_classicActionsResolveStoryLocationsInsteadOfTableRows() {
        let fixture = ClassicSwipeCallbackFixture()
        fixture.table.currentIndexPath = IndexPath(row: 2, section: 0)
        fixture.controller.mappedLocation = 1
        fixture.cell.storyHash = "classic-story-1"
        fixture.begin()
        fixture.end(state: 1)

        XCTAssertEqual(fixture.stories.savedHashes, ["classic-story-1"])
        XCTAssertEqual(fixture.controller.reloaded, [IndexPath(row: 2, section: 0)])
        XCTAssertNil(fixture.controller.swipingIndexPath)
        XCTAssertNil(fixture.controller.swipingStoryHash)

        fixture.table.currentIndexPath = IndexPath(row: 2, section: 3)
        fixture.stories.isDailyBriefing = true
        fixture.begin()
        fixture.end(state: 3)
        XCTAssertEqual(fixture.stories.readHashes, ["classic-story-1"])
        XCTAssertEqual(fixture.controller.reloaded.last, IndexPath(row: 2, section: 3))
    }

    func test_classicActionsCompareStoryHashesByValue() {
        let fixture = ClassicSwipeCallbackFixture()
        fixture.cell.setValue(NSMutableString(string: "classic-story-0"), forKey: "storyHash")
        fixture.begin()
        fixture.table.currentIndexPath = IndexPath(indexes: [0, 0])
        fixture.end(state: 1)

        XCTAssertEqual(fixture.stories.savedHashes, ["classic-story-0"])
    }

    func test_classicActionsIgnoreReusedCells() {
        let fixture = ClassicSwipeCallbackFixture()
        fixture.begin()
        fixture.cell.storyHash = "replacement-story"
        fixture.end(state: 1)

        XCTAssertTrue(fixture.stories.savedHashes.isEmpty)
        XCTAssertTrue(fixture.controller.reloaded.isEmpty)
        XCTAssertNil(fixture.controller.swipingIndexPath)
        XCTAssertNil(fixture.controller.swipingStoryHash)
    }

    func test_classicActionsIgnoreMovedAndRemovedCells() {
        for endedPath in [IndexPath(row: 1, section: 0), nil] {
            let fixture = ClassicSwipeCallbackFixture()
            fixture.begin()
            fixture.table.currentIndexPath = endedPath
            fixture.end(state: 3)

            XCTAssertTrue(fixture.stories.readHashes.isEmpty)
            XCTAssertTrue(fixture.controller.reloaded.isEmpty)
            XCTAssertNil(fixture.controller.swipingIndexPath)
            XCTAssertNil(fixture.controller.swipingStoryHash)
        }
    }

    func test_classicActionsIgnoreMissingAndNonStoryLocations() {
        let briefing = ClassicSwipeCallbackFixture()
        briefing.stories.isDailyBriefing = true
        briefing.table.currentIndexPath = IndexPath(row: 20, section: 3)
        briefing.controller.mappedLocation = 1
        briefing.cell.storyHash = "classic-story-1"
        briefing.begin()
        briefing.end(state: 3)
        XCTAssertEqual(briefing.stories.readHashes, ["classic-story-1"])

        for location in [NSNotFound, -1, 50] {
            let fixture = ClassicSwipeCallbackFixture()
            fixture.controller.mappedLocation = location
            fixture.begin()
            fixture.end(state: 1)
            XCTAssertTrue(fixture.stories.savedHashes.isEmpty)
            XCTAssertTrue(fixture.controller.reloaded.isEmpty)
        }

        let fixture = ClassicSwipeCallbackFixture()
        fixture.begin()
        fixture.stories.activeFeedStories = []
        fixture.end(state: 3)
        XCTAssertTrue(fixture.stories.readHashes.isEmpty)
        XCTAssertNil(fixture.controller.swipingIndexPath)
        XCTAssertNil(fixture.controller.swipingStoryHash)
    }

    func test_changingPreferenceWithCachedListDoesNotDisableAnotherScreensNavigation() throws {
        let controller = CachedSwipeTestController()
        controller.view = UIView()
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController(), controller]
        navigation.loadViewIfNeeded()
        let content = try XCTUnwrap(navigation.interactiveContentPopGestureRecognizer)
        content.isEnabled = true

        selectActions()
        controller.updateStoryTitleSwipePreference()

        XCTAssertTrue(content.isEnabled)
    }

    func test_classicSuppressesBothFullScreenBackGesturesAndKeepsEdgeBack() throws {
        let controller = FeedDetailObjCViewController()
        controller.view = UIView()
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController(), controller]
        navigation.loadViewIfNeeded()
        let fullScreen = UIPanGestureRecognizer()
        controller.setValue(fullScreen, forKey: "fullScreenPopGesture")
        let edge = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let content = try XCTUnwrap(navigation.interactiveContentPopGestureRecognizer)
        content.isEnabled = true

        for style in ["save", "back", "share", "read", "menu"] {
            UserDefaults.standard.set(style, forKey: keys[0])
            controller.perform(NSSelectorFromString("setupStoryTitlesSwipeGestures"))
            XCTAssertEqual(fullScreen.isEnabled, style == "back")
            XCTAssertEqual(content.isEnabled, style == "back")
            if style != "back" { XCTAssertTrue(edge.isEnabled) }
        }

        controller.perform(NSSelectorFromString("restoreContentPopGesture"))
        XCTAssertTrue(content.isEnabled, "StoryTitleSwipeTests.swift keeps other screens' navigation unchanged")
    }

    func test_swipeActionsCanBeReversed() {
        let fixture = ClassicSwipeCallbackFixture()
        UserDefaults.standard.set("read", forKey: keys[0])
        UserDefaults.standard.set("save", forKey: keys[1])
        fixture.begin()
        fixture.end(state: 1)
        fixture.begin()
        fixture.end(state: 3)
        XCTAssertEqual(fixture.stories.readHashes, ["classic-story-0"])
        XCTAssertEqual(fixture.stories.savedHashes, ["classic-story-0"])
    }

    func test_menusAndBackDoNotCompeteWithDirectRowGestures() {
        for action in StoryTitleSwipePreference.actions {
            UserDefaults.standard.set(action.value, forKey: keys[0])
            UserDefaults.standard.set(action.value, forKey: keys[1])
            XCTAssertEqual(StoryTitleSwipePreference.usesRowSwipe(right: true, canMarkRead: true),
                           [.save, .read, .share].contains(action))
            XCTAssertEqual(StoryTitleSwipePreference.usesRowSwipe(right: false, canMarkRead: true), action != .menu)
        }
        UserDefaults.standard.set("read", forKey: keys[0])
        XCTAssertFalse(StoryTitleSwipePreference.usesRowSwipe(right: true, canMarkRead: false))
    }

    func test_legacyChoiceMigratesWithoutOverwritingNewChoices() {
        let suite = "StoryTitleSwipeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let registration = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer {
            defaults.removePersistentDomain(forName: suite)
            defaults.setVolatileDomain(registration, forName: UserDefaults.registrationDomain)
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        }
        var testArguments = arguments
        for key in [keys[0], keys[1], "story_title_swipe_style"] { testArguments.removeValue(forKey: key) }
        defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
        defaults.register(defaults: [keys[0]: "back", keys[1]: "menu"])
        defaults.set("classic", forKey: "story_title_swipe_style")
        defaults.set("share", forKey: keys[1])
        StoryTitleSwipePreference.migrateLegacyStyle(in: defaults, persistentDomainName: suite)
        XCTAssertEqual(defaults.string(forKey: keys[0]), "save")
        XCTAssertEqual(defaults.string(forKey: keys[1]), "share")
        XCTAssertNil(defaults.object(forKey: "story_title_swipe_style"))

        defaults.setPersistentDomain([
            "story_title_swipe_style": "classic", keys[0]: "back", keys[1]: "menu"
        ], forName: suite)
        StoryTitleSwipePreference.migrateLegacyStyle(in: defaults, persistentDomainName: suite)
        XCTAssertEqual(defaults.string(forKey: keys[0]), "back")
        XCTAssertEqual(defaults.string(forKey: keys[1]), "menu")

        defaults.setPersistentDomain(["story_title_swipe_style": "classic"], forName: suite)
        testArguments[keys[0]] = "share"
        defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
        StoryTitleSwipePreference.migrateLegacyStyle(in: defaults, persistentDomainName: suite)
        XCTAssertEqual(defaults.string(forKey: keys[0]), "share")
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[keys[0]])
        XCTAssertEqual(defaults.string(forKey: keys[1]), "read")

        testArguments.removeValue(forKey: keys[0])
        defaults.setVolatileDomain(testArguments, forName: UserDefaults.argumentDomain)
        defaults.removePersistentDomain(forName: suite)
        StoryTitleSwipePreference.migrateLegacyStyle(in: defaults, persistentDomainName: suite)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[keys[0]])
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[keys[1]])
    }
}

@MainActor private final class StorySwipeReloadController: FeedDetailViewController {
    var tableReloadCount = 0
    var onReload: (() -> Void)?
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override var isDailyBriefingView: Bool { false }
    override func reloadTable() {
        tableReloadCount += 1
        onReload?()
    }
}

@MainActor private final class StorySwipeLifecyclePan: UIPanGestureRecognizer {
    var testState = UIGestureRecognizer.State.possible
    override var state: UIGestureRecognizer.State {
        get { testState }
        set { testState = newValue }
    }
    override func velocity(in view: UIView?) -> CGPoint { CGPoint(x: 100, y: 0) }
    override func translation(in view: UIView?) -> CGPoint { .zero }
}

@MainActor private final class StoryListSwipeReloadTable: UITableView {
    override func indexPath(for cell: UITableViewCell) -> IndexPath? { IndexPath(row: 0, section: 0) }
}

@MainActor private final class StoryListSwipeReloadStories: StoriesCollection {
    var savedHashes = [String]()

    override func toggleStorySaved(_ story: [AnyHashable: Any]!) -> Bool {
        savedHashes.append(story["story_hash"] as! String)
        return true
    }
}

private final class CachedSwipeTestController: FeedDetailObjCViewController {
    override func reload() {}
}

@MainActor private final class DisabledSwipeTestPan: UIPanGestureRecognizer {
    var testVelocity = CGPoint.zero
    var startX: CGFloat = 80

    override func velocity(in view: UIView?) -> CGPoint { testVelocity }
    override func translation(in view: UIView?) -> CGPoint { CGPoint(x: 12, y: 0) }
    override func location(in view: UIView?) -> CGPoint { CGPoint(x: startX + 12, y: 30) }
}

// StoryTitleSwipeTests.swift isolates row identity from network and database mutations.
@MainActor private final class ClassicSwipeCallbackFixture {
    let controller = ClassicSwipeCallbackController()
    let table = ClassicSwipeCallbackTable()
    let stories = ClassicSwipeCallbackStories()
    let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)

    init() {
        UserDefaults.standard.set("save", forKey: "story_title_swipe_right")
        UserDefaults.standard.set("read", forKey: "story_title_swipe_left")
        stories.activeFeedStories = (0..<3).map { ["story_hash": "classic-story-\($0)"] }
        stories.activeFeedStoryLocations = NSMutableArray(array: [0, 1, 2])
        stories.storyLocationsCount = 3
        controller.storiesCollection = stories
        controller.storyTitlesTable = table
        cell.storyHash = "classic-story-0"
    }

    func begin() {
        controller.swipeTableViewCellDidStartSwiping(cell)
    }

    func end(state: UInt) {
        controller.swipeTableViewCell(cell,
            didEndSwipingSwipingWith: MCSwipeTableViewCellState(rawValue: state)!, mode: .switch)
    }
}

@MainActor private final class ClassicSwipeCallbackController: FeedDetailObjCViewController {
    var mappedLocation = 0
    var reloaded = [IndexPath]()

    override func storyLocation(for indexPath: IndexPath!) -> Int { mappedLocation }
    override func reload(_ indexPath: IndexPath!, with rowAnimation: UITableView.RowAnimation) {
        reloaded.append(indexPath)
    }
}

@MainActor private final class ClassicSwipeCallbackTable: UITableView {
    var currentIndexPath: IndexPath? = IndexPath(row: 0, section: 0)

    override func indexPath(for cell: UITableViewCell) -> IndexPath? { currentIndexPath }
}

@MainActor private final class ClassicSwipeCallbackStories: StoriesCollection {
    var savedHashes = [String]()
    var readHashes = [String]()

    override func toggleStorySaved(_ story: [AnyHashable: Any]!) -> Bool {
        savedHashes.append(story["story_hash"] as! String)
        return true
    }

    override func toggleStoryUnread(_ story: [AnyHashable: Any]!) {
        readHashes.append(story["story_hash"] as! String)
    }
}
