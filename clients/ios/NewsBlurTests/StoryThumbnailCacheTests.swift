import XCTest
import UIKit

@testable import NewsBlur

final class Test_StoryThumbnailCache: XCTestCase {
    func test_prefetchCapturesDisplayTraitsAndCancelsAnOlderSameHashPreparationWhenTheyChange() {
        let queue = DispatchQueue(label: "test.thumbnail-display.traits")
        let firstTraits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 2), UITraitCollection(displayGamut: .SRGB)])
        let nextTraits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 3), UITraitCollection(displayGamut: .P3)])
        let entered = expectation(description: "First display preparation is active")
        let resume = DispatchSemaphore(value: 0)
        var seen = [(CGFloat, UIDisplayGamut)]()
        var canceled = [Bool]()
        let prefetcher = StoryThumbnailPrefetcher(worker: queue) { _, operation in
            seen.append((UITraitCollection.current.displayScale, UITraitCollection.current.displayGamut))
            if seen.count == 1 {
                entered.fulfill()
                _ = resume.wait(timeout: .now() + 3)
            }
            canceled.append(operation.isCancelled)
        }
        firstTraits.performAsCurrent { prefetcher.prefetchStoryHashes(["story"]) }
        wait(for: [entered], timeout: 1)
        nextTraits.performAsCurrent { prefetcher.prefetchStoryHashes(["story"]) }
        resume.signal()
        queue.sync {}
        XCTAssertEqual(seen.map(\.0), [2, 3])
        XCTAssertEqual(seen.map(\.1), [.SRGB, .P3])
        XCTAssertEqual(canceled, [true, false], "The same story hash must be prepared again for a changed display")
    }

    func test_preparedMemoryThumbnailFallsBackToOriginalWhenDisplayScaleOrGamutChanges() throws {
        for changedTrait in [UITraitCollection(displayScale: 3), UITraitCollection(displayGamut: .P3)] {
            let (app, cache) = makeCache()
            let originalTraits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 2), UITraitCollection(displayGamut: .SRGB)])
            let prepared = makeImage()
            let source = ThumbnailPreparationImage(cgImage: try XCTUnwrap(prepared.cgImage), scale: prepared.scale, orientation: prepared.imageOrientation)
            source.preparation = { prepared }
            cache.diskCache.setObject(source, forKey: "story")
            let queue = DispatchQueue(label: "test.thumbnail-display.trait-cache")
            queue.async {
                originalTraits.performAsCurrent { app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation()) }
            }
            queue.sync {}
            originalTraits.performAsCurrent { XCTAssertTrue(app.cachedImage(forStoryHash: "story") === prepared) }
            XCTAssertEqual(cache.diskCache.readCount, 1)
            UITraitCollection(traitsFrom: [originalTraits, changedTrait]).performAsCurrent {
                XCTAssertTrue(app.cachedImage(forStoryHash: "story") === source, "Prepared pixels must not be reused on an incompatible display")
                XCTAssertTrue(app.cachedImage(forStoryHash: "story") === source)
            }
            XCTAssertEqual(cache.diskCache.readCount, 2)
            XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === source)
        }
    }

    func test_diskPrefetchPreparesTheBitmapOnItsWorkerWithoutRewritingTheOriginal() throws {
        let (app, cache) = makeCache()
        let prepared = makeImage()
        let source = ThumbnailPreparationImage(cgImage: try XCTUnwrap(prepared.cgImage), scale: prepared.scale, orientation: prepared.imageOrientation)
        var preparationThreads = [Bool]()
        source.preparation = {
            preparationThreads.append(Thread.isMainThread)
            return prepared
        }
        cache.diskCache.setObject(source, forKey: "story")
        let queue = DispatchQueue(label: "test.thumbnail-display.worker")
        let prefetcher = StoryThumbnailPrefetcher(worker: queue) { hash, operation in
            app.prefetchCachedStoryImage(forStoryHash: hash, operation: operation)
        }
        prefetcher.prefetchStoryHashes(["story"])
        queue.sync {}
        let bitmap = try XCTUnwrap(prepared.cgImage)
        XCTAssertEqual(preparationThreads, [false], "Disk unarchiving alone leaves image decoding until the Core Animation draw")
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === prepared)
        XCTAssertEqual(cache.memoryCache.cost(forKey: "story"), UInt(bitmap.bytesPerRow * bitmap.height))
        XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === source, "Display preparation must not replace the original disk representation")
        prefetcher.prefetchStoryHashes(["story"])
        queue.sync {}
        XCTAssertEqual(preparationThreads, [false], "Already prepared memory images must not be decoded repeatedly")
    }

    func test_failedDisplayPreparationRetainsTheOriginalAndForegroundFallbackStaysSynchronous() throws {
        let (app, cache) = makeCache()
        let source = ThumbnailPreparationImage(cgImage: try XCTUnwrap(makeImage().cgImage))
        var preparations = 0
        source.preparation = { preparations += 1; return nil }
        cache.diskCache.setObject(source, forKey: "story")
        XCTAssertTrue(app.cachedImage(forStoryHash: "story") === source)
        XCTAssertEqual(preparations, 0, "An outrun prefetch must retain the immediate original image without adding foreground preparation work")
        cache.memoryCache.removeAllObjects()
        let queue = DispatchQueue(label: "test.thumbnail-display.failure")
        queue.async {
            app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation())
        }
        queue.sync {}
        XCTAssertEqual(preparations, 1)
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === source)
        XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === source)
    }

    @MainActor func test_displayPreparationCannotPublishAfterCancellationNewerSaveRemovalAccountOrMemoryRelease() throws {
        for invalidation in ["cancel", "save", "save_then_evict", "remove", "account", "memory"] {
            let (app, cache) = makeCache()
            let prepared = makeImage()
            let newer = makeImage()
            let source = ThumbnailPreparationImage(cgImage: try XCTUnwrap(prepared.cgImage), scale: prepared.scale, orientation: prepared.imageOrientation)
            let entered = expectation(description: "Display preparation started: \(invalidation)")
            let resume = DispatchSemaphore(value: 0)
            source.preparation = {
                entered.fulfill()
                _ = resume.wait(timeout: .now() + 3)
                return prepared
            }
            cache.diskCache.setObject(source, forKey: "story")
            let operation = BlockOperation()
            let queue = DispatchQueue(label: "test.thumbnail-display.invalidation")
            queue.async { app.prefetchCachedStoryImage(forStoryHash: "story", operation: operation) }
            wait(for: [entered], timeout: 1)
            switch invalidation {
            case "cancel": operation.cancel()
            case "save", "save_then_evict":
                app.cacheStoryImage(newer, forStoryHash: "story")
                if invalidation == "save_then_evict" { cache.memoryCache.removeAllObjects() }
            case "remove": app.removeCachedStoryImage(forStoryHash: "story")
            case "account": app.dictFeeds = nil
            default: app.didReceiveMemoryWarning()
            }
            resume.signal()
            queue.sync {}
            if invalidation == "save" {
                XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === newer)
            } else {
                XCTAssertNil(cache.memoryCache.object(forKey: "story"), invalidation)
            }
            if invalidation == "cancel" {
                // StoryThumbnailCacheTests.swift ensures a canceled decode does not permanently suppress a later nearby retry.
                source.preparation = { prepared }
                queue.async { app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation()) }
                queue.sync {}
                XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === prepared)
            }
        }
    }

    @MainActor func test_preparedDiskThumbnailsPreserveExactCellPixelsAcrossColorOrientationScaleAndReadStates() throws {
        let defaults = UserDefaults.standard
        let previousPreference = defaults.object(forKey: "story_list_preview_images_size")
        defer {
            if let previousPreference { defaults.set(previousPreference, forKey: "story_list_preview_images_size") }
            else { defaults.removeObject(forKey: "story_list_preview_images_size") }
        }
        let (app, cache) = makeCache()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        app.recentlyReadStories = NSMutableDictionary()
        let queue = DispatchQueue(label: "test.thumbnail-display.pixel-parity")
        for colorSpaceName in [CGColorSpace.sRGB, CGColorSpace.displayP3] {
            let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
            let context = try XCTUnwrap(CGContext(data: nil, width: 63, height: 45, bitsPerComponent: 8, bytesPerRow: 0,
                                                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            for x in 0..<63 {
                context.setFillColor(try XCTUnwrap(CGColor(colorSpace: colorSpace, components: [CGFloat(x) / 62, 0.25, 1 - CGFloat(x) / 62, x < 20 ? 0.35 : 1])))
                context.fill(CGRect(x: x, y: 0, width: 1, height: 45))
            }
            let encoded = try XCTUnwrap(UIImage(cgImage: try XCTUnwrap(context.makeImage())).pngData())
            let decoded = try XCTUnwrap(UIImage(data: encoded)?.cgImage)
            for orientation in [UIImage.Orientation.up, .left, .rightMirrored] {
                for scale in [CGFloat(1), CGFloat(3)] {
                    let source = UIImage(cgImage: decoded, scale: scale, orientation: orientation)
                    cache.memoryCache.removeAllObjects()
                    cache.diskCache.setObject(source, forKey: "story")
                    queue.async { app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation()) }
                    queue.sync {}
                    let actual = try XCTUnwrap(cache.memoryCache.object(forKey: "story") as? UIImage)
                    XCTAssertEqual(actual.size, source.size)
                    XCTAssertEqual(actual.scale, source.scale)
                    XCTAssertEqual(actual.imageOrientation, source.imageOrientation)
                    let bitmap = try XCTUnwrap(actual.cgImage)
                    XCTAssertEqual(cache.memoryCache.cost(forKey: "story"), UInt(bitmap.bytesPerRow * bitmap.height))
                    XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === source)
                    for imageStyle in ["small_right", "large_left"] {
                        defaults.set(imageStyle, forKey: "story_list_preview_images_size")
                        for state in 0..<3 {
                            func cellPNG(_ image: UIImage) -> Data? {
                                cache.memoryCache.setObject(image, forKey: "story")
                                let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
                                cell.setValue(app, forKey: "appDelegate")
                                cell.storyHash = "story"
                                cell.storyTitle = "Exact thumbnail display preparation"
                                cell.storyContent = "Retain the original crop, colors, alpha, and read dimming."
                                cell.storyAuthor = "Fixture"
                                cell.storyDate = "3m"
                                cell.textSize = FeedDetailTextSize(rawValue: 0)!
                                cell.isRead = state > 0
                                cell.isHighlighted = state == 2
                                let view = FeedDetailTableCellView(frame: CGRect(x: 0, y: 0, width: 390, height: 180))
                                view.cell = cell
                                view.appDelegate = app
                                return UIGraphicsImageRenderer(size: view.bounds.size).image { _ in view.draw(view.bounds) }.pngData()
                            }
                            XCTAssertEqual(cellPNG(actual), cellPNG(source), "\(colorSpaceName), orientation=\(orientation.rawValue), scale=\(scale), \(imageStyle), state=\(state)")
                        }
                    }
                }
            }
        }
    }

    @MainActor func test_reversePrefetchRestoresEvictedDiskThumbnailBeforeTheOlderCellDraws() throws {
        let defaults = UserDefaults.standard
        let imagePreference = defaults.object(forKey: "story_list_preview_images_size")
        defaults.set("small_right", forKey: "story_list_preview_images_size")
        defer {
            if let imagePreference { defaults.set(imagePreference, forKey: "story_list_preview_images_size") }
            else { defaults.removeObject(forKey: "story_list_preview_images_size") }
        }
        let (app, cache) = makeCache()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        app.recentlyReadStories = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Reverse thumbnail fixture", "active": 1]]
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.activeFeed = ["id": 1]
        stories.setStories((0..<1_000).map { index -> [String: Any] in
            ["story_hash": "reverse-\(index)", "story_feed_id": 1,
             "story_title": "Reverse thumbnail fixture \(index)", "story_content": "Preview text",
             "story_authors": "Author", "short_parsed_date": "3m", "story_timestamp": 1_800_000_000 - index,
             "image_urls": ["https://example.test/\(index).jpg"], "read_status": 0,
             "intelligence": ["feed": 0, "title": 0, "author": 0, "tags": 0]]
        })
        let controller = ThumbnailPrefetchController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.textSize = FeedDetailTextSize(rawValue: 0)!
        controller.pageFetching = true
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.setValue((0..<1_000).map { ["type": 0, "story_location": $0] }, forKey: "visibleStoryRows")
        let path = IndexPath(row: 0, section: 0)
        cache.diskCache.setObject(makeImage(), forKey: "reverse-0")
        func drawOlderCell() throws -> Data? {
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: path) as? FeedDetailTableCell)
            cell.setValue(app, forKey: "appDelegate")
            let height = controller.tableView(table, heightForRowAt: path)
            let view = FeedDetailTableCellView(frame: CGRect(x: 0, y: 0, width: 390, height: height))
            view.cell = cell
            view.appDelegate = app
            return UIGraphicsImageRenderer(size: view.bounds.size).image { _ in view.draw(view.bounds) }.pngData()
        }
        let reference = try drawOlderCell()
        XCTAssertNotNil(cache.memoryCache.object(forKey: "reverse-0"))
        // StoryThumbnailCacheTests.swift reproduces an older image falling out of the bounded memory cache during a long forward scroll.
        cache.memoryCache.removeAllObjects()
        cache.diskCache.resetReadTracking()
        let warmed = expectation(description: "Evicted thumbnail read from disk before the reverse row becomes visible")
        cache.diskCache.onRead = { hash, isMain in
            if hash == "reverse-0" && !isMain { warmed.fulfill() }
        }
        defer { cache.diskCache.onRead = nil }
        let prefetcher = try XCTUnwrap(controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(table, prefetchRowsAt: [path])
        wait(for: [warmed], timeout: 2)
        let promoted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            cache.memoryCache.object(forKey: "reverse-0") is UIImage
        }, object: nil)
        wait(for: [promoted], timeout: 2)
        let started = CACurrentMediaTime()
        let actual = try drawOlderCell()
        print("THUMBNAIL_REVERSE_BENCHMARK loaded_stories=1000 main_disk_reads=\(cache.diskCache.mainReadCount) worker_disk_reads=\(cache.diskCache.readCount - cache.diskCache.mainReadCount) first_cell_draw_and_png_ms=\((CACurrentMediaTime() - started) * 1_000)")
        XCTAssertEqual(actual, reference, "The prefetched image keeps the exact existing cell rendering")
        XCTAssertEqual(cache.diskCache.mainReadCount, 0, "Reverse scrolling must not synchronously unarchive the evicted thumbnail while drawing")
        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_removingThumbnailDuringDiskReadRejectsItsOldResult() {
        let (appDelegate, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.removeCachedStoryImage(forStoryHash: "story")
        }

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertFalse(cache.diskCache.object(forKey: "story") is UIImage)
    }

    func test_thumbnailPrefetchCoalescesAndBoundsAbandonedReverseRows() {
        let queue = DispatchQueue(label: "test.thumbnail-prefetch.coalescing")
        queue.suspend()
        var loaded = [String]()
        let prefetcher = StoryThumbnailPrefetcher(worker: queue) { hash, _ in loaded.append(hash) }
        for page in 0..<100 {
            prefetcher.prefetchStoryHashes((0..<100).map { "page-\(page)-story-\($0)" })
            XCTAssertEqual(prefetcher.pendingHashCount, 24)
        }
        prefetcher.cancelAll()
        XCTAssertEqual(prefetcher.pendingHashCount, 0)
        prefetcher.prefetchStoryHashes(["current", "current", "", String(repeating: "x", count: 1_025)])
        XCTAssertEqual(prefetcher.pendingHashCount, 1)
        queue.resume()
        queue.sync {}
        XCTAssertEqual(loaded, ["current"])
        XCTAssertEqual(prefetcher.pendingHashCount, 0)
    }

    @MainActor func test_memoryWarningStopsActiveAndQueuedPrefetchForEveryControllerInEitherClearOrder() {
        for notificationFirst in [false, true] {
            let (app, cache) = makeCache()
            let image = makeImage()
            let leftHashes = (0..<24).map { "left-\($0)" }
            let rightHashes = (0..<24).map { "right-\($0)" }
            for hash in leftHashes + rightHashes { cache.diskCache.setObject(image, forKey: hash) }
            let entered = expectation(description: "Both title controllers have an active disk read")
            entered.expectedFulfillmentCount = 2
            let resume = DispatchSemaphore(value: 0)
            cache.diskCache.onRead = { hash, isMain in
                if !isMain && (hash == "left-0" || hash == "right-0") {
                    entered.fulfill()
                    _ = resume.wait(timeout: .now() + 2)
                }
            }
            let leftQueue = DispatchQueue(label: "test.thumbnail-memory.left")
            let rightQueue = DispatchQueue(label: "test.thumbnail-memory.right")
            let left = StoryThumbnailPrefetcher(worker: leftQueue) { hash, operation in
                app.prefetchCachedStoryImage(forStoryHash: hash, operation: operation)
            }
            let right = StoryThumbnailPrefetcher(worker: rightQueue) { hash, operation in
                app.prefetchCachedStoryImage(forStoryHash: hash, operation: operation)
            }
            left.prefetchStoryHashes(leftHashes)
            right.prefetchStoryHashes(rightHashes)
            wait(for: [entered], timeout: 2)
            // StoryThumbnailCacheTests.swift covers both notification orders because PINMemoryCache also clears memory independently.
            if notificationFirst { NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil) }
            app.didReceiveMemoryWarning()
            if !notificationFirst { NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil) }
            resume.signal()
            resume.signal()
            leftQueue.sync {}
            rightQueue.sync {}
            cache.diskCache.onRead = nil
            XCTAssertEqual(cache.diskCache.readCount, 2, "A memory warning must stop all queued thumbnail reads")
            for hash in leftHashes + rightHashes { XCTAssertNil(cache.memoryCache.object(forKey: hash)) }
            XCTAssertEqual(left.pendingHashCount, 0)
            XCTAssertEqual(right.pendingHashCount, 0)
        }
    }

    @MainActor func test_memoryWarningBitmapClearInvalidatesAnEarlierDiskPublication() {
        let (app, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        cache.diskCache.afterRead = { app.didReceiveMemoryWarning() }
        app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation())
        XCTAssertNil(cache.memoryCache.object(forKey: "story"), "Bitmap-only memory release must advance disk-promotion generation")
    }

    @MainActor func test_memoryWarningRetainsCompletedSourceOwnershipForLaterDiskReuse() {
        let (app, cache) = makeCache()
        let controller = makeController(appDelegate: app)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        let image = makeImage()
        finish(controller.requests[0], with: image, on: controller)
        app.didReceiveMemoryWarning()
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertNil(cache.memoryCache.object(forKey: "story"))
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 1)
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_scaledThumbnailSaveChargesDecodedBytesWithoutChangingItsPixelsOrMetadata() throws {
        let (app, cache) = makeCache()
        let bitmap = try XCTUnwrap(makeImage().cgImage)
        let image = UIImage(cgImage: bitmap, scale: 3, orientation: .right)
        app.cacheStoryImage(image, forStoryHash: "scaled")
        XCTAssertEqual(cache.memoryCache.cost(forKey: "scaled"), UInt(bitmap.bytesPerRow * bitmap.height))
        let stored = try XCTUnwrap(cache.memoryCache.object(forKey: "scaled") as? UIImage)
        XCTAssertTrue(stored === image)
        XCTAssertEqual(stored.scale, 3)
        XCTAssertEqual(stored.imageOrientation, .right)
        XCTAssertEqual(stored.pngData(), image.pngData())
    }

    func test_thumbnailPrefetchCancelsAnActiveReadAndLoadsTheNewDirection() {
        let queue = DispatchQueue(label: "test.thumbnail-prefetch.direction")
        let entered = expectation(description: "Old direction is reading its first image")
        let resume = DispatchSemaphore(value: 0)
        var published = [String]()
        let prefetcher = StoryThumbnailPrefetcher(worker: queue) { hash, operation in
            if hash == "old" {
                entered.fulfill()
                _ = resume.wait(timeout: .now() + 2)
            }
            if !operation.isCancelled { published.append(hash) }
        }
        prefetcher.prefetchStoryHashes(["old", "abandoned"])
        wait(for: [entered], timeout: 2)
        prefetcher.prefetchStoryHashes(["reverse"])
        resume.signal()
        queue.sync {}
        XCTAssertEqual(published, ["reverse"])
        XCTAssertEqual(prefetcher.pendingHashCount, 0)
    }

    func test_slowThumbnailPrefetchDoesNotHoldThePublicationLockOrOverwriteANewDownload() {
        let (app, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        let entered = expectation(description: "Disk prefetch is waiting outside the publication lock")
        let resume = DispatchSemaphore(value: 0)
        cache.diskCache.onRead = { _, isMain in
            if !isMain {
                entered.fulfill()
                _ = resume.wait(timeout: .now() + 2)
            }
        }
        let queue = DispatchQueue(label: "test.thumbnail-prefetch.publication")
        let prefetcher = StoryThumbnailPrefetcher(worker: queue) { hash, operation in
            app.prefetchCachedStoryImage(forStoryHash: hash, operation: operation)
        }
        prefetcher.prefetchStoryHashes(["story"])
        wait(for: [entered], timeout: 2)
        let newer = makeImage()
        let started = CACurrentMediaTime()
        app.cacheStoryImage(newer, forStoryHash: "story")
        XCTAssertLessThan(CACurrentMediaTime() - started, 0.1, "The main thread must not wait for an unrelated disk operation's lock")
        resume.signal()
        queue.sync {}
        cache.diskCache.onRead = nil
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === newer)
    }

    func test_prefetchRejectsDiskImageAfterConcurrentSaveEvenIfTheNewImageIsEvicted() {
        let (app, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        let newer = makeImage()
        cache.diskCache.afterRead = {
            app.cacheStoryImage(newer, forStoryHash: "story")
            cache.memoryCache.removeAllObjects()
        }
        app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation())
        XCTAssertNil(cache.memoryCache.object(forKey: "story"), "An old read cannot regain ownership after the newer bitmap was evicted")
        XCTAssertTrue(app.cachedImage(forStoryHash: "story") === newer)
    }

    func test_cancelRemovalAndAccountResetRejectInFlightDiskPrefetch() {
        for invalidation in ["cancel", "remove", "clear", "account"] {
            let (app, cache) = makeCache()
            cache.diskCache.setObject(makeImage(), forKey: "story")
            let operation = BlockOperation()
            cache.diskCache.afterRead = {
                switch invalidation {
                case "cancel": operation.cancel()
                case "remove": app.removeCachedStoryImage(forStoryHash: "story")
                case "clear": app.removeAllCachedStoryImages()
                default: app.dictFeeds = nil
                }
            }
            app.prefetchCachedStoryImage(forStoryHash: "story", operation: operation)
            XCTAssertNil(cache.memoryCache.object(forKey: "story"), invalidation)
        }
    }

    func test_prefetchedMissesAvoidRepeatedDiskReadsAndSuccessfulSourcesKeepTheirOwnership() {
        let (app, cache) = makeCache()
        app.prefetchCachedStoryImage(forStoryHash: "missing", operation: BlockOperation())
        for _ in 0..<500 { XCTAssertNil(app.cachedImage(forStoryHash: "missing")) }
        XCTAssertEqual(cache.diskCache.readCount, 1)

        let controller = makeController(appDelegate: app)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        let image = makeImage()
        finish(controller.requests[0], with: image, on: controller)
        cache.memoryCache.removeAllObjects()
        app.prefetchCachedStoryImage(forStoryHash: "story", operation: BlockOperation())
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 1)
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_removingAllThumbnailsDuringDiskReadRejectsItsOldResult() {
        let (appDelegate, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.removeAllCachedStoryImages()
        }

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertFalse(cache.diskCache.object(forKey: "story") is UIImage)
    }

    func test_removingOneThumbnailPreservesOtherImagesAndAllowsNewSave() {
        let (appDelegate, cache) = makeCache()
        let unrelated = makeImage()
        appDelegate.cacheStoryImage(makeImage(), forStoryHash: "story")
        appDelegate.cacheStoryImage(unrelated, forStoryHash: "other")

        appDelegate.removeCachedStoryImage(forStoryHash: "story")

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "other") === unrelated)
        let replacement = makeImage()
        appDelegate.cacheStoryImage(replacement, forStoryHash: "story")
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === replacement)
        XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_removingAllThumbnailsAllowsDiskRecoveryAfterNewSave() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        appDelegate.removeAllCachedStoryImages()
        let image = makeImage()
        appDelegate.cacheStoryImage(image, forStoryHash: "story")
        cache.memoryCache.removeAllObjects()

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_explicitFeedRefreshRequestsSameURLAgainWithoutHidingThumbnail() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let controller = makeController(appDelegate: appDelegate)
        let collection = StoriesCollection()
        collection.appDelegate = appDelegate
        collection.activeFeed = ["id": 1]
        controller.storiesCollection = collection
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        let image = makeImage()
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: image, on: controller)

        controller.instafetchFeed()
        cacheStories(stories, on: controller)

        XCTAssertEqual(appDelegate.feedRefreshRequests, 1)
        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_accountChangeRequestsSameURLAgainWithoutHidingThumbnail() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let controller = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = controller
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        let image = makeImage()
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: image, on: controller)

        // StoryThumbnailCacheTests.swift exercises the same feed reset used by NewsBlurAppDelegate.showLogin.
        appDelegate.dictFeeds = nil
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_missingThumbnailIsReadFromDiskOnlyOnceAcrossCellReuse() {
        let (appDelegate, cache) = makeCache()
        appDelegate.cacheStoryImagePlaceholder("missing")

        for _ in 0..<500 {
            XCTAssertNil(appDelegate.cachedImage(forStoryHash: "missing"))
        }

        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_legacyPlaceholderStillRecoversRealDiskThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(NSNull(), forKey: "story")
        cache.diskCache.setObject(image, forKey: "story")

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_savedThumbnailReplacesKnownMissAndSurvivesMemoryEviction() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        let image = makeImage()

        appDelegate.cacheStoryImage(image, forStoryHash: "story")
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        cache.memoryCache.removeAllObjects()
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_clearingMemoryCacheInvalidatesKnownMiss() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "story")
        cache.memoryCache.removeAllObjects()

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_placeholderCannotOverwriteDownloadFinishingAfterItsLookup() {
        let appDelegate = ThumbnailLookupRaceAppDelegate()
        let cache = ThumbnailCacheDouble()
        let image = makeImage()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        appDelegate.afterLookup = {
            appDelegate.cacheStoryImage(image, forStoryHash: "story")
        }

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_diskPromotionCannotOverwriteNewerDownload() {
        let (appDelegate, cache) = makeCache()
        let oldImage = makeImage()
        let newImage = makeImage()
        cache.diskCache.setObject(oldImage, forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.cacheStoryImage(newImage, forStoryHash: "story")
        }

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === newImage)
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === newImage)
    }

    func test_placeholderDoesNotReplaceWarmThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(image, forKey: "story")

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_placeholderDoesNotMaskThumbnailAlreadyOnDisk() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "story")

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_existingStoryAndClusterThumbnailsRemainVisibleDuringFirstSessionRefresh() {
        let (appDelegate, cache) = makeCache()
        let storyImage = makeImage()
        let clusterImage = makeImage()
        cache.memoryCache.setObject(storyImage, forKey: "story")
        cache.diskCache.setObject(clusterImage, forKey: "cluster")
        let controller = makeController(appDelegate: appDelegate)

        let stories: [[String: Any]] = [
            ["story_hash": "story", "image_urls": ["https://example.test/story.jpg"],
             "cluster_stories": [["story_hash": "cluster", "image_urls": ["https://example.test/cluster.jpg"]]]]
        ]
        cacheStories(stories, on: controller)
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "cluster"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === storyImage)
        XCTAssertTrue(cache.object(forKey: "cluster") as? UIImage === clusterImage)

        finish(controller.requests[0], with: storyImage, on: controller)
        finish(controller.requests[1], with: clusterImage, on: controller)
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requestedStoryHashes, ["story", "cluster"])
    }

    func test_missingThumbnailStillStartsDownload() {
        let (appDelegate, _) = makeCache()
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "missing", "image_urls": ["https://example.test/missing.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["missing"])
    }

    func test_failedThumbnailPlaceholderCanRetryOnLaterPageLoad() {
        let (appDelegate, cache) = makeCache()
        cache.memoryCache.setObject(NSNull(), forKey: "retry")
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "retry", "image_urls": ["https://example.test/retry.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["retry"])
    }

    func test_changedSourceRefreshesWithoutHidingPreviousThumbnail() {
        let (appDelegate, cache) = makeCache()
        let original = makeImage()
        let replacement = makeImage()
        cache.memoryCache.setObject(original, forKey: "story")
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        finish(controller.requests[0], with: original, on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === original)

        finish(controller.requests[1], with: replacement, on: controller)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
    }

    func test_obsoleteDownloadCannotOverwriteNewerSource() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let replacement = makeImage()

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        finish(controller.requests[1], with: replacement, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_failedRefreshRetriesAndKeepsOldThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(image, forKey: "story")
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]

        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: nil, on: controller)
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_revertingToCachedSourceDiscardsPendingReplacement() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        let controller = makeController(appDelegate: appDelegate)
        let original: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]

        cacheStories(original, on: controller)
        finish(controller.requests[0], with: image, on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        cacheStories(original, on: controller)
        finish(controller.requests[1], with: makeImage(), on: controller)

        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_explicitlyEmptyImageSourcesRemoveOldThumbnailAndRejectPendingResult() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        cache.memoryCache.setObject(makeImage(), forKey: "story")

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        cacheStories([["story_hash": "story", "image_urls": []]], on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
    }

    func test_resetAllowsCancelledSourceToBeRequestedAgain() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]

        cacheStories(stories, on: controller)
        controller.perform(NSSelectorFromString("resetStoryImageRequests"))
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
    }

    func test_anotherControllerCannotMakeCompletedSourcesHideAStaleSharedThumbnail() throws {
        let (appDelegate, cache) = makeCache()
        let previous = makeController(appDelegate: appDelegate)
        let current = makeController(appDelegate: appDelegate)
        let old: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]
        let updated: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]]
        cacheStories(old, on: previous)
        cacheStories(updated, on: current)
        let newImage = makeImage()
        finish(current.requests[0], with: newImage, on: current)
        let oldImage = makeImage()
        finish(previous.requests[0], with: oldImage, on: previous)

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === newImage, "An older controller must not overwrite a newer completed request, even before the next source lookup")
        cacheStories(updated, on: current)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === newImage)
        XCTAssertEqual(current.requests.count, 1, "The verified replacement should be reused")
    }

    func test_completedSourceStillReusesDiskImageAfterMemoryEviction() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        let image = makeImage()
        finish(controller.requests[0], with: image, on: controller)
        cache.memoryCache.removeAllObjects()
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 1)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_sourceLessImageSaveInvalidatesCompletedSourceOwnership() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)
        let replacement = makeImage()
        appDelegate.cacheStoryImage(replacement, forStoryHash: "story")
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_accountResetInvalidatesSourceOwnershipForAnotherLiveController() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let primary = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = primary
        let supplementary = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: supplementary)
        let image = makeImage()
        finish(supplementary.requests[0], with: image, on: supplementary)
        appDelegate.dictFeeds = nil
        cacheStories(stories, on: supplementary)
        XCTAssertEqual(supplementary.requests.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_sameSourceAcrossControllersAllowsEitherDownloadToSucceed() {
        for failedRequestFinishesFirst in [false, true] {
            let (appDelegate, cache) = makeCache()
            let first = makeController(appDelegate: appDelegate)
            let second = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: first)
            cacheStories(stories, on: second)
            let image = makeImage()
            if failedRequestFinishesFirst { finish(first.requests[0], with: nil, on: first) }
            finish(second.requests[0], with: image, on: second)
            if !failedRequestFinishesFirst { finish(first.requests[0], with: nil, on: first) }

            XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
            cacheStories(stories, on: second)
            XCTAssertEqual(second.requests.count, 1)
        }
    }

    func test_sameSourceAcrossControllersKeepsBothSuccessfulRequestsValid() {
        let (appDelegate, cache) = makeCache()
        let first = makeController(appDelegate: appDelegate)
        let second = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: first)
        cacheStories(stories, on: second)
        let firstImage = makeImage()
        let secondImage = makeImage()
        finish(first.requests[0], with: firstImage, on: first)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === firstImage)
        finish(second.requests[0], with: secondImage, on: second)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === secondImage)
        cacheStories(stories, on: first)
        cacheStories(stories, on: second)
        XCTAssertEqual(first.requests.count, 1)
        XCTAssertEqual(second.requests.count, 1)
    }

    func test_rejectedRequestClearsItsPendingStateAndCanRetry() throws {
        let (appDelegate, cache) = makeCache()
        let first = makeController(appDelegate: appDelegate)
        let second = makeController(appDelegate: appDelegate)
        let old: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]
        cacheStories(old, on: first)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: second)
        finish(first.requests[0], with: makeImage(), on: first)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
        XCTAssertNil((first.value(forKey: "pendingStoryImageRequests") as? NSDictionary)?["story"])

        cacheStories(old, on: first)
        XCTAssertEqual(first.requests.count, 2)
        let retry = try XCTUnwrap(first.requests.last)
        let image = makeImage()
        finish(retry, with: image, on: first)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_evictedSharedRequestDoesNotSuppressCompletionRetryOrPendingRetry() throws {
        for finishBeforeRetry in [false, true] {
            let (appDelegate, cache) = makeCache()
            let controller = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: controller)
            let sharedRequests = try XCTUnwrap(appDelegate.value(forKey: "storyImageRequests") as? NSCache<NSString, NSDictionary>)
            sharedRequests.removeAllObjects()
            if finishBeforeRetry {
                finish(controller.requests[0], with: makeImage(), on: controller)
                XCTAssertFalse(cache.object(forKey: "story") is UIImage)
                XCTAssertNil((controller.value(forKey: "pendingStoryImageRequests") as? NSDictionary)?["story"])
            }

            cacheStories(stories, on: controller)
            XCTAssertEqual(controller.requests.count, 2)
            let retry = try XCTUnwrap(controller.requests.last)
            let image = makeImage()
            finish(retry, with: image, on: controller)
            finish(controller.requests[0], with: makeImage(), on: controller)
            XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
        }
    }

    func test_explicitRefreshRejectsEarlierSameSourceFromAnotherControllerOnly() throws {
        let (appDelegate, cache) = makeCache()
        let previous = makeController(appDelegate: appDelegate)
        let current = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories + [["story_hash": "other", "image_urls": ["https://example.test/other.jpg"]]], on: previous)
        cacheStories(stories, on: current)
        let original = makeImage()
        finish(current.requests[0], with: original, on: current)
        current.resetStoryImageSources()
        cacheStories(stories, on: current)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === original)

        XCTAssertEqual(current.requests.count, 2)
        let refreshedRequest = try XCTUnwrap(current.requests.last)
        let refreshed = makeImage()
        finish(refreshedRequest, with: refreshed, on: current)
        finish(previous.requests[0], with: makeImage(), on: previous)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === refreshed)
        let unrelated = makeImage()
        finish(previous.requests[1], with: unrelated, on: previous)
        XCTAssertTrue(cache.object(forKey: "other") as? UIImage === unrelated)
    }

    func test_externalSaveOrRemovalRejectsAnotherControllersPendingImage() {
        for removeImage in [false, true] {
            let (appDelegate, cache) = makeCache()
            let controller = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: controller)
            let savedImage = makeImage()
            appDelegate.cacheStoryImage(savedImage, forStoryHash: "story")
            if removeImage { appDelegate.removeCachedStoryImage(forStoryHash: "story") }
            finish(controller.requests[0], with: makeImage(), on: controller)
            if removeImage {
                XCTAssertFalse(cache.object(forKey: "story") is UIImage)
            } else {
                XCTAssertTrue(cache.object(forKey: "story") as? UIImage === savedImage)
            }
            cacheStories(stories, on: controller)
            XCTAssertEqual(controller.requests.count, 2)
        }
    }

    func test_accountResetRejectsAnotherControllersPendingImageAndAllowsRetry() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let primary = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = primary
        let supplementary = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: supplementary)
        appDelegate.dictFeeds = nil
        finish(supplementary.requests[0], with: makeImage(), on: supplementary)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
        cacheStories(stories, on: supplementary)
        XCTAssertEqual(supplementary.requests.count, 2)
    }

    private func finish(_ request: NSDictionary, with image: UIImage?, on controller: ThumbnailDownloadController) {
        controller.perform(NSSelectorFromString("finishStoryImageRequest:withImage:"), with: request, with: image)
    }

    private func cacheStories(_ stories: [[String: Any]], on controller: ThumbnailDownloadController) {
        // StoryThumbnailCacheTests.swift intercepts the private download selector before any network work.
        controller.perform(NSSelectorFromString("cacheImagesForStories:"), with: stories)
        controller.appDelegate.cacheImagesOperationQueue.waitUntilAllOperationsAreFinished()
    }

    private func makeController(appDelegate: NewsBlurAppDelegate) -> ThumbnailDownloadController {
        appDelegate.cacheImagesOperationQueue = OperationQueue()
        appDelegate.cacheImagesOperationQueue.maxConcurrentOperationCount = 1
        let controller = ThumbnailDownloadController()
        controller.appDelegate = appDelegate
        return controller
    }

    private func makeCache() -> (NewsBlurAppDelegate, ThumbnailCacheDouble) {
        let appDelegate = NewsBlurAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        return (appDelegate, cache)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }
}

