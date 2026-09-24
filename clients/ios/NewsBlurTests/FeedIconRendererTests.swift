import XCTest
import UIKit
@testable import NewsBlur

@MainActor final class Test_FeedIconRenderer: XCTestCase {
    func test_repeatedCellPreparationLoadsAndRoundsTheOriginalOnlyOnce() throws {
        let renderer = FeedIconRenderer()
        let source = makeImage(size: 384, color: .red)
        var loads = 0
        let loader = { loads += 1; return source as UIImage? }
        let first = try XCTUnwrap(renderer.image(forKey: "feed", size: CGSize(width: 16, height: 16), loader: loader))
        for _ in 0..<500 {
            XCTAssertTrue(renderer.image(forKey: "feed", size: CGSize(width: 16, height: 16), loader: loader) === first)
        }
        XCTAssertEqual(loads, 1, "Feed reuse must not reload the large original after its small bitmap is prepared.")
    }

    func test_preparedPixelsExactlyMatchExistingCellArtwork() throws {
        let renderer = FeedIconRenderer()
        for width: CGFloat in [16, 26, 28] {
            let size = CGSize(width: width, height: width)
            let source = makeImage(size: 384, color: .purple)
            let result = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { source })
            let expected = try XCTUnwrap(Utilities.roundCorneredImage(source, radius: 4, convertTo: size))
            XCTAssertEqual(result.pngData(), expected.pngData())
            XCTAssertEqual(result.size, size)
            XCTAssertEqual(result.scale, expected.scale)
        }
    }

    func test_changedFaviconInvalidatesItsPreparedBitmap() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        let first = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { self.makeImage(size: 384, color: .red) })
        renderer.removeImage(forKey: "feed")
        let replacement = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { self.makeImage(size: 384, color: .blue) })
        XCTAssertNotEqual(first.pngData(), replacement.pngData())
    }

    func test_clearingCacheAndMissingIconsPermitFreshLoads() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        XCTAssertNil(renderer.image(forKey: "feed", size: size) { nil })
        let first = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { self.makeImage(size: 384, color: .red) })
        renderer.removeAllImages()
        let replacement = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { self.makeImage(size: 384, color: .blue) })
        XCTAssertNotEqual(first.pngData(), replacement.pngData())
    }

    func test_hundredsOfLargeOriginalsRetainOnlySmallPreparedBitmaps() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        weak var original: UIImage?
        try autoreleasepool {
            let source = makeImage(size: 384, color: .orange)
            original = source
            for index in 0..<300 {
                let image = try XCTUnwrap(renderer.image(forKey: "feed-\(index)", size: size) { source })
                XCTAssertEqual(image.cgImage?.width, Int(16 * image.scale))
            }
        }
        XCTAssertNil(original, "The prepared cache must not retain hundreds of large originals.")
        for index in 0..<300 {
            XCTAssertNotNil(renderer.image(forKey: "feed-\(index)", size: size) { nil })
        }
    }

    func test_invalidatedInFlightOriginalCannotPopulateTheCache() {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        let stale = renderer.image(forKey: "feed", size: size) {
            renderer.removeImage(forKey: "feed")
            return self.makeImage(size: 384, color: .red)
        }
        XCTAssertNil(stale)
        XCTAssertNil(renderer.image(forKey: "feed", size: size) { nil })
    }

    func test_clearingDuringLoadDiscardsOnlyTheOlderGeneration() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        var replacement: UIImage?
        let stale = renderer.image(forKey: "feed", size: size) {
            renderer.removeAllImages()
            replacement = renderer.image(forKey: "feed", size: size) {
                self.makeImage(size: 384, color: .blue)
            }
            return self.makeImage(size: 384, color: .red)
        }
        XCTAssertNil(stale)
        let current = try XCTUnwrap(replacement)
        XCTAssertTrue(renderer.image(forKey: "feed", size: size) { nil } === current)
    }

    func test_invalidatingOneFeedPreservesOtherPreparedArtwork() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        let other = try XCTUnwrap(renderer.image(forKey: "other", size: size) {
            self.makeImage(size: 384, color: .red)
        })
        renderer.removeImage(forKey: "feed")
        XCTAssertTrue(renderer.image(forKey: "other", size: size) { nil } === other)
    }

    func test_missingDifferentSizeDoesNotDestroyPreparedArtwork() throws {
        let renderer = FeedIconRenderer()
        let size = CGSize(width: 16, height: 16)
        let original = try XCTUnwrap(renderer.image(forKey: "feed", size: size) {
            self.makeImage(size: 384, color: .red)
        })
        XCTAssertNil(renderer.image(forKey: "feed", size: CGSize(width: 28, height: 28)) { nil })
        XCTAssertTrue(renderer.image(forKey: "feed", size: size) { nil } === original)
    }

    func test_proactiveBudgetPreservesEarlierArtworkAndLeavesDemandPreparationAvailable() throws {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.budget")
        let size = CGSize(width: 16, height: 16)
        let source = makeImage(size: 384, color: .orange)
        let expected = try XCTUnwrap(Utilities.roundCorneredImage(source, radius: 4, convertTo: size))
        let bitmap = try XCTUnwrap(expected.cgImage)
        let cost = bitmap.bytesPerRow * bitmap.height + "feed-0".utf8.count
        let renderer = FeedIconRenderer(preparationQueue: queue, preparationByteLimit: cost * 3)
        let loads = FeedPreparationLoadCounter()
        renderer.prepare((0..<20).map { FeedIconPreparationRequest(key: "feed-\($0)", size: size) }) { _ in
            loads.record()
            return source
        }
        queue.sync {}

        XCTAssertEqual(loads.counts.main, 0)
        XCTAssertEqual(loads.counts.worker, 4, "One final bitmap is measured but rejected before it can evict admitted artwork.")
        for index in 0..<3 {
            let image = try XCTUnwrap(renderer.image(forKey: "feed-\(index)", size: size) { nil })
            XCTAssertEqual(image.pngData(), expected.pngData())
        }
        XCTAssertNil(renderer.image(forKey: "feed-3", size: size) { nil })
        XCTAssertNotNil(renderer.image(forKey: "feed-3", size: size) { source },
                        "Normal nearby row preparation must remain useful after the proactive budget fills.")
    }

    func test_replacingAndCancellingQueuedPreparationKeepsOnlyBoundedIdentifiers() {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.queued")
        queue.suspend()
        let renderer = FeedIconRenderer(preparationQueue: queue)
        let loads = FeedPreparationLoadCounter()
        let size = CGSize(width: 16, height: 16)
        weak var obsolete: FeedIconPreparationRequest?
        autoreleasepool {
            let request = FeedIconPreparationRequest(key: "obsolete", size: size)
            obsolete = request
            renderer.prepare([request]) { _ in loads.record(); return nil }
        }
        XCTAssertNotNil(obsolete)
        renderer.prepare((0..<5_000).map { FeedIconPreparationRequest(key: "feed-\($0)", size: size) }) { _ in
            loads.record()
            return nil
        }
        XCTAssertNil(obsolete)
        XCTAssertEqual(renderer.pendingPreparationCount, 1_024)
        renderer.cancelPreparation()
        XCTAssertEqual(renderer.pendingPreparationCount, 0)
        queue.resume()
        queue.sync {}
        XCTAssertEqual(loads.counts.worker, 0)
    }

    func test_actualEightMiBAdmissionStopsBeforeEvictingTheFirstPreparedFeed() throws {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.actual-budget")
        let renderer = FeedIconRenderer(preparationQueue: queue)
        let size = CGSize(width: 28, height: 28)
        let source = makeImage(size: 384, color: .purple)
        let bitmap = try XCTUnwrap(Utilities.roundCorneredImage(source, radius: 4, convertTo: size)?.cgImage)
        let cost = bitmap.bytesPerRow * bitmap.height + "feed-0000".utf8.count
        let admitted = (8 * 1_024 * 1_024) / cost
        let loads = FeedPreparationLoadCounter()
        renderer.prepare((0..<1_024).map {
            FeedIconPreparationRequest(key: String(format: "feed-%04d", $0), size: size)
        }) { _ in loads.record(); return source }
        queue.sync {}

        XCTAssertLessThan(admitted, 1_024)
        XCTAssertEqual(loads.counts.worker, admitted + 1)
        XCTAssertNotNil(renderer.image(forKey: "feed-0000", size: size) { nil })
        XCTAssertNotNil(renderer.image(forKey: String(format: "feed-%04d", admitted - 1), size: size) { nil })
        XCTAssertNil(renderer.image(forKey: String(format: "feed-%04d", admitted), size: size) { nil })
        XCTAssertEqual(renderer.pendingPreparationCount, 0)
    }

    func test_replacementWhileAnOriginalLoadsRejectsObsoleteArtworkAndQueuedRows() throws {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.replacement")
        let renderer = FeedIconRenderer(preparationQueue: queue)
        let size = CGSize(width: 16, height: 16)
        let oldSource = makeImage(size: 384, color: .red)
        let newSource = makeImage(size: 384, color: .blue)
        let entered = expectation(description: "An old original is being read")
        let resume = DispatchSemaphore(value: 0)
        let loads = FeedPreparationLoadCounter()
        renderer.prepare([FeedIconPreparationRequest(key: "feed", size: size),
                          FeedIconPreparationRequest(key: "obsolete", size: size)]) { key in
            loads.record()
            if key == "feed" {
                entered.fulfill()
                resume.wait()
            }
            return oldSource
        }
        wait(for: [entered], timeout: 5)
        renderer.prepare([FeedIconPreparationRequest(key: "feed", size: size)]) { _ in newSource }
        resume.signal()
        queue.sync {}

        let actual = try XCTUnwrap(renderer.image(forKey: "feed", size: size) { nil })
        let expected = Utilities.roundCorneredImage(newSource, radius: 4, convertTo: size)
        XCTAssertEqual(actual.pngData(), expected?.pngData())
        XCTAssertNil(renderer.image(forKey: "obsolete", size: size) { nil })
        XCTAssertEqual(loads.counts.worker, 1)
    }

    func test_accountResetRejectsActivePreparationAndReleasesTheOldPlan() {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.account")
        let renderer = FeedIconRenderer(preparationQueue: queue)
        let app = NewsBlurAppDelegate()
        app.setValue(renderer, forKey: "feedIconRenderer")
        let size = CGSize(width: 16, height: 16)
        let source = makeImage(size: 384, color: .red)
        let entered = expectation(description: "Old account preparation started")
        let resume = DispatchSemaphore(value: 0)
        renderer.prepare([FeedIconPreparationRequest(key: "feed", size: size)]) { _ in
            entered.fulfill()
            resume.wait()
            return source
        }
        wait(for: [entered], timeout: 5)
        app.dictFeeds = nil
        resume.signal()
        queue.sync {}

        XCTAssertNil(renderer.image(forKey: "feed", size: size) { nil })
        XCTAssertEqual(renderer.pendingPreparationCount, 0)
    }

    func test_memoryWarningClearsPreparedImagesAndCancelsQueuedWarming() throws {
        let queue = DispatchQueue(label: "test.feed-icon-preparation.memory")
        let renderer = FeedIconRenderer(preparationQueue: queue)
        let size = CGSize(width: 16, height: 16)
        let source = makeImage(size: 384, color: .red)
        XCTAssertNotNil(renderer.image(forKey: "cached", size: size) { source })
        queue.suspend()
        let loads = FeedPreparationLoadCounter()
        renderer.prepare([FeedIconPreparationRequest(key: "queued", size: size)]) { _ in
            loads.record()
            return source
        }

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        queue.resume()
        queue.sync {}

        XCTAssertNil(renderer.image(forKey: "cached", size: size) { nil })
        XCTAssertNil(renderer.image(forKey: "queued", size: size) { nil })
        XCTAssertEqual(renderer.pendingPreparationCount, 0)
        XCTAssertEqual(loads.counts.worker, 0)
    }

    private func makeImage(size: CGFloat, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor.yellow.setFill()
            context.fill(CGRect(x: size / 3, y: 0, width: size / 4, height: size))
        }
    }
}

private final class FeedPreparationLoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var main = 0
    private var worker = 0
    func record() {
        lock.lock()
        if Thread.isMainThread { main += 1 } else { worker += 1 }
        lock.unlock()
    }
    var counts: (main: Int, worker: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (main, worker)
    }
}
