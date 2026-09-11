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

    func test_parentMidpointUsesActualCellGeometryRegardlessOfPreviewChildrenAndInsets() throws {
        try withGeometryPreferences {
            var heights = Set<Int>()
            for textSize in [FeedDetailTextSize.titleOnly, .short, .medium, .long] {
                for childCount in [0, 1, 5] {
                    for inset: CGFloat in [0, 47, 101] {
                        let fixture = try makeGeometryFixture(children: [childCount], textSize: textSize, inset: inset)
                        let parent = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 0))
                        let next = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 1))
                        let rect = fixture.table.rectForRow(at: parent)
                        XCTAssertGreaterThan(rect.height, 0, "The real table must have measured its parent row")
                        heights.insert(Int(rect.height.rounded()))
                        XCTAssertEqual(next.row - parent.row - 1, childCount, "Use the production Match/Related row builder")
                        XCTAssertEqual(fixture.table.adjustedContentInset.top, inset, accuracy: 0.01)
                        XCTAssertGreaterThanOrEqual(rect.minY, fixture.table.tableHeaderView!.frame.height)
                        fixture.scroll(top: rect.midY - 0.5)
                        XCTAssertTrue(fixture.controller.marked.isEmpty, "Too early: size=\(textSize.rawValue), children=\(childCount), inset=\(inset)")
                        fixture.scroll(top: rect.midY + 0.5)
                        XCTAssertEqual(fixture.controller.marked, ["geometry-0"], "Too late: size=\(textSize.rawValue), children=\(childCount), inset=\(inset), height=\(rect.height)")
                    }
                }
            }
            XCTAssertGreaterThan(heights.count, 3, "Exercise real variable parent heights")
        }
    }

    func test_parentMidpointPreservesRealClusterModelAndVisibleCells() throws {
        try withGeometryPreferences {
            for clusterMarkRead in [true, false] {
                for spacing in ["compact", "comfortable"] {
                    UserDefaults.standard.set(spacing, forKey: "feed_list_spacing")
                    let fixture = try makeGeometryFixture(children: [4], textSize: .long, clusterMarkRead: clusterMarkRead)
                    let parentPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 0))
                    let paths = (0...4).map { IndexPath(row: parentPath.row + $0, section: 0) }
                    let cells = try paths.map { try XCTUnwrap(fixture.table.cellForRow(at: $0) as? FeedDetailTableCell) }
                    let reloadCount = fixture.table.reloadCount
                    fixture.scroll(top: fixture.table.rectForRow(at: parentPath).midY + 0.5)
                    XCTAssertEqual(fixture.controller.marked, ["geometry-0"])
                    let parent = try XCTUnwrap(fixture.controller.getStoryAtLocation(0))
                    XCTAssertEqual(parent["read_status"] as? Int, 1)
                    let children = try XCTUnwrap(parent["cluster_stories"] as? [[String: Any]])
                    XCTAssertEqual(children.map { $0["read_status"] as? Int }, Array(repeating: clusterMarkRead ? 1 : 0, count: 4))
                    for (index, path) in paths.enumerated() {
                        XCTAssertTrue(fixture.table.cellForRow(at: path) === cells[index])
                        XCTAssertEqual(cells[index].isRead, index == 0 || clusterMarkRead)
                    }
                    XCTAssertEqual(fixture.table.reloadCount, reloadCount)
                    XCTAssertEqual(fixture.table.rowReloadCount, 0)
                    let next = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 1))
                    fixture.scroll(top: fixture.table.rectForRow(at: next).minY - 0.5)
                    XCTAssertEqual(fixture.controller.marked, ["geometry-0"], "Children must not cause independent read operations")
                }
            }
        }
    }

    func test_fastScrollCrossesEachParentMidpointOnceAndReverseDoesNotRepeat() throws {
        try withGeometryPreferences {
            let fixture = try makeGeometryFixture(children: [5, 0, 2, 1], textSize: .medium, inset: 47)
            let third = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 2))
            let rect = fixture.table.rectForRow(at: third)
            fixture.scroll(top: rect.midY - 0.5)
            XCTAssertEqual(fixture.controller.marked, ["geometry-0", "geometry-1"])
            fixture.scroll(top: rect.midY + 0.5)
            XCTAssertEqual(fixture.controller.marked, ["geometry-0", "geometry-1", "geometry-2"])
            fixture.scroll(top: 0)
            fixture.scroll(top: rect.midY + 0.5)
            XCTAssertEqual(fixture.controller.marked, ["geometry-0", "geometry-1", "geometry-2"])
            XCTAssertEqual(fixture.controller.getStoryAtLocation(3)?["read_status"] as? Int, 0)
        }
    }

    func test_lastParentMarksBeforeItsRelatedChildrenAndLoadingRow() throws {
        try withGeometryPreferences {
            let fixture = try makeGeometryFixture(children: [0, 5], textSize: .long, count: 2)
            let last = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 1))
            fixture.scroll(top: fixture.table.rectForRow(at: last).midY + 0.5)
            XCTAssertEqual(fixture.controller.marked, ["geometry-0", "geometry-1"])
            XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), 8, "Two parents, five children and the loading row")
        }
    }

    private func withGeometryPreferences(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let keys = ["story_clustering", "feed_list_spacing", "feed_list_font_size"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(true, forKey: "story_clustering")
        defaults.set("comfortable", forKey: "feed_list_spacing")
        defaults.set("medium", forKey: "feed_list_font_size")
        try body()
    }

    private func makeGeometryFixture(children childCounts: [Int], textSize: FeedDetailTextSize,
                                     inset: CGFloat = 0, clusterMarkRead: Bool = true, count: Int = 12) throws -> StoryListGeometryFixture {
        let app = NewsBlurAppDelegate()
        app.selectedIntelligence = 0
        app.isPremium = true
        app.isPremiumArchive = true
        app.recentlyReadStories = NSMutableDictionary()
        app.dictUserProfile = ["preferences": ["cluster_mark_read": clusterMarkRead]]
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Parent", "active": 1],
                         "2": ["id": 2, "feed_title": "Related", "active": 1]]
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.isRiverView = true
        stories.setStories((0..<count).map { index -> [String: Any] in
            let children = (0..<(index < childCounts.count ? childCounts[index] : 0)).map { child -> [String: Any] in
                ["story_hash": "child-\(index)-\(child)", "story_feed_id": 2, "story_title": "Related report \(child)",
                 "story_timestamp": 1_800_000_000 - child, "cluster_tier": child.isMultiple(of: 2) ? "title" : "semantic", "read_status": 0]
            }
            return ["story_hash": "geometry-\(index)", "story_feed_id": 1, "read_status": 0,
                    "story_title": "Parent report with a title whose full cell geometry changes with the preview size",
                    "story_content": String(repeating: "Preview content is part of the parent cell. ", count: 12),
                    "short_parsed_date": "3m", "story_authors": "Reporter", "image_urls": [],
                    "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0], "cluster_stories": children]
        })
        app.storiesCollection = stories
        let controller = StoryListGeometryController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.textSize = textSize
        controller.pageFetching = true
        controller.isOnline = false
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        let table = StoryListGeometryTable(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        table.estimatedRowHeight = 0
        table.estimatedSectionHeaderHeight = 0
        table.estimatedSectionFooterHeight = 0
        table.contentInsetAdjustmentBehavior = .never
        table.contentInset = UIEdgeInsets(top: inset, left: 0, bottom: 37, right: 0)
        table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: inset == 0 ? 0 : 53))
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        let rows = try XCTUnwrap(controller.perform(NSSelectorFromString("buildVisibleStoryRows"))?.takeUnretainedValue() as? [[String: Any]])
        controller.setValue(rows, forKey: "visibleStoryRows")
        table.dataSource = controller
        table.delegate = controller
        table.reloadData()
        table.layoutIfNeeded()
        XCTAssertEqual(table.numberOfSections, 1, "FeedDetail requires the empty/error message view to be hidden before displaying rows")
        XCTAssertEqual(table.numberOfRows(inSection: 0), rows.count + 1)
        controller.setValue(NSNotFound, forKey: "scrollingMarkReadRow")
        let fixture = StoryListGeometryFixture(controller: controller, table: table)
        fixture.scroll(top: 0)
        XCTAssertTrue(controller.marked.isEmpty, "Opening a list must not mark the first story")
        return fixture
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

// StoryListReloadTests.swift keeps real row geometry and rendering; explicit calls control the scroll event timing.
@MainActor private final class StoryListGeometryController: FeedDetailViewController {
    var marked = [String]()
    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    override func scrollViewDidScroll(_ scrollView: UIScrollView!) {}
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {}

    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        guard storiesCollection.isStoryUnread(story) else { return false }
        marked.append(story["story_hash"] as! String)
        // A nil feed preserves the real parent/child model mutation without database, sync or feed UI side effects.
        storiesCollection.markStoryRead(story, feed: nil)
        return true
    }
}

@MainActor private struct StoryListGeometryFixture {
    let controller: StoryListGeometryController
    let table: StoryListGeometryTable

    func scroll(top: CGFloat) {
        table.setContentOffset(CGPoint(x: 0, y: top - table.adjustedContentInset.top), animated: false)
        table.layoutIfNeeded()
        controller.checkScroll()
    }
}

@MainActor private final class StoryListGeometryTable: UITableView {
    var reloadCount = 0
    var rowReloadCount = 0
    override func reloadData() {
        reloadCount += 1
        super.reloadData()
    }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloadCount += 1
        super.reloadRows(at: indexPaths, with: animation)
    }
}
