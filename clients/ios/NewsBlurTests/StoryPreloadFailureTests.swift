import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryPreloadFailure: XCTestCase {
    func test_failedPreloadedNavigationIsReloadedWhenSelected() async throws {
        let defaults = UserDefaults.standard
        let previousFontSize = defaults.object(forKey: "story_font_size")
        defaults.set("medium", forKey: "story_font_size")
        defer {
            if let previousFontSize { defaults.set(previousFontSize, forKey: "story_font_size") }
            else { defaults.removeObject(forKey: "story_font_size") }
        }
        for provisional in [false, true] {
            let app = PreloadFailureApp()
            let pages = PreloadFailurePages()
            app.testPages = pages
            pages.appDelegate = app
            pages.loadViewIfNeeded()
            pages.scrollView = UIScrollView(frame: pages.view.bounds)
            pages.view.addSubview(pages.scrollView)
            let stories: [NSMutableDictionary] = (0..<2).map {
                ["story_hash": "preload-\($0)", "story_feed_id": 1, "story_title": "Article \($0)",
                 "story_content": "<p>Preloaded article \($0)</p>", "read_status": 1]
            }
            let collection = StoriesCollection()
            collection.appDelegate = app
            collection.activeFeedStories = stories
            collection.storyCount = 2
            collection.storyLocationsCount = 2
            collection.activeFeedStoryLocations = NSMutableArray(array: [0, 1])
            collection.activeFeedStoryLocationIds = NSMutableArray(array: ["preload-0", "preload-1"])
            app.storiesCollection = collection
            let children = (0..<3).map { _ -> PreloadFailurePage in
                let page = PreloadFailurePage()
                page.appDelegate = app
                page.loadViewIfNeeded()
                page.webView = PreloadFailureWebView(frame: pages.view.bounds, configuration: WKWebViewConfiguration())
                page.view.addSubview(page.webView)
                page.webView.isHidden = true
                page.setValue(true, forKey: "preparedWebViewFonts")
                page.pageIndex = -2
                pages.addChild(page)
                pages.scrollView.addSubview(page.view)
                page.didMove(toParent: pages)
                return page
            }
            pages.currentPage = children[0]
            pages.nextPage = children[1]
            pages.previousPage = children[2]
            defer {
                pages.cancelPendingStoryPresentation()
                // StoryPreloadFailureTests.swift supplied web views without the production KVO observer.
                for page in children { page.webView = nil }
                app.testPages = nil
            }
            // StoryPreloadFailureTests.swift selects a cached neighbor from an existing reader, not an empty iPad pane's early entrance.
            children[0].pageIndex = 0
            children[0].activeStory = stories[0]
            children[0].drawStory()
            await drainMainQueue()
            children[0].perform(NSSelectorFromString("webViewNotifyLoaded"))
            XCTAssertTrue(children[0].hasStory)
            XCTAssertFalse(children[0].webView.isHidden)
            let selected = children[1]
            let web = try XCTUnwrap(selected.webView as? PreloadFailureWebView)
            selected.pageIndex = 1
            selected.activeStory = stories[1]
            selected.drawStory()
            await drainMainQueue()
            let failed = try XCTUnwrap(web.navigations.last)
            XCTAssertTrue(selected.hasStory)
            XCTAssertNil(pages.value(forKey: "pendingPresentationCompletion"))

            // StoryPreloadFailureTests.swift fails a cached neighbor before the user selects its title.
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotLoadFromNetwork)
            if provisional { selected.webView(web, didFailProvisionalNavigation: failed, withError: error) }
            else { selected.webView(web, didFail: failed, withError: error) }
            let loadCount = web.navigations.count
            app.activeStory = stories[1] as? [AnyHashable: Any]
            app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": false])
            await drainMainQueue()

            XCTAssertGreaterThan(web.navigations.count, loadCount,
                                 "Selecting a failed preload must reload instead of waiting for lost readiness")
            guard web.navigations.last !== failed else { continue }
            selected.webView(web, didFail: failed, withError: error)
            XCTAssertNotNil(pages.value(forKey: "pendingPresentationCompletion"), "The old failure must not cancel the retry")
            selected.perform(NSSelectorFromString("webViewNotifyLoaded"))
            await drainMainQueue()
            XCTAssertEqual(app.presentations, 1)
            XCTAssertEqual(pages.currentPage.activeStoryId, "preload-1")
            XCTAssertTrue(pages.currentPage.readyForPresentation)
            XCTAssertFalse(pages.currentPage.webView.isHidden)
        }
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

@MainActor private final class PreloadFailureApp: NewsBlurAppDelegate {
    var testPages: StoryPagesViewController?
    var presentations = 0
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set { testPages = newValue }
    }
    override var feedDetailViewController: FeedDetailViewController! { nil }
    override var detailViewController: DetailViewController! {
        get { nil }
        set {}
    }
    override func isFeed(inTextView feedId: Any!) -> Bool { false }
    override func showDetailViewController(_ vc: UIViewController, sender: Any?) { presentations += 1 }
}

@MainActor private final class PreloadFailurePages: StoryPagesViewController {
    override var useCustomToolbar: Bool { false }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func setTextButton() {}
    override func setTextButton(_ storyViewController: StoryDetailViewController!) {}
    override func changePage(_ pageIndex: Int, animated: Bool) {}
    override func animate(intoPlace animated: Bool) {}
}

@MainActor private final class PreloadFailurePage: StoryDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func getHeader() -> String! { "<h1>Fixture article</h1>" }
    override func getShareBar() -> String! { "" }
    override func getComments() -> String! { "" }
    override func changeWebViewWidth() {}
    override func checkTryFeedStory() {}
    @objc(getSideOptions) func sideOptions() -> String { "" }
}

@MainActor private final class PreloadFailureWebView: WKWebView {
    var navigations: [WKNavigation] = []
    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        // StoryPreloadFailureTests.swift uses unique navigation identities without network or WebKit timing.
        let navigation = unsafeBitCast(NSObject(), to: WKNavigation.self)
        navigations.append(navigation)
        return navigation
    }
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil) {
        completionHandler?(nil, nil)
    }
    override func __callAsyncJavaScript(_ functionBody: String, arguments: [String: Any]?, inFrame frame: WKFrameInfo?,
                                      in contentWorld: WKContentWorld, completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil) {
        completionHandler?(true, nil)
    }
}
