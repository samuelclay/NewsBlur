import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_ShareStoryUpdate: XCTestCase {
    func test_sharingPreservesIntelligenceAndKeepsTheStoryInFocus() throws {
        let original = story("1:focused", id: "article", feed: 1)
        original["intelligence"] = ["feed": 1, "author": 0, "title": 0, "tags": 0]
        original["cluster_stories"] = [["story_hash": "2:related"]]
        let (app, share) = try fixture(stories: [original], active: original)
        app.selectedIntelligence = 1
        app.storiesCollection.calculateStoryLocations()
        XCTAssertEqual(app.storiesCollection.storyLocationsCount, 1)

        replace(on: share, response: ["story_hash": "1:focused", "id": "article", "story_feed_id": 1,
                                     "shared": true, "shared_comments": "Fixture comment"])

        XCTAssertEqual((app.activeStory["intelligence"] as? NSDictionary)?["feed"] as? Int, 1)
        XCTAssertEqual((app.activeStory["cluster_stories"] as? [NSDictionary])?.count, 1)
        XCTAssertEqual(app.activeStory["shared"] as? Bool, true)
        app.storiesCollection.calculateStoryLocations()
        XCTAssertEqual(app.storiesCollection.storyLocationsCount, 1,
                       "Sharing must not remove a trained story from the Focus filter")
        XCTAssertEqual(app.storiesCollection.locationOfActiveStory(), 0)
    }

    func test_sharingDoesNotReplaceAnotherFeedWithTheSameArticleID() throws {
        let original = story("1:same", id: "article", feed: 1)
        let other = story("2:same", id: "article", feed: 2)
        let (app, share) = try fixture(stories: [original, other], active: original)
        replace(on: share, response: ["story_hash": "1:same", "id": "article", "story_feed_id": 1, "shared": true])
        let stories = try XCTUnwrap(app.storiesCollection.activeFeedStories as? [NSDictionary])
        XCTAssertEqual(stories.map { $0["story_hash"] as? String }, ["1:same", "2:same"])
        XCTAssertNil(stories[1]["shared"])
    }

    func test_lateShareResponseDoesNotReplaceTheStoryNowBeingRead() throws {
        let shared = story("1:shared", id: "shared", feed: 1)
        let current = story("1:current", id: "current", feed: 1)
        let (app, share) = try fixture(stories: [shared, current], active: current)
        replace(on: share, response: ["story_hash": "1:shared", "id": "shared", "story_feed_id": 1, "shared": true])
        XCTAssertEqual(app.activeStory["story_hash"] as? String, "1:current")
        XCTAssertEqual(app.testPage.activeStory["story_hash"] as? String, "1:current")
        XCTAssertEqual(app.testPage.commentRefreshes, 0)
        let stories = try XCTUnwrap(app.storiesCollection.activeFeedStories as? [NSDictionary])
        XCTAssertEqual(stories[0]["shared"] as? Bool, true)
    }

    func test_missingStoryInResponseDoesNotClearTheReader() throws {
        let original = story("1:current", id: "current", feed: 1)
        let (app, share) = try fixture(stories: [original], active: original)
        replace(on: share, response: nil)
        XCTAssertEqual(app.activeStory?["story_hash"] as? String, "1:current")
        XCTAssertEqual(app.testPage.activeStory?["story_hash"] as? String, "1:current")
    }

    func test_responseWithoutHashMatchesFeedAndArticleTogether() throws {
        let original = story("1:same", id: "article", feed: 1)
        let other = story("2:same", id: "article", feed: 2)
        let (app, share) = try fixture(stories: [original, other], active: original)
        replace(on: share, response: ["id": "article", "story_feed_id": "1", "shared": true])
        let stories = try XCTUnwrap(app.storiesCollection.activeFeedStories as? [NSDictionary])
        XCTAssertEqual(stories[0]["shared"] as? Bool, true)
        XCTAssertEqual(stories[0]["story_hash"] as? String, "1:same")
        XCTAssertNil(stories[1]["shared"])
    }

    func test_lateReplyUpdatesItsCapturedStoryAndPreservesTheReader() throws {
        let original = story("1:replied", id: "replied", feed: 1)
        original["friend_comments"] = [["user_id": 7, "comments": "Original", "replies": []]]
        let current = story("1:current", id: "current", feed: 1)
        let (app, share) = try fixture(stories: [original, current], active: current)
        // ShareStoryUpdateTests.swift keeps HUD cleanup on isolated views without loading the reader storyboard.
        app.testPages.view = UIView()
        app.testPage.view = UIView()
        let response: NSDictionary = ["code": 1, "reply_id": "reply", "comment": [
            "user_id": 7, "comments": "Original", "replies": [["reply_id": "reply", "comments": "Fixture reply"]]
        ]]
        _ = share.perform(NSSelectorFromString("finishAddReply:forStory:"), with: response, with: original)
        XCTAssertEqual(app.activeStory["story_hash"] as? String, "1:current")
        XCTAssertEqual(app.testPage.commentRefreshes, 0)
        let stories = try XCTUnwrap(app.storiesCollection.activeFeedStories as? [NSDictionary])
        let comment = try XCTUnwrap((stories[0]["friend_comments"] as? [NSDictionary])?.first)
        XCTAssertEqual((comment["replies"] as? [NSDictionary])?.first?["reply_id"] as? String, "reply")
    }

    private func replace(on share: BaseViewController, response: NSDictionary?) {
        // ShareStoryUpdateTests.swift calls the existing Objective-C sharing callback without sending any requests.
        _ = share.perform(NSSelectorFromString("replaceStory:withReplyId:"), with: response, with: nil)
    }

    private func story(_ hash: String, id: String, feed: Int) -> NSMutableDictionary {
        ["story_hash": hash, "id": id, "story_feed_id": feed,
         "story_title": "Fixture article", "story_content": "Fixture body", "read_status": 1]
    }

    private func fixture(stories: [NSDictionary], active: NSMutableDictionary) throws -> (ShareUpdateApp, BaseViewController) {
        let app = ShareUpdateApp()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.storiesCollection.setStories(stories)
        app.activeStory = active as? [AnyHashable: Any]
        app.testPage.appDelegate = app
        app.testPage.activeStory = active.mutableCopy() as? NSMutableDictionary
        app.testPages.currentPage = app.testPage
        let type = try XCTUnwrap(NSClassFromString("ShareViewController") as? BaseViewController.Type)
        let share = type.init(nibName: nil, bundle: nil)
        share.appDelegate = app
        return (app, share)
    }
}

@MainActor private final class ShareUpdateApp: NewsBlurAppDelegate {
    let testFeed = ShareUpdateFeed()
    let testPages = StoryPagesViewController()
    let testPage = ShareUpdatePage()
    override var feedDetailViewController: FeedDetailViewController! { testFeed }
    override var storyPagesViewController: StoryPagesViewController! { testPages }
    override func changeActiveFeedDetailRow() {}
}

@MainActor private final class ShareUpdateFeed: FeedDetailViewController {
    override func reloadWithSizing() {}
}

@MainActor private final class ShareUpdatePage: StoryDetailViewController {
    var commentRefreshes = 0
    override func refreshComments(_ replyId: String!) { commentRefreshes += 1 }
}
