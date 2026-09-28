import XCTest
import UIKit
@testable import NewsBlur

final class Test_StoryImageViewer: XCTestCase {
    @MainActor func test_tallImageFitsBelowStatusBarWhenSafeAreaChanges() throws {
        let preview = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 240)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 240))
        }
        var body = payload
        body["naturalWidth"] = 600
        body["naturalHeight"] = 2400
        body["src"] = "data:image/png;base64," + (try XCTUnwrap(preview.pngData())).base64EncodedString()
        let viewer = StoryImageViewerController(source: try XCTUnwrap(StoryImageSource(body)), preview: preview, origin: .zero)
        let canvas = ImageViewerSafeAreaView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        viewer.view = canvas
        viewer.viewDidLoad()
        for topInset: CGFloat in [24, 48] {
            canvas.topInset = topInset
            viewer.viewDidLayoutSubviews()
            let scroll = try XCTUnwrap(canvas.subviews.compactMap { $0 as? UIScrollView }.first)
            let image = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIImageView }.first)
            let imageFrame = image.convert(image.bounds, to: canvas)
            XCTAssertEqual(scroll.frame.minY, topInset, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(imageFrame.minY, topInset)
            XCTAssertLessThanOrEqual(imageFrame.maxY, canvas.bounds.maxY)
            XCTAssertEqual(imageFrame.height, canvas.bounds.height - topInset, accuracy: 0.5)
            XCTAssertEqual(imageFrame.width / imageFrame.height, 0.25, accuracy: 0.001)
        }
    }

    func test_fittedImageNeverUpscalesAndPreservesAspectRatio() {
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 120, height: 80), in: CGSize(width: 1024, height: 768)), CGSize(width: 120, height: 80))
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 2400, height: 1200), in: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 400))
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 600, height: 2400), in: CGSize(width: 800, height: 600)), CGSize(width: 150, height: 600))
    }

    func test_bridgeRejectsInvalidGeometryAndNonImageSchemes() throws {
        var body = payload
        XCTAssertNotNil(StoryImageSource(body))
        body["src"] = "file:///private/example.png"
        XCTAssertNil(StoryImageSource(body))
        body = payload
        body["token"] = "1\";alert(1)"
        XCTAssertNil(StoryImageSource(body))
        body = payload
        body["naturalWidth"] = Double.infinity
        XCTAssertNil(StoryImageSource(body))
        body = payload
        body["rect"] = ["x": 0, "y": 0, "width": 30, "height": 30, "viewportWidth": 0]
        XCTAssertNil(StoryImageSource(body))
        body = payload
        body["link"] = "javascript:alert(1)"
        body["originalURL"] = "data:image/png;base64,AAAA"
        let source = try XCTUnwrap(StoryImageSource(body))
        XCTAssertNil(source.link)
        XCTAssertNil(source.originalURL)
    }

    func test_cachedImagesKeepTheirOriginalBrowserAddress() {
        let original = "https://example.com/picture.jpg?width=800&crop=1"
        let cached = "data:image/jpeg;base64,abc+/="
        let html = "<a href='https://example.com/article'><img alt='Photo' src='\(cached)'></a>"
        let annotated = StoryImageOfflineSource.annotate(html, cachedURL: cached, originalURL: original)
        XCTAssertTrue(annotated.contains("data-newsblur-original-src=\"https://example.com/picture.jpg?width=800&amp;crop=1\""))
        XCTAssertTrue(annotated.contains("src='\(cached)'"))
        XCTAssertTrue(annotated.contains("href='https://example.com/article'"))
    }

    @MainActor func test_largeCachedImagesDoNotBlockStoryPaging() {
        // StoryImageViewerTests.swift models StoryDetailObjCViewController.m annotating three cached photos while preparing the next page.
        let originalURLs = (0..<3).map { "https://example.com/photo-\($0).jpg?size=large&crop=1" }
        let cachedURLs = (0..<3).map { index in
            "data:image/jpeg;base64," + String(repeating: "AbC123+\(index)", count: 131_072)
        }
        var html = originalURLs.map { "<img src='\($0)'>" }.joined()
        let started = CACurrentMediaTime()
        for (original, cached) in zip(originalURLs, cachedURLs) {
            html = html.replacingOccurrences(of: original, with: cached)
            html = StoryImageOfflineSource.annotate(html, cachedURL: cached, originalURL: original)
        }
        let elapsed = CACurrentMediaTime() - started
        print("OFFLINE_IMAGE_ANNOTATION three_1MiB_images_seconds=\(elapsed)")
        XCTAssertLessThan(elapsed, 2, "Cached photo annotation runs on the paging main thread and must not cause a multi-second freeze")
        XCTAssertEqual(html.components(separatedBy: "data-newsblur-original-src=").count - 1, 3)
        for original in originalURLs {
            XCTAssertTrue(html.contains("data-newsblur-original-src=\"\(original.replacingOccurrences(of: "&", with: "&amp;"))\""))
        }
        for cached in cachedURLs { XCTAssertTrue(html.contains("src='\(cached)'")) }
    }

    func test_largeNearlyIdenticalCachedSourcesRemainDistinct() {
        let prefix = "data:image/jpeg;base64," + String(repeating: "AbC123+4", count: 65_536)
        let cached = prefix + "AA=="
        let other = prefix + "Aa=="
        let unaffected = "<img src='\(other)' srcset='\(cached) 1x'>"
        let annotated = StoryImageOfflineSource.annotate(unaffected + "<img src=\"\(cached)\">",
                                                       cachedURL: cached, originalURL: "https://example.com/exact.jpg")
        XCTAssertTrue(annotated.hasPrefix(unaffected))
        XCTAssertEqual(annotated.components(separatedBy: "data-newsblur-original-src=").count - 1, 1)
    }

    func test_cachedImageAnnotationPreservesQuotedAttributesAndOnlyMatchesTheExactSource() {
        let cached = "data:image/jpeg;base64,AbC+/="
        let original = "https://example.com/photo.jpg?a=1&label=\"quote\"&price=$5"
        let unaffected = "<a href='\(cached)'>Link</a><img src='data:image/jpeg;base64,abc+/='>"
        let html = unaffected + "<IMG alt=\"A > B and src='unrelated'\" SRC = '\(cached)' data-caption='Photo'>"
        let annotated = StoryImageOfflineSource.annotate(html, cachedURL: cached, originalURL: original)
        XCTAssertTrue(annotated.hasPrefix(unaffected), "Base64 image bytes are case-sensitive; links and other sources must remain untouched")
        XCTAssertTrue(annotated.contains("alt=\"A > B and src='unrelated'\""))
        XCTAssertTrue(annotated.contains("data-caption='Photo'"))
        XCTAssertTrue(annotated.contains("data-newsblur-original-src=\"https://example.com/photo.jpg?a=1&amp;label=&quot;quote&quot;&amp;price=$5\""))
        XCTAssertEqual(annotated.components(separatedBy: "data-newsblur-original-src=").count - 1, 1)
    }

    func test_identicalCachedImageBytesRetainEachImagesOriginalAddress() {
        let cached = "data:image/jpeg;base64,AbC+/="
        let first = "https://example.com/first.jpg"
        let second = "https://example.com/second.jpg"
        let firstImage = StoryImageOfflineSource.annotate("<img src='\(cached)'>", cachedURL: cached, originalURL: first)
        let annotated = StoryImageOfflineSource.annotate(firstImage + "<img src='\(cached)'>", cachedURL: cached, originalURL: second)
        XCTAssertTrue(annotated.hasPrefix(firstImage), "An already annotated image must keep the address assigned when its own URL was replaced")
        XCTAssertEqual(annotated.components(separatedBy: "data-newsblur-original-src=").count - 1, 2)
        XCTAssertTrue(annotated.contains("data-newsblur-original-src=\"\(second)\""))
    }

    @MainActor func test_largeMalformedImageTagsDoNotBlockStoryPaging() {
        let cached = "data:image/jpeg;base64,AbC+/="
        let padding = String(repeating: "a", count: 1_048_576)
        let malformed = "<img alt=" + padding
        let unclosedQuote = "<img alt='" + padding
        let whitespaceOnly = "<img " + String(repeating: " ", count: 1_048_576) + ">"
        let started = CACurrentMediaTime()
        for html in [malformed, unclosedQuote, whitespaceOnly] {
            let annotated = StoryImageOfflineSource.annotate(html, cachedURL: cached, originalURL: "https://example.com/photo.jpg")
            XCTAssertEqual(annotated.count, html.count)
            XCTAssertFalse(annotated.contains("data-newsblur-original-src="))
        }
        XCTAssertLessThan(CACurrentMediaTime() - started, 2, "Malformed article HTML must not trigger regex backtracking on the paging main thread")
    }

    private var payload: [String: Any] {
        ["loadID": "3", "token": "1", "src": "https://example.com/image.png",
         "originalURL": "https://example.com/image.png", "link": "https://example.com/article",
         "title": "An image", "naturalWidth": 1200, "naturalHeight": 800,
         "rect": ["x": 10, "y": 50, "width": 300, "height": 200, "viewportWidth": 375]]
    }
}

// StoryImageViewerTests.swift exercises iPad-sized layout and inset changes on the shared simulator.
private final class ImageViewerSafeAreaView: UIView {
    var topInset: CGFloat = 24
    override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0) }
}
