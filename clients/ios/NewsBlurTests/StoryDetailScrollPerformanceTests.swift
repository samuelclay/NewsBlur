import XCTest
import WebKit
@testable import NewsBlur

@MainActor final class Test_StoryDetailScrollPerformance: XCTestCase {
    func test_repeatedClampedToolbarOffsetDoesNotMutateAdjacentScrollViews() {
        let pages = makePages()
        pages.setToolbarOffset(44)
        let next = pages.nextPage as! DetailScrollProbe
        let previous = pages.previousPage as! DetailScrollProbe
        let current = pages.currentPage as! DetailScrollProbe
        next.trackedScroll.offsetWrites = 0
        previous.trackedScroll.offsetWrites = 0
        current.gradientUpdates = 0
        pages.statusUpdates = 0

        for _ in 0..<500 { pages.setToolbarOffset(44) }

        XCTAssertEqual(next.trackedScroll.offsetWrites, 0)
        XCTAssertEqual(previous.trackedScroll.offsetWrites, 0)
        XCTAssertEqual(current.gradientUpdates, 0)
        XCTAssertEqual(pages.statusUpdates, 0)
    }

    func test_changedOffsetStillSynchronizesToolbarAndTopAdjacentPages() {
        let pages = makePages()
        pages.setToolbarOffset(20)
        XCTAssertEqual(pages.storyToolbar.transform.ty, -20)
        XCTAssertEqual(pages.nextPage.webView.scrollView.contentOffset.y, -80)
        XCTAssertEqual(pages.previousPage.webView.scrollView.contentOffset.y, -80)
        XCTAssertEqual((pages.currentPage as! DetailScrollProbe).gradientUpdates, 1)
    }

    func test_newAdjacentPageSynchronizesEvenWhenToolbarIsAlreadyHidden() {
        let pages = makePages()
        pages.setToolbarOffset(44)
        pages.nextPage.webView.scrollView.contentOffset.y = -100
        pages.setToolbarOffset(44)
        XCTAssertEqual(pages.nextPage.webView.scrollView.contentOffset.y, -56)
    }

    func test_scrolledAdjacentPageKeepsItsReadingPosition() {
        let pages = makePages()
        pages.nextPage.webView.scrollView.contentOffset.y = 400
        pages.setToolbarOffset(44)
        XCTAssertEqual(pages.nextPage.webView.scrollView.contentOffset.y, 400)
    }

    func test_scrollHandlerAlreadyUpdatedBeforeToolbarTransformIsApplied() {
        let pages = makePages()
        pages.toolbarScrollHandler.handleScrollDelta(20, atTop: false, atBottom: false, nearTop: true)
        pages.setToolbarOffset(pages.toolbarScrollHandler.toolbarOffset)

        XCTAssertEqual(pages.storyToolbar.transform.ty, -20)
        XCTAssertEqual((pages.currentPage as! DetailScrollProbe).gradientUpdates, 1)
    }

    func test_resetHandlerStillRestoresHiddenToolbarAndAdjacentPages() {
        let pages = makePages()
        pages.setToolbarOffset(44)
        pages.toolbarScrollHandler.reset()
        pages.setToolbarOffset(0)

        XCTAssertEqual(pages.storyToolbar.transform, .identity)
        XCTAssertEqual(pages.nextPage.webView.scrollView.contentOffset.y, -100)
        XCTAssertEqual(pages.previousPage.webView.scrollView.contentOffset.y, -100)
    }

    func test_changedToolbarUpdatesGradientForAdjacentPageAlreadyAtTarget() {
        let pages = makePages()
        let next = pages.nextPage as! DetailScrollProbe
        next.trackedScroll.contentOffset.y = -80
        next.trackedScroll.offsetWrites = 0
        pages.setToolbarOffset(20)

        XCTAssertEqual(next.trackedScroll.offsetWrites, 0)
        XCTAssertEqual(next.gradientUpdates, 1)
    }

    private func makePages() -> DetailPagesProbe {
        let pages = DetailPagesProbe()
        pages.storyToolbar = StoryToolbar()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        pages.toolbarScrollHandler.toolbarHeight = 44
        pages.currentPage = DetailScrollProbe()
        pages.nextPage = DetailScrollProbe()
        pages.previousPage = DetailScrollProbe()
        return pages
    }
}

@MainActor private final class DetailPagesProbe: StoryPagesObjCViewController {
    var statusUpdates = 0
    override func updateStatusBarState() { statusUpdates += 1 }
}

@MainActor private final class DetailScrollProbe: StoryDetailViewController {
    let trackedScroll = DetailOffsetProbe()
    var gradientUpdates = 0

    init() {
        super.init(nibName: nil, bundle: nil)
        let web = DetailWebProbe(frame: .zero, configuration: WKWebViewConfiguration())
        web.trackedScroll = trackedScroll
        webView = web
        trackedScroll.contentInset.top = 100
        trackedScroll.contentOffset.y = -100
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    deinit {
        // StoryDetailScrollPerformanceTests.swift never installs the real web view's KVO observer.
        webView = nil
    }

    override func updateFeedTitleGradientPosition() { gradientUpdates += 1 }
}

@MainActor private final class DetailWebProbe: WKWebView {
    var trackedScroll = DetailOffsetProbe()
    override var scrollView: UIScrollView { trackedScroll }
}

@MainActor private final class DetailOffsetProbe: UIScrollView {
    var offsetWrites = 0
    override var contentOffset: CGPoint {
        didSet { offsetWrites += 1 }
    }
}
