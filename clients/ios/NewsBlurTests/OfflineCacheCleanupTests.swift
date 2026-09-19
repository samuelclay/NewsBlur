import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_OfflineCacheCleanup: XCTestCase {
    func test_manualDeletionRemovesArticleTextAndReclaimsDiskSpaceWithoutLosingPendingActions() async throws {
        try await verifyManualDeletion(wal: false)
    }

    func test_manualDeletionReclaimsWALStorageAsWellAsDatabasePages() async throws {
        try await verifyManualDeletion(wal: true)
    }

    func test_partialImageCleanupFailureStillDiscardsURLsForDeletedOfflineFiles() async throws {
        try await verifyManualDeletion(wal: false, imageCleanupSucceeds: false)
    }

    private func verifyManualDeletion(wal: Bool, imageCleanupSucceeds: Bool = true) async throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.app.imageCleanupSucceeds = imageCleanupSucceeds
        fixture.app.activeCachedImages = ["https://example.com/image.jpg": "deleted.jpeg"]
        if wal {
            fixture.database.inDatabase { db in
                let rows = db!.executeQuery("PRAGMA journal_mode=WAL", withArgumentsIn: [])!
                XCTAssertTrue(rows.next())
                XCTAssertEqual(rows.string(forColumnIndex: 0), "wal")
                rows.close()
            }
        }
        fixture.seed(count: 8, payloadSize: 512 * 1024)
        let sizeBefore = try fixture.diskSize()
        XCTAssertGreaterThan(sizeBefore, 4 * 1024 * 1024)
        let defaults = UserDefaults.standard
        let key = "offline_cache_empty_stories"
        let oldValue = defaults.object(forKey: key)
        defer { defaults.set(oldValue, forKey: key) }
        defaults.set("Waiting for deletion", forKey: key)
        let controller = FeedsViewController()
        controller.appDelegate = fixture.app

        controller.perform(NSSelectorFromString("preferencesButtonTappedWithKey:action:"), with: key, with: "deleteOfflineStories")

        let expectedMessage = imageCleanupSucceeds ? "Cleared all stories and images!" : "Could not completely clear the cache. Please try again."
        let deadline = Date().addingTimeInterval(10)
        while defaults.string(forKey: key) != expectedMessage, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(defaults.string(forKey: key), expectedMessage)
        XCTAssertEqual(fixture.app.activeCachedImages.count, 0)
        XCTAssertEqual(fixture.count("stories"), 0)
        XCTAssertEqual(fixture.count("cached_text"), 0, "The Delete offline stories action must delete cached article text")
        XCTAssertEqual(fixture.count("cached_images"), 0)
        XCTAssertEqual(fixture.count("queued_read_hashes"), 1)
        XCTAssertEqual(fixture.count("queued_saved_hashes"), 1)
        XCTAssertEqual(fixture.count("accounts"), 1)
        let sizeAfter = try fixture.diskSize()
        print("Manual cache deletion (WAL=\(wal)): \(sizeBefore) -> \(sizeAfter) bytes")
        XCTAssertLessThan(sizeAfter, sizeBefore / 4, "Deleting rows must return the database's disk space")
    }

    func test_automaticCleanupBoundsReadStoriesWhenNoUnreadStoriesRemain() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)
        let defaults = UserDefaults.standard
        let previousLimit = defaults.object(forKey: "offline_store_limit")
        let previousOrder = defaults.object(forKey: "default_order")
        defer {
            defaults.set(previousLimit, forKey: "offline_store_limit")
            defaults.set(previousOrder, forKey: "default_order")
        }
        defaults.set(3, forKey: "offline_store_limit")
        defaults.set("newest", forKey: "default_order")
        let operationType = try XCTUnwrap(NSClassFromString("OfflineSyncUnreads") as? Operation.Type)
        let operation = operationType.init()
        operation.setValue(fixture.app, forKey: "appDelegate")

        operation.perform(NSSelectorFromString("storeUnreadHashes:"), with: ["unread_feed_story_hashes": [:]])

        XCTAssertEqual(fixture.count("stories"), 3, "Cleanup must enforce the storage limit even with zero unread stories")
        XCTAssertEqual(fixture.count("cached_text"), 3)
        XCTAssertEqual(fixture.count("cached_images"), 3)
        XCTAssertEqual(fixture.hashes(), ["42:5", "42:6", "42:7"])
        XCTAssertEqual(fixture.count("queued_read_hashes"), 1)
        XCTAssertEqual(fixture.count("queued_saved_hashes"), 1)
    }

    func test_manualDeletionReportsDatabaseFailureWithoutPartiallyDeletingStories() async throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)
        fixture.app.activeCachedImages = ["https://example.com/image.jpg": "retained.jpeg"]
        fixture.database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("CREATE TRIGGER fail_cache_deletion BEFORE DELETE ON cached_text BEGIN SELECT RAISE(ABORT, 'fixture failure'); END", withArgumentsIn: []))
        }
        let defaults = UserDefaults.standard
        let key = "offline_cache_empty_stories"
        let oldValue = defaults.object(forKey: key)
        defer { defaults.set(oldValue, forKey: key) }
        defaults.set("Waiting for deletion", forKey: key)
        let controller = FeedsViewController()
        controller.appDelegate = fixture.app

        controller.perform(NSSelectorFromString("preferencesButtonTappedWithKey:action:"), with: key, with: "deleteOfflineStories")

        let deadline = Date().addingTimeInterval(10)
        while ["Waiting for deletion", "Deleting..."].contains(defaults.string(forKey: key) ?? ""), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(defaults.string(forKey: key), "Could not completely clear the cache. Please try again.")
        XCTAssertEqual(fixture.count("stories"), 8, "A failed cache deletion must roll back")
        XCTAssertEqual(fixture.count("cached_text"), 8)
        XCTAssertEqual(fixture.count("queued_read_hashes"), 1)
        XCTAssertEqual(fixture.app.activeCachedImages.count, 1)
        XCTAssertFalse(fixture.app.clearingOfflineCache, "A failed deletion must allow retrying")
    }

    func test_automaticCleanupReservesSpaceForUnreadStoriesNotDownloadedYet() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)

        try sync(fixture, limit: 3, hashes: [["42:0", 1_800_000_000], ["42:missing", 1_800_000_100]])

        XCTAssertEqual(fixture.hashes(), ["42:0", "42:7"], "An unfetched unread story needs its own slot within the limit")
        XCTAssertEqual(fixture.count("unread_hashes"), 2)
        XCTAssertEqual(fixture.count("cached_text"), 2)
        XCTAssertEqual(fixture.count("cached_images"), 2)
    }

    func test_automaticCleanupPreservesReadingPositionsWithoutCachedStories() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)
        fixture.database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("INSERT INTO story_scrolls (story_hash, scroll) VALUES ('42:uncached', 0.75)", withArgumentsIn: []))
        }

        try sync(fixture, limit: 3, hashes: [])

        XCTAssertEqual(fixture.count("stories"), 3)
        XCTAssertEqual(fixture.count("story_scrolls"), 1, "Reading positions also belong to articles viewed without offline downloads")
    }

    func test_failedImageWriteStopsDownloadPassWithoutMarkingImageCached() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 1)
        fixture.database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("UPDATE cached_images SET image_cached = NULL", withArgumentsIn: []))
        }
        // OfflineCacheCleanupTests.swift uses a file in place of the directory to reproduce an unwritable destination.
        let directory = fixture.directory.appendingPathComponent("story_images")
        try FileManager.default.removeItem(at: directory)
        try Data([1]).write(to: directory)
        fixture.app.remainingUncachedImagesCount = 1
        let operationType = try XCTUnwrap(NSClassFromString("OfflineFetchImages") as? Operation.Type)
        let operation = operationType.init()
        operation.setValue(fixture.app, forKey: "appDelegate")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let selector = NSSelectorFromString("storeCachedImage:withImage:storyHash:storyTimestamp:")
        typealias StoreImage = @convention(c) (AnyObject, Selector, NSString, UIImage, NSString, Int) -> Void
        let storeImage = unsafeBitCast(operation.method(for: selector), to: StoreImage.self)

        storeImage(operation, selector, "https://example.com/0.jpg", image, "42:0", 1_800_000_000)

        XCTAssertTrue(operation.isCancelled, "An unwritable cache must stop the pass instead of redownloading the same image")
        XCTAssertEqual(fixture.app.remainingUncachedImagesCount, 1, "A failed write must not advance the download progress")
        fixture.database.inDatabase { db in
            let rows = db!.executeQuery("SELECT image_cached FROM cached_images", withArgumentsIn: [])!
            XCTAssertTrue(rows.next())
            XCTAssertTrue(rows.columnIsNull("image_cached"))
            rows.close()
        }
    }

    func test_oldestUnreadOrderStillRetainsMostRecentReadStoriesInSpareSpace() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)

        try sync(fixture, limit: 3, order: "oldest", hashes: [["42:1", 1_800_000_001]])

        XCTAssertEqual(fixture.hashes(), ["42:1", "42:6", "42:7"])
    }

    func test_unreadSelectionHonorsBothSortOrdersAndExactLimitForTiedTimestamps() throws {
        for order in ["newest", "oldest"] {
            let fixture = try OfflineCleanupFixture()
            defer { fixture.close() }
            fixture.seed(count: 8)
            let hashes: [[Any]] = (0..<8).map { ["42:\($0)", 1_800_000_000 + $0] }
            try sync(fixture, limit: 3, order: order, hashes: hashes)
            XCTAssertEqual(fixture.hashes(), order == "oldest" ? ["42:0", "42:1", "42:2"] : ["42:5", "42:6", "42:7"])
            XCTAssertEqual(fixture.count("unread_hashes"), 3)

            let ties: [[Any]] = (0..<8).map { ["42:\($0)", 1_800_000_000] }
            try sync(fixture, limit: 3, order: order, hashes: ties)
            XCTAssertEqual(fixture.count("unread_hashes"), 3, "Timestamp ties must not exceed the configured limit")
            XCTAssertLessThanOrEqual(fixture.count("stories"), 3)
        }
    }

    func test_automaticCleanupDeletesEvictedImageFilesButPreservesSharedURLs() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)
        let sharedURL = "https://example.com/shared.jpg"
        fixture.database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("INSERT INTO cached_images VALUES (42, '42:0', ?, 1, 0)", withArgumentsIn: [sharedURL]))
            XCTAssertTrue(db!.executeUpdate("INSERT INTO cached_images VALUES (42, '42:7', ?, 1, 0)", withArgumentsIn: [sharedURL]))
        }
        let directory = fixture.directory.appendingPathComponent("story_images")
        let urls = (0..<8).map { "https://example.com/\($0).jpg" } + [sharedURL]
        for url in urls {
            try Data(repeating: 1, count: 1024).write(to: directory.appendingPathComponent(Utilities.md5(url) + ".jpeg"))
        }

        try sync(fixture, limit: 3, hashes: [])

        for (index, url) in urls.enumerated() {
            let exists = FileManager.default.fileExists(atPath: directory.appendingPathComponent(Utilities.md5(url) + ".jpeg").path)
            XCTAssertEqual(exists, index >= 5, "Shared images must remain while a retained story uses them: \(url)")
        }
    }

    func test_automaticCleanupCompactsSubstantialUnusedDatabaseSpace() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8, payloadSize: 512 * 1024)
        let before = try fixture.diskSize()

        try sync(fixture, limit: 3, hashes: [])

        XCTAssertEqual(fixture.count("stories"), 3)
        let after = try fixture.diskSize()
        print("Automatic cache cleanup: \(before) -> \(after) bytes")
        XCTAssertLessThan(after, before / 2)
    }

    func test_malformedUnreadResponseDoesNotDiscardOfflineData() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 8)
        fixture.database.inDatabase { db in
            XCTAssertTrue(db!.executeUpdate("INSERT INTO unread_hashes VALUES (42, '42:0', 1800000000)", withArgumentsIn: []))
        }
        let operationType = try XCTUnwrap(NSClassFromString("OfflineSyncUnreads") as? Operation.Type)
        let responses: [Any] = [[:], ["unread_feed_story_hashes": NSNull()], ["unread_feed_story_hashes": ["42": ["bad tuple"]]], []]
        for malformed in responses {
            let operation = operationType.init()
            operation.setValue(fixture.app, forKey: "appDelegate")
            operation.perform(NSSelectorFromString("storeUnreadHashes:"), with: malformed)
            XCTAssertEqual(fixture.count("stories"), 8)
            XCTAssertEqual(fixture.count("unread_hashes"), 1)
            XCTAssertEqual(fixture.count("cached_text"), 8)
        }
    }

    func test_cancelledDownloadCannotRefillStoriesAfterManualDeletion() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        let operationType = try XCTUnwrap(NSClassFromString("OfflineFetchStories") as? Operation.Type)
        let operation = operationType.init()
        operation.setValue(fixture.app, forKey: "appDelegate")
        operation.cancel()
        let response: [String: Any] = ["stories": [["story_hash": "42:late", "story_feed_id": 42,
                                                    "story_timestamp": 1_800_000_000, "image_urls": []]]]

        operation.perform(NSSelectorFromString("storeAllUnreadStories:withHashes:"), with: response, with: ["42:late"])

        XCTAssertEqual(fixture.count("stories"), 0)
        XCTAssertEqual(fixture.count("cached_text"), 0)
        XCTAssertEqual(fixture.count("cached_images"), 0)
    }

    func test_cancelledTextDownloadCannotOverwriteNewCache() throws {
        let fixture = try OfflineCleanupFixture()
        defer { fixture.close() }
        fixture.seed(count: 1)
        let operationType = try XCTUnwrap(NSClassFromString("OfflineFetchText") as? Operation.Type)
        let operation = operationType.init()
        operation.setValue(fixture.app, forKey: "appDelegate")
        operation.cancel()

        operation.perform(NSSelectorFromString("storeTextDictionary:forStoryHash:"), with: ["text": "late old response"], with: "42:0")

        fixture.database.inDatabase { db in
            let rows = db!.executeQuery("SELECT text_json FROM cached_text", withArgumentsIn: [])!
            XCTAssertTrue(rows.next())
            XCTAssertEqual(rows.string(forColumn: "text_json"), String(repeating: "x", count: 32))
            rows.close()
        }
    }

    private func sync(_ fixture: OfflineCleanupFixture, limit: Int, order: String = "newest", hashes: [[Any]]) throws {
        let defaults = UserDefaults.standard
        let previousLimit = defaults.object(forKey: "offline_store_limit")
        let previousOrder = defaults.object(forKey: "default_order")
        defer {
            defaults.set(previousLimit, forKey: "offline_store_limit")
            defaults.set(previousOrder, forKey: "default_order")
        }
        defaults.set(limit, forKey: "offline_store_limit")
        defaults.set(order, forKey: "default_order")
        let operationType = try XCTUnwrap(NSClassFromString("OfflineSyncUnreads") as? Operation.Type)
        let operation = operationType.init()
        operation.setValue(fixture.app, forKey: "appDelegate")
        operation.perform(NSSelectorFromString("storeUnreadHashes:"), with: ["unread_feed_story_hashes": ["42": hashes]])
    }
}