private final class ThumbnailDownloadController: FeedDetailViewController {
    private(set) var requestedStoryHashes = [String]()
    private(set) var requests = [NSDictionary]()

    override var isLegacyTable: Bool { false }
    override func reload() {}

    @objc(getFirstImage:forStoryHash:withManager:)
    func recordImageRequest(_ urls: Any?, forStoryHash hash: String?, withManager manager: Any?) {
        if let hash {
            requestedStoryHashes.append(hash)
            if let pending = value(forKey: "pendingStoryImageRequests") as? NSDictionary,
               let request = pending[hash] as? NSDictionary {
                requests.append(request)
            }
        }
    }

    @objc(showImageForStoryHash:)
    func ignoreVisibleImageRefresh(_ hash: String) {
    }
}

@MainActor private final class ThumbnailPrefetchController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override func reload() {}
}

private final class ThumbnailRefreshAppDelegate: NewsBlurAppDelegate {
    var feedRefreshRequests = 0
    weak var testFeedDetail: FeedDetailViewController?

    override var feedDetailViewController: FeedDetailViewController! {
        get { testFeedDetail }
        set { testFeedDetail = newValue }
    }

    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        // StoryThumbnailCacheTests.swift stops the real refresh before network access or response rendering.
        feedRefreshRequests += 1
    }
}

