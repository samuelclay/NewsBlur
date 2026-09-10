import XCTest
import UIKit
import QuartzCore

@testable import NewsBlur

@MainActor final class Test_StoryPaginationPerformance: XCTestCase {
    private let defaults = UserDefaults.standard
    private let preferenceValues: [String: Any] = [
        "story_list_preview_text_size": "medium",
        "story_list_preview_images_size": "small",
        "feed_list_spacing": "comfortable",
        "story_clustering": true,
    ]
    private var savedPreferences: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let bundleID = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persisted = defaults.persistentDomain(forName: bundleID) ?? [:]
        for (key, value) in preferenceValues {
            savedPreferences[key] = persisted[key]
            defaults.set(value, forKey: key)
        }
    }

    override func tearDown() {
        for key in preferenceValues.keys {
            if let value = savedPreferences[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        savedPreferences.removeAll()
        super.tearDown()
    }

    func test_appendingPageDoesNotRenormalizeUnchangedCachedStories() throws {
        let fixture = makeFixture(storyCount: 100)
        let before = try snapshot(fixture, locations: [0, 40, 99])
        fixture.resetMeasurements()

        fixture.controller.renderStories(makeStories(100..<112))
        fixture.table.layoutIfNeeded()

        let repeatedHashes = fixture.previews.storedKeys.filter { key in
            guard let index = Int(key.replacingOccurrences(of: "pagination-", with: "")) else { return false }
            return index < 100
        }
        XCTAssertEqual(repeatedHashes.count, 0, "An unchanged cached story should not parse its HTML again when a later page arrives.")
        XCTAssertEqual(try snapshot(fixture, locations: [0, 40, 99]), before)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 112)
    }

    func test_compareFullReloadAndTailInsertionAtIncreasingStoryCounts() throws {
        for count in [100, 1_000, 5_000] {
            for mode in [PaginationApplyMode.productionReload, .experimentalTailInsertion] {
                let fixture = makeFixture(storyCount: count)
                let locations = [0, count / 2, count - 1]
                let before = try snapshot(fixture, locations: locations)
                let oldRows = fixture.table.numberOfRows(inSection: 0)
                let oldOffset = fixture.table.contentOffset
                let oldHeight = fixture.table.contentSize.height
                let page = makeStories(count..<(count + 12))
                fixture.resetMeasurements()

                let started = CACurrentMediaTime()
                if mode == .productionReload {
                    fixture.controller.renderStories(page)
                } else {
                    fixture.stories.addStories(page)
                    try insertTailForExperiment(fixture, oldRows: oldRows)
                }
                fixture.table.layoutIfNeeded()
                let applyMilliseconds = (CACurrentMediaTime() - started) * 1_000
                let measurements: [String: Any] = [
                    "existing_stories": count,
                    "appended_stories": 12,
                    "mode": mode.rawValue,
                    "apply_ms": applyMilliseconds,
                    "model_append_ms": fixture.stories.appendMilliseconds,
                    "height_calls": fixture.controller.heightCalls,
                    "preview_normalizations": fixture.previews.storedKeys.count,
                    "preview_cache_misses": fixture.previews.misses,
                    "height_cache_misses": fixture.heights.misses,
                    "reload_data_calls": fixture.table.reloadCalls,
                    "inserted_rows": fixture.table.insertedRows,
                ]
                let report = try JSONSerialization.data(withJSONObject: measurements, options: [.sortedKeys])
                print("PAGINATION_BENCHMARK \(String(decoding: report, as: UTF8.self))")

                XCTAssertEqual(try snapshot(fixture, locations: locations), before)
                XCTAssertEqual(fixture.table.contentOffset.y, oldOffset.y, accuracy: 0.5)
                XCTAssertGreaterThan(fixture.table.contentSize.height, oldHeight)
                XCTAssertEqual(fixture.stories.storyLocationsCount, Int32(count + 12))
                XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), expectedRowCount(storyCount: count + 12))
                try verifyRowMappings(fixture, storyCount: count + 12)
                let appended = try snapshot(fixture, locations: Array(count..<(count + 12)))
                XCTAssertTrue(appended.allSatisfy { $0.preview.contains("café") })
            }
        }
    }

    private func makeFixture(storyCount: Int) -> PaginationFixture {
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.isPremium = true
        appDelegate.isPremiumArchive = true
        appDelegate.selectedIntelligence = 0
        appDelegate.recentlyReadStories = NSMutableDictionary()
        appDelegate.dictFeeds = [
            "1": ["id": 1, "feed_title": "Performance & Engineering", "active": 1],
            "2": ["id": 2, "feed_title": "Related Coverage", "active": 1],
        ]
        let stories = PaginationStoriesCollection()
        stories.appDelegate = appDelegate
        stories.isRiverView = true
        stories.activeFolder = "everything"
        stories.feedPage = 2
        stories.setStories(makeStories(0..<storyCount))
        appDelegate.storiesCollection = stories

        let controller = PaginationRenderController()
        controller.appDelegate = appDelegate
        controller.storiesCollection = stories
        let table = PaginationMeasurementTable(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        table.estimatedRowHeight = 0
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.pageFetching = true
        let previews = PaginationMeasurementCache()
        previews.countLimit = 512
        let heights = PaginationMeasurementCache()
        heights.countLimit = 1_024
        controller.setValue(previews, forKey: "storyPreviewTextCache")
        controller.setValue(heights, forKey: "storyHeightCache")
        table.dataSource = controller
        table.delegate = controller
        controller.reloadTable()
        table.layoutIfNeeded()
        table.contentOffset.y = max(0, table.contentSize.height - table.bounds.height - 40)
        table.layoutIfNeeded()
        return PaginationFixture(controller: controller, stories: stories, table: table, previews: previews, heights: heights)
    }

    private func makeStories(_ indices: Range<Int>) -> [[String: Any]] {
        indices.map { index in
            let paragraph = "<p>Reading caf&#233; news &amp; technical analysis with <strong>native scrolling</strong>, <a href='https://example.test/\(index)'>sources</a>, and varied article content.</p>"
            var story: [String: Any] = [
                "story_hash": "pagination-\(index)",
                "story_feed_id": 1,
                "story_title": "Report \(index) &amp; native scrolling",
                "story_content": "<article><h2>Report \(index)</h2>" + String(repeating: paragraph, count: 10 + index % 6) + "</article>",
                "story_authors": "Reporter \(index % 7)",
                "short_parsed_date": "3m",
                "story_timestamp": 1_800_000_000 - index,
                "read_status": index % 4 == 0 ? 1 : 0,
                "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0],
                "image_urls": index % 3 == 0 ? ["https://example.test/images/\(index).jpg"] : [],
            ]
            if index % 10 == 0 {
                story["cluster_stories"] = [[
                    "story_hash": "related-\(index)",
                    "story_feed_id": 2,
                    "story_title": "Related \(index) &amp; coverage",
                    "story_timestamp": 1_800_000_000 - index,
                    "cluster_tier": "semantic",
                    "read_status": 0,
                    "image_urls": ["https://example.test/images/related-\(index).jpg"],
                ]]
            }
            return story
        }
    }

    private func insertTailForExperiment(_ fixture: PaginationFixture, oldRows: Int) throws {
        // StoryPaginationPerformanceTests.swift changes only the test instance, using the real row builder and UITableView.
        let result = fixture.controller.perform(NSSelectorFromString("buildVisibleStoryRows"))?.takeUnretainedValue()
        let descriptors = try XCTUnwrap(result as? [[String: Any]])
        fixture.controller.setValue(descriptors, forKey: "visibleStoryRows")
        let paths = ((oldRows - 1)..<descriptors.count).map { IndexPath(row: $0, section: 0) }
        UIView.performWithoutAnimation {
            fixture.table.insertRows(at: paths, with: .none)
        }
    }

    private func snapshot(_ fixture: PaginationFixture, locations: [Int]) throws -> [PaginationCellSnapshot] {
        try locations.map { location in
            let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: location))
            let cell = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: path) as? FeedDetailTableCell)
            let story = try XCTUnwrap(fixture.controller.getStory(atLocation: location))
            XCTAssertEqual(cell.storyTitle, "Report \(location) & native scrolling")
            return PaginationCellSnapshot(
                hash: cell.storyHash ?? "", title: cell.storyTitle ?? "", preview: cell.storyContent ?? "",
                height: fixture.controller.tableView(fixture.table, heightForRowAt: path),
                imageURLs: story["image_urls"] as? [String] ?? [], isRead: cell.isRead
            )
        }
    }

    private func verifyRowMappings(_ fixture: PaginationFixture, storyCount: Int) throws {
        let descriptors = try XCTUnwrap(fixture.controller.value(forKey: "visibleStoryRows") as? [[String: Any]])
        let storyRows = descriptors.filter { ($0["type"] as? Int) == 0 }
        XCTAssertEqual(storyRows.compactMap { $0["story_location"] as? Int }, Array(0..<storyCount))
        for location in stride(from: 0, to: storyCount, by: 10) {
            let parentPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: location))
            let clusterPath = IndexPath(row: parentPath.row + 1, section: 0)
            let cluster = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: clusterPath) as? FeedDetailTableCell)
            XCTAssertTrue(cluster.isClusterStory)
            XCTAssertEqual(cluster.storyHash, "related-\(location)")
            XCTAssertEqual(cluster.storyTitle, "Related \(location) & coverage")
        }
    }

    private func expectedRowCount(storyCount: Int) -> Int {
        storyCount + (storyCount + 9) / 10 + 1
    }
}

