import XCTest
import UIKit

final class ReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func test_readerLaunchShowsFixtureFoldersAndFeeds() {
        launch(on: "reader")

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))
        XCTAssertTrue(reveal(folderButton(named: "All Site Stories"), in: feedsList))
        XCTAssertTrue(reveal(folderButton(named: "Tech"), in: feedsList))
        XCTAssertTrue(reveal(folderButton(named: "Culture"), in: feedsList))
        XCTAssertTrue(reveal(feedCell("910001"), in: feedsList))
        XCTAssertTrue(reveal(feedCell("910002"), in: feedsList))
        XCTAssertTrue(reveal(feedCell("910003"), in: feedsList))
    }

    func test_feedToolbarKeepsPrimaryControlsVisibleAndOrdered() {
        launch(on: "reader")
        let toolbar = app.toolbars["feed-list-toolbar"]
        let addButton = app.buttons["feed-list-add"]
        let settings = app.buttons["feed-list-settings"]
        let filter = app.segmentedControls["feed-list-intelligence"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        let feedsList = app.tables["feeds-list"].firstMatch
        let outerInset: CGFloat
        if #available(iOS 27.0, *), UIDevice.current.userInterfaceIdiom == .phone {
            outerInset = 0
        } else {
            outerInset = 8
        }
        XCTAssertEqual(toolbar.frame.minX - feedsList.frame.minX, outerInset, accuracy: 1)
        XCTAssertEqual(feedsList.frame.maxX - toolbar.frame.maxX, outerInset, accuracy: 1)
        XCTAssertTrue(addButton.isHittable)
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(filter.buttons.count, 4)
        for button in filter.buttons.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable, "Every intelligence filter must remain directly available")
        }
        XCTAssertLessThanOrEqual(addButton.frame.maxX, filter.frame.minX)
        XCTAssertLessThanOrEqual(filter.frame.maxX, settings.frame.minX)
        XCTAssertLessThan(addButton.frame.minX - toolbar.frame.minX, 30)
        XCTAssertLessThan(toolbar.frame.maxX - settings.frame.maxX, 30)
        attachScreenshot(named: "feed-toolbar-primary-controls")
        addButton.tap()
        XCTAssertTrue(app.textFields["add-site-url-field"].waitForExistence(timeout: 5))
    }

    func test_readerScenarioWaitsForDelayedFeedFixture() {
        app.launchArguments = ["-newsblur-ui-test-feed-delay", "3"]
        launch(on: "reader-feed-swift", storyTitlesStyle: "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
        XCTAssertTrue(storyRow("ui-story-swift-1").waitForExistence(timeout: 5))
        attachScreenshot(named: "delayed-feed-fixture-requested-story-list")
    }

    func test_fixtureStoryMutationsDoNotSurviveRelaunch() {
        for experimental in [false, true] {
            launchSwipes(experimental: experimental, right: "save", left: "read")
            assertFirstStoryState("Unread, Unsaved")
            swipeFirstStory(right: true)
            assertFirstStoryState("Unread, Saved")
            swipeFirstStory(right: false)
            assertFirstStoryState("Read, Saved")
            attachScreenshot(named: "fixture-before-relaunch-\(experimental)")

            app.terminate()
            launchSwipes(experimental: experimental, right: "save", left: "read")
            assertFirstStoryState("Unread, Unsaved")
            attachScreenshot(named: "fixture-after-relaunch-\(experimental)")
        }
    }

    func test_gesturePreferencesCollapseIndependentlyAndKeepSelections() {
        app.launchArguments = ["-newsblur-ui-test-reset-gestures", "-newsblur-ui-test-animations"]
        launch(on: "preferences")
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        func show(_ element: XCUIElement) {
            for _ in 0..<18 {
                if element.isHittable && element.frame.minY > 120 && element.frame.maxY < 750 { return }
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let up = !element.exists || element.frame.midY > app.frame.midY
                origin.withOffset(CGVector(dx: 185, dy: up ? 720 : 260)).press(forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(dx: 185, dy: up ? 370 : 610)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            XCTAssertTrue(element.isHittable)
        }
        let feedToggle = app.switches["enable_feed_swipes"]
        let storyToggle = app.switches["enable_story_swipes"]
        let feedLeft = app.buttons["feed_title_swipe_left"]
        let storyLeft = app.buttons["story_title_swipe_left"]
        let storyRight = app.buttons["story_title_swipe_right"]
        show(storyRight)
        XCTAssertTrue(storyLeft.label.contains("Read / unread"))
        XCTAssertTrue(storyRight.label.contains("Back to feeds"))
        XCTAssertTrue(app.buttons["long_press_story_title"].label.contains("Share"))
        storyRight.tap()
        app.buttons["Save / unsave"].tap()
        show(feedToggle)
        feedToggle.tap()
        XCTAssertFalse(feedLeft.exists)
        XCTAssertFalse(app.buttons["feed_title_swipe_right"].exists)
        XCTAssertTrue(storyRight.exists)
        XCTAssertTrue(app.buttons["long_press_feed_title"].exists)
        show(storyToggle)
        storyToggle.tap()
        XCTAssertFalse(storyRight.exists)
        XCTAssertFalse(app.buttons["story_title_swipe_left"].exists)
        XCTAssertTrue(app.buttons["long_press_story_title"].exists)
        attachScreenshot(named: "gesture-groups-swipes-off")
        storyToggle.tap()
        XCTAssertTrue(storyRight.waitForExistence(timeout: 3))
        XCTAssertTrue(storyRight.label.contains("Save / unsave"))
        XCTAssertFalse(feedLeft.exists)
        show(feedToggle)
        feedToggle.tap()
        XCTAssertTrue(feedLeft.waitForExistence(timeout: 3))
        attachScreenshot(named: "gesture-groups-swipes-on")
    }

    func test_feedSwipeDirectionsWorkWithStorySwipesDisabled() {
        for right in [false, true] {
            app = XCUIApplication()
            app.launchArguments = ["-enable_feed_swipes", "YES", "-enable_story_swipes", "NO",
                                   "-feed_title_swipe_left", right ? "notifications" : "read",
                                   "-feed_title_swipe_right", right ? "read" : "notifications",
                                   "-show_feeds_after_being_read", "YES", "-newsblur-ui-test-animations"]
            launch(on: "reader")
            let row = feedCell("910002")
            guard let frame = waitForStableVisibleFrame(of: row) else { return }
            XCTAssertTrue(row.label.contains("4 unread stories"))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: right ? 80 : 330, dy: frame.midY)).press(forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: right ? 260 : 150, dy: frame.midY)),
                withVelocity: .slow, thenHoldForDuration: 0)
            expectation(for: NSPredicate(format: "label == %@", "Swift Weekly feed"), evaluatedWith: row)
            waitForExpectations(timeout: 5)
        }
    }

    func test_disabledFeedSwipesLeaveStorySwipesEnabled() {
        app.launchArguments = ["-enable_feed_swipes", "NO", "-enable_story_swipes", "YES",
                               "-story_title_swipe_right", "save", "-story_title_swipe_left", "read",
                               "-newsblur-ui-test-animations"]
        launch(on: "reader", storyTitlesStyle: "standard")
        let row = feedCell("910002")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for right in [false, true] {
            guard let frame = waitForStableVisibleFrame(of: row) else { return }
            origin.withOffset(CGVector(dx: right ? 80 : 330, dy: frame.midY)).press(forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: right ? 260 : 150, dy: frame.midY)),
                withVelocity: .slow, thenHoldForDuration: 0)
            XCTAssertTrue(row.label.contains("4 unread stories"))
        }
        guard let frame = waitForStableVisibleFrame(of: row) else { return }
        origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        XCTAssertTrue(waitForFixtureStoryTitles())
        swipeFirstStory(right: true)
        assertFirstStoryState("Unread, Saved")
    }

    func test_disabledStorySwipesKeepEdgeBack() { verifyDisabledStorySwipes(experimental: false) }
    func test_experimentalDisabledStorySwipesKeepEdgeBack() { verifyDisabledStorySwipes(experimental: true) }

    private func verifyDisabledStorySwipes(experimental: Bool) {
        app.launchArguments = ["-enable_feed_swipes", "YES", "-enable_story_swipes", "NO",
                               "-story_title_swipe_right", "back", "-story_title_swipe_left", "save",
                               "-newsblur-ui-test-animations"]
        launch(on: "reader-feed-swift", storyTitlesStyle: experimental ? "experimental" : "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: 80, dy: 195)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 350, dy: 195)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(isVisibleOnScreen(fixtureStorySurface()))
        swipeFirstStory(right: false)
        XCTAssertTrue(isVisibleOnScreen(fixtureStorySurface()))
        origin.withOffset(CGVector(dx: 2, dy: 300)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 350, dy: 300)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.tables["feeds-list"].firstMatch.waitForExistence(timeout: 5))
    }

    func test_classicTitlesKeepEdgeSwipeBack() {
        verifyStoryListSwipeBack(classic: true, experimental: false)
    }

    func test_classicExperimentalTitlesKeepEdgeSwipeBack() {
        verifyStoryListSwipeBack(classic: true, experimental: true)
    }

    func test_currentTitlesKeepFullScreenSwipeBack() {
        verifyStoryListSwipeBack(classic: false, experimental: false)
    }

    func test_currentExperimentalTitlesKeepFullScreenSwipeBack() {
        verifyStoryListSwipeBack(classic: false, experimental: true)
    }

    func test_defaultStorySwipesToggleReadAndReturnToFeeds() {
        verifyDefaultStorySwipes(experimental: false)
    }

    func test_defaultExperimentalStorySwipesToggleReadAndReturnToFeeds() {
        verifyDefaultStorySwipes(experimental: true)
    }

    private func verifyDefaultStorySwipes(experimental: Bool) {
        app.launchArguments = ["-newsblur-ui-test-reset-gestures", "-newsblur-ui-test-animations",
                               "-default_feed_read_filter", "all", "-910002:read_filter", "all"]
        launch(on: "reader-feed-swift", storyTitlesStyle: experimental ? "experimental" : "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
        let initialState = storyRow("ui-story-swift-1").value as? String ?? ""
        XCTAssertTrue(initialState.hasPrefix("Read,") || initialState.hasPrefix("Unread,"))
        let toggledState = initialState.replacingOccurrences(of: initialState.hasPrefix("Read,") ? "Read," : "Unread,",
                                                             with: initialState.hasPrefix("Read,") ? "Unread," : "Read,")
        swipeFirstStory(right: false)
        assertFirstStoryState(toggledState)
        attachScreenshot(named: experimental ? "default-experimental-left-read" : "default-left-read")
        swipeFirstStory(right: false)
        assertFirstStoryState(initialState)

        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: 80, dy: 195)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 350, dy: 195)),
            withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.tables["feeds-list"].firstMatch.waitForExistence(timeout: 5))
    }

    func test_classicStoryActionsAreReversible() {
        verifyClassicActions(experimental: false)
    }

    func test_classicExperimentalStoryActionsAreReversible() {
        verifyClassicActions(experimental: true)
    }

    func test_reversedStorySwipeActions() {
        verifyClassicActions(experimental: false, reversed: true)
    }

    func test_reversedExperimentalStorySwipeActions() {
        verifyClassicActions(experimental: true, reversed: true)
    }

    func test_saveSwipeWithLeftMenu() { verifySwipeMenu(experimental: false, rightMenu: false) }
    func test_experimentalSaveSwipeWithLeftMenu() { verifySwipeMenu(experimental: true, rightMenu: false) }
    func test_rightMenuWithReadSwipe() { verifySwipeMenu(experimental: false, rightMenu: true) }
    func test_experimentalRightMenuWithReadSwipe() { verifySwipeMenu(experimental: true, rightMenu: true) }
    func test_experimentalSwipeMenuIconsStayCompact() {
        launchSwipes(experimental: true, right: "menu", left: "read")
        swipeFirstStory(right: true)
        XCTAssertTrue(app.buttons["Save"].firstMatch.waitForExistence(timeout: 3))
        attachScreenshot(named: "experimental-swipe-menu-icon-sizes")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        for name in ["indicator-unread", "saved-stories", "email"] {
            let icon = app.images[name].firstMatch
            XCTAssertTrue(icon.exists, "Missing swipe icon \(name)")
            XCTAssertGreaterThan(icon.frame.width, 0)
            XCTAssertLessThanOrEqual(icon.frame.width, 18)
            XCTAssertLessThanOrEqual(icon.frame.height, 18)
        }
    }
    func test_shareSwipes() { verifyShareSwipes(experimental: false) }
    func test_experimentalShareSwipes() { verifyShareSwipes(experimental: true) }
    func test_leftSwipeBack() { verifyConfiguredBack(experimental: false, leftBack: true) }
    func test_experimentalLeftSwipeBack() { verifyConfiguredBack(experimental: true, leftBack: true) }
    func test_rightSwipeBackWithLeftAction() { verifyConfiguredBack(experimental: false, leftBack: false) }
    func test_experimentalRightSwipeBackWithLeftAction() { verifyConfiguredBack(experimental: true, leftBack: false) }

    private func launchSwipes(experimental: Bool, right: String, left: String) {
        app = XCUIApplication()
        app.launchArguments = ["-story_title_swipe_right", right, "-story_title_swipe_left", left,
                               "-enable_story_swipes", "YES", "-newsblur-ui-test-animations",
                               "-default_feed_read_filter", "all", "-910002:read_filter", "all"]
        launch(on: "reader-feed-swift", storyTitlesStyle: experimental ? "experimental" : "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
    }

    private func swipeFirstStory(right: Bool) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: right ? 80 : 330, dy: 195)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: right ? 230 : 180, dy: 195)),
            withVelocity: .slow, thenHoldForDuration: 0)
    }

    private func assertFirstStoryState(_ value: String) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: storyRow("ui-story-swift-1"))
        waitForExpectations(timeout: 3)
    }

    private func verifySwipeMenu(experimental: Bool, rightMenu: Bool) {
        launchSwipes(experimental: experimental, right: rightMenu ? "menu" : "save", left: rightMenu ? "read" : "menu")
        if !rightMenu {
            swipeFirstStory(right: true)
            assertFirstStoryState("Unread, Saved")
        }
        swipeFirstStory(right: rightMenu)
        let save = app.buttons[rightMenu ? "Save" : "Unsave"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Share"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Mark Read"].firstMatch.exists)
        save.tap()
        assertFirstStoryState(rightMenu ? "Unread, Saved" : "Unread, Unsaved")
        XCTAssertTrue(isVisibleOnScreen(fixtureStorySurface()))
    }

    private func verifyShareSwipes(experimental: Bool) {
        for right in [true, false] {
            launchSwipes(experimental: experimental, right: right ? "share" : "back", left: right ? "menu" : "share")
            swipeFirstStory(right: right)
            // ReaderUITests.swift accepts the system share sheet's activity cell accessibility type.
            XCTAssertTrue(app.descendants(matching: .any)["Copy Link"].firstMatch.waitForExistence(timeout: 8), app.debugDescription)
            attachScreenshot(named: right ? "swipe-right-share" : "swipe-left-share")
        }
    }

    private func verifyConfiguredBack(experimental: Bool, leftBack: Bool) {
        launchSwipes(experimental: experimental, right: leftBack ? "save" : "back", left: leftBack ? "back" : "save")
        attachScreenshot(named: "configured-back-before")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: leftBack ? 330 : 80, dy: 195)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: leftBack ? 100 : 350, dy: 195)),
            withVelocity: .slow, thenHoldForDuration: 0)
        attachScreenshot(named: "configured-back-after")
        XCTAssertTrue(app.tables["feeds-list"].firstMatch.waitForExistence(timeout: 5))
    }

    private func verifyClassicActions(experimental: Bool, reversed: Bool = false) {
        app.launchArguments += ["-story_title_swipe_right", reversed ? "read" : "save",
                                "-story_title_swipe_left", reversed ? "save" : "read", "-newsblur-ui-test-animations",
                                "-enable_story_swipes", "YES",
                                "-default_feed_read_filter", "all", "-910002:read_filter", "all"]
        launch(on: "reader-feed-swift", storyTitlesStyle: experimental ? "experimental" : "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
        let row = storyRow("ui-story-swift-1")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        func swipe(_ from: CGFloat, _ to: CGFloat) {
            origin.withOffset(CGVector(dx: from, dy: 195)).press(forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: to, dy: 195)),
                withVelocity: .slow, thenHoldForDuration: 0)
        }
        func assertState(_ value: String) {
            let predicate = NSPredicate(format: "value == %@", value)
            expectation(for: predicate, evaluatedWith: row)
            waitForExpectations(timeout: 3)
        }
        func saveSwipe() { swipe(reversed ? 330 : 80, reversed ? 180 : 230) }
        func readSwipe() { swipe(reversed ? 80 : 330, reversed ? 230 : 180) }
        assertState("Unread, Unsaved")
        let rowFrame = row.frame
        func rowImageData() -> Data {
            let image = app.screenshot().image
            let scale = CGFloat(image.cgImage!.width) / app.frame.width
            let crop = rowFrame.applying(CGAffineTransform(scaleX: scale, y: scale)).integral
            return UIImage(cgImage: image.cgImage!.cropping(to: crop)!).pngData()!
        }
        let initialRowImage = experimental ? rowImageData() : nil
        saveSwipe()
        assertState("Unread, Saved")
        attachScreenshot(named: experimental ? "experimental-classic-saved" : "classic-saved")
        if let initialRowImage {
            XCTAssertNotEqual(rowImageData(), initialRowImage, "ReaderUITests.swift requires a visible saved indicator")
        }
        saveSwipe()
        assertState("Unread, Unsaved")
        if let initialRowImage {
            XCTAssertEqual(rowImageData(), initialRowImage, "ReaderUITests.swift requires the saved indicator to disappear")
        }
        readSwipe()
        assertState("Read, Unsaved")
        attachScreenshot(named: experimental ? "experimental-classic-read" : "classic-read")
        if let initialRowImage {
            XCTAssertNotEqual(rowImageData(), initialRowImage, "ReaderUITests.swift requires visible read-state dimming")
        }
        readSwipe()
        assertState("Unread, Unsaved")
        if let initialRowImage {
            XCTAssertEqual(rowImageData(), initialRowImage, "ReaderUITests.swift requires unread appearance to return")
        }
        swipe(80, 115)
        assertState("Unread, Unsaved")
        XCTAssertTrue(isVisibleOnScreen(fixtureStorySurface()))
        tapElementCenter(row)
        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
    }

    private func verifyStoryListSwipeBack(classic: Bool, experimental: Bool) {
        app.launchArguments += ["-story_title_swipe_right", classic ? "save" : "back",
                                "-story_title_swipe_left", classic ? "read" : "menu",
                                "-enable_story_swipes", "YES", "-newsblur-ui-test-animations"]
        launch(on: "reader-feed-swift", storyTitlesStyle: experimental ? "experimental" : "standard")
        XCTAssertTrue(waitForFixtureStoryTitles())
        attachScreenshot(named: classic ? "classic-before-edge-back" : "current-before-swipe-back")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: classic ? 2 : 85, dy: 300))
        let end = origin.withOffset(CGVector(dx: 350, dy: 300))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.tables["feeds-list"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: classic ? "classic-after-edge-back" : "current-after-swipe-back")
    }

    func test_goodReadsAppearsAtBottomAndLoadsTrendingStories() {
        launch(on: "reader-good-reads")

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let goodReadsFolder = folderButton(named: "Good Reads")
        XCTAssertTrue(reveal(goodReadsFolder, in: feedsList))
        attachScreenshot(named: "good-reads-feed-list")
        tapElementCenter(goodReadsFolder)

        let storyList = app.tables["story-titles-list"]
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        XCTAssertTrue(storyRow("ui-story-good-reads-1").waitForExistence(timeout: 10))
    }

    func test_selectingFolderLoadsRiverStories() {
        launch(on: "reader")

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        // FolderTitleView.m's button can also appear in a hidden table accessibility copy.
        let cultureFolders = app.buttons.matching(identifier: "folder-header-culture")
        var cultureFolder: XCUIElement?
        let hittableFolder = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            cultureFolder = cultureFolders.allElementsBoundByIndex.first { $0.isHittable }
            return cultureFolder != nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [hittableFolder], timeout: 10), .completed,
                       "Culture folder has no hittable accessibility match")
        guard let cultureFolder else { return }
        guard let folderFrame = waitForStableVisibleFrame(of: cultureFolder) else { return }
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: folderFrame.midX, dy: folderFrame.midY)).tap()

        let storyList = app.tables["story-titles-list"]
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        let firstStory = storyList.cells.element(boundBy: 0)
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))

        tapElementCenter(firstStory)

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Design Notes Keeps Another Folder Alive")
    }

    func test_selectingFeedLoadsStoriesAndOpeningStoryShowsDetail() {
        launch(on: "reader-feed-swift")

        let storyList = fixtureStorySurface()
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))

        let firstStory = storyCells(in: storyList).element(boundBy: 0)
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        tapElementCenter(firstStory)

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
    }

    func test_rotatingFromStoryDetailKeepsStoryVisibleWhenReturningToPortrait() {
        launch(on: "reader-feed-swift")

        let storyList = fixtureStorySurface()
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))

        let firstStory = storyCells(in: storyList).element(boundBy: 0)
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        tapElementCenter(firstStory)

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
        XCTAssertTrue(isVisibleOnScreen(currentStory), "Story should be visible before rotation: \(debugVisibility(currentStory))")
        attachScreenshot(named: "portrait-story")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        attachScreenshot(named: "landscape-story")

        XCUIDevice.shared.orientation = .portrait

        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
        XCTAssertTrue(isVisibleOnScreen(currentStory), "Story should stay visible after returning to portrait: \(debugVisibility(currentStory))")
        attachScreenshot(named: "portrait-after-rotate")
    }

    func test_selectingFeedShowsExpectedFixtureStoryRows() {
        launch(on: "reader-feed-swift")

        let storyList = fixtureStorySurface()
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        // FeedDetailTableCell.m exposes the drawn title in the cell's combined accessibility label.
        for (hash, title) in [("ui-story-swift-1", "Swift Fixture Story One"),
                              ("ui-story-swift-2", "Swift Fixture Story Two"),
                              ("ui-story-swift-3", "Swift Fixture Story Three")] {
            let row = storyCell(hash)
            XCTAssertTrue(reveal(row, in: storyList))
            XCTAssertTrue(row.label.contains("\"\(title)\""))
        }
    }

    func test_experimentalTitlesShowClusterRows() {
        launch(on: "reader-feed-swift-cluster", storyTitlesStyle: "experimental")

        XCTAssertTrue(waitForFixtureStoryTitles())
        let storyList = fixtureStorySurface()
        XCTAssertTrue(reveal(storyTitle("Swift Cluster Fixture Related Coverage"), in: storyList))
    }

    func test_experimentalTitlesSupportSwipeActionsAndReadToggling() {
        launchSwipes(experimental: true, right: "back", left: "menu")

        let firstStory = storyRow("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        let rowFrame = firstStory.frame
        func rowImageData() -> Data {
            let image = app.screenshot().image
            let scale = CGFloat(image.cgImage!.width) / app.frame.width
            let crop = rowFrame.applying(CGAffineTransform(scaleX: scale, y: scale)).integral
            return UIImage(cgImage: image.cgImage!.cropping(to: crop)!).pngData()!
        }
        let initialRowImage = rowImageData()

        swipeElementLeft(firstStory)

        let readAction = app.buttons.matching(NSPredicate(format: "label IN %@", ["Mark Read", "Mark Unread"])).firstMatch
        XCTAssertTrue(readAction.waitForExistence(timeout: 2))
        let initialActionTitle = readAction.label
        let oppositeActionTitle = initialActionTitle == "Mark Read" ? "Mark Unread" : "Mark Read"
        XCTAssertTrue(app.buttons["Save"].firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Share"].firstMatch.waitForExistence(timeout: 2))

        readAction.tap()

        // ReaderUITests.swift verifies read-state changes on the row retained by the All filter.
        let updatedStory = storyRow("ui-story-swift-1")
        XCTAssertTrue(updatedStory.waitForExistence(timeout: 2))
        attachScreenshot(named: "experimental-menu-after-read-action")
        let updatedRowImage = rowImageData()
        swipeElementLeft(updatedStory)

        let oppositeAction = app.buttons[oppositeActionTitle].firstMatch
        XCTAssertTrue(oppositeAction.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons[initialActionTitle].firstMatch.exists)
        XCTAssertNotEqual(updatedRowImage, initialRowImage, "ReaderUITests.swift requires visible read-state changes before reopening the menu")
        attachScreenshot(named: "experimental-menu-toggled")
        oppositeAction.tap()

        let restoredStory = storyRow("ui-story-swift-1")
        XCTAssertTrue(restoredStory.waitForExistence(timeout: 2))
        XCTAssertEqual(rowImageData(), initialRowImage, "ReaderUITests.swift requires the original appearance after reversing the read action")
        swipeElementLeft(restoredStory)
        XCTAssertTrue(app.buttons[initialActionTitle].firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(oppositeAction.exists)
        attachScreenshot(named: "experimental-menu-restored")
    }

    func test_experimentalTitlesKeepSwipeActionsScopedToOneRow() {
        launchSwipes(experimental: true, right: "back", left: "menu")

        let firstStory = storyRow("ui-story-swift-1")
        let secondStory = storyRow("ui-story-swift-2")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        XCTAssertTrue(secondStory.waitForExistence(timeout: 10))

        let markReadButtons = app.buttons.matching(NSPredicate(format: "label IN %@", ["Mark Read", "Mark Unread"]))
        let saveButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Save"))
        let shareButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Share"))

        XCTAssertEqual(markReadButtons.count, 0)
        XCTAssertEqual(saveButtons.count, 0)
        XCTAssertEqual(shareButtons.count, 0)

        swipeElementLeft(firstStory)
        XCTAssertTrue(markReadButtons.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(markReadButtons.count, 1)
        XCTAssertEqual(saveButtons.count, 1)
        XCTAssertEqual(shareButtons.count, 1)

        swipeElementLeft(secondStory)
        XCTAssertTrue(markReadButtons.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(markReadButtons.count, 1)
        XCTAssertEqual(saveButtons.count, 1)
        XCTAssertEqual(shareButtons.count, 1)
    }

    func test_experimentalTitlesTappingStoryOpensDetail() {
        launch(on: "reader-feed-swift", storyTitlesStyle: "experimental")

        XCTAssertTrue(waitForFixtureStoryTitles())
        let storyList = fixtureStorySurface()

        let firstStory = storyRow("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        tapElementCenter(firstStory)

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
    }

    func test_nextStoryFetchesAdditionalPageWhenMoreUnreadExist() {
        launch(on: "reader-story-swift-1")

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))

        let nextButton = app.buttons["story-traverse-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10))

        tapElementCenter(nextButton)
        XCTAssertTrue(waitForLabel("Swift Fixture Story Two", on: currentStory))

        tapElementCenter(nextButton)
        XCTAssertTrue(waitForLabel("Swift Fixture Story Three", on: currentStory))

        // Crossing a page boundary: the app must fetch page 2 before navigating.
        // Give extra timeout for the async fetch + render pipeline on slow CI runners.
        tapElementCenter(nextButton)
        XCTAssertTrue(waitForLabel("Swift Fixture Story Four", on: currentStory, timeout: 30))
    }

    func test_traverseButtonsFadeRelativeAfterNextWithHiddenToolbar() {
        launch(on: "reader-story-swift-1")

        let currentStory = currentStoryProbe()
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))

        let nextButton = app.buttons["story-traverse-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForTraverseFadeAlpha({ $0 >= 0.99 }), "Traverse controls should start fully visible")

        let storyContent = app.webViews.firstMatch
        XCTAssertTrue(storyContent.waitForExistence(timeout: 10))

        dragUp(on: storyContent, distance: 52)
        XCTAssertTrue(
            waitForTraverseFadeAlpha({ $0 > 0.05 && $0 < 0.95 }),
            "Initial scroll should partially fade traversal controls without hiding them immediately; alpha=\(traverseFadeAlpha() ?? -1)"
        )

        tapElementCenter(nextButton)
        XCTAssertTrue(waitForLabel("Swift Fixture Story Two", on: currentStory))
        XCTAssertTrue(
            waitForTraverseFadeAlpha({ $0 >= 0.99 }),
            "Next story should reset traversal fade even while the toolbar remains hidden; alpha=\(traverseFadeAlpha() ?? -1)"
        )

        dragUp(on: storyContent, distance: 20)
        XCTAssertTrue(
            waitForTraverseFadeAlpha({ $0 > 0.20 && $0 < 1.0 }),
            "First scroll on the next story should fade traversal controls relative to the new story; alpha=\(traverseFadeAlpha() ?? -1)"
        )
    }

    func test_profileCurrentStoryTitlesScroll() throws {
        try requireLiveSession()
#if compiler(>=6.2)
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("XCTHitchMetric requires iOS 26.0 or newer")
        }

        app.activate()

        let storyList = app.tables["story-titles-list"].firstMatch
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))

        measure(metrics: [
            XCTHitchMetric(application: app),
            XCTOSSignpostMetric.scrollingAndDecelerationMetric,
        ]) {
            storyList.swipeUp()
            storyList.swipeDown()
        }
#else
        throw XCTSkip("XCTHitchMetric requires Xcode 26 or newer to compile")
#endif
    }

    func test_openLiveAllSiteStories() throws {
        try requireLiveSession()
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFolder(named: "All Site Stories"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_openLiveCodeFolder() throws {
        try requireLiveSession()
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFolder(named: "Code"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_openLiveEngadgetFeed() throws {
        try requireLiveSession()
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFeed(named: "Engadget"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_profileLiveCurrentExperimentalScroll() throws {
        try requireLiveSession()
#if compiler(>=6.2)
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("XCTHitchMetric requires iOS 26.0 or newer")
        }

        app.activate()
        XCTAssertTrue(waitForLiveStoryTitles())

        let storySurface = liveStorySurface()
        XCTAssertTrue(storySurface.waitForExistence(timeout: 5))

        measure(metrics: [
            XCTHitchMetric(application: app),
            XCTOSSignpostMetric.scrollingAndDecelerationMetric,
        ]) {
            storySurface.swipeUp()
            storySurface.swipeDown()
        }
#else
        throw XCTSkip("XCTHitchMetric requires Xcode 26 or newer to compile")
#endif
    }

    // ReaderUITests.swift runs manual navigation/profiling individually against a prepared signed-in simulator.
    // Open the desired story list before profiling, then run from clients/ios:
    // TEST_RUNNER_NEWSBLUR_LIVE_UI_TESTS=1 xcodebuild test -project NewsBlur.xcodeproj -scheme NewsBlur \
    //   -destination "id=$IOS_SIM_UDID" -only-testing:NewsBlurUITests/ReaderUITests/test_profileCurrentStoryTitlesScroll
    private func requireLiveSession() throws {
        guard ProcessInfo.processInfo.environment["NEWSBLUR_LIVE_UI_TESTS"] == "1" else {
            throw XCTSkip("Manual test requires a prepared signed-in simulator. Run individually with TEST_RUNNER_NEWSBLUR_LIVE_UI_TESTS=1.")
        }
    }

    private func folderButton(named title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(title) folder")
        return app.buttons.matching(predicate).firstMatch
    }

    private func feedCell(_ feedID: String) -> XCUIElement {
        app.tables["feeds-list"].cells.matching(identifier: "feed-row-\(feedID)").firstMatch
    }

    private func waitForStableVisibleFrame(of element: XCUIElement, timeout: TimeInterval = 10,
                                          file: StaticString = #filePath, line: UInt = #line) -> CGRect? {
        // ReaderUITests.swift uses coordinates here: isHittable can fail while table geometry is updating.
        var previousFrame: CGRect?
        var visibleFrame: CGRect?
        let predicate = NSPredicate { _, _ in
            guard element.exists else {
                previousFrame = nil
                return false
            }
            let frame = element.frame
            guard !frame.isEmpty, frame.minX.isFinite, frame.minY.isFinite,
                  frame.maxX.isFinite, frame.maxY.isFinite, self.app.frame.contains(frame) else {
                previousFrame = nil
                return false
            }
            defer { previousFrame = frame }
            guard previousFrame == frame else { return false }
            visibleFrame = frame
            return true
        }
        // ReaderUITests.swift captures the element above; passing it again makes XCTest spend the wait dumping its hierarchy.
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let completed = XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
        if !completed {
            attachScreenshot(named: "feed-element-did-not-settle")
            let frame = element.exists ? String(describing: element.frame) : "unavailable"
            XCTFail("Element never settled: exists=\(element.exists) " +
                    "frame=\(frame) appFrame=\(app.frame)", file: file, line: line)
        }
        return completed ? visibleFrame : nil
    }

    private func storyCell(_ storyHash: String) -> XCUIElement {
        app.tables["story-titles-list"].cells.matching(identifier: "story-row-\(storyHash)").firstMatch
    }

    private func storyRow(_ storyHash: String) -> XCUIElement {
        let identifier = "story-row-\(storyHash)"
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        let largestVisibleMatch = matches.allElementsBoundByIndex
            .filter { !$0.frame.isEmpty }
            .max { lhs, rhs in
                (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
            }

        return largestVisibleMatch ?? matches.firstMatch
    }

    private func storyTitle(_ title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label == %@", title)
        return app.staticTexts.matching(predicate).firstMatch
    }

    private func currentStoryProbe() -> XCUIElement {
        app.staticTexts["story-current-story"].firstMatch
    }

    private func traverseFadeProbe() -> XCUIElement {
        app.staticTexts["story-traverse-fade-state"].firstMatch
    }

    private func traverseFadeAlpha(from element: XCUIElement? = nil) -> Double? {
        let fadeElement = element ?? traverseFadeProbe()
        guard let value = fadeElement.value as? String else {
            return nil
        }

        return value.split(separator: " ")
            .first { $0.hasPrefix("alpha=") }
            .flatMap { Double($0.dropFirst("alpha=".count)) }
    }

    private func waitForTraverseFadeAlpha(_ isExpectedAlpha: @escaping (Double) -> Bool, timeout: TimeInterval = 5) -> Bool {
        let fadeProbe = traverseFadeProbe()
        guard fadeProbe.waitForExistence(timeout: timeout) else {
            return false
        }

        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement,
                  let alpha = self.traverseFadeAlpha(from: element) else {
                return false
            }

            return isExpectedAlpha(alpha)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: fadeProbe)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func isVisibleOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty else {
            return false
        }

        return app.frame.intersects(element.frame)
    }

    private func debugVisibility(_ element: XCUIElement) -> String {
        "exists=\(element.exists) frame=\(element.frame) appFrame=\(app.frame)"
    }

    private func liveFeedCell(named title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(title) feed")
        return app.tables["feeds-list"].cells.matching(predicate).firstMatch
    }

    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }

        for _ in 0..<maxSwipes {
            scrollView.swipeDown()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        for _ in 0..<maxSwipes {
            scrollView.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }

    private func ensureFeedsListVisible() -> Bool {
        let feedsList = app.tables["feeds-list"].firstMatch
        if feedsList.waitForExistence(timeout: 3) {
            return true
        }

        let showSitesButton = app.buttons["Show Sites"].firstMatch
        if showSitesButton.waitForExistence(timeout: 2) {
            tapElementCenter(showSitesButton)
        } else {
            let sidebarButton = app.buttons["Sidebar"].firstMatch
            if sidebarButton.waitForExistence(timeout: 2) {
                tapElementCenter(sidebarButton)
            } else {
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.waitForExistence(timeout: 2) {
                    tapElementCenter(backButton)
                }
            }
        }

        return feedsList.waitForExistence(timeout: 5)
    }

    private func openLiveFolder(named title: String) -> Bool {
        let feedsList = app.tables["feeds-list"].firstMatch
        let folder = folderButton(named: title)
        guard reveal(folder, in: feedsList, maxSwipes: 10) else {
            return false
        }

        tapElementCenter(folder)
        return true
    }

    private func openLiveFeed(named title: String) -> Bool {
        let feedsList = app.tables["feeds-list"].firstMatch
        let feed = liveFeedCell(named: title)
        guard reveal(feed, in: feedsList, maxSwipes: 10) else {
            return false
        }

        tapElementCenter(feed)
        return true
    }

    private func fixtureStorySurface() -> XCUIElement {
        let legacyTable = app.tables["story-titles-list"].firstMatch
        if legacyTable.exists {
            return legacyTable
        }

        let swiftUIScroll = app.scrollViews["story-titles-scroll"].firstMatch
        if swiftUIScroll.exists {
            return swiftUIScroll
        }

        let swiftUIContainer = app.otherElements["story-titles-scroll"].firstMatch
        if swiftUIContainer.exists {
            return swiftUIContainer
        }

        return legacyTable
    }

    private func waitForFixtureStoryTitles() -> Bool {
        let legacyTable = app.tables["story-titles-list"].firstMatch
        if legacyTable.waitForExistence(timeout: 5) {
            return true
        }

        let swiftUIScroll = app.scrollViews["story-titles-scroll"].firstMatch
        if swiftUIScroll.waitForExistence(timeout: 10) {
            return true
        }

        let swiftUIContainer = app.otherElements["story-titles-scroll"].firstMatch
        if swiftUIContainer.waitForExistence(timeout: 10) {
            return true
        }

        return false
    }

    private func storyCells(in storySurface: XCUIElement) -> XCUIElementQuery {
        let cells = storySurface.cells
        if cells.count > 0 {
            return cells
        }

        return app.cells
    }

    private func liveStorySurface() -> XCUIElement {
        let legacyTable = app.tables["story-titles-list"].firstMatch
        if legacyTable.exists {
            return legacyTable
        }

        let swiftUIScroll = app.scrollViews["story-titles-scroll"].firstMatch
        if swiftUIScroll.exists {
            return swiftUIScroll
        }

        let swiftUIContainer = app.otherElements["story-titles-scroll"].firstMatch
        if swiftUIContainer.exists {
            return swiftUIContainer
        }
        
        return legacyTable
    }

    private func waitForLiveStoryTitles() -> Bool {
        let legacyTable = app.tables["story-titles-list"].firstMatch
        if legacyTable.waitForExistence(timeout: 5), legacyTable.isHittable {
            return true
        }

        let swiftUIScroll = app.scrollViews["story-titles-scroll"].firstMatch
        if swiftUIScroll.waitForExistence(timeout: 10) {
            return true
        }

        let swiftUIContainer = app.otherElements["story-titles-scroll"].firstMatch
        if swiftUIContainer.waitForExistence(timeout: 10) {
            return true
        }

        return app.buttons["Show Sites"].waitForExistence(timeout: 10)
    }

    private func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapElementCenter(_ element: XCUIElement) {
        XCTAssertTrue(element.exists)

        let frame = element.frame
        if frame.isEmpty {
            element.tap()
            return
        }

        let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
        coordinate.tap()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func swipeElementLeft(_ element: XCUIElement, distance: CGFloat = 180) {
        XCTAssertTrue(element.exists)

        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.maxX - 12, dy: frame.midY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: max(frame.minX + 12, frame.maxX - distance), dy: frame.midY))

        // FeedDetailCardView.swift uses predicted travel to distinguish opening a menu from a full-swipe action.
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    private func dragUp(on element: XCUIElement, distance: CGFloat) {
        XCTAssertTrue(element.exists)

        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)

        let startY = min(frame.midY + distance / 2, frame.maxY - 20)
        let endY = max(frame.midY - distance / 2, frame.minY + 20)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: startY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: endY))

        // ReaderUITests.swift measures partial fade from a short drag without release momentum.
        start.press(forDuration: 0.2, thenDragTo: end,
                    withVelocity: XCUIGestureVelocity(rawValue: 40), thenHoldForDuration: 0.5)
    }

    private func launch(on screen: String, storyTitlesStyle: String? = nil) {
        app.launchArguments += [
            "-newsblur-ui-testing",
            "-newsblur-ui-test-screen",
            screen,
            "-ApplePersistenceIgnoreState",
            "YES",
        ]
        if let storyTitlesStyle {
            app.launchArguments += [
                "-newsblur-ui-test-story-titles-style",
                storyTitlesStyle,
            ]
        }
        app.launch()
    }
}
