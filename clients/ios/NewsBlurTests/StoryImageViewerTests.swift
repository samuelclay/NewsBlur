import XCTest
import UIKit
import WebKit
@testable import NewsBlur

final class Test_StoryImageViewer: XCTestCase {
    @MainActor func test_nativeImageHitTestingMatchesInsetWebViewBeforeAndAfterScrolling() async throws {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(web)
        defer {
            web.stopLoading()
            window.isHidden = true
            previousWindow?.makeKey()
        }
        let scriptURL = try XCTUnwrap(Bundle.main.url(forResource: "storyDetailView", withExtension: "js"))
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let start = try XCTUnwrap(script.range(of: "var newsblur_image_sequence"))
        let end = try XCTUnwrap(script.range(of: "document.addEventListener('click'", range: start.lowerBound..<script.endIndex))
        let hitTestScript = String(script[start.lowerBound..<end.lowerBound])
        web.loadHTMLString("""
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="newsblur-story-load" content="1"></head>
        <body style="margin:0"><div style="height:200px"></div>
        <img id="photo" data-newsblur-image-token="1" width="120" height="80" style="display:block;margin-left:40px;background:orange">
        <div style="height:2000px"></div><script>
        \(hitTestScript)
        function newsblurOpenImage(image) { return image && image.id === 'photo'; }
        </script></body></html>
        """, baseURL: nil)
        var ready = false
        for _ in 0..<200 {
            ready = (try? await web.evaluateJavaScript("document.readyState === 'complete' && typeof newsblurOpenImageAt === 'function'")) as? Bool == true
            if ready { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(ready)
        for offsetY: CGFloat in [-100, 80] {
            web.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            try await Task.sleep(nanoseconds: 100_000_000)
            // StoryImageViewerTests.swift uses the known CSS fixture position through UIKit's content coordinates.
            let point = web.scrollView.convert(CGPoint(x: 100, y: 240), to: web)
            let offset = web.scrollView.contentOffset
            let hit = try await web.evaluateJavaScript("newsblurOpenImageAt(\(point.x), \(point.y), \(offset.x), \(offset.y), \(web.bounds.width))") as? Bool
            XCTAssertEqual(hit, true, "The stationary native tap must hit the small photo at native offset \(offsetY)")
            let result = try await web.evaluateJavaScript("newsblurImageRect('1', '1')")
            let (rect, viewport) = try XCTUnwrap(StoryImageSource.geometry(result))
            let nativeRect = StoryImageSource.viewRect(rect, viewportWidth: viewport, in: web)
            let expectedOrigin = web.scrollView.convert(CGPoint(x: 40, y: 200), to: web)
            XCTAssertEqual(nativeRect.origin.x, expectedOrigin.x, accuracy: 0.5)
            XCTAssertEqual(nativeRect.origin.y, expectedOrigin.y, accuracy: 0.5)
            XCTAssertEqual(nativeRect.width, 120, accuracy: 0.5)
            XCTAssertEqual(nativeRect.height, 80, accuracy: 0.5)
            XCTAssertTrue(nativeRect.contains(point), "Snapshot and return geometry must contain the native image tap")
        }
    }

    @MainActor func test_scrollMomentumDoesNotOpenImageFromTapCallback() {
        let page = ImageScrollTapPage()
        page.probe.trackedScroll.simulatedDecelerating = true
        page.perform(NSSelectorFromString("tap:"), with: ImageScrollTapGesture())
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") },
                       "A touch during article momentum must stop scrolling without opening the photo")
    }

    @MainActor func test_stationarySingleTapStillRequestsImage() {
        let page = ImageScrollTapPage()
        page.perform(NSSelectorFromString("tap:"), with: ImageScrollTapGesture())
        XCTAssertTrue(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") })
    }

    @MainActor func test_stationaryLongPressRequestsActionsWithoutTogglingReaderChrome() {
        let page = ImageScrollTapPage()
        let gesture = ImageLongPressGesture()
        page.beginTouch(gesture)
        page.longPressImage(gesture)
        XCTAssertTrue(page.probe.scripts.contains { $0.hasPrefix("newsblurOpenImageAt") && $0.hasSuffix(", true)") })
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("linkAt") })
    }

