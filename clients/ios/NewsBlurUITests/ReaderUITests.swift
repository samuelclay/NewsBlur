import XCTest

final class ReaderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_readerLaunchShowsFixtureFoldersAndFeeds() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.tables["feeds-list"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["All Site Stories folder"].exists)
        XCTAssertTrue(app.buttons["Tech folder"].exists)
        XCTAssertTrue(app.buttons["Culture folder"].exists)
        XCTAssertTrue(app.cells["feed-row-910001"].exists)
        XCTAssertTrue(app.cells["feed-row-910002"].exists)
        XCTAssertTrue(app.cells["feed-row-910003"].exists)
    }

    func test_selectingFolderLoadsRiverStories() {
        let app = makeApp()
        app.launch()

        let techFolder = app.buttons["Tech folder"]
        XCTAssertTrue(techFolder.waitForExistence(timeout: 10))
        techFolder.tap()

        let storyList = app.tables["story-titles-list"]
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells["story-row-ui-story-swift-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells["story-row-ui-story-arc-1"].exists)
    }

    func test_selectingFeedLoadsStoriesAndOpeningStoryShowsDetail() {
        let app = makeApp()
        app.launch()

        let swiftFeed = app.cells["feed-row-910002"]
        XCTAssertTrue(swiftFeed.waitForExistence(timeout: 10))
        swiftFeed.tap()

        let firstStory = app.cells["story-row-ui-story-swift-1"]
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements["story-current-story"]
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
    }

    func test_storyPagingMovesBetweenFixtureStories() {
        let app = makeApp()
        app.launch()

        let swiftFeed = app.cells["feed-row-910002"]
        XCTAssertTrue(swiftFeed.waitForExistence(timeout: 10))
        swiftFeed.tap()

        let firstStory = app.cells["story-row-ui-story-swift-1"]
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements["story-current-story"]
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")

        let nextButton = app.buttons["story-traverse-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10))
        nextButton.tap()
        XCTAssertTrue(waitForLabel("Swift Fixture Story Two", on: currentStory))

        let previousButton = app.buttons["story-traverse-previous-button"]
        XCTAssertTrue(previousButton.exists)
        previousButton.tap()
        XCTAssertTrue(waitForLabel("Swift Fixture Story One", on: currentStory))
    }

    func test_nextStoryFetchesAdditionalPageWhenMoreUnreadExist() {
        let app = makeApp()
        app.launch()

        let swiftFeed = app.cells["feed-row-910002"]
        XCTAssertTrue(swiftFeed.waitForExistence(timeout: 10))
        swiftFeed.tap()

        let firstStory = app.cells["story-row-ui-story-swift-1"]
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements["story-current-story"]
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))

        let nextButton = app.buttons["story-traverse-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10))

        nextButton.tap()
        XCTAssertTrue(waitForLabel("Swift Fixture Story Two", on: currentStory))

        nextButton.tap()
        XCTAssertTrue(waitForLabel("Swift Fixture Story Three", on: currentStory))

        nextButton.tap()
        XCTAssertTrue(waitForLabel("Swift Fixture Story Four", on: currentStory))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-newsblur-ui-testing",
            "-newsblur-ui-test-screen",
            "reader",
        ]
        return app
    }

    private func waitForLabel(_ label: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }
}