private final class ThumbnailLookupRaceAppDelegate: NewsBlurAppDelegate {
    var afterLookup: (() -> Void)?

    override func cachedImage(forStoryHash storyHash: String!) -> UIImage! {
        let result = super.cachedImage(forStoryHash: storyHash)
        let completion = afterLookup
        afterLookup = nil
        completion?()
        return result
    }
}

private final class ThumbnailPreparationImage: UIImage {
    var preparation: (() -> UIImage?)?

    override func preparingForDisplay() -> UIImage? {
        preparation?()
    }
}

private final class ThumbnailCacheDouble: NSObject {
    @objc let memoryCache = ThumbnailStorageDouble()
    @objc let diskCache = ThumbnailStorageDouble()

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        if let image = memoryCache.object(forKey: key) {
            return image
        }
        let image = diskCache.object(forKey: key)
        if let image {
            memoryCache.setObject(image, forKey: key)
        }
        return image
    }

    @objc(objectForKeyedSubscript:)
    func objectForKeyedSubscript(_ key: String) -> Any? {
        object(forKey: key)
    }

    @objc(removeObjectForKey:)
    func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }

    @objc func removeAllObjects() {
        memoryCache.removeAllObjects()
        diskCache.removeAllObjects()
    }
}

private final class ThumbnailStorageDouble: NSObject {
    private let lock = NSLock()
    private var objects: [String: Any] = [:]
    private var costs: [String: UInt] = [:]
    private var reads = 0
    private var mainReads = 0
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads }
    var mainReadCount: Int { lock.lock(); defer { lock.unlock() }; return mainReads }
    var afterRead: (() -> Void)?
    var onRead: ((String, Bool) -> Void)?

    func resetReadTracking() {
        lock.lock()
        reads = 0
        mainReads = 0
        lock.unlock()
    }

    func cost(forKey key: String) -> UInt? {
        lock.lock()
        defer { lock.unlock() }
        return costs[key]
    }

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        lock.lock()
        reads += 1
        if Thread.isMainThread { mainReads += 1 }
        let result = objects[key]
        let completion = afterRead
        afterRead = nil
        let recorder = onRead
        lock.unlock()
        recorder?(key, Thread.isMainThread)
        completion?()
        return result
    }

    @objc(setObject:forKey:)
    func setObject(_ object: Any, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        objects[key] = object
        costs.removeValue(forKey: key)
    }

    @objc(setObject:forKey:withCost:)
    func setObject(_ object: Any, forKey key: String, withCost cost: UInt) {
        lock.lock()
        defer { lock.unlock() }
        objects[key] = object
        costs[key] = cost
    }

    @objc(removeObjectForKey:)
    func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        objects.removeValue(forKey: key)
        costs.removeValue(forKey: key)
    }

    @objc func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        objects.removeAll()
        costs.removeAll()
    }
}
