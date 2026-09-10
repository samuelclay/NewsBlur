import XCTest
import UIKit
import ObjectiveC.runtime

@testable import NewsBlur

@MainActor final class Test_StoryTextLayoutEviction: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = ["story_list_preview_text_size", "story_list_preview_images_size", "feed_list_spacing"]
    private var saved: [String: Any] = [:]
    private let title = "Older unread story 数学 العربية 👩🏽‍🔬"

    override func setUp() {
        super.setUp()
        for key in keys { saved[key] = defaults.object(forKey: key) }
        defaults.set("medium", forKey: keys[0])
        defaults.set("none", forKey: keys[1])
        defaults.set("comfortable", forKey: keys[2])
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        saved.removeAll()
        super.tearDown()
    }

    func test_evictedOlderPreviewIsPreparedBeforeItsNextVisibleDraw() throws {
        let fixture = makeFixture(storyCount: 1_000)
        let (app, controller, table, previews, queue) =
            (fixture.app, fixture.controller, fixture.table, fixture.previews, fixture.layoutQueue)
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

    func test_cancelledQueuedBatchReleasesItsReservationAndPreparesCurrentRows() throws {
        let fixture = makeFixture(storyCount: 30)
        fixture.previewQueue.isSuspended = true
        let cancelled = (0..<24).map { IndexPath(row: $0, section: 0) }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: cancelled)
        prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: cancelled)
        let current = IndexPath(row: 29, section: 0)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [current])

        let measured = expectation(description: "Current row prepared after a cancelled queued batch")
        let probe = try TextMeasurementProbe(matching: ["Loaded story 29"]) { isMain in
            if !isMain { measured.fulfill() }
        }
        defer { probe.restore() }
        fixture.previewQueue.isSuspended = false
        wait(for: [measured], timeout: 5)
        fixture.layoutQueue.sync {}

        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.worker, 1)
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.main, 0)
        for index in 0..<24 { XCTAssertNil(fixture.previews.object(forKey: "eviction-\(index)" as NSString)) }
        XCTAssertNotNil(fixture.previews.object(forKey: "eviction-29"))
    }

    func test_sameHashContentMutationRejectsTheOldPreviewAndPreparesTheNewContent() throws {
        let fixture = makeFixture(storyCount: 1)
        let entered = expectation(description: "Worker owns an immutable old-content snapshot")
        let resume = DispatchSemaphore(value: 0)
        fixture.controller.normalizationRecorder.beforeNormalize = { source, isMain in
            if !isMain && source.contains("Preview eviction fixture") {
                entered.fulfill()
                resume.wait()
            }
        }
        defer { resume.signal() }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [IndexPath(row: 0, section: 0)])
        wait(for: [entered], timeout: 5)

        var updated = try XCTUnwrap(fixture.controller.getStoryAtLocation(0))
        updated["story_content"] = "<p>Updated source 数学 العربية &amp; intact entities.</p>"
        fixture.stories.setStories([updated])
        let measured = expectation(description: "Only current content reaches exact layout preparation")
        let probe = try TextMeasurementProbe(matching: [title]) { isMain in
            if !isMain { measured.fulfill() }
        }
        defer { probe.restore() }
        resume.signal()
        wait(for: [measured], timeout: 5)
        fixture.layoutQueue.sync {}

        let preview = try XCTUnwrap(fixture.previews.object(forKey: "eviction-0"))
        XCTAssertTrue(preview.contains("Updated source"))
        XCTAssertFalse(preview.contains("Preview eviction fixture"))
        XCTAssertFalse(preview.contains("&amp;"))
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.worker, 2)
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.main, 0)
    }

    func test_generationResetDuringNormalizationRejectsTheResultAndStopsRemainingRows() throws {
        let fixture = makeFixture(storyCount: 24)
        let entered = expectation(description: "First row is normalizing")
        let resume = DispatchSemaphore(value: 0)
        let recorder = fixture.controller.normalizationRecorder
        recorder.beforeNormalize = { _, isMain in
            if !isMain {
                recorder.beforeNormalize = nil
                entered.fulfill()
                resume.wait()
            }
        }
        defer { resume.signal() }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: (0..<24).map { IndexPath(row: $0, section: 0) })
        wait(for: [entered], timeout: 5)
        fixture.controller.perform(NSSelectorFromString("clearStoryRenderCaches"))
        resume.signal()
        waitForPreviewCompletion(fixture)

        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.worker, 1,
                       "StoryTextLayoutEvictionTests.swift verifies cancellation between rows of an active batch.")
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.main, 0)
        for index in 0..<24 { XCTAssertNil(fixture.previews.object(forKey: "eviction-\(index)" as NSString)) }
    }

    func test_previewBatchBoundsSourceBytesBeforeItsFirstPublication() throws {
        let largeContent = "<p>" + String(repeating: "x", count: 524_288) + "</p>"
        let fixture = makeFixture(storyCount: 24, content: largeContent)
        fixture.previewQueue.isSuspended = true
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        let paths = (0..<24).map { IndexPath(row: $0, section: 0) }
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        fixture.previewQueue.isSuspended = false
        // StoryTextLayoutEvictionTests.swift holds main publication so this observes only the first reserved batch.
        fixture.previewQueue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.worker, 3,
                       "Four 1 MiB HTML sources plus metadata would exceed the 4 MiB active-batch budget.")
        prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: paths)
        waitForPreviewCompletion(fixture)
        XCTAssertEqual(fixture.controller.normalizationRecorder.counts.main, 0)
    }

    private func waitForPreviewCompletion(_ fixture: EvictionLayoutFixture) {
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            fixture.controller.value(forKey: "storyPreviewPrefetchOperation") == nil
        }, object: nil)
        wait(for: [completed], timeout: 5)
    }

    private func makeFixture(storyCount: Int, content: String? = nil) -> EvictionLayoutFixture {
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
        let paragraph = "<p>Preview eviction fixture with <strong>数学 العربية 👩🏽‍🔬</strong> and &amp; HTML entities.</p>"
        stories.setStories((0..<storyCount).map { index -> [String: Any] in
            ["story_hash": "eviction-\(index)", "story_feed_id": 1,
             "story_title": index == 0 ? title : "Loaded story \(index)",
             "story_content": content ?? String(repeating: paragraph, count: 20),
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
        controller.setValue((0..<storyCount).map { ["type": 0, "story_location": $0] }, forKey: "visibleStoryRows")
        let previews = NSCache<NSString, NSString>()
        previews.countLimit = 512
        controller.setValue(previews, forKey: "storyPreviewTextCache")
        let layoutQueue = DispatchQueue(label: "test.story-text-layout.evicted")
        controller.setValue(StoryTextLayoutCache(worker: layoutQueue), forKey: "storyTextLayoutCache")
        let previewQueue = OperationQueue()
        previewQueue.maxConcurrentOperationCount = 1
        controller.setValue(previewQueue, forKey: "storyPreviewPrefetchQueue")
        return EvictionLayoutFixture(app: app, stories: stories, controller: controller,
            table: table, previews: previews, layoutQueue: layoutQueue, previewQueue: previewQueue)
    }
}

@MainActor private struct EvictionLayoutFixture {
    let app: EvictionLayoutAppDelegate
    let stories: StoriesCollection
    let controller: EvictionLayoutController
    let table: UITableView
    let previews: NSCache<NSString, NSString>
    let layoutQueue: DispatchQueue
    let previewQueue: OperationQueue
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
        normalizationRecorder.record(source: story["story_content"] as? String ?? "", main: Thread.isMainThread)
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
    private var hook: ((String, Bool) -> Void)?
    var beforeNormalize: ((String, Bool) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return hook
        }
        set {
            lock.lock()
            hook = newValue
            lock.unlock()
        }
    }
    func record(source: String, main isMain: Bool) {
        lock.lock()
        if isMain { main += 1 } else { worker += 1 }
        let callback = hook
        lock.unlock()
        callback?(source, isMain)
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
