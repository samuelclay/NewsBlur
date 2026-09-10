import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_HiddenFeedRowPerformance: XCTestCase {
    func test_collapsedAncestorDoesNotConstructFeedCellsOrLoadFavicons() {
        let fixture = makeFixture(collapsedParent: true)
        let path = IndexPath(row: 0, section: 3)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), 0)

        for _ in 0..<100 {
            let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)
            XCTAssertFalse(cell is FeedTableCell)
        }

        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 0)
    }

    func test_aggregatedSubfolderDuplicateDoesNotConstructFeedCellsOrLoadFavicons() {
        let fixture = makeFixture()
        let path = IndexPath(row: 1, section: 2)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), 0)

        let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)

        XCTAssertFalse(cell is FeedTableCell)
        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 0)
    }

    func test_prefetchSkipsCollapsedDescendantsAndAggregatedDuplicates() {
        for collapsedParent in [false, true] {
            let fixture = makeFixture(collapsedParent: collapsedParent)
            let path = collapsedParent ? IndexPath(row: 0, section: 3) : IndexPath(row: 1, section: 2)

            fixture.controller.tableView(fixture.table, prefetchRowsAt: [path])

            XCTAssertEqual(fixture.queue.operationsAdded, 0)
        }
    }

    func test_visibleNestedFeedKeepsItsTitleCountsIndentationAndPreparedIcon() throws {
        let fixture = makeFixture()
        let path = IndexPath(row: 0, section: 3)
        XCTAssertGreaterThan(fixture.controller.tableView(fixture.table, heightForRowAt: path), 0)

        let cell = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: path) as? FeedTableCell)
        fixture.controller.tableView(fixture.table, prefetchRowsAt: [path])

        XCTAssertEqual(cell.feedTitle, "Nested Feed")
        XCTAssertEqual(cell.neutralCount, 27)
        XCTAssertEqual(cell.indentationLevel, 2)
        XCTAssertTrue(cell.feedFavicon === fixture.appDelegate.icon)
        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 1)
        XCTAssertEqual(fixture.queue.operationsAdded, 1)
    }

    func test_searchCanRevealCollapsedDescendantButStillOmitsParentDuplicate() throws {
        let fixture = makeFixture(collapsedParent: true)
        fixture.controller.searchFeedIds = ["2"]
        let childPath = IndexPath(row: 0, section: 3)
        let duplicatePath = IndexPath(row: 1, section: 2)
        XCTAssertGreaterThan(fixture.controller.tableView(fixture.table, heightForRowAt: childPath), 0)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: duplicatePath), 0)

        let child = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: childPath) as? FeedTableCell)
        let duplicate = fixture.controller.tableView(fixture.table, cellForRowAt: duplicatePath)
        fixture.controller.tableView(fixture.table, prefetchRowsAt: [childPath, duplicatePath])

        XCTAssertEqual(child.feedTitle, "Nested Feed")
        XCTAssertFalse(duplicate is FeedTableCell)
        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 1)
        XCTAssertEqual(fixture.queue.operationsAdded, 1)
    }

    private func makeFixture(collapsedParent: Bool = false) -> HiddenFeedFixture {
        let appDelegate = HiddenFeedAppDelegate()
        appDelegate.selectedIntelligence = 0
        appDelegate.dictFoldersArray = ["dashboard", "daily_briefing", "Parent", "Parent ▸ Child"]
        appDelegate.dictFolders = ["dashboard": [], "daily_briefing": [], "Parent": [1], "Parent ▸ Child": [2]]
        appDelegate.dictSubfolders = [:]
        appDelegate.dictFeeds = [
            "1": ["id": 1, "feed_title": "Parent Feed", "active": 1],
            "2": ["id": 2, "feed_title": "Nested Feed", "active": 1],
        ]
        appDelegate.dictUnreadCounts = ["1": ["nt": 1], "2": ["nt": 27]]
        appDelegate.dictInactiveFeeds = [:]
        appDelegate.collapsedFolders = collapsedParent ? ["Parent": "Parent"] : [:]
        let controller = HiddenFeedController()
        controller.appDelegate = appDelegate
        controller.viewShowingAllFeeds = true
        // HiddenFeedRowPerformanceTests.swift uses the real folder aggregation that creates invisible parent duplicates.
        controller.addSubfolderFeeds()
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.feedTitlesTable = table
        controller.setValue(NSMutableDictionary(), forKey: "rowHeights")
        let queue = HiddenFeedPrefetchQueue()
        controller.setValue(queue, forKey: "faviconPrefetchQueue")
        controller.setValue(NSMutableDictionary(), forKey: "faviconPrefetchOperations")
        return HiddenFeedFixture(appDelegate: appDelegate, controller: controller, table: table, queue: queue)
    }
}

@MainActor private struct HiddenFeedFixture {
    let appDelegate: HiddenFeedAppDelegate
    let controller: HiddenFeedController
    let table: UITableView
    let queue: HiddenFeedPrefetchQueue
}

private final class HiddenFeedAppDelegate: NewsBlurAppDelegate {
    let icon = UIImage()
    var preparedIconReads = 0

    override func preparedFavicon(_ filename: String!, size: CGSize) -> UIImage! {
        preparedIconReads += 1
        return icon
    }
}

@MainActor private final class HiddenFeedController: FeedsViewController {
    override func viewDidLoad() {}
}

private final class HiddenFeedPrefetchQueue: OperationQueue, @unchecked Sendable {
    private(set) var operationsAdded = 0

    override func addOperation(_ operation: Operation) {
        // HiddenFeedRowPerformanceTests.swift records scheduling without executing background work or reading disk.
        operationsAdded += 1
    }
}
