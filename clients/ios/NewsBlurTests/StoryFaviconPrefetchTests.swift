import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_StoryFaviconPrefetch: XCTestCase {
    private let defaults = UserDefaults.standard
    private let preferences: [String: Any] = [
        "story_clustering": true, "story_list_preview_images_size": "none",
        "story_list_preview_text_size": "none", "feed_list_spacing": "comfortable",
        "theme_style": "light", "theme_light": "light", "theme_dark": "dark",
    ]
    private var saved = [String: Any]()

    override func setUp() {
        super.setUp()
        for (key, value) in preferences {
            saved[key] = defaults.object(forKey: key)
            defaults.set(value, forKey: key)
        }
    }

    override func tearDown() {
        for key in preferences.keys {
            if let value = saved[key] { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        saved.removeAll()
        super.tearDown()
    }

    func test_deepNativePrefetchPreparesRegularAndClusterFaviconsWithoutForegroundDiskReads() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let paths = try fixture.nearbyPaths()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)

        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        fixture.queue.sync {}

        XCTAssertEqual(fixture.storage.diskCache.workerReads, 3, "Native prefetch must prepare the actual parent and cluster feed IDs, coalescing duplicate feeds.")
        let started = CACurrentMediaTime()
        for (path, key) in zip(paths, ["1", "2", "1", "3"]) {
            let cell = try fixture.cell(at: path)
            let rounded = try XCTUnwrap(cell.perform(NSSelectorFromString("roundedSiteFaviconImage"))?.takeUnretainedValue() as? UIImage)
            let original = try XCTUnwrap(fixture.sources[key])
            let expected = try XCTUnwrap(Utilities.roundCorneredImage(original, radius: 4, convertTo: CGSize(width: 16, height: 16)))
            XCTAssertEqual(rounded.pngData(), expected.pngData())
        }
        print("STORY_FAVICON_PREFETCH_BENCHMARK loaded_stories=1000 worker_reads=\(fixture.storage.diskCache.workerReads) main_reads=\(fixture.storage.diskCache.mainReads) cell_and_icon_ms=\((CACurrentMediaTime() - started) * 1_000) original_worker_promotions=\(fixture.storage.memoryCache.workerWrites)")
        XCTAssertEqual(fixture.storage.diskCache.mainReads, 0, "A prepared deep-scroll row must not enter PINDiskCache or its file timestamp write on main.")
        XCTAssertEqual(fixture.storage.memoryCache.workerWrites, 0, "Preparing nearby artwork must not refill the raw original cache.")
    }

    func test_prefetchedCellPixelsMatchOriginalRoundingAcrossThemesReadStatesAndClusterRows() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let paths = try fixture.nearbyPaths()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        fixture.queue.sync {}

        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for isRead in [false, true] {
                for (path, key) in zip(paths, ["1", "2", "1", "3"]) {
                    let cell = try fixture.cell(at: path)
                    cell.isRead = isRead
                    let actual = fixture.pixels(cell)
                    // StoryFaviconPrefetchTests.swift restores the original source setter and existing cell rounding for the reference.
                    cell.siteFavicon = fixture.sources[key]
                    let reference = fixture.pixels(cell)
                    XCTAssertEqual(actual, reference, "\(theme) read=\(isRead) row=\(path.row)")
                }
            }
        }
        XCTAssertEqual(fixture.storage.diskCache.mainReads, 0)
    }

    func test_nativeCancellationAndRenderResetDiscardQueuedFaviconPreparation() throws {
        for clearRenderState in [false, true] {
            let fixture = try makeFixture()
            defer { fixture.close() }
            let paths = try fixture.nearbyPaths()
            let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
            fixture.queue.suspend()
            prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
            XCTAssertEqual(fixture.renderer.pendingPreparationCount, 3)
            if clearRenderState { fixture.controller.perform(NSSelectorFromString("clearStoryRenderCaches")) }
            else { prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: paths) }
            XCTAssertEqual(fixture.renderer.pendingPreparationCount, 0)
            fixture.queue.resume()
            fixture.queue.sync {}
            XCTAssertEqual(fixture.storage.diskCache.workerReads, 0)
        }
    }

    func test_faviconSaveDuringPrefetchCannotPublishTheOldSource() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 997))
        let readStarted = expectation(description: "The old icon is read by native prefetch")
        let release = DispatchSemaphore(value: 0)
        fixture.storage.diskCache.afterRead = { key, isMain in
            if key == "1" && !isMain {
                readStarted.fulfill()
                _ = release.wait(timeout: .now() + 5)
            }
        }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [path])
        wait(for: [readStarted], timeout: 1)
        let replacement = makeImage(size: CGSize(width: 96, height: 64), color: .green)
        fixture.app.saveFavicon(replacement, feedId: "1")
        release.signal()
        fixture.queue.sync {}
        fixture.storage.diskCache.afterRead = nil

        let cell = try fixture.cell(at: path)
        let actual = try XCTUnwrap(cell.perform(NSSelectorFromString("roundedSiteFaviconImage"))?.takeUnretainedValue() as? UIImage)
        let expected = try XCTUnwrap(Utilities.roundCorneredImage(replacement, radius: 4, convertTo: CGSize(width: 16, height: 16)))
        XCTAssertEqual(actual.pngData(), expected.pngData())
        XCTAssertEqual(fixture.storage.diskCache.mainReads, 0)
    }

    func test_missingFaviconKeepsTheExistingWorldArtworkWithoutForegroundDiskReads() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.storage.diskCache.remove("1")
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 997))
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [path])
        fixture.queue.sync {}

        let cell = try fixture.cell(at: path)
        let actual = try XCTUnwrap(cell.perform(NSSelectorFromString("roundedSiteFaviconImage"))?.takeUnretainedValue() as? UIImage)
        let expected = try XCTUnwrap(Utilities.roundCorneredImage(UIImage(named: "world.png"), radius: 4, convertTo: CGSize(width: 16, height: 16)))
        XCTAssertEqual(actual.pngData(), expected.pngData())
        XCTAssertEqual(fixture.storage.diskCache.workerReads, 1)
        XCTAssertEqual(fixture.storage.diskCache.mainReads, 0)
    }

    func test_reusedCellClearsPreparedArtworkForNilWorldAndOrdinaryImageAssignments() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 997))
        let cell = try fixture.cell(at: path)
        let setter = NSSelectorFromString("setPreparedSiteFavicon:")
        guard cell.responds(to: setter) else {
            return XCTFail("The cell needs an explicit prepared-artwork setter that preserves the original setter contract.")
        }
        let roundedSelector = NSSelectorFromString("roundedSiteFaviconImage")
        let prepared = try XCTUnwrap(Utilities.roundCorneredImage(fixture.sources["1"], radius: 4, convertTo: CGSize(width: 16, height: 16)))
        for replacement in [nil, UIImage(named: "world.png"), fixture.sources["2"], prepared] {
            cell.perform(setter, with: prepared)
            XCTAssertTrue(cell.perform(roundedSelector)?.takeUnretainedValue() as? UIImage === prepared)
            cell.siteFavicon = replacement
            let actual = cell.perform(roundedSelector)?.takeUnretainedValue() as? UIImage
            let expected = Utilities.roundCorneredImage(replacement, radius: 4, convertTo: CGSize(width: 16, height: 16))
            XCTAssertEqual(actual?.pngData(), expected?.pngData())
            XCTAssertEqual(cell.value(forKey: "siteFaviconPrepared") as? Bool, false)
        }
    }

    func test_oldTitleCancellationLeavesNewerFeedListPreparationAlive() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let paths = try fixture.nearbyPaths()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        fixture.queue.suspend()
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        // StoryFaviconPrefetchTests.swift uses identical IDs to ensure ownership is not inferred only from request contents.
        fixture.app.prepareFavicons(["1", "2", "3"].map {
            FeedIconPreparationRequest(key: $0, size: CGSize(width: 16, height: 16))
        })
        prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: paths)
        XCTAssertEqual(fixture.renderer.pendingPreparationCount, 3)
        fixture.queue.resume()
        fixture.queue.sync {}
        XCTAssertEqual(fixture.storage.diskCache.workerReads, 3)
        XCTAssertNotNil(fixture.renderer.image(forKey: "3", size: CGSize(width: 16, height: 16)) { nil })
    }

    func test_replacingNearbyRowsBoundsActiveAndQueuedFaviconWorkTogether() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let oldPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 997))
        let readStarted = expectation(description: "Original nearby icon entered its worker")
        let release = DispatchSemaphore(value: 0)
        fixture.storage.diskCache.afterRead = { key, main in
            if key == "1" && !main {
                readStarted.fulfill()
                _ = release.wait(timeout: .now() + 5)
            }
        }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [oldPath])
        wait(for: [readStarted], timeout: 1)
        var stories = try XCTUnwrap(fixture.controller.storiesCollection.activeFeedStories as? [[String: Any]])
        for index in 0..<100 { stories[index]["story_feed_id"] = index + 1_000 }
        fixture.controller.storiesCollection.setStories(stories)
        let newPaths = (0..<100).map { IndexPath(row: $0, section: 0) }

        prefetcher.tableView(fixture.table, prefetchRowsAt: newPaths)
        XCTAssertEqual(fixture.renderer.pendingPreparationCount, 24, "The old active disk read counts toward the same24-row bound.")
        prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: newPaths)
        XCTAssertEqual(fixture.renderer.pendingPreparationCount, 1)
        release.signal()
        fixture.queue.sync {}
        fixture.storage.diskCache.afterRead = nil
        XCTAssertEqual(fixture.renderer.pendingPreparationCount, 0)
        XCTAssertEqual(fixture.storage.diskCache.workerReads, 1)
        XCTAssertNil(fixture.renderer.image(forKey: "1", size: CGSize(width: 16, height: 16)) { nil })
    }

    func test_identicalFullNearbyRequestKeepsItsActiveReadAndPreparesEveryFeedOnce() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        var stories = try XCTUnwrap(fixture.controller.storiesCollection.activeFeedStories as? [[String: Any]])
        for index in 0..<24 { stories[index]["story_feed_id"] = index + 1 }
        fixture.controller.storiesCollection.setStories(stories)
        let paths = (0..<24).map { IndexPath(row: $0, section: 0) }
        let readStarted = expectation(description: "The first of24 nearby feeds entered its worker")
        let release = DispatchSemaphore(value: 0)
        fixture.storage.diskCache.afterRead = { key, main in
            if key == "1" && !main {
                readStarted.fulfill()
                _ = release.wait(timeout: .now() + 5)
            }
        }
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        wait(for: [readStarted], timeout: 1)

        // StoryFaviconPrefetchTests.swift repeats UIKit's same nearby window while its first read is active.
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        XCTAssertEqual(fixture.renderer.pendingPreparationCount, 24)
        fixture.storage.diskCache.afterRead = nil
        release.signal()
        fixture.queue.sync {}

        XCTAssertEqual(fixture.storage.diskCache.workerReadKeys, (1...24).map(String.init),
                       "An identical request must not cancel and reread its first feed or drop its24th feed.")
        XCTAssertEqual(fixture.storage.diskCache.mainReads, 0)
    }

    private func makeFixture() throws -> StoryFaviconFixture {
        let app = NewsBlurAppDelegate()
        app.isPremium = true
        app.isPremiumArchive = true
        app.selectedIntelligence = 0
        app.dictFeeds = NSMutableDictionary(dictionary: [
            "1": ["id": 1, "feed_title": "Primary", "active": 1],
            "2": ["id": 2, "feed_title": "Cluster", "active": 1],
            "3": ["id": 3, "feed_title": "Another", "active": 1],
        ])
        let sources = ["1": makeImage(size: CGSize(width: 384, height: 384), color: .orange),
                       "2": makeImage(size: CGSize(width: 41, height: 31), color: .purple),
                       "3": makeImage(size: CGSize(width: 96, height: 64), color: .cyan)]
        let storage = try StoryFaviconStorage(sources: sources)
        var decodedSources = [String: UIImage]()
        for key in sources.keys {
            decodedSources[key] = try XCTUnwrap(UIImage(contentsOfFile: storage.diskCache.directory.appendingPathComponent(key).path))
        }
        app.setValue(storage, forKey: "cachedFavicons")
        let queue = DispatchQueue(label: "test.story-favicon-prefetch")
        let renderer = FeedIconRenderer(preparationQueue: queue)
        app.setValue(renderer, forKey: "feedIconRenderer")
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.isRiverView = true
        stories.activeFolder = "everything"
        stories.feedPage = 80
        stories.setStories((0..<1_000).map { index -> [String: Any] in
            var story: [String: Any] = ["story_hash": "favicon-story-\(index)", "story_feed_id": index == 999 ? 3 : 1,
                "story_title": "Prepared favicon \(index)", "story_content": "<p>Preview</p>",
                "story_authors": "Reporter", "short_parsed_date": "3m", "story_timestamp": 1_800_000_000,
                "read_status": 0, "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0], "image_urls": []]
            if index == 997 {
                story["cluster_stories"] = [["story_hash": "favicon-child", "story_feed_id": "2",
                    "story_title": "Related coverage", "story_timestamp": 1_800_000_000,
                    "cluster_tier": "semantic", "read_status": 0, "image_urls": []]]
            }
            return story
        })
        app.storiesCollection = stories
        let controller = StoryFaviconController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.isOnline = false
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 707), style: .plain)
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.textSize = FeedDetailTextSize(rawValue: 0)!
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        return StoryFaviconFixture(app: app, controller: controller, table: table, renderer: renderer,
                                   queue: queue, storage: storage, sources: decodedSources)
    }

    private func makeImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.withAlphaComponent(0.7).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.blue.setFill()
            context.fill(CGRect(x: size.width / 3, y: 0, width: size.width / 5, height: size.height))
        }
    }
}

