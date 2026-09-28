import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedUnreadCountRefresh: XCTestCase {
    func test_retainedArticleReadActionUpdatesItsFeedWithoutChangingBrowsedSource() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeed = fixture.app.dictFeeds["2"] as? [AnyHashable: Any]
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        stories.activeFeedStories = [browsed]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = ["browsed-2"]
        stories.visibleUnreadCount = 1
        fixture.app.storiesCollection = stories
        fixture.app.activeStory = retained
        fixture.app.activeUsername = "retained-read-" + UUID().uuidString

        // FeedUnreadCountRefreshTests.swift models the mounted article after Duo's overlay switches to another source.
        stories.markStoryRead(retained)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(stories.visibleUnreadCount, 1, "Reading the retained article must not decrement the browsed source")
        XCTAssertEqual(stories.activeFeedStories.count, 1)
        XCTAssertEqual((stories.activeFeedStories.first as? [String: Any])?["story_hash"] as? String, "browsed-2")
        XCTAssertEqual((stories.activeFeedStories.first as? [String: Any])?["read_status"] as? Int, 0)
        XCTAssertEqual(fixture.app.recentlyReadStories["retained-1"] as? Bool, true)
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 1)
    }

    func test_retainedArticleUnreadAndReadUpdateSharedFeedsWithoutChangingBrowsedProgress() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 1, "intelligence": ["feed": 0], "shared_by_friends": [3]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = retained
        fixture.app.originalStoryCount = 7
        fixture.app.recentlyReadStories["retained-1"] = true
        fixture.app.activeUsername = "retained-unread-" + UUID().uuidString
        let page = StoryDetailViewController()
        page.activeStory = NSMutableDictionary(dictionary: retained)
        fixture.pages.currentPage = page

        stories.markStoryUnread(retained)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 11)
        XCTAssertEqual((fixture.app.dictUnreadCounts["social:3"] as? [String: Int])?["nt"], 6)
        XCTAssertNil(fixture.app.recentlyReadStories["retained-1"])
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 0)
        XCTAssertTrue(page.isRecentlyUnread)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 7)
        XCTAssertEqual(fixture.pages.navigationRefreshes, 0)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)

        // FeedUnreadCountRefreshTests.swift repeats the reader action using its newly updated activeStory.
        stories.markStoryRead(fixture.app.activeStory)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual((fixture.app.dictUnreadCounts["social:3"] as? [String: Int])?["nt"], 5)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 1)
        XCTAssertFalse(page.isRecentlyUnread)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 7)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_dictionaryReadActionKeepsItsStoryWhenActiveStoryHasChanged() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let supplied: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = browsed

        stories.markStoryRead(supplied)

        XCTAssertEqual(fixture.app.activeStory as NSDictionary, browsed as NSDictionary)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(fixture.app.recentlyReadStories["retained-1"] as? Bool, true)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_idReadActionsResolveRetainedStoryAndIgnoreAnUnknownHash() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = retained

        stories.markStoryRead("retained-1", feedId: 1)
        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        stories.markStoryUnread("retained-1", feedId: 1)
        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        stories.markStoryUnread("missing", feedId: 1)
        stories.markStoryRead("missing", feedId: 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_inListReadAndUnreadStillUpdateVisibleCountAndProgress() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let listed: [AnyHashable: Any] = ["story_hash": "listed-1", "story_feed_id": 1,
                                       "read_status": 0, "intelligence": ["feed": 0], "story_title": "Current title"]
        let stories = makeCollection(fixture: fixture, story: listed)
        fixture.app.activeStory = listed
        fixture.app.originalStoryCount = 7
        var stale = listed
        stale["story_title"] = "Old title"

        stories.markStoryRead(stale)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual(fixture.app.activeStory["story_title"] as? String, "Current title")
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual(stories.visibleUnreadCount, 0)

        stories.markStoryUnread(fixture.app.activeStory)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 8)
        XCTAssertEqual(fixture.pages.navigationRefreshes, 1)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [listed] as NSArray)
    }

    func test_refreshUpdatesEveryVisibleFeedAndDuplicateWithoutReloading() throws {
        let fixture = try makeFixture()
        let cells = try [0, 1, 2].map { try fixture.cell(row: $0) }
        let duplicate = try fixture.cell(row: 0, section: 3)
        let icons = cells.map { $0.value(forKey: "feedFavicon") as? UIImage }
        let offset = fixture.table.contentOffset
        let initialReads = fixture.app.iconReads
        fixture.app.dictUnreadCounts["1"] = ["nt": 4, "ps": 2, "ng": 1]
        fixture.app.dictUnreadCounts["2"] = ["nt": 0, "ps": 0, "ng": 0]
        fixture.app.dictUnreadCounts["social:3"] = ["nt": 3, "ps": 1, "ng": 0]
        fixture.controller.currentRowAtIndexPath = nil

        fixture.controller.refreshFeedCounts()

        XCTAssertEqual(cells[0].value(forKey: "neutralCount") as? Int, 4)
        XCTAssertEqual(cells[0].value(forKey: "positiveCount") as? Int, 2)
        XCTAssertEqual(cells[0].value(forKey: "negativeCount") as? Int, 1)
        XCTAssertEqual(duplicate.value(forKey: "neutralCount") as? Int, 4)
        XCTAssertEqual(cells[1].value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(cells[2].value(forKey: "neutralCount") as? Int, 3)
        XCTAssertEqual(cells[0].accessibilityLabel, "First feed, 4 unread stories")
        XCTAssertEqual(cells[1].accessibilityLabel, "Second feed")
        XCTAssertTrue(fixture.app.folderCountCache.count == 0)
        XCTAssertEqual(fixture.controller.headerRefreshes, 1)
        XCTAssertEqual(fixture.controller.reloads, 0)
        XCTAssertEqual(fixture.table.reloads, 0)
        XCTAssertEqual(fixture.table.rowReloads, 0)
        XCTAssertEqual(fixture.table.contentOffset, offset)
        XCTAssertEqual(fixture.app.iconReads, initialReads)
        for row in cells.indices {
            XCTAssertTrue(try fixture.cell(row: row) === cells[row])
            XCTAssertTrue(cells[row].value(forKey: "feedFavicon") as? UIImage === icons[row])
        }
    }

    func test_searchInactiveAndSavedRowsRetainTheirCountSemantics() throws {
        let fixture = try makeFixture()
        let search = try fixture.cell(row: 3)
        let inactive = try fixture.cell(row: 4)
        let saved = try fixture.cell(row: 5)
        fixture.app.dictUnreadCounts["1"] = ["nt": 99, "ps": 99, "ng": 99]
        fixture.app.dictUnreadCounts["4"] = ["nt": 99, "ps": 99, "ng": 99]
        fixture.app.dictUnreadCounts["saved:tag"] = ["nt": 0, "ps": 7, "ng": 0]

        fixture.controller.refreshFeedCounts()

        for cell in [search, inactive] {
            XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
            XCTAssertEqual(cell.value(forKey: "positiveCount") as? Int, 0)
        }
        XCTAssertEqual(saved.value(forKey: "positiveCount") as? Int, 7)
        XCTAssertEqual(saved.value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(fixture.table.reloads, 0)
    }

    func test_existingCellActuallyPaintsItsNewBadge() throws {
        let fixture = try makeFixture()
        let cell = try fixture.cell(row: 0)
        let before = renderedImage(of: cell)
        let badge = try XCTUnwrap(cell.value(forKey: "unreadCount") as? NSObject)
        XCTAssertEqual(badge.value(forKey: "ntCount") as? Int, 10)
        fixture.app.dictUnreadCounts["1"] = ["nt": 9, "ps": 3, "ng": 2]

        fixture.controller.refreshFeedCounts()
        let after = renderedImage(of: cell)

        XCTAssertEqual(badge.value(forKey: "ntCount") as? Int, 9, "FeedUnreadCountRefreshTests.swift must observe the badge actually drawn by the retained cell")
        XCTAssertNotEqual(before.pngData(), after.pngData())
        for (name, image) in [("feed-count-before", before), ("feed-count-after", after)] {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(fixture.table.reloads, 0)
    }

    func test_savedIntelligenceModeKeepsSavedCountInsteadOfUnreadBadge() throws {
        let fixture = try makeFixture(savedMode: true)
        let cell = try fixture.cell(row: 0)
        XCTAssertEqual(cell.value(forKey: "savedStoriesCount") as? Int, 8)
        fixture.app.dictUnreadCounts["1"] = ["nt": 0, "ps": 0, "ng": 0]
        fixture.controller.refreshFeedCounts()
        XCTAssertEqual(cell.value(forKey: "savedStoriesCount") as? Int, 8)
        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
    }

    func test_markReadBeforeOpeningArticleUpdatesModelAndSidebar() async throws {
        let fixture = try makeFixture()
        let cell = try fixture.cell(row: 0)
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeedStories = [["story_hash": "count-1", "story_feed_id": 1, "read_status": 0,
                                     "intelligence": ["feed": 0]]]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = ["count-1"]
        let refreshed = expectation(description: "Read updates reach feed counts before article pages exist")
        fixture.controller.onRefresh = { refreshed.fulfill() }
        XCTAssertNil(fixture.pages.currentPage)
        let story = try XCTUnwrap(stories.activeFeedStories.first as? [AnyHashable: Any])

        stories.markStoryRead(story)

        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 9)
        XCTAssertFalse(fixture.pages.isViewLoaded)
        XCTAssertEqual(fixture.table.reloads, 0)
        fixture.controller.reloadWorkItem?.cancel()
    }

    func test_burstOfReadsCoalescesAndUsesLatestCounts() async throws {
        let fixture = try makeFixture()
        fixture.pages.previousPage = StoryDetailViewController()
        fixture.pages.currentPage = StoryDetailViewController()
        fixture.pages.nextPage = StoryDetailViewController()
        fixture.controller.lastFeedTitlesReloadTime = Date()
        let refreshed = expectation(description: "A reading burst refreshes the latest feed counts once")
        fixture.controller.onRefresh = { refreshed.fulfill() }
        let cell = try fixture.cell(row: 0)

        for count in stride(from: 9, through: 0, by: -1) {
            fixture.app.dictUnreadCounts["1"] = ["nt": count, "ps": 0, "ng": 0]
            fixture.app.finishMark(asRead: ["story_hash": "count-\(count)"])
        }
        await fulfillment(of: [refreshed], timeout: 2)

        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(fixture.controller.refreshes, 1)
        XCTAssertEqual(fixture.table.reloads, 0)
        XCTAssertFalse(fixture.pages.isViewLoaded)
        fixture.controller.reloadWorkItem?.cancel()
    }

    func test_markUnreadWithoutArticlePagesStillRefreshesFeedVisibilityAndCount() throws {
        let fixture = try makeFixture()
        fixture.app.originalStoryCount = 3
        fixture.app.finishMark(asUnread: ["story_hash": "count-1"])
        XCTAssertEqual(fixture.app.originalStoryCount, 4)
        XCTAssertEqual(fixture.controller.reloads, 1)
        XCTAssertFalse(fixture.pages.isViewLoaded)
    }

    func test_partialArticlePagesStillUpdateTheirReadState() async throws {
        let fixture = try makeFixture()
        let page = StoryDetailViewController()
        page.activeStory = ["story_hash": "count-1"]
        page.isRecentlyUnread = true
        fixture.pages.currentPage = page
        let refreshed = expectation(description: "Missing neighbors do not skip feed refresh")
        fixture.controller.onRefresh = { refreshed.fulfill() }

        fixture.app.finishMark(asRead: ["story_hash": "count-1"])
        await fulfillment(of: [refreshed], timeout: 2)

        XCTAssertFalse(page.isRecentlyUnread)
        XCTAssertEqual(fixture.pages.headerRefreshes, 1)
        XCTAssertFalse(page.isViewLoaded)
        fixture.controller.reloadWorkItem?.cancel()
    }

    private func makeCollection(fixture: CountFixture, story: [AnyHashable: Any]) -> StoriesCollection {
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeed = fixture.app.dictFeeds[String(describing: story["story_feed_id"]!)] as? [AnyHashable: Any]
        stories.activeFeedStories = [story]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = [story["story_hash"]!]
        stories.visibleUnreadCount = story["read_status"] as? Int == 0 ? 1 : 0
        fixture.app.storiesCollection = stories
        return stories
    }

    private func cachedReadStatus(_ story: [AnyHashable: Any], fixture: CountFixture) throws -> Int? {
        let request = try XCTUnwrap(StoryFirstPageRequest(account: fixture.app.activeUsername, host: fixture.app.url,
                                                        url: fixture.app.url + "/reader/feed/1/?page=1"))
        let response = StoryFirstPageCache.shared.overlay(["stories": [story]], request: request, revision: 0)
        return (response["stories"] as? [[String: Any]])?.first?["read_status"] as? Int
    }

    private func makeFixture(savedMode: Bool = false) throws -> CountFixture {
        let app = CountAppDelegate()
        app.selectedIntelligence = savedMode ? 2 : 0
        app.dictFoldersArray = ["dashboard", "daily_briefing", "Feeds", "Duplicate"]
        app.dictFolders = ["dashboard": [], "daily_briefing": [],
                           "Feeds": [1, "2", "social:3", "1?query", 4, "saved:tag"], "Duplicate": ["1"]]
        app.dictSubfolders = [:]
        app.dictFeeds = ["1": ["id": 1, "feed_title": "First", "active": 1],
                         "2": ["id": "2", "feed_title": "Second", "active": 1],
                         "4": ["id": 4, "feed_title": "Inactive", "active": 1]]
        app.dictSocialFeeds = ["social:3": ["id": "social:3", "feed_title": "Friend", "active": 1]]
        app.dictSavedStoryTags = ["saved:tag": ["id": "tag", "feed_title": "Saved tag"]]
        app.dictSavedStoryFeedCounts = savedMode ? ["1": 8] : [:]
        app.dictUnreadCounts = ["1": ["nt": 10, "ps": 3, "ng": 2], "2": ["nt": 1, "ps": 0, "ng": 0],
                               "social:3": ["nt": 5, "ps": 2, "ng": 0], "4": ["nt": 5], "saved:tag": ["ps": 8]]
        app.dictInactiveFeeds = ["4": true]
        app.collapsedFolders = [:]
        app.folderCountCache = ["Feeds": ["nt": 100]]
        app.recentlyReadFeeds = []
        app.recentlyReadStories = [:]
        app.unreadStoryHashes = [:]
        let controller = CountFeedsController()
        controller.appDelegate = app
        controller.viewShowingAllFeeds = true
        controller.searchFeedIds = ["1", "2", "social:3", "1?query", "4"]
        controller.setValue(NSMutableDictionary(), forKey: "rowHeights")
        controller.setValue(NSMutableDictionary(), forKey: "folderTitleViews")
        let pages = CountPagesController()
        pages.appDelegate = app
        app.testFeeds = controller
        app.testPages = pages
        let table = CountTable(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.feedTitlesTable = table
        table.dataSource = controller
        table.delegate = controller
        table.reloadData()
        table.layoutIfNeeded()
        table.reloads = 0
        return CountFixture(app: app, controller: controller, pages: pages, table: table)
    }

    private func renderedImage(of view: UIView) -> UIImage {
        view.layoutIfNeeded()
        func displayPendingLayers(_ layer: CALayer) {
            layer.displayIfNeeded()
            layer.sublayers?.forEach(displayPendingLayers)
        }
        displayPendingLayers(view.layer)
        return UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            view.layer.render(in: context.cgContext)
        }
    }
}

@MainActor private struct CountFixture {
    let app: CountAppDelegate
    let controller: CountFeedsController
    let pages: CountPagesController
    let table: CountTable

    func cell(row: Int, section: Int = 2) throws -> UITableViewCell {
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: row, section: section)))
        XCTAssertTrue(cell.responds(to: NSSelectorFromString("neutralCount")))
        return cell
    }
}

