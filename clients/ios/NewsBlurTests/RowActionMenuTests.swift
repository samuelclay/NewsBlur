import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_RowActionMenus: XCTestCase {
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

    func test_storyMenuGroupsReadSaveAndShareWithoutSelectingStory() {
        let (app, _) = feedFixture()
        let controller = FeedDetailViewController()
        controller.appDelegate = app
        controller.storiesCollection = app.storiesCollection
        let story = Story(index: 0, dictionary: ["story_hash": "42:test", "story_title": "Test",
                                                "story_permalink": "https://example.com/test"])
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

@MainActor private final class RowMenuTestApp: NewsBlurAppDelegate {
    var lastURL: String?
    var lastParameters: [String: Any]?
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        lastURL = urlString
        lastParameters = parameters as? [String: Any]
    }
}
