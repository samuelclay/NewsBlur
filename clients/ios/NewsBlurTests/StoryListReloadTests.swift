import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryListReload: XCTestCase {
    func test_legacyTableReloadDoesNotRebuildUnusedSwiftUIStories() {
        let controller = StoryListReloadController()
        let cache = StoryListReloadCache()
        controller.storyCache = cache

        controller.configureDataSource()

        XCTAssertEqual(controller.tableReloadCount, 1)
        XCTAssertEqual(cache.reloadCount, 0)
        XCTAssertEqual(cache.dashboardRedrawCount, 0)
    }

    func test_switchingFromLegacyTableBuildsCurrentSwiftUIStories() {
        let controller = StoryListReloadController()
        let cache = StoryListReloadCache()
        controller.storyCache = cache
        controller.configureDataSource()

        controller.legacyTableForTest = false
        controller.configureDataSource()

        XCTAssertEqual(controller.tableReloadCount, 1)
        XCTAssertEqual(cache.reloadCount, 1)
    }

    func test_gridAndExperimentalLayoutsStillRebuildTheirStoryCache() {
        let controller = StoryListReloadController()
        controller.legacyTableForTest = false
        let cache = StoryListReloadCache()
        controller.storyCache = cache

        controller.configureDataSource()

        XCTAssertEqual(controller.tableReloadCount, 0)
        XCTAssertEqual(cache.reloadCount, 1)
    }

    func test_dashboardRootRedrawsWithoutReloadingStoryList() {
        let controller = StoryListReloadController()
        controller.legacyTableForTest = false
        controller.dashboardForTest = true
        controller.dashboardIndex = -1
        let cache = StoryListReloadCache()
        controller.storyCache = cache

        controller.configureDataSource()

        XCTAssertEqual(cache.dashboardRedrawCount, 1)
        XCTAssertEqual(cache.reloadCount, 0)
        XCTAssertEqual(controller.tableReloadCount, 0)
    }

    func test_selectedDashboardModuleStillReloadsItsStories() {
        let controller = StoryListReloadController()
        controller.legacyTableForTest = false
        controller.dashboardForTest = true
        controller.dashboardIndex = 0
        let cache = StoryListReloadCache()
        controller.storyCache = cache

        controller.configureDataSource()

        XCTAssertEqual(cache.dashboardRedrawCount, 1)
        XCTAssertEqual(cache.reloadCount, 1)
        XCTAssertEqual(controller.tableReloadCount, 0)
    }

    func test_scrollingMarksPassedStoriesWithoutReloadingOrReplacingVisibleCells() {
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.recentlyReadStories = NSMutableDictionary()
        appDelegate.selectedIntelligence = 0
        let stories = StoriesCollection()
        stories.appDelegate = appDelegate
        stories.setStories((0..<3).map { index in
            ["story_hash": "scroll-test-\(index)", "story_feed_id": 1, "read_status": 0]
        })

        let table = StoryListScrollTable(frame: CGRect(x: 0, y: 0, width: 320, height: 640), style: .plain)
        let controller = StoryListScrollController()
        controller.appDelegate = appDelegate
        controller.storiesCollection = stories
        controller.storyTitlesTable = table
        controller.pageFetching = true
        controller.setValue(0, forKey: "scrollingMarkReadRow")

        controller.checkScroll()

        XCTAssertEqual(controller.markedStoryHashes, ["scroll-test-0", "scroll-test-1"])
        XCTAssertEqual(table.rowReloadCount, 0)
        XCTAssertEqual(table.tableReloadCount, 0)
        XCTAssertTrue(table.passedCell.isRead)
        XCTAssertFalse(table.currentCell.isRead)
        XCTAssertEqual(controller.value(forKey: "scrollingMarkReadRow") as? Int, 2)

        controller.checkScroll()
        XCTAssertEqual(controller.markedStoryHashes.count, 2)
    }

    func test_scrollingPreservesClusterMarkReadPreference() {
        for clusterMarkRead in [true, false] {
            let appDelegate = NewsBlurAppDelegate()
            appDelegate.recentlyReadStories = NSMutableDictionary()
            appDelegate.selectedIntelligence = 0
            appDelegate.isPremiumArchive = true
            appDelegate.dictUserProfile = ["preferences": ["cluster_mark_read": clusterMarkRead]]
            let stories = StoriesCollection()
            stories.appDelegate = appDelegate
            stories.setStories((0..<3).map { index in
                ["story_hash": "cluster-test-\(index)", "story_feed_id": 1, "read_status": 0]
            })

            let table = StoryListScrollTable(frame: .zero, style: .plain)
            table.passedCell.isClusterStory = true
            let controller = StoryListScrollController()
            controller.appDelegate = appDelegate
            controller.storiesCollection = stories
            controller.storyTitlesTable = table
            controller.pageFetching = true
            controller.setValue(0, forKey: "scrollingMarkReadRow")
            controller.setValue([
                ["type": 0, "story_location": 0],
                ["type": 1, "story_location": 0, "cluster_story": ["read_status": 0]],
                ["type": 0, "story_location": 1],
                ["type": 0, "story_location": 2]
            ], forKey: "visibleStoryRows")

            controller.checkScroll()

            XCTAssertEqual(controller.markedStoryHashes, ["cluster-test-0"])
            XCTAssertEqual(table.rowReloadCount, 0)
            XCTAssertEqual(table.tableReloadCount, 0)
            XCTAssertEqual(table.passedCell.isRead, clusterMarkRead)
            XCTAssertFalse(table.currentCell.isRead)
        }
    }
}

@MainActor private final class StoryListReloadController: FeedDetailViewController {
    var legacyTableForTest = true
    var dashboardForTest = false
    var tableReloadCount = 0

    override var isLegacyTable: Bool { legacyTableForTest }
    override var isDashboard: Bool { dashboardForTest }
    override var isDailyBriefingView: Bool { false }

    override func reloadTable() {
        tableReloadCount += 1
    }
}

@MainActor private final class StoryListReloadCache: StoryCache {
    var reloadCount = 0
    var dashboardRedrawCount = 0

    override func reload() {
        reloadCount += 1
    }

    override func redrawDashboard() {
        dashboardRedrawCount += 1
    }
}

@MainActor private final class StoryListScrollController: FeedDetailViewController {
    var markedStoryHashes = [String]()

    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }

    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        let hash = story["story_hash"] as! String
        markedStoryHashes.append(hash)
        appDelegate.recentlyReadStories[hash] = true
        return true
    }
}

@MainActor private final class StoryListScrollTable: UITableView {
    let passedCell = FeedDetailTableCell(style: .default, reuseIdentifier: "passed")
    let currentCell = FeedDetailTableCell(style: .default, reuseIdentifier: "current")
    var rowReloadCount = 0
    var tableReloadCount = 0

    override var indexPathsForVisibleRows: [IndexPath]? {
        [IndexPath(row: 1, section: 0), IndexPath(row: 2, section: 0)]
    }

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        IndexPath(row: 2, section: 0)
    }

    override func cellForRow(at indexPath: IndexPath) -> UITableViewCell? {
        indexPath.row == 1 ? passedCell : currentCell
    }

    override func numberOfRows(inSection section: Int) -> Int { 4 }

    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloadCount += 1
    }

    override func reloadData() {
        tableReloadCount += 1
    }
}
