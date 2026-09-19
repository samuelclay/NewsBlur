import XCTest
import UIKit

@testable import NewsBlur

final class Test_StoryTextLayoutCache: XCTestCase {
    func test_contentFontParagraphAndGeometryChangesCannotReusePreparedMeasurements() {
        let cache = StoryTextLayoutCache()
        let original = request()
        cache.cacheLayout(original.measure(), for: original)
        XCTAssertNotNil(cache.cachedLayout(for: request()))
        for changed in [request(title: "A changed title"), request(preview: "A changed preview"),
                        request(width: 180), request(height: 240), request(pointSize: 18),
                        request(textSize: 1), request(short: true), request(river: false),
                        request(margin: 0), request(padding: 20), request(image: true),
                        request(lineHeight: 1.2)] {
            XCTAssertNil(cache.cachedLayout(for: changed))
        }
    }

    func test_mutableInputsAreSnapshottedBeforeWorkerMeasurement() {
        let title = NSMutableString(string: "A short title")
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 0.95
        let original = request(title: title, paragraph: paragraph)
        let expected = original.measure()
        title.append(String(repeating: " changed", count: 40))
        paragraph.lineHeightMultiple = 3
        let actual = original.measure()
        XCTAssertEqual(actual.titleSize, expected.titleSize)
        XCTAssertEqual(actual.previewSize, expected.previewSize)
        XCTAssertEqual(actual.contentGap, expected.contentGap)
        XCTAssertFalse(original.isEqual(request(title: title, paragraph: paragraph)))
    }

    func test_cancelledQueuedRowsReleaseCapturedTextWithoutWaitingForWorker() {
        let queue = DispatchQueue(label: "test.story-text-layout.cancel")
        queue.suspend()
        let cache = StoryTextLayoutCache(worker: queue)
        weak var first: StoryTextLayoutRequest?
        weak var last: StoryTextLayoutRequest?
        for index in 0..<100 {
            let item = request(title: "Queued story \(index)" as NSString)
            if index == 0 { first = item }
            if index == 99 { last = item }
            cache.prefetch([item], identifier: "row-\(index)")
            XCTAssertLessThanOrEqual(cache.pendingRowCount, 24)
            XCTAssertLessThanOrEqual(cache.pendingByteCost, 4 * 1_024 * 1_024)
        }
        XCTAssertNil(first, "The bounded queue must release displaced requests, including their text.")
        XCTAssertNotNil(last)
        cache.cancelPrefetch((0..<100).map { "row-\($0)" })
        XCTAssertNil(last, "Cancelling a dispatch block must not leave its captured story text retained.")
        XCTAssertEqual(cache.pendingRowCount, 0)
        queue.resume()
        queue.sync {}
        XCTAssertEqual(cache.cachedEntryCount, 0)
    }

    func test_cacheBoundsBothEntryCountAndActualTextCost() {
        let cache = StoryTextLayoutCache()
        let scalar = StoryTextLayout(titleSize: CGSize(width: 80, height: 15), previewSize: .zero, contentGap: 2)
        for index in 0..<300 {
            cache.cacheLayout(scalar, for: request(title: "Cached story \(index)" as NSString))
            XCTAssertLessThanOrEqual(cache.cachedEntryCount, 256)
        }
        XCTAssertEqual(cache.cachedEntryCount, 256)
        XCTAssertNil(cache.cachedLayout(for: request(title: "Cached story 0")))
        XCTAssertNotNil(cache.cachedLayout(for: request(title: "Cached story 299")))

        cache.removeAllLayouts()
        for index in 0..<8 {
            let title = (String(repeating: "文", count: 524_288) + "\(index)") as NSString
            cache.cacheLayout(scalar, for: request(title: title))
            XCTAssertLessThanOrEqual(cache.cachedByteCost, 4 * 1_024 * 1_024)
        }
        XCTAssertEqual(cache.cachedEntryCount, 3, "Four 1 MiB strings plus request metadata exceed the 4 MiB budget.")
        let oversized = request(title: String(repeating: "文", count: 2_097_152) as NSString)
        cache.cacheLayout(scalar, for: oversized)
        cache.prefetch([oversized], identifier: "oversized")
        XCTAssertNil(cache.cachedLayout(for: oversized))
        XCTAssertEqual(cache.pendingRowCount, 0)
    }

    func test_backgroundMeasurementsPublishScalarsAndClearCancelsQueuedWork() {
        let queue = DispatchQueue(label: "test.story-text-layout.prepare")
        let cache = StoryTextLayoutCache(worker: queue)
        let item = request(title: "数学 العربية 👩🏽‍🔬")
        cache.prefetch([item], identifier: "row")
        queue.sync {}
        let actual = cache.cachedLayout(for: item)
        XCTAssertNotNil(actual)
        let expected = item.measure()
        XCTAssertEqual(actual?.titleSize, expected.titleSize)
        XCTAssertEqual(actual?.previewSize, expected.previewSize)
        XCTAssertEqual(actual?.contentGap, expected.contentGap)
        queue.suspend()
        cache.prefetch([request(title: "New content")], identifier: "next-row")
        cache.removeAllLayouts()
        queue.resume()
        queue.sync {}
        XCTAssertEqual(cache.cachedEntryCount, 0)
        XCTAssertEqual(cache.pendingRowCount, 0)
    }

    func test_clearingDuringActiveMeasurementRejectsItsResultAndAllowsFreshWork() throws {
        let queue = DispatchQueue(label: "test.story-text-layout.active-cancel")
        let cache = StoryTextLayoutCache(worker: queue)
        let title = "Active cancellation layout fixture 数学 العربية"
        let item = request(title: title as NSString)
        let entered = expectation(description: "Worker has measured title and still owns the request")
        let resume = DispatchSemaphore(value: 0)
        let probe = try TextMeasurementProbe(matching: [title]) { isMain in
            if !isMain {
                entered.fulfill()
                resume.wait()
            }
        }
        defer { probe.restore() }
        cache.prefetch([item], identifier: "row")
        wait(for: [entered], timeout: 5)

        cache.removeAllLayouts()
        resume.signal()
        queue.sync {}

        XCTAssertNil(cache.cachedLayout(for: item))
        XCTAssertEqual(cache.cachedEntryCount, 0)
        XCTAssertEqual(cache.pendingRowCount, 0)
        let fresh = request(title: "Replacement content after cancellation")
        cache.prefetch([fresh], identifier: "row")
        queue.sync {}
        XCTAssertNotNil(cache.cachedLayout(for: fresh))
    }

    private func request(title: NSString = "A measured title", preview: NSString = "A paragraph with enough text to wrap onto several lines and exercise the exact title-dependent preview bounds.",
                         width: CGFloat = 250, height: CGFloat = 190, pointSize: CGFloat = 13,
                         textSize: Int = 2, short: Bool = false, river: Bool = true,
                         margin: CGFloat = 10, padding: CGFloat = 30, image: Bool = false,
                         lineHeight: CGFloat = 0.95, paragraph: NSParagraphStyle? = nil) -> StoryTextLayoutRequest {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.alignment = .left
        style.lineHeightMultiple = lineHeight
        return StoryTextLayoutRequest(title: title, preview: preview, contentWidth: width,
            boundsHeight: height, fontPointSize: pointSize, textSize: textSize, shortTitles: short,
            river: river, comfortMargin: margin, riverPadding: padding, hasImage: image,
            paragraphStyle: paragraph ?? style)
    }
}
