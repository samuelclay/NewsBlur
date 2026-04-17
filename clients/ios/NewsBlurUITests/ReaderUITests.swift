import XCTest

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

    func test_selectingFolderLoadsRiverStories() {
        launch(on: "reader")

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let cultureFolder = folderButton(named: "Culture")
        XCTAssertTrue(reveal(cultureFolder, in: feedsList))
        tapElementCenter(cultureFolder)

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

    func test_selectingFeedShowsExpectedFixtureStoryRows() {
        launch(on: "reader-feed-swift")

        let storyList = fixtureStorySurface()
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        XCTAssertTrue(reveal(storyTitle("Swift Fixture Story One"), in: storyList))
        XCTAssertTrue(reveal(storyTitle("Swift Fixture Story Two"), in: storyList))
        XCTAssertTrue(reveal(storyTitle("Swift Fixture Story Three"), in: storyList))
    }

    func test_experimentalTitlesShowClusterRows() {
        launch(on: "reader-feed-swift-cluster", storyTitlesStyle: "experimental")

        XCTAssertTrue(waitForFixtureStoryTitles())
        let storyList = fixtureStorySurface()
        XCTAssertTrue(reveal(storyTitle("Swift Cluster Fixture Related Coverage"), in: storyList))
    }

    func test_experimentalTitlesSupportSwipeActionsAndReadToggling() {
        launch(on: "reader-feed-swift", storyTitlesStyle: "experimental")

        XCTAssertTrue(waitForFixtureStoryTitles())
        let storyList = fixtureStorySurface()

        let firstStory = storyRow("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))

        swipeElementLeft(firstStory)

        let markReadButton = app.buttons["Mark Read"].firstMatch
        XCTAssertTrue(markReadButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Save"].firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Share"].firstMatch.waitForExistence(timeout: 2))

        markReadButton.tap()

        let updatedStory = storyRow("ui-story-swift-1")
        XCTAssertFalse(updatedStory.waitForExistence(timeout: 2))
    }

    func test_experimentalTitlesKeepSwipeActionsScopedToOneRow() {
        launch(on: "reader-feed-swift", storyTitlesStyle: "experimental")

        XCTAssertTrue(waitForFixtureStoryTitles())

        let firstStory = storyRow("ui-story-swift-1")
        let secondStory = storyRow("ui-story-swift-2")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        XCTAssertTrue(secondStory.waitForExistence(timeout: 10))

        let markReadButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Mark Read"))
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

    func test_profileCurrentStoryTitlesScroll() throws {
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
    }

    func test_openLiveAllSiteStories() {
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFolder(named: "All Site Stories"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_openLiveCodeFolder() {
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFolder(named: "Code"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_openLiveEngadgetFeed() {
        app.activate()
        XCTAssertTrue(ensureFeedsListVisible())
        XCTAssertTrue(openLiveFeed(named: "Engadget"))
        XCTAssertTrue(waitForLiveStoryTitles())
    }

    func test_profileLiveCurrentExperimentalScroll() throws {
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
    }

    private func folderButton(named title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(title) folder")
        return app.buttons.matching(predicate).firstMatch
    }

    private func feedCell(_ feedID: String) -> XCUIElement {
        app.tables["feeds-list"].cells.matching(identifier: "feed-row-\(feedID)").firstMatch
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

    private func swipeElementLeft(_ element: XCUIElement, distance: CGFloat = 180) {
        XCTAssertTrue(element.exists)

        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.maxX - 12, dy: frame.midY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: max(frame.minX + 12, frame.maxX - distance), dy: frame.midY))

        start.press(forDuration: 0.05, thenDragTo: end)
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