@MainActor private final class StoryFaviconController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override func viewDidLoad() {}
    override func checkScroll() {}
}

@MainActor private struct StoryFaviconFixture {
    let app: NewsBlurAppDelegate
    let controller: StoryFaviconController
    let table: UITableView
    let renderer: FeedIconRenderer
    let queue: DispatchQueue
    let storage: StoryFaviconStorage
    let sources: [String: UIImage]

    func nearbyPaths() throws -> [IndexPath] {
        let parent = try XCTUnwrap(controller.indexPath(forStoryLocation: 997))
        return [parent, IndexPath(row: parent.row + 1, section: 0),
                try XCTUnwrap(controller.indexPath(forStoryLocation: 998)),
                try XCTUnwrap(controller.indexPath(forStoryLocation: 999))]
    }

    func cell(at path: IndexPath) throws -> FeedDetailTableCell {
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: path) as? FeedDetailTableCell)
        cell.setValue(app, forKey: "appDelegate")
        return cell
    }

    func pixels(_ cell: FeedDetailTableCell) -> Data? {
        let view = FeedDetailTableCellView(frame: CGRect(x: 0, y: 0, width: 390, height: cell.isClusterStory ? 42 : 100))
        view.cell = cell
        view.appDelegate = app
        return UIGraphicsImageRenderer(size: view.bounds.size).image { _ in view.draw(view.bounds) }.pngData()
    }

    func close() {
        renderer.cancelPreparation()
        queue.sync {}
        try? FileManager.default.removeItem(at: storage.diskCache.directory)
    }
}

