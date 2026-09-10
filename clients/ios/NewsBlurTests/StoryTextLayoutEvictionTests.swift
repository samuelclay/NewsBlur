import XCTest
import UIKit
import ObjectiveC.runtime

@testable import NewsBlur

@MainActor final class Test_StoryTextLayoutEviction: XCTestCase {
    func test_evictedOlderPreviewIsPreparedBeforeItsNextVisibleDraw() throws {
        let defaults = UserDefaults.standard
        let keys = ["story_list_preview_text_size", "story_list_preview_images_size", "feed_list_spacing"]
        let saved = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defaults.set("medium", forKey: keys[0])
        defaults.set("none", forKey: keys[1])
        defaults.set("comfortable", forKey: keys[2])
        defer {
            for key in keys {
                if let value = saved[key] ?? nil { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        let app = EvictionLayoutAppDelegate()
        app.isPremium = true
        app.selectedIntelligence = 0
        app.recentlyReadStories = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Eviction fixture", "active": 1]]
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.isRiverView = true
        stories.activeFolder = "everything"
        let title = "Older unread story 数学 العربية 👩🏽‍🔬"
        let paragraph = "<p>Preview eviction fixture with <strong>数学 العربية 👩🏽‍🔬</strong> and &amp; HTML entities.</p>"
        stories.setStories((0..<1_000).map { index -> [String: Any] in
            ["story_hash": "eviction-\(index)", "story_feed_id": 1,
             "story_title": index == 0 ? title : "Loaded story \(index)",
             "story_content": String(repeating: paragraph, count: 20),
             "story_authors": "Author", "short_parsed_date": "3m", "story_timestamp": 1_800_000_000 - index,
             "read_status": 0, "intelligence": ["feed": 0, "title": 0, "author": 0, "tags": 0]]
        })
        let controller = EvictionLayoutController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.textSize = FeedDetailTextSize(rawValue: 2)!
        controller.pageFetching = true
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.setValue((0..<1_000).map { ["type": 0, "story_location": $0] }, forKey: "visibleStoryRows")
        let previews = NSCache<NSString, NSString>()
        previews.countLimit = 512
        controller.setValue(previews, forKey: "storyPreviewTextCache")
        let queue = DispatchQueue(label: "test.story-text-layout.evicted")
        let layouts = StoryTextLayoutCache(worker: queue)
        controller.setValue(layouts, forKey: "storyTextLayoutCache")
        let path = IndexPath(row: 0, section: 0)

        // StoryTextLayoutEvictionTests.swift primes the real HTML normalizer, then recreates bounded-cache eviction.
        let previousCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: path) as? FeedDetailTableCell)
        let preview = try XCTUnwrap(previousCell.storyContent)
        XCTAssertTrue(preview.contains("Preview eviction fixture"))
        XCTAssertFalse(preview.contains("<strong>"))
        XCTAssertNotNil(previews.object(forKey: "eviction-0"))
        previews.removeObject(forKey: "eviction-0")
        XCTAssertNil(previews.object(forKey: "eviction-0"))
        controller.normalizationRecorder.reset()

        let prepared = expectation(description: "Evicted row's title and actual normalized preview prepared off main")
        prepared.expectedFulfillmentCount = 2
        let probe = try TextMeasurementProbe(matching: [title, preview]) { isMain in
            if !isMain { prepared.fulfill() }
        }
        defer { probe.restore() }
        let prefetcher = try XCTUnwrap(controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(table, prefetchRowsAt: [path])
        wait(for: [prepared], timeout: 5)
        queue.sync {}

        let started = CACurrentMediaTime()
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: path) as? FeedDetailTableCell)
        cell.setValue(app, forKey: "appDelegate")
        let height = controller.tableView(table, heightForRowAt: path)
        let view = FeedDetailTableCellView(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        view.cell = cell
        view.appDelegate = app
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in view.draw(view.bounds) }
        let normalizations = controller.normalizationRecorder.counts
        print("PREVIEW_EVICTION_BENCHMARK loaded_stories=1000 worker_normalizations=\(normalizations.worker) main_normalizations=\(normalizations.main) worker_layout_ms=\(probe.workerMilliseconds) main_layouts=\(probe.counts.main) first_cell_and_draw_ms=\((CACurrentMediaTime() - started) * 1_000)")
        XCTAssertEqual(cell.storyContent, preview)
        XCTAssertEqual(image.size.width, 390)
        XCTAssertGreaterThan(normalizations.worker, 0, "An evicted nearby preview needs a new background normalization request.")
        XCTAssertEqual(normalizations.main, 0, "Returning to an older row should not normalize its HTML during cell creation.")
        XCTAssertEqual(probe.counts.main, 0, "The older row's first visible draw should consume prepared geometry.")
    }
}

private final class EvictionLayoutAppDelegate: NewsBlurAppDelegate {
    override func getFavicon(_ feedId: String!) -> UIImage! { nil }
    override func cachedImage(forStoryHash storyHash: String!) -> UIImage! { nil }
}

@MainActor private final class EvictionLayoutController: FeedDetailViewController {
    nonisolated let normalizationRecorder = EvictionNormalizationRecorder()
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override func viewDidLoad() {}
    override func checkScroll() {}

    @objc(normalizedPreviewTextForStory:)
    nonisolated func recordNormalization(_ story: NSDictionary) -> NSString {
        normalizationRecorder.record(main: Thread.isMainThread)
        let selector = NSSelectorFromString("normalizedPreviewTextForStory:")
        let method = class_getInstanceMethod(FeedDetailObjCViewController.self, selector)!
        typealias Function = @convention(c) (AnyObject, Selector, NSDictionary) -> Unmanaged<NSString>
        let original = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return original(self, selector, story).takeUnretainedValue()
    }
}

private final class EvictionNormalizationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var main = 0
    private var worker = 0
    func record(main isMain: Bool) {
        lock.lock()
        if isMain { main += 1 } else { worker += 1 }
        lock.unlock()
    }
    func reset() {
        lock.lock()
        main = 0
        worker = 0
        lock.unlock()
    }
    var counts: (main: Int, worker: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (main, worker)
    }
}
