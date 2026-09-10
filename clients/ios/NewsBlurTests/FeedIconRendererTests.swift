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
        var source: UIImage? = makeImage(size: 384, color: .orange)
        weak var original = source
        for index in 0..<300 {
            let image = try XCTUnwrap(renderer.image(forKey: "feed-\(index)", size: size) { source })
            XCTAssertEqual(image.cgImage?.width, Int(16 * image.scale))
        }
        source = nil
        XCTAssertNil(original, "The prepared cache must not retain hundreds of large originals.")
        for index in 0..<300 {
            XCTAssertNotNil(renderer.image(forKey: "feed-\(index)", size: size) { nil })
        }
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
