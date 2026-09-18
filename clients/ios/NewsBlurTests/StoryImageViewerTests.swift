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