private enum PaginationApplyMode: String {
    case productionReload
    case experimentalTailInsertion
}

private struct PaginationCellSnapshot: Equatable {
    let hash: String
    let title: String
    let preview: String
    let height: CGFloat
    let imageURLs: [String]
    let isRead: Bool
}

@MainActor private struct PaginationFixture {
    let controller: PaginationRenderController
    let stories: PaginationStoriesCollection
    let table: PaginationMeasurementTable
    let previews: PaginationMeasurementCache
    let heights: PaginationMeasurementCache

    func resetMeasurements() {
        controller.heightCalls = 0
        table.reloadCalls = 0
        table.insertedRows = 0
        previews.resetMeasurements()
        heights.resetMeasurements()
        stories.appendMilliseconds = 0
    }
}

@MainActor private final class PaginationRenderController: FeedDetailObjCViewController {
    var heightCalls = 0

    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    override func reload() { reloadTable() }
    override func checkScroll() {}
    override func scrollViewDidScroll(_ scrollView: UIScrollView!) {}

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        heightCalls += 1
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // StoryPaginationPerformanceTests.swift measures synchronous render work with no background warmup or network tasks.
    @objc(warmStoryPreviewCacheAroundLocation:)
    func suppressBackgroundWarmup(_ location: Int) {}

