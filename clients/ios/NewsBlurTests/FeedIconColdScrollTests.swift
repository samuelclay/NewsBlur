import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedIconColdScroll: XCTestCase {
    func test_firstPassAfterFeedReloadUsesPreparedArtworkWithoutForegroundDiskReads() throws {
        let feedCount = 651
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("favicon.png")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = UIGraphicsImageRenderer(size: CGSize(width: 384, height: 384), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 384, height: 384))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 140, y: 0, width: 60, height: 384))
        }
        try XCTUnwrap(original.pngData()).write(to: file)
        let cache = ColdFeedDiskCache(file: file)
        let app = NewsBlurAppDelegate()
        app.setValue(cache, forKey: "cachedFavicons")
        app.selectedIntelligence = 0
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        app.dictFoldersArray = ["dashboard", "daily_briefing", "Sites"]
        app.dictFolders = ["dashboard": [], "daily_briefing": [], "Sites": Array(1...feedCount)]
        app.dictSubfolders = [:]
        app.collapsedFolders = [:]
        app.dictInactiveFeeds = [:]
        app.dictFeedIcons = [:]
        app.dictFeeds = NSMutableDictionary()
        app.dictUnreadCounts = NSMutableDictionary()
        for index in 1...feedCount {
            app.dictFeeds["\(index)"] = ["id": index, "feed_title": "Site \(index)", "active": 1]
            app.dictUnreadCounts["\(index)"] = ["nt": 1]
        }
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        let controller = ColdFeedController()
        controller.appDelegate = app
        controller.viewShowingAllFeeds = true
        controller.feedTitlesTable = table
        controller.setValue(NSMutableDictionary(), forKey: "rowHeights")
        controller.setValue(OperationQueue(), forKey: "faviconPrefetchQueue")
        controller.setValue(NSMutableDictionary(), forKey: "faviconPrefetchOperations")
        let renderer = try XCTUnwrap(app.value(forKey: "feedIconRenderer") as? FeedIconRenderer)
        let size = CGSize(width: 16, height: 16)

        // FeedIconColdScrollTests.swift enters through the production feed-data reload before the first fast pass.
        let snapshotStarted = CACurrentMediaTime()
        controller.reloadFeedTitlesTable()
        let snapshotMilliseconds = (CACurrentMediaTime() - snapshotStarted) * 1_000
        let prepared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            renderer.image(forKey: "\(feedCount)", size: size) { nil } != nil
        }, object: nil)
        wait(for: [prepared], timeout: 10)
        let backgroundReads = cache.diskCache.counts.worker
        let originalPromotions = cache.memoryCache.workerWrites
        cache.diskCache.resetCounts()
        let expected = try XCTUnwrap(Utilities.roundCorneredImage(original, radius: 4, convertTo: size)).pngData()
        var cellMilliseconds = [Double]()
        for row in 0..<feedCount {
            try autoreleasepool {
                let started = CACurrentMediaTime()
                let cell = controller.tableView(table, cellForRowAt: IndexPath(row: row, section: 2))
                cellMilliseconds.append((CACurrentMediaTime() - started) * 1_000)
                let icon = try XCTUnwrap(cell.value(forKey: "feedFavicon") as? UIImage)
                XCTAssertEqual(cell.value(forKey: "feedTitle") as? String, "Site \(row + 1)")
                XCTAssertEqual(icon.size, size)
                XCTAssertEqual(cell.value(forKey: "feedFaviconPrepared") as? Bool, true)
                if row == 0 || row == feedCount - 1 { XCTAssertEqual(icon.pngData(), expected) }
            }
        }
        let sorted = cellMilliseconds.sorted()
        print("FEED_PREPARATION_BENCHMARK feeds=\(feedCount) snapshot_and_reload_ms=\(snapshotMilliseconds) worker_disk_reads=\(backgroundReads) foreground_disk_reads=\(cache.diskCache.counts.main) original_worker_promotions=\(originalPromotions) cell_mean_ms=\(sorted.reduce(0, +) / Double(sorted.count)) cell_p95_ms=\(sorted[Int(Double(sorted.count - 1) * 0.95)]) cell_max_ms=\(sorted.last ?? 0)")
        XCTAssertEqual(backgroundReads, feedCount)
        XCTAssertEqual(cache.diskCache.counts.main, 0, "Cold first-pass cells must consume prepared artwork instead of entering the disk-cache lock.")
        XCTAssertEqual(originalPromotions, 0, "Preparing display-sized icons must not churn the 5 MiB original-image cache.")
    }
}

@MainActor private final class ColdFeedController: FeedsViewController {
    override func viewDidLoad() {}
}

private final class ColdFeedDiskCache: NSObject {
    @objc let memoryCache = ColdFeedMemoryStorage()
    @objc let diskCache: ColdFeedDiskStorage
    init(file: URL) { diskCache = ColdFeedDiskStorage(file: file) }
}

private final class ColdFeedMemoryStorage: NSObject {
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var writes = 0
    override init() {
        cache.countLimit = 12
        cache.totalCostLimit = 5 * 1_024 * 1_024
        super.init()
    }
    @objc(objectForKey:) func object(forKey key: NSString) -> UIImage? { cache.object(forKey: key) }
    @objc(setObject:forKey:withCost:) func setObject(_ image: UIImage, forKey key: NSString, withCost cost: UInt) {
        if !Thread.isMainThread {
            lock.lock()
            writes += 1
            lock.unlock()
        }
        cache.setObject(image, forKey: key, cost: Int(cost))
    }
    @objc func removeAllObjects() { cache.removeAllObjects() }
    var workerWrites: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }
}

private final class ColdFeedDiskStorage: NSObject {
    private let file: URL
    private let lock = NSLock()
    private var mainReads = 0
    private var workerReads = 0
    init(file: URL) { self.file = file }
    @objc(objectForKey:) func object(forKey key: NSString) -> UIImage? {
        lock.lock()
        if Thread.isMainThread { mainReads += 1 } else { workerReads += 1 }
        lock.unlock()
        guard let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }
    func resetCounts() {
        lock.lock()
        mainReads = 0
        workerReads = 0
        lock.unlock()
    }
    var counts: (main: Int, worker: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (mainReads, workerReads)
    }
}
