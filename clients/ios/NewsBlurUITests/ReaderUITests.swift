import XCTest

final class ReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-newsblur-ui-testing",
            "-newsblur-ui-test-screen",
            "reader",
            "-ApplePersistenceIgnoreState",
            "YES",
        ]
    }

    func test_readerLaunchShowsFixtureFoldersAndFeeds() {
        app.launch()

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
        app.launch()

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let techFolder = folderButton(named: "Tech")
        XCTAssertTrue(reveal(techFolder, in: feedsList))
        techFolder.tap()

        let storyList = app.tables["story-titles-list"]
        XCTAssertTrue(storyList.waitForExistence(timeout: 10))
        XCTAssertTrue(storyCell("ui-story-swift-1").waitForExistence(timeout: 10))
        XCTAssertTrue(storyCell("ui-story-arc-1").exists)
    }

    func test_selectingFeedLoadsStoriesAndOpeningStoryShowsDetail() {
        app.launch()

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let swiftFeed = feedCell("910002")
        XCTAssertTrue(reveal(swiftFeed, in: feedsList))
        swiftFeed.tap()

        let firstStory = storyCell("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements.matching(identifier: "story-current-story").firstMatch
        XCTAssertTrue(currentStory.waitForExistence(timeout: 10))
        XCTAssertEqual(currentStory.label, "Swift Fixture Story One")
    }

    func test_storyPagingMovesBetweenFixtureStories() {
        app.launch()

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let swiftFeed = feedCell("910002")
        XCTAssertTrue(reveal(swiftFeed, in: feedsList))
        swiftFeed.tap()

        let firstStory = storyCell("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements.matching(identifier: "story-current-story").firstMatch
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
        app.launch()

        let feedsList = app.tables["feeds-list"].firstMatch
        XCTAssertTrue(feedsList.waitForExistence(timeout: 10))

        let swiftFeed = feedCell("910002")
        XCTAssertTrue(reveal(swiftFeed, in: feedsList))
        swiftFeed.tap()

        let firstStory = storyCell("ui-story-swift-1")
        XCTAssertTrue(firstStory.waitForExistence(timeout: 10))
        firstStory.tap()

        let currentStory = app.otherElements.matching(identifier: "story-current-story").firstMatch
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

    private func waitForLabel(_ label: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }
}
