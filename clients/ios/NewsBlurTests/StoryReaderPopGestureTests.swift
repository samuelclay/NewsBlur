import UIKit
import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryReaderPopGesture: XCTestCase {
    private let keys = ["story_detail_swipe_left_edge", "scroll_stories_horizontally"]
    private var preferences: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persisted = UserDefaults.standard.persistentDomain(forName: bundle) ?? [:]
        for key in keys { preferences[key] = persisted[key] }
    }

    override func tearDown() {
        for key in keys {
            if let value = preferences[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        preferences.removeAll()
        super.tearDown()
    }

    func test_initialAppearanceHonorsPreviousStoryAndBackPreferences() throws {
        for preference in ["previous_story", "pop_to_story_list"] {
            for horizontal in [true, false] {
                UserDefaults.standard.set(preference, forKey: keys[0])
                UserDefaults.standard.set(horizontal, forKey: keys[1])
                let (pages, navigation) = makeReader()
                pages.viewDidAppear(false)
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    func test_changingScrollOrientationPreservesBothPreferences() throws {
        for preference in ["previous_story", "pop_to_story_list"] {
            UserDefaults.standard.set(preference, forKey: keys[0])
            let (pages, navigation) = makeReader()
            pages.viewDidAppear(false)
            for horizontal in [true, false, true] {
                UserDefaults.standard.set(horizontal, forKey: keys[1])
                pages.changedScrollOrientation()
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    func test_reappearingReaderRechecksPreferenceForExistingGestures() throws {
        for horizontal in [true, false] {
            UserDefaults.standard.set(horizontal, forKey: keys[1])
            let (pages, navigation) = makeReader()
            for preference in ["pop_to_story_list", "previous_story", "pop_to_story_list"] {
                UserDefaults.standard.set(preference, forKey: keys[0])
                pages.viewDidAppear(false)
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    func test_horizontalPagingKeepsArticlePanDisabledUntilPagingFinishes() {
        UserDefaults.standard.set(true, forKey: keys[1])
        let (pages, _) = makeReaderWithArticles()
        pages.scrollViewWillBeginDragging(pages.scrollView)
        for page in [pages.currentPage!, pages.nextPage!, pages.previousPage!] {
            XCTAssertFalse(page.webView.scrollView.isScrollEnabled)
            XCTAssertFalse(page.webView.scrollView.panGestureRecognizer.isEnabled,
                           "A disabled article must not compete with the active horizontal page gesture")
        }
        pages.scrollViewDidEndDecelerating(pages.scrollView)
        XCTAssertFalse(pages.isDraggingScrollview)
        XCTAssertTrue(pages.currentPage.webView.scrollView.isScrollEnabled)
        XCTAssertTrue(pages.currentPage.webView.scrollView.panGestureRecognizer.isEnabled)
    }

    func test_changingOrientationAfterInterruptedPagingRestoresArticleScrolling() {
        UserDefaults.standard.set(true, forKey: keys[1])
        let (pages, _) = makeReaderWithArticles()
        pages.scrollViewWillBeginDragging(pages.scrollView)
        UserDefaults.standard.set(false, forKey: keys[1])
        pages.changedScrollOrientation()
        XCTAssertFalse(pages.isDraggingScrollview)
        for page in [pages.currentPage!, pages.nextPage!, pages.previousPage!] {
            XCTAssertTrue(page.webView.scrollView.isScrollEnabled)
        }
    }

    func test_articleScrollRestorationDoesNotInterruptHorizontalPaging() {
        UserDefaults.standard.set(true, forKey: keys[1])
        let (pages, _) = makeReaderWithArticles()
        pages.scrollViewWillBeginDragging(pages.scrollView)
        for page in [pages.currentPage!, pages.nextPage!, pages.previousPage!] {
            page.perform(NSSelectorFromString("deferredEnableScrolling"))
            XCTAssertFalse(page.webView.scrollView.isScrollEnabled,
                           "Article readiness and double-tap callbacks must respect active paging")
        }
        pages.scrollViewDidEndDragging(pages.scrollView, willDecelerate: true)
        pages.currentPage.perform(NSSelectorFromString("deferredEnableScrolling"))
        XCTAssertFalse(pages.currentPage.webView.scrollView.isScrollEnabled)
        pages.scrollViewDidEndDecelerating(pages.scrollView)
        XCTAssertTrue(pages.currentPage.webView.scrollView.isScrollEnabled)
    }

    func test_blankStoryTapRestoresTraversalWithoutEnablingAutoscroll() {
        let (pages, _) = makeReaderWithArticles()
        pages.traverseView = UIView()
        pages.traverseView.alpha = 0
        pages.traverseFadeAccumulator = 80

        pages.tappedStory()

        XCTAssertEqual(pages.traverseView.alpha, 1)
        XCTAssertEqual(pages.traverseFadeAccumulator, 0)
        XCTAssertFalse(pages.autoscrollActive)
    }

    func test_cancelledHorizontalPeekRestoresTraversalOnTheSameStory() {
        UserDefaults.standard.set(true, forKey: keys[1])
        let (pages, _) = makeReaderWithArticles()
        pages.currentPage.pageIndex = 0
        pages.traverseView = UIView()
        pages.traverseView.alpha = 0
        pages.traverseFadeAccumulator = 80
        pages.scrollViewWillBeginDragging(pages.scrollView)
        pages.scrollView.contentOffset.x = 30
        var target = CGPoint.zero
        pages.scrollViewWillEndDragging(pages.scrollView, withVelocity: .zero, targetContentOffset: &target)
        pages.scrollView.contentOffset = target
        pages.scrollViewDidEndDecelerating(pages.scrollView)

        XCTAssertEqual(pages.currentPage.pageIndex, 0)
        XCTAssertEqual(pages.traverseView.alpha, 1)
        XCTAssertEqual(pages.traverseFadeAccumulator, 0)

        pages.traverseView.alpha = 0
        pages.traverseFadeAccumulator = 80
        pages.scrollViewWillBeginDragging(pages.scrollView)
        pages.scrollViewDidEndDecelerating(pages.scrollView)
        XCTAssertEqual(pages.traverseView.alpha, 0, "A stationary touch is not a horizontal peek")
    }

    func test_upwardTraversalRevealWaitsForIntentAndDownwardScrollFadesAgain() {
        let (pages, _) = makeReaderWithArticles()
        pages.traverseView = UIView()
        pages.traverseView.alpha = 0
        pages.traverseFadeAccumulator = 80
        let page = pages.currentPage!
        let scroll = page.webView.scrollView as! ReaderTraversalScroll
        scroll.contentSize = CGSize(width: 375, height: 4000)
        scroll.contentOffset.y = 700
        scroll.simulatesDragging = true
        page.lastDragDirectionDown = false
        func scrollBy(_ delta: CGFloat) {
            let old = scroll.contentOffset
            scroll.contentOffset.y += delta
            page.observeValue(forKeyPath: "contentOffset", of: scroll,
                              change: [.oldKey: NSValue(cgPoint: old), .newKey: NSValue(cgPoint: scroll.contentOffset)],
                              context: nil)
        }

        scrollBy(-10)
        XCTAssertEqual(pages.traverseView.alpha, 0, "Small direction changes must not flash navigation")
        page.scrollViewWillBeginDragging(scroll)
        scrollBy(-20)
        XCTAssertGreaterThan(pages.traverseView.alpha, 0)
        scrollBy(-80)
        XCTAssertEqual(pages.traverseView.alpha, 1)
        scrollBy(30)
        XCTAssertGreaterThan(pages.traverseView.alpha, 0)
        XCTAssertLessThan(pages.traverseView.alpha, 1)
    }

    private func makeReaderWithArticles() -> (ReaderPopGesturePages, UINavigationController) {
        let (pages, navigation) = makeReader()
        let articles = (0..<3).map { _ -> StoryDetailViewController in
            let page = ReaderScrollArticle()
            page.appDelegate = pages.appDelegate
            page.webView = ReaderTraversalWebView(frame: pages.view.bounds)
            return page
        }
        pages.currentPage = articles[0]
        pages.nextPage = articles[1]
        pages.previousPage = articles[2]
        return (pages, navigation)
    }

    private func makeReader() -> (ReaderPopGesturePages, UINavigationController) {
        let pages = ReaderPopGesturePages()
        let app = ReaderPopGestureAppDelegate()
        app.reader = pages
        pages.appDelegate = app
        pages.loadViewIfNeeded()
        pages.scrollView = UIScrollView(frame: pages.view.bounds)
        pages.view.addSubview(pages.scrollView)
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController(), pages]
        navigation.loadViewIfNeeded()
        return (pages, navigation)
    }

    private func assertGestures(_ pages: ReaderPopGesturePages, _ navigation: UINavigationController,
                                preference: String, horizontal: Bool) throws {
        let edge = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let fullScreen = try XCTUnwrap(pages.fullScreenPopGesture)
        let enabled = preference == "pop_to_story_list"
        XCTAssertEqual(edge.isEnabled, enabled && horizontal, "preference=\(preference), horizontal=\(horizontal)")
        XCTAssertEqual(fullScreen.isEnabled, enabled && !horizontal, "preference=\(preference), horizontal=\(horizontal)")
    }
}

@MainActor private final class ReaderPopGesturePages: StoryPagesViewController {
    // StoryReaderPopGestureTests.swift exercises real appearance and gesture setup without loading article content.
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func reorientPages() {}
    override func setStoryFromScroll() {}
    override func resizeScrollView() {}
}

@MainActor private final class ReaderScrollArticle: StoryDetailViewController {
    override func loadView() { view = UIView() }
    override func viewDidLoad() {}
    deinit {
        // StoryReaderPopGestureTests.swift creates the web view without the production KVO observer.
        webView = nil
    }
}

private final class ReaderPopGestureAppDelegate: NewsBlurAppDelegate {
    weak var reader: StoryPagesViewController?
    override var storyPagesViewController: StoryPagesViewController! { reader }
    override var isCompactWidth: Bool { true }
    override func adjustStoryDetailWebView() {}
}

@MainActor private final class ReaderTraversalWebView: WKWebView {
    private let trackedScroll = ReaderTraversalScroll()
    override var scrollView: UIScrollView { trackedScroll }
}

@MainActor private final class ReaderTraversalScroll: UIScrollView {
    var simulatesDragging = false
    override var isDragging: Bool { simulatesDragging }
}