    @MainActor func test_longPressStoppingMomentumDoesNotOpenImage() {
        let page = ImageScrollTapPage()
        let gesture = ImageLongPressGesture()
        page.probe.trackedScroll.simulatedDecelerating = true
        page.beginTouch(gesture)
        page.probe.trackedScroll.simulatedDecelerating = false
        page.longPressImage(gesture)
        XCTAssertTrue(page.probe.scripts.isEmpty)
        page.beginTouch(gesture)
        page.longPressImage(gesture)
        XCTAssertTrue(page.probe.scripts.contains { $0.hasPrefix("newsblurOpenImageAt") })
    }

    @MainActor func test_imageTapDoesNotAlsoToggleReaderChrome() {
        let page = ImageScrollTapPage()
        page.probe.imageHitResult = true
        page.perform(NSSelectorFromString("tap:"), with: ImageScrollTapGesture())
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("linkAt") },
                       "Reader chrome must not shift the scroll inset while the photo snapshot is pending")
    }

    @MainActor func test_nonImageTapStillChecksReaderChrome() {
        let page = ImageScrollTapPage()
        page.probe.imageHitResult = false
        page.perform(NSSelectorFromString("tap:"), with: ImageScrollTapGesture())
        XCTAssertTrue(page.probe.scripts.contains { $0.contains("linkAt") })
    }

    @MainActor func test_touchStoppingMomentumDoesNotBecomeAnImageTap() {
        let page = ImageScrollTapPage()
        let gesture = ImageScrollTapGesture()
        page.probe.trackedScroll.simulatedDecelerating = true
        page.beginTouch(gesture)
        // StoryImageViewerTests.swift models UIKit stopping momentum before delivering the tap callback.
        page.probe.trackedScroll.simulatedDecelerating = false
        page.perform(NSSelectorFromString("tap:"), with: gesture)
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") })
    }

    @MainActor func test_activeArticleDragDoesNotOpenImageFromTapCallback() {
        let page = ImageScrollTapPage()
        let gesture = ImageScrollTapGesture()
        page.beginTouch(gesture)
        page.probe.trackedScroll.simulatedDragging = true
        page.perform(NSSelectorFromString("tap:"), with: gesture)
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") })
    }

    @MainActor func test_stationaryTapAfterStoppingMomentumCanOpenImage() {
        let page = ImageScrollTapPage()
        let gesture = ImageScrollTapGesture()
        page.probe.trackedScroll.simulatedDecelerating = true
        page.beginTouch(gesture)
        page.probe.trackedScroll.simulatedDecelerating = false
        page.perform(NSSelectorFromString("tap:"), with: gesture)
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") })

        page.probe.scripts.removeAll()
        page.beginTouch(gesture)
        page.perform(NSSelectorFromString("tap:"), with: gesture)
        XCTAssertTrue(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") },
                      "A fresh stationary tap must work immediately after the touch that stopped scrolling")
    }

    @MainActor func test_completedArticleDragDoesNotBecomeAnImageTap() {
        let page = ImageScrollTapPage()
        let gesture = ImageScrollTapGesture()
        page.beginTouch(gesture)
        let delegate: UIScrollViewDelegate = page
        page.probe.trackedScroll.simulatedDragging = true
        delegate.scrollViewWillBeginDragging?(page.probe.trackedScroll)
        page.probe.trackedScroll.simulatedDragging = false
        page.perform(NSSelectorFromString("tap:"), with: gesture)
        XCTAssertFalse(page.probe.scripts.contains { $0.contains("newsblurOpenImageAt") })
    }

    @MainActor func test_accessibilityImageActivationWorksAfterScrollingButNotDuringMomentum() {
        let page = ImageScrollTapPage()
        page.probe.trackedScroll.simulatedDecelerating = true
        page.beginTouch(ImageScrollTapGesture())
        XCTAssertFalse(page.canOpenStoryImage(accessibility: true))
        page.probe.trackedScroll.simulatedDecelerating = false
        XCTAssertFalse(page.canOpenStoryImage(accessibility: false))
        XCTAssertTrue(page.canOpenStoryImage(accessibility: true),
                      "Keyboard and VoiceOver activation do not require a fresh native touch after scrolling")
    }

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
        guard !Utilities.usesSystemVerticalBar(viewer.traitCollection) else {
            throw XCTSkip("Conventional status-bar protection is checked on iPhone and iPad; Duo uses the full display")
        }
        let canvas = ImageViewerSafeAreaView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        viewer.view = canvas
        viewer.viewDidLoad()
        XCTAssertFalse(viewer.prefersStatusBarHidden, "Conventional iPhone and iPad images retain their status bar")
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

    @MainActor func test_duoImagePresentationCoversTheSideRailAndSafeArea() async throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("Duo image presentation does not apply to Catalyst")
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer {
            root.dismiss(animated: false)
            window.isHidden = true
            previousWindow?.makeKey()
        }
        guard Utilities.usesSystemVerticalBar(window.traitCollection) else {
            throw XCTSkip("Requires a Duo pose with the system side rail")
        }
        let preview = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }
        var body = payload
        body["naturalWidth"] = 2400
        body["naturalHeight"] = 1600
        body["src"] = "data:image/png;base64," + (try XCTUnwrap(preview.pngData())).base64EncodedString()
        let viewer = StoryImageViewerController(source: try XCTUnwrap(StoryImageSource(body)), preview: preview, origin: .zero)
        root.present(viewer, animated: false)
        try await Task.sleep(nanoseconds: 500_000_000)
        viewer.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(viewer.view.subviews.compactMap { $0 as? UIScrollView }.first)
        let image = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIImageView }.first)
        XCTAssertTrue(viewer.prefersStatusBarHidden, "Fullscreen photos must hide Duo's status rail")
        XCTAssertEqual(scroll.frame, viewer.view.bounds, "Image panning must reach every screen edge, including the cutout")
        XCTAssertEqual(image.frame.width, viewer.view.bounds.width, accuracy: 0.5,
                       "A landscape photo must fit the full closed-display width, not stop at the old rail")
        let close = try XCTUnwrap(viewer.view.subviews.flatMap(\.subviews).compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == "Close image" })
        XCTAssertTrue(viewer.view.safeAreaLayoutGuide.layoutFrame.contains(close.convert(close.bounds, to: viewer.view)),
                      "StoryImageViewerController.swift must keep dismissal accessible outside the cutout")
        #endif
    }

    func test_fittedImageNeverUpscalesAndPreservesAspectRatio() {
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 120, height: 80), in: CGSize(width: 1024, height: 768)), CGSize(width: 120, height: 80))
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 2400, height: 1200), in: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 400))
        XCTAssertEqual(StoryImageSource.fittedSize(CGSize(width: 600, height: 2400), in: CGSize(width: 800, height: 600)), CGSize(width: 150, height: 600))
    }

    func test_hoverTextIsIndependentOfTheAccessibleDescription() throws {
        var body = payload
        body["hoverText"] = "  This is the comic’s joke.  "
        body["showActions"] = true
        let source = try XCTUnwrap(StoryImageSource(body))
        XCTAssertEqual(source.title, "An image")
        XCTAssertEqual(source.hoverText, "This is the comic’s joke.")
        XCTAssertTrue(source.showActions)
        body["hoverText"] = " \n "
        XCTAssertNil(StoryImageSource(body)?.hoverText)
        XCTAssertNil(StoryImageSource(payload)?.hoverText, "An alt description must not become hover text when the image has no title")
        XCTAssertEqual(StoryImageSource(payload)?.showActions, false)
    }

    @MainActor func test_longHoverTextAndActionsLeaveRoomForImageInPortraitAndLandscape() throws {
        var body = payload
        body["hoverText"] = String(repeating: "Long comic hover text remains readable. ", count: 80)
        body["showActions"] = true
        body["src"] = "data:image/png;base64,AAAA"
        let viewer = StoryImageViewerController(source: try XCTUnwrap(StoryImageSource(body)), preview: nil, origin: .zero)
        let canvas = ImageViewerSafeAreaView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        viewer.view = canvas
        viewer.viewDidLoad()
        for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390), CGSize(width: 320, height: 568)] {
            canvas.frame.size = size
            viewer.viewDidLayoutSubviews()
            let hover = try XCTUnwrap(canvas.subviews.first { $0.accessibilityIdentifier == "image-hover-disclosure" } as? UIScrollView)
            let actions = try XCTUnwrap(canvas.subviews.first { $0.accessibilityIdentifier == "image-action-disclosure" } as? UIStackView)
            let scroll = try XCTUnwrap(canvas.subviews.first { $0.accessibilityIdentifier == "story-image-zoom" } as? UIScrollView)
            let image = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIImageView }.first)
            let imageFrame = image.convert(image.bounds, to: canvas)
            XCTAssertFalse(hover.isHidden)
            XCTAssertFalse(actions.isHidden)
            XCTAssertGreaterThan(hover.contentSize.height, hover.bounds.height, "Long hover text must scroll instead of truncating")
            XCTAssertLessThanOrEqual(hover.frame.maxY, imageFrame.minY)
            XCTAssertFalse(actions.frame.intersects(imageFrame))
            XCTAssertTrue(canvas.bounds.contains(actions.frame))
            XCTAssertTrue(canvas.bounds.contains(imageFrame))
            XCTAssertGreaterThan(imageFrame.height, 40)
            XCTAssertEqual(actions.arrangedSubviews.count, 3)
        }
    }

    @MainActor func test_imageWithoutTitleOmitsHoverDisclosure() throws {
        var body = payload
        body["showActions"] = true
        body["src"] = "data:image/png;base64,AAAA"
        let viewer = StoryImageViewerController(source: try XCTUnwrap(StoryImageSource(body)), preview: nil, origin: .zero)
        viewer.loadViewIfNeeded()
        viewer.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewer.viewDidLayoutSubviews()
        XCTAssertTrue(try XCTUnwrap(viewer.view.subviews.first { $0.accessibilityIdentifier == "image-hover-disclosure" }).isHidden)
        XCTAssertFalse(try XCTUnwrap(viewer.view.subviews.first { $0.accessibilityIdentifier == "image-action-disclosure" }).isHidden)
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

// StoryImageViewerTests.swift replays the native tap callback while the article still has momentum.
@MainActor private final class ImageScrollTapPage: StoryDetailViewController {
    let probe = ImageScrollTapWebView(frame: .zero, configuration: WKWebViewConfiguration())
    init() {
        super.init(nibName: nil, bundle: nil)
        view = UIView()
        webView = probe
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used by StoryImageViewerTests.swift") }
    deinit { webView = nil }
    override func point(forGesture gestureRecognizer: UIGestureRecognizer!) -> CGPoint {
        CGPoint(x: 100, y: 200)
    }
    func beginTouch(_ gesture: UIGestureRecognizer) {
        let delegate: UIGestureRecognizerDelegate = self
        _ = delegate.gestureRecognizer?(gesture, shouldReceive: ImageScrollTapTouch())
    }
}

@MainActor private final class ImageScrollTapWebView: WKWebView {
    let trackedScroll = ImageScrollTapScrollView()
    var scripts: [String] = []
    var imageHitResult: Bool?
    override var scrollView: UIScrollView { trackedScroll }
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        scripts.append(javaScriptString)
        if javaScriptString.hasPrefix("newsblurOpenImageAt"), let imageHitResult {
            completionHandler?(imageHitResult, nil)
        }
    }
}

@MainActor private final class ImageScrollTapScrollView: UIScrollView {
    var simulatedDecelerating = false
    var simulatedDragging = false
    override var isDecelerating: Bool { simulatedDecelerating }
    override var isDragging: Bool { simulatedDragging }
}

@MainActor private final class ImageScrollTapTouch: UITouch {
    override var tapCount: Int { 1 }
}

@MainActor private final class ImageScrollTapGesture: UITapGestureRecognizer {
    override var state: UIGestureRecognizer.State { get { .ended } set {} }
    override var numberOfTouches: Int { 1 }
}

@MainActor private final class ImageLongPressGesture: UILongPressGestureRecognizer {
    override var state: UIGestureRecognizer.State { get { .began } set {} }
    override func location(in view: UIView?) -> CGPoint { CGPoint(x: 100, y: 200) }
}

// StoryImageViewerTests.swift exercises iPad-sized layout and inset changes on the shared simulator.
private final class ImageViewerSafeAreaView: UIView {
    var topInset: CGFloat = 24
    override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0) }
}