private final class StoryFaviconStorage: NSObject {
    @objc let memoryCache = StoryFaviconMemoryStorage()
    @objc let diskCache: StoryFaviconDiskStorage
    init(sources: [String: UIImage]) throws {
        diskCache = try StoryFaviconDiskStorage(sources: sources)
    }
}

private final class StoryFaviconMemoryStorage: NSObject {
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var writes = 0
    var workerWrites: Int { lock.lock(); defer { lock.unlock() }; return writes }
    @objc(objectForKey:) func object(forKey key: NSString) -> UIImage? { cache.object(forKey: key) }
    @objc(setObject:forKey:withCost:) func setObject(_ image: UIImage, forKey key: NSString, withCost cost: UInt) {
        lock.lock()
        if !Thread.isMainThread { writes += 1 }
        lock.unlock()
        cache.setObject(image, forKey: key, cost: Int(cost))
    }
    @objc func removeAllObjects() { cache.removeAllObjects() }
}

private final class StoryFaviconDiskStorage: NSObject {
    let directory: URL
    private let lock = NSLock()
    private var reads: [Bool: Int] = [:]
    private var workerKeys = [String]()
    var afterRead: ((String, Bool) -> Void)?
    var mainReads: Int { lock.lock(); defer { lock.unlock() }; return reads[true, default: 0] }
    var workerReads: Int { lock.lock(); defer { lock.unlock() }; return reads[false, default: 0] }
    var workerReadKeys: [String] { lock.lock(); defer { lock.unlock() }; return workerKeys }

    init(sources: [String: UIImage]) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (key, image) in sources { try image.pngData()?.write(to: directory.appendingPathComponent(key)) }
    }

    @objc(objectForKey:) func object(forKey key: String) -> UIImage? {
        let main = Thread.isMainThread
        lock.lock()
        reads[main, default: 0] += 1
        if !main { workerKeys.append(key) }
        lock.unlock()
        let image = UIImage(contentsOfFile: directory.appendingPathComponent(key).path)
        afterRead?(key, main)
        return image
    }

    @objc(setObject:forKey:) func setObject(_ image: UIImage, forKey key: String) {
        try? image.pngData()?.write(to: directory.appendingPathComponent(key))
    }

    func remove(_ key: String) { try? FileManager.default.removeItem(at: directory.appendingPathComponent(key)) }
}