private final class OfflineCleanupFixture {
    let app = OfflineCleanupApp()
    let directory: URL
    let database: FMDatabaseQueue
    let path: String

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        path = directory.appendingPathComponent("offline.sqlite").path
        database = try XCTUnwrap(FMDatabaseQueue(path: path))
        app.fixtureDocumentsURL = directory
        app.database = database
        database.inDatabase { db in
            self.app.setupDatabase(db, force: false)
        }
    }

    func seed(count: Int, payloadSize: Int = 32) {
        database.inTransaction { db, _ in
            guard let db else { return XCTFail("Missing fixture database") }
            let payload = String(repeating: "x", count: payloadSize)
            for index in 0..<count {
                XCTAssertTrue(db.executeUpdate("INSERT INTO stories (story_feed_id, story_hash, story_timestamp, story_json) VALUES (42, ?, ?, ?)", withArgumentsIn: ["42:\(index)", 1_800_000_000 + index, payload]))
                XCTAssertTrue(db.executeUpdate("INSERT INTO cached_text VALUES (42, ?, ?, ?)", withArgumentsIn: ["42:\(index)", 1_800_000_000 + index, payload]))
                XCTAssertTrue(db.executeUpdate("INSERT INTO cached_images VALUES (42, ?, ?, 1, 0)", withArgumentsIn: ["42:\(index)", "https://example.com/\(index).jpg"]))
            }
            XCTAssertTrue(db.executeUpdate("INSERT INTO queued_read_hashes VALUES (42, '42:0')", withArgumentsIn: []))
            XCTAssertTrue(db.executeUpdate("INSERT INTO queued_saved_hashes VALUES (42, '42:1', 1, '{}')", withArgumentsIn: []))
            XCTAssertTrue(db.executeUpdate("INSERT INTO accounts VALUES ('cache-test', 0, '{}')", withArgumentsIn: []))
        }
    }

    func count(_ table: String) -> Int {
        var result = -1
        database.inDatabase { db in
            let rows = db?.executeQuery("SELECT COUNT(*) AS count FROM \(table)", withArgumentsIn: [])
            if rows?.next() == true { result = Int(rows!.int(forColumn: "count")) }
            rows?.close()
        }
        return result
    }

    func hashes() -> [String] {
        var result: [String] = []
        database.inDatabase { db in
            let rows = db?.executeQuery("SELECT story_hash FROM stories ORDER BY story_timestamp", withArgumentsIn: [])
            while rows?.next() == true { result.append(rows!.string(forColumn: "story_hash")!) }
            rows?.close()
        }
        return result
    }

    func diskSize() throws -> Int {
        try [path, path + "-wal", path + "-shm"].filter { FileManager.default.fileExists(atPath: $0) }.reduce(0) { total, file in
            let attributes = try FileManager.default.attributesOfItem(atPath: file)
            return total + (attributes[.size] as! NSNumber).intValue
        }
    }

    func close() {
        database.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class OfflineCleanupApp: NewsBlurAppDelegate {
    var fixtureDocumentsURL: URL!
    var imageCleanupSucceeds = true
    override var documentsURL: URL! { fixtureDocumentsURL }
    // OfflineCacheCleanupTests.swift isolates the database from the simulator's shared image cache and network.
    override func deleteAllCachedImages(completion: @escaping (Bool) -> Void) { completion(imageCleanupSucceeds) }
    override func startOfflineFetchStories() {}
}