private final class CountAppDelegate: NewsBlurAppDelegate {
    var iconReads = 0
    weak var testFeeds: CountFeedsController?
    weak var testPages: CountPagesController?
    let icon = UIImage()
    override var url: String! { "https://feed-count-fixture.invalid" }
    override var feedsViewController: FeedsViewController! {
        get { testFeeds }
        set {}
    }
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set {}
    }
    override func preparedFavicon(_ filename: String!, size: CGSize) -> UIImage! {
        iconReads += 1
        return icon
    }
}

@MainActor private final class CountFeedsController: FeedsViewController {
    var refreshes = 0
    var reloads = 0
    var headerRefreshes = 0
    var onRefresh: (() -> Void)?
    override func viewDidLoad() {}
    override func refreshFeedCounts() {
        super.refreshFeedCounts()
        refreshes += 1
        onRefresh?()
    }
    override func refreshHeaderCounts() { headerRefreshes += 1 }
    override func reloadFeedTitlesTable() { reloads += 1 }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 60 }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
}

@MainActor private final class CountPagesController: StoryPagesViewController {
    var headerRefreshes = 0
    var navigationRefreshes = 0
    override func reloadWidget() {}
    override func refreshHeaders() { headerRefreshes += 1 }
    override func setNextPreviousButtons() { navigationRefreshes += 1 }
}

@MainActor private final class CountTable: UITableView {
    var reloads = 0
    var rowReloads = 0
    override func reloadData() { reloads += 1; super.reloadData() }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloads += 1
        super.reloadRows(at: indexPaths, with: animation)
    }
}
