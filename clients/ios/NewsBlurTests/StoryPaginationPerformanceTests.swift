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

    func test_appendPreservesScrollMarkReadAnchor() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.setValue(40, forKey: "scrollingMarkReadRow")
        fixture.resetMeasurements()

        fixture.controller.renderStories(makeStories(100..<112))

        XCTAssertEqual(fixture.controller.value(forKey: "scrollingMarkReadRow") as? Int, 40)
        XCTAssertEqual(fixture.table.reloadCalls, 0)
        XCTAssertEqual(fixture.table.insertedRows, 14)
    }

    func test_fetchingLaterNativeRiverPageDoesNotRestartListPresentation() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.isOnline = false
        fixture.controller.pageFetching = false
        fixture.controller.setValue(40, forKey: "scrollingMarkReadRow")
        fixture.resetMeasurements()

        fixture.controller.fetchRiverPage(3, withCallback: nil)

        XCTAssertEqual(fixture.controller.loadingPresentations, 0,
                       "Presenting an existing list again schedules immediate and delayed whole-list reloads during scrolling.")
        XCTAssertEqual(fixture.controller.offlinePageLoads, 1)
        XCTAssertEqual(fixture.stories.feedPage, 3)
        XCTAssertTrue(fixture.controller.pageFetching)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 100)
        XCTAssertEqual(fixture.table.reloadCalls, 0)
        XCTAssertEqual(fixture.controller.value(forKey: "scrollingMarkReadRow") as? Int, 40)
    }

    func test_nonNativeRiverPaginationStillUpdatesItsPresentation() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.legacyTableForTest = false
        fixture.controller.isOnline = false
        fixture.controller.pageFetching = false

        fixture.controller.fetchRiverPage(3, withCallback: nil)

        XCTAssertEqual(fixture.controller.loadingPresentations, 1)
        XCTAssertEqual(fixture.controller.offlinePageLoads, 1)
        XCTAssertEqual(fixture.stories.feedPage, 3)
    }

    func test_nativePaginationStartsBeforeFastScrollReachesTheLoadingRow() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.isOnline = false
        fixture.controller.pageFetching = false
        fixture.controller.runsScrollCheck = true
        fixture.controller.setValue(NSNotFound, forKey: "scrollingMarkReadRow")
        let maximumOffset = fixture.table.contentSize.height - fixture.table.bounds.height
        fixture.table.contentOffset.y = maximumOffset - 1_000

        fixture.controller.checkScroll()

        XCTAssertEqual(fixture.controller.offlinePageLoads, 1,
                       "StoryPaginationPerformanceTests.swift reproduces waiting until less than one screen remains before preparing another page.")
        XCTAssertEqual(fixture.stories.feedPage, 3)
        fixture.controller.checkScroll()
        XCTAssertEqual(fixture.controller.offlinePageLoads, 1, "One pending page must coalesce repeated scroll callbacks.")
    }

    func test_nativePaginationDoesNotFetchPagesFarBeyondTheViewport() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.isOnline = false
        fixture.controller.pageFetching = false
        fixture.controller.runsScrollCheck = true
        fixture.controller.setValue(NSNotFound, forKey: "scrollingMarkReadRow")
        let maximumOffset = fixture.table.contentSize.height - fixture.table.bounds.height
        fixture.table.contentOffset.y = maximumOffset - 4 * fixture.table.bounds.height

        fixture.controller.checkScroll()

        XCTAssertEqual(fixture.controller.offlinePageLoads, 0)
        XCTAssertEqual(fixture.stories.feedPage, 2)
    }

    func test_dailyBriefingPaginationStillUsesItsPresentationAndLoader() {
        let fixture = makeFixture(storyCount: 100)
        fixture.stories.isDailyBriefing = true
        fixture.controller.pageFetching = false

        fixture.controller.fetchRiverPage(3, withCallback: nil)

        XCTAssertEqual(fixture.controller.loadingPresentations, 1)
        XCTAssertEqual(fixture.controller.dailyBriefingPages, [3])
        XCTAssertEqual(fixture.controller.offlinePageLoads, 0)
    }

    func test_emptyPageReloadsCompletionRow() {
        let fixture = makeFixture(storyCount: 100)
        fixture.resetMeasurements()

        fixture.controller.renderStories([])
        fixture.table.layoutIfNeeded()

        XCTAssertTrue(fixture.controller.pageFinished)
        XCTAssertEqual(fixture.table.reloadCalls, 1)
        XCTAssertEqual(fixture.table.insertedRows, 0)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 100)
    }

    func test_firstPageReplacementReloadsInsteadOfAppending() throws {
        let fixture = makeFixture(storyCount: 100)
        fixture.stories.feedPage = 1
        fixture.resetMeasurements()

        fixture.controller.renderStories(makeStories(200..<212))
        fixture.table.layoutIfNeeded()

        XCTAssertEqual(fixture.table.reloadCalls, 1)
        XCTAssertEqual(fixture.table.insertedRows, 0)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 12)
        let first = try XCTUnwrap(fixture.controller.getStoryAtLocation(0))
        XCTAssertEqual(first["story_hash"] as? String, "pagination-200")
    }

    func test_changedIntelligenceFilterFallsBackToReload() {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.appDelegate.selectedIntelligence = 1
        fixture.resetMeasurements()

        fixture.controller.renderStories(makeStories(100..<112))
        fixture.table.layoutIfNeeded()

        XCTAssertEqual(fixture.table.reloadCalls, 1)
        XCTAssertEqual(fixture.table.insertedRows, 0)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 0)
    }

    func test_changedTextSizeOrWidthFallsBackToReload() {
        for changeWidth in [false, true] {
            let fixture = makeFixture(storyCount: 100)
            if changeWidth {
                fixture.table.bounds.size.width = 320
            } else {
                defaults.set("long", forKey: "story_list_preview_text_size")
            }
            fixture.resetMeasurements()

            fixture.controller.renderStories(makeStories(100..<112))

            XCTAssertEqual(fixture.table.reloadCalls, 1)
            XCTAssertEqual(fixture.table.insertedRows, 0)
            defaults.set("medium", forKey: "story_list_preview_text_size")
        }
    }

    func test_changedClusterPreferenceOrSubscriptionsFallsBackToReload() {
        for changeSubscriptions in [false, true] {
            let fixture = makeFixture(storyCount: 100)
            if changeSubscriptions {
                fixture.controller.appDelegate.dictFeeds.removeObject(forKey: "2")
            } else {
                defaults.set(false, forKey: "story_clustering")
            }
            fixture.resetMeasurements()

            fixture.controller.renderStories(makeStories(100..<112))
            fixture.table.layoutIfNeeded()

            XCTAssertEqual(fixture.table.reloadCalls, 1)
            XCTAssertEqual(fixture.table.insertedRows, 0)
            XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), 113)
            defaults.set(true, forKey: "story_clustering")
        }
    }

    func test_pageContainingOnlyHiddenStoriesPreservesNativeRowsAndReaderPosition() throws {
        let fixture = makeFixture(storyCount: 100)
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 36))
        fixture.table.tableFooterView = footer
        fixture.table.layoutIfNeeded()
        fixture.table.contentOffset.y = fixture.table.contentSize.height - fixture.table.bounds.height
        fixture.table.layoutIfNeeded()
        let selectedPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 99))
        fixture.table.selectRow(at: selectedPath, animated: false, scrollPosition: .none)
        let loadingPath = IndexPath(row: fixture.table.numberOfRows(inSection: 0) - 1, section: 0)
        let loadingCell = try XCTUnwrap(fixture.table.cellForRow(at: loadingPath))
        let visibleCells = fixture.table.visibleCells
        let originalRows = try XCTUnwrap(fixture.controller.value(forKey: "visibleStoryRows") as? NSArray)
        let originalIDs = fixture.stories.activeFeedStoryLocationIds
        let originalHeight = fixture.table.contentSize.height
        let originalOffset = fixture.table.contentOffset
        let before = try snapshot(fixture, locations: [0, 40, 99])
        fixture.controller.setValue(40, forKey: "scrollingMarkReadRow")
        fixture.resetMeasurements()

        fixture.controller.renderStories(makeHiddenStories(100..<112))
        fixture.table.layoutIfNeeded()

        XCTAssertEqual(fixture.stories.activeFeedStories.count, 112)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 100)
        XCTAssertEqual(fixture.stories.activeFeedStoryLocationIds, originalIDs)
        XCTAssertEqual(fixture.table.reloadCalls, 0, "A filtered append changes the raw model without changing the displayed rows.")
        XCTAssertEqual(fixture.table.insertedRows, 0)
        XCTAssertEqual(fixture.controller.heightCalls, 0)
        XCTAssertEqual(fixture.previews.storedKeys.count, 0)
        XCTAssertEqual(fixture.controller.value(forKey: "visibleStoryRows") as? NSArray, originalRows)
        XCTAssertEqual(fixture.table.visibleCells, visibleCells)
        XCTAssertTrue(fixture.table.cellForRow(at: loadingPath) === loadingCell)
        XCTAssertTrue(fixture.table.tableFooterView === footer)
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, selectedPath)
        XCTAssertEqual(fixture.table.contentSize.height, originalHeight)
        XCTAssertEqual(fixture.table.contentOffset, originalOffset)
        XCTAssertEqual(fixture.controller.value(forKey: "scrollingMarkReadRow") as? Int, 40)
        XCTAssertFalse(fixture.controller.pageFinished)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertEqual(try snapshot(fixture, locations: [0, 40, 99]), before)
        try verifyRowMappings(fixture, storyCount: 100)
    }

    func test_filteredPagesAdvanceOnceAndLaterVisiblePageUsesCorrectModelLocations() async throws {
        let fixture = makeFixture(storyCount: 100)
        fixture.controller.isOnline = false
        fixture.controller.setValue(40, forKey: "scrollingMarkReadRow")
        fixture.resetMeasurements()

        for (page, indices) in [(3, 100..<112), (4, 112..<124)] {
            let nextPage = expectation(description: "Request page \(page) after a filtered response")
            fixture.controller.onOfflinePageLoad = { nextPage.fulfill() }
            fixture.controller.renderStories(makeHiddenStories(indices))
            await fulfillment(of: [nextPage], timeout: 1)
            fixture.controller.onOfflinePageLoad = nil

            XCTAssertEqual(fixture.controller.offlinePageLoads, page - 2)
            XCTAssertEqual(fixture.stories.feedPage, Int32(page))
            XCTAssertTrue(fixture.controller.pageFetching)
            XCTAssertFalse(fixture.controller.pageFinished)
            XCTAssertEqual(fixture.controller.value(forKey: "scrollingMarkReadRow") as? Int, 40)
            fixture.controller.fetchRiverPage(Int32(page + 1), withCallback: nil)
            XCTAssertEqual(fixture.controller.offlinePageLoads, page - 2, "The pending request still coalesces repeated fetch attempts.")
        }

        fixture.controller.renderStories(makeStories(124..<136))
        fixture.table.layoutIfNeeded()

        XCTAssertEqual(fixture.table.reloadCalls, 0)
        XCTAssertEqual(fixture.stories.activeFeedStories.count, 136)
        XCTAssertEqual(fixture.stories.storyLocationsCount, 112)
        XCTAssertEqual(fixture.table.insertedRows, 13)
        XCTAssertEqual(fixture.controller.getStoryAtLocation(100)?["story_hash"] as? String, "pagination-124")
        XCTAssertEqual(fixture.controller.getStoryAtLocation(111)?["story_hash"] as? String, "pagination-135")
        let parentPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 106))
        let cluster = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: IndexPath(row: parentPath.row + 1, section: 0)) as? FeedDetailTableCell)
        XCTAssertEqual(cluster.storyHash, "related-130")
        XCTAssertEqual(fixture.controller.value(forKey: "scrollingMarkReadRow") as? Int, 40)

        fixture.controller.renderStories([])
        fixture.table.layoutIfNeeded()
        XCTAssertTrue(fixture.controller.pageFinished)
        XCTAssertEqual(fixture.table.reloadCalls, 1, "An actually empty response still updates the completion row.")
    }

    func test_filteredPageDoesNotAdvanceFarFromTheViewportOrAfterNavigation() async {
        for changeFeed in [false, true] {
            let fixture = makeFixture(storyCount: 100)
            fixture.controller.isOnline = false
            if !changeFeed {
                fixture.table.contentOffset.y = 0
            }
            fixture.resetMeasurements()
            let unexpectedRequest = expectation(description: "No filtered-page continuation for an irrelevant viewport")
            unexpectedRequest.isInverted = true
            fixture.controller.onOfflinePageLoad = { unexpectedRequest.fulfill() }

            fixture.controller.renderStories(makeHiddenStories(100..<112))
            if changeFeed {
                fixture.stories.activeFolder = "another-folder"
            }
            await fulfillment(of: [unexpectedRequest], timeout: 0.15)

            XCTAssertEqual(fixture.controller.offlinePageLoads, 0)
            XCTAssertEqual(fixture.stories.feedPage, 2)
            XCTAssertEqual(fixture.table.reloadCalls, 0)
        }
    }

    func test_filteredAppendReloadsWhenExistingVisibleStoryOrClusterRowsChanged() throws {
        for changeCluster in [false, true] {
            let fixture = makeFixture(storyCount: 100)
            var stories = try XCTUnwrap(fixture.stories.activeFeedStories as? [[String: Any]])
            if changeCluster {
                stories[0].removeValue(forKey: "cluster_stories")
            } else {
                stories[0]["intelligence"] = ["feed": -1, "author": 0, "tags": 0, "title": 0]
            }
            fixture.stories.activeFeedStories = stories
            fixture.resetMeasurements()

            fixture.controller.renderStories(makeHiddenStories(100..<112))
            fixture.table.layoutIfNeeded()

            XCTAssertEqual(fixture.table.reloadCalls, 1)
            XCTAssertEqual(fixture.table.insertedRows, 0)
            XCTAssertEqual(fixture.stories.storyLocationsCount, changeCluster ? 100 : 99)
            XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), changeCluster ? 110 : 109)
        }
    }

    func test_filteredPageApplyDoesNotRebuildGeometryAtIncreasingStoryCounts() throws {
        for count in [100, 1_000, 5_000] {
            let fixture = makeFixture(storyCount: count)
            fixture.table.contentOffset.y = 0
            fixture.table.layoutIfNeeded()
            fixture.resetMeasurements()
            let started = CACurrentMediaTime()

            fixture.controller.renderStories(makeHiddenStories(count..<(count + 12)))
            fixture.table.layoutIfNeeded()

            let measurements: [String: Any] = [
                "existing_stories": count,
                "apply_ms": (CACurrentMediaTime() - started) * 1_000,
                "model_append_ms": fixture.stories.appendMilliseconds,
                "height_calls": fixture.controller.heightCalls,
                "preview_normalizations": fixture.previews.storedKeys.count,
                "reload_data_calls": fixture.table.reloadCalls,
            ]
            let report = try JSONSerialization.data(withJSONObject: measurements, options: [.sortedKeys])
            print("FILTERED_PAGINATION_BENCHMARK \(String(decoding: report, as: UTF8.self))")
            XCTAssertEqual(fixture.table.reloadCalls, 0)
            XCTAssertEqual(fixture.controller.heightCalls, 0)
            XCTAssertEqual(fixture.previews.storedKeys.count, 0)
        }
    }

    func test_warmHeightReturnsWithoutFontOrRenderCacheLookup() throws {
        let fixture = makeFixture(storyCount: 100)
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 40))
        let expected = fixture.controller.tableView(fixture.table, heightForRowAt: path)
        fixture.resetMeasurements()

        for _ in 0..<500 {
            XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), expected)
        }

        XCTAssertEqual(fixture.appDelegate.fontLookups, 0)
        XCTAssertEqual(fixture.heights.lookups, 0)
        XCTAssertEqual(fixture.previews.lookups, 0)
    }

    func test_sizingChangesInvalidateStoredRowGeometry() throws {
        let fixture = makeFixture(storyCount: 100)
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 40))
        let initialHeight = fixture.controller.tableView(fixture.table, heightForRowAt: path)
        defaults.set("long", forKey: "story_list_preview_text_size")
        fixture.table.bounds.size.width = 320
        fixture.resetMeasurements()

        fixture.controller.reloadWithSizing()
        fixture.table.layoutIfNeeded()
        let newHeight = fixture.controller.tableView(fixture.table, heightForRowAt: path)

        XCTAssertGreaterThan(newHeight, initialHeight)
        XCTAssertGreaterThan(fixture.appDelegate.fontLookups, 0)
        fixture.resetMeasurements()
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: path), newHeight)
        XCTAssertEqual(fixture.appDelegate.fontLookups, 0)
    }

    func test_appendedStoryCannotReuseFormerLoadingRowHeight() throws {
        let fixture = makeFixture(storyCount: 100)
        let formerLoadingPath = IndexPath(row: fixture.table.numberOfRows(inSection: 0) - 1, section: 0)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: formerLoadingPath), 40)

        fixture.controller.renderStories(makeStories(100..<112))
        fixture.table.layoutIfNeeded()

        let newStoryPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 100))
        XCTAssertEqual(newStoryPath, formerLoadingPath)
        XCTAssertGreaterThan(fixture.controller.tableView(fixture.table, heightForRowAt: newStoryPath), 40)
        let loadingPath = IndexPath(row: fixture.table.numberOfRows(inSection: 0) - 1, section: 0)
        XCTAssertEqual(fixture.controller.tableView(fixture.table, heightForRowAt: loadingPath), 40)
    }

    func test_fullPayloadRefreshInvalidatesPreviewAndGeometryBeforeAppend() throws {
        let fixture = makeFixture(storyCount: 100)
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 0))
        let initialHeight = fixture.controller.tableView(fixture.table, heightForRowAt: path)
        var updated = try XCTUnwrap(fixture.controller.getStoryAtLocation(0))
        updated["story_title"] = "Updated"
        updated["story_content"] = "<p>short</p>"
        let shareType = try XCTUnwrap(NSClassFromString("ShareViewController") as? UIViewController.Type)
        let share = shareType.init(nibName: nil, bundle: nil)
        share.setValue(fixture.appDelegate, forKey: "appDelegate")
        // StoryPaginationPerformanceTests.swift uses the real share/reply replacement entry point, without sending a request.
        share.perform(NSSelectorFromString("replaceStory:withReplyId:"), with: updated, with: nil)
        fixture.controller.renderStories(makeStories(100..<112))
        fixture.table.layoutIfNeeded()

        let cell = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: path) as? FeedDetailTableCell)
        XCTAssertEqual(cell.storyTitle, "Updated")
        XCTAssertEqual(cell.storyContent, "short")
        XCTAssertLessThan(fixture.controller.tableView(fixture.table, heightForRowAt: path), initialHeight)
    }

    private func makeFixture(storyCount: Int) -> PaginationFixture {
        let appDelegate = PaginationAppDelegate()
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
        appDelegate.testFeedDetail = controller
        controller.storiesCollection = stories
        let table = PaginationMeasurementTable(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        table.estimatedRowHeight = 0
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.isOnline = false
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
                "id": "pagination-\(index)",
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

    private func makeHiddenStories(_ indices: Range<Int>) -> [[String: Any]] {
        makeStories(indices).map { story in
            var hidden = story
            hidden["intelligence"] = ["feed": -1, "author": 0, "tags": 0, "title": 0]
            return hidden
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
            let story = try XCTUnwrap(fixture.controller.getStoryAtLocation(location))
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

    var appDelegate: PaginationAppDelegate { controller.appDelegate as! PaginationAppDelegate }

    func resetMeasurements() {
        controller.heightCalls = 0
        table.reloadCalls = 0
        table.insertedRows = 0
        previews.resetMeasurements()
        heights.resetMeasurements()
        stories.appendMilliseconds = 0
        appDelegate.fontLookups = 0
    }
}

private final class PaginationAppDelegate: NewsBlurAppDelegate {
    var fontLookups = 0
    weak var testFeedDetail: FeedDetailViewController?

    override var feedDetailViewController: FeedDetailViewController! {
        get { testFeedDetail }
        set { testFeedDetail = newValue }
    }

    override var fontDescriptorTitleSize: UIFontDescriptor! {
        get {
            fontLookups += 1
            return super.fontDescriptorTitleSize
        }
        set { super.fontDescriptorTitleSize = newValue }
    }
}

@MainActor private final class PaginationRenderController: FeedDetailViewController {
    var heightCalls = 0
    var legacyTableForTest = true
    var loadingPresentations = 0
    var offlinePageLoads = 0
    var dailyBriefingPages = [Int32]()
    var runsScrollCheck = false
    var onOfflinePageLoad: (() -> Void)?

    override var isLegacyTable: Bool { legacyTableForTest }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    override func reload() { reloadTable() }
    override func checkScroll() { if runsScrollCheck { super.checkScroll() } }
    override func scrollViewDidScroll(_ scrollView: UIScrollView!) {}
    override func loadingFeed() { loadingPresentations += 1 }
    override func loadOfflineStories() {
        offlinePageLoads += 1
        onOfflinePageLoad?()
    }
    override func fetchDailyBriefingPage(_ page: Int32, withCallback callback: (() -> Void)?) {
        dailyBriefingPages.append(page)
    }

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
    private(set) var lookups = 0
    private(set) var misses = 0
    private(set) var storedKeys: [String] = []

    override func object(forKey key: NSString) -> NSObject? {
        lookups += 1
        let object = super.object(forKey: key)
        if object == nil { misses += 1 }
        return object
    }

    override func setObject(_ obj: NSObject, forKey key: NSString) {
        storedKeys.append(key as String)
        super.setObject(obj, forKey: key)
    }

    func resetMeasurements() {
        lookups = 0
        misses = 0
        storedKeys.removeAll(keepingCapacity: true)
    }
}
