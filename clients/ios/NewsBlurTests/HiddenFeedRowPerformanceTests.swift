import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_HiddenFeedRowPerformance: XCTestCase {
    func test_readFeedReturningToItsRetainedRowStillDrawsItsTitle() throws {
        let fixture = makeFixture()
        fixture.controller.viewShowingAllFeeds = false
        let path = IndexPath(row: 0, section: 2)
        let height = fixture.controller.tableView(fixture.table, heightForRowAt: path)
        XCTAssertGreaterThan(height, 0)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, cellForRowAt: path).value(forKey: "feedTitle") as? String, "Parent Feed")

        fixture.appDelegate.dictUnreadCounts["1"] = ["nt": 0, "ps": 0, "ng": 0]
        XCTAssertFalse(fixture.controller.isFeedVisible("1"))
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), height)

        let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)
        XCTAssertEqual(cell.accessibilityIdentifier, "feed-row-1", "HiddenFeedRowPerformanceTests.swift requires a drawn feed in every retained positive-height row")
        XCTAssertNotEqual(cell.reuseIdentifier, "BlankCellIdentifier")
        fixture.controller.tableView(fixture.table, prefetchRowsAt: [path])
        XCTAssertEqual(fixture.queue.operationsAdded, 1)
    }

    func test_scrollToTopAfterReadsDoesNotLeaveThreeBlankRows() throws {
        let fixture = makeFixture()
        fixture.controller.viewShowingAllFeeds = false
        fixture.appDelegate.dictFoldersArray = ["dashboard", "daily_briefing", "Absolute Newsletters", "Other Feeds"]
        let following = Array(4...64)
        fixture.appDelegate.dictFolders = ["dashboard": [], "daily_briefing": [],
                                           "Absolute Newsletters": [1, 2, 3], "Other Feeds": following]
        fixture.appDelegate.dictSubfolders = [:]
        for id in 1...64 {
            fixture.appDelegate.dictFeeds[String(id)] = ["id": id, "feed_title": "Newsletter \(id)", "active": 1]
            fixture.appDelegate.dictUnreadCounts[String(id)] = ["nt": 1, "ps": 0, "ng": 0]
        }
        fixture.table.frame = CGRect(x: 0, y: 0, width: 320, height: 420)
        fixture.table.estimatedRowHeight = 0
        fixture.table.estimatedSectionHeaderHeight = 0
        fixture.table.estimatedSectionFooterHeight = 0
        fixture.table.isPrefetchingEnabled = false
        fixture.controller.view = UIView(frame: fixture.table.frame)
        fixture.controller.view.addSubview(fixture.table)
        fixture.table.dataSource = fixture.controller
        fixture.table.delegate = fixture.controller
        fixture.table.reloadData()
        fixture.table.layoutIfNeeded()
        let paths = (0..<3).map { IndexPath(row: $0, section: 2) }
        let originalRects = paths.map { fixture.table.rectForRow(at: $0) }
        XCTAssertTrue(originalRects.allSatisfy { $0.height > 0 })
        attachTable(fixture.table, name: "feed-rows-before-reading")

        // HiddenFeedRowPerformanceTests.swift uses UIKit reuse during the same return-to-top movement as a status-bar tap.
        fixture.table.setContentOffset(CGPoint(x: 0, y: 1200), animated: false)
        fixture.table.layoutIfNeeded()
        XCTAssertTrue(paths.allSatisfy { !(fixture.table.indexPathsForVisibleRows ?? []).contains($0) })
        for id in 1...3 {
            fixture.appDelegate.dictUnreadCounts[String(id)] = ["nt": 0, "ps": 0, "ng": 0]
        }
        fixture.controller.refreshVisibleFeedCounts()
        fixture.table.setContentOffset(.zero, animated: false)
        fixture.table.layoutIfNeeded()
        attachTable(fixture.table, name: "feed-rows-after-return-to-top")

        for (row, path) in paths.enumerated() {
            XCTAssertEqual(fixture.table.rectForRow(at: path), originalRects[row])
            let cell = try XCTUnwrap(fixture.table.cellForRow(at: path))
            XCTAssertEqual(cell.accessibilityIdentifier, "feed-row-\(row + 1)")
            XCTAssertNotEqual(cell.reuseIdentifier, "BlankCellIdentifier")
        }
    }

    private func attachTable(_ table: UITableView, name: String) {
        func display(_ layer: CALayer) {
            layer.displayIfNeeded()
            layer.sublayers?.forEach(display)
        }
        display(table.layer)
        let image = UIGraphicsImageRenderer(bounds: table.bounds).image { table.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_collapsedAncestorDoesNotConstructFeedCellsOrLoadFavicons() {
        let fixture = makeFixture(collapsedParent: true)
        let path = IndexPath(row: 0, section: 3)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), 0)

        for _ in 0..<100 {
            let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)
            XCTAssertEqual(cell.reuseIdentifier, "BlankCellIdentifier")
        }

        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 0)
    }

    func test_aggregatedSubfolderDuplicateDoesNotConstructFeedCellsOrLoadFavicons() {
        let fixture = makeFixture()
        let path = IndexPath(row: 1, section: 2)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), 0)

        let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)

        XCTAssertEqual(cell.reuseIdentifier, "BlankCellIdentifier")
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

        let cell = fixture.controller.tableView(fixture.table, cellForRowAt: path)
        fixture.controller.tableView(fixture.table, prefetchRowsAt: [path])

        XCTAssertEqual(cell.reuseIdentifier, "FeedCellIdentifier")
        XCTAssertEqual(cell.value(forKey: "feedTitle") as? String, "Nested Feed")
        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 27)
        XCTAssertEqual(cell.indentationLevel, 2)
        XCTAssertTrue(cell.value(forKey: "feedFavicon") as? UIImage === fixture.appDelegate.icon)
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

        let child = fixture.controller.tableView(fixture.table, cellForRowAt: childPath)
        let duplicate = fixture.controller.tableView(fixture.table, cellForRowAt: duplicatePath)
        fixture.controller.tableView(fixture.table, prefetchRowsAt: [childPath, duplicatePath])

        XCTAssertEqual(child.reuseIdentifier, "FeedCellIdentifier")
        XCTAssertEqual(child.value(forKey: "feedTitle") as? String, "Nested Feed")
        XCTAssertEqual(duplicate.reuseIdentifier, "BlankCellIdentifier")
        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 1)
        XCTAssertEqual(fixture.queue.operationsAdded, 1)
    }

    func test_proactivePreparationUsesDisplayedOrderWithoutAggregatedDuplicates() {
        let fixture = makeFixture()

        fixture.controller.reloadFeedTitlesTable()

        XCTAssertEqual(fixture.appDelegate.proactiveRequests.map(\.key), ["1", "2"])
        XCTAssertTrue(fixture.appDelegate.proactiveRequests.allSatisfy { $0.size == CGSize(width: 16, height: 16) })
        XCTAssertEqual(fixture.appDelegate.preparedIconReads, 0, "Collecting nearby identifiers must not decode artwork on main.")
    }

    func test_proactivePreparationDoesNotSpendItsBudgetOnCollapsedDescendants() {
        let fixture = makeFixture(collapsedParent: true)

        fixture.controller.reloadFeedTitlesTable()

        XCTAssertTrue(fixture.appDelegate.proactiveRequests.isEmpty)
        fixture.controller.searchFeedIds = ["2"]
        fixture.controller.reloadFeedTitlesTable()
        XCTAssertEqual(fixture.appDelegate.proactiveRequests.map(\.key), ["2"])
    }

    func test_proactivePreparationSkipsFeedsUsingCustomArtwork() {
        let fixture = makeFixture()
        fixture.appDelegate.dictFeedIcons = ["1": ["icon_type": "emoji", "icon_value": "🌞"]]

        fixture.controller.reloadFeedTitlesTable()

        XCTAssertEqual(fixture.appDelegate.proactiveRequests.map(\.key), ["2"])
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
    var proactiveRequests = [FeedIconPreparationRequest]()

    override func prepareFavicons(_ requests: [FeedIconPreparationRequest]!) {
        proactiveRequests = requests
    }

    override func preparedFavicon(_ filename: String!, size: CGSize) -> UIImage! {
        preparedIconReads += 1
        return icon
    }
}

@MainActor private final class HiddenFeedController: FeedsViewController {
    override func viewDidLoad() {}
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0 }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
}

private final class HiddenFeedPrefetchQueue: OperationQueue, @unchecked Sendable {
    private(set) var operationsAdded = 0

    override func addOperation(_ operation: Operation) {
        // HiddenFeedRowPerformanceTests.swift records scheduling without executing background work or reading disk.
        operationsAdded += 1
    }
}