    @objc(cacheImagesForStories:)
    func suppressNetworkDownloads(_ stories: Any?) {}

    @objc(updateBottomNextFeedControlForScroll:)
    func suppressNavigationControls(_ scroll: UIScrollView) {}
}

private final class PaginationStoriesCollection: StoriesCollection {
    var appendMilliseconds = 0.0

    override func addStories(_ stories: [Any]!) {
        let started = CACurrentMediaTime()
        super.addStories(stories)
        appendMilliseconds += (CACurrentMediaTime() - started) * 1_000
    }
}

@MainActor private final class PaginationMeasurementTable: UITableView {
    var reloadCalls = 0
    var insertedRows = 0

    override func reloadData() {
        reloadCalls += 1
        super.reloadData()
    }

    override func insertRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        insertedRows += indexPaths.count
        super.insertRows(at: indexPaths, with: animation)
    }
}

private final class PaginationMeasurementCache: NSCache<NSString, NSObject> {
    private(set) var misses = 0
    private(set) var storedKeys: [String] = []

    override func object(forKey key: NSString) -> NSObject? {
        let object = super.object(forKey: key)
        if object == nil { misses += 1 }
        return object
    }

    override func setObject(_ obj: NSObject, forKey key: NSString) {
        storedKeys.append(key as String)
        super.setObject(obj, forKey: key)
    }

    func resetMeasurements() {
        misses = 0
        storedKeys.removeAll(keepingCapacity: true)
    }
}
