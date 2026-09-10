import Network
import UIKit
import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryDetailLoading: XCTestCase {
    private var preferences: [String: Any] = [:]
    private let preferenceKeys = ["story_font_size", "story_line_spacing", "fontStyle"]

    override func setUp() {
        super.setUp()
        let bundleID = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persisted = UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]
        for key in preferenceKeys {
            preferences[key] = persisted[key]
            UserDefaults.standard.set(key == "fontStyle" ? "GothamNarrow-Book" : "medium", forKey: key)
        }
    }

    override func tearDown() {
        for key in preferenceKeys {
            if let value = preferences[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        preferences.removeAll()
        super.tearDown()
    }

    func test_bootstrapPreparesBundledFontsWithoutStoryOrRemoteResources() throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        let html = try XCTUnwrap(fixture.web.loads.last?.html)

        for family in ["ChronicleSSm-Book", "GothamNarrow-Book", "WhitneySSm-Book"] {
            XCTAssertTrue(html.contains(family))
        }
        XCTAssertTrue(html.contains("data:font/otf;base64,"))
        XCTAssertFalse(html.contains("Fixture article"))
        XCTAssertFalse(html.contains("<img"))
        XCTAssertFalse(html.contains("https://"))
    }

    func test_earlyStoryDrawWaitsForBootstrapAndUsesLatestQueuedStory() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        let bootstrap = try XCTUnwrap(fixture.web.loads.last?.navigation)
        fixture.page.drawStory()
        fixture.page.activeStory = story("second", body: "Latest early story")
        fixture.page.drawStory()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 1)
        fixture.page.webView(fixture.web, didFinish: bootstrap)
        await drainMainQueue()
        XCTAssertEqual(fixture.web.loads.count, 2)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Latest early story") == true)
    }

    func test_firstNavigationAlreadyContainsCompleteStoryAndHTTPSOrigin() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 1)
        XCTAssertTrue(fixture.web.loads.first?.html.contains("Fixture article body") == true)
        XCTAssertTrue(fixture.web.loads.first?.html.contains("Fixture comments") == true)
        XCTAssertEqual(fixture.web.loads.first?.baseURL?.absoluteString, "https://newsblur.com/")
    }

    func test_finishingNavigationDoesNotSubmitAnotherDocument() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let navigation = try XCTUnwrap(fixture.web.loads.first?.navigation)

        fixture.page.webView(fixture.web, didFinish: navigation)
        fixture.page.webView(fixture.web, didFinish: navigation)

        XCTAssertEqual(fixture.web.loads.count, 1)
    }

    func test_reusedPageSubmitsOnlyLatestQueuedStory() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        fixture.page.activeStory = story("second", body: "Latest body")
        fixture.page.drawStory()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 1)
        XCTAssertTrue(fixture.web.loads.first?.html.contains("Latest body") == true)
        XCTAssertFalse(fixture.web.loads.first?.html.contains("Fixture article body") == true)
    }

    func test_clearCancelsPreviouslyQueuedStorySubmission() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        fixture.page.clearStory()
        fixture.web.loads.removeAll()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 0)
        XCTAssertTrue(fixture.web.isHidden)
    }

    func test_hideCancelsAlreadyScheduledReveal() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.perform(NSSelectorFromString("loadStory"))
        fixture.page.hideStory()
        await delay(0.15)

        XCTAssertTrue(fixture.web.isHidden)
    }

    func test_oldNavigationCompletionCannotConfigureReusedPage() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let previous = try XCTUnwrap(fixture.web.loads.first?.navigation)
        fixture.page.activeStory = story("second", body: "Latest body")
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.widthUpdates = 0

        fixture.page.webView(fixture.web, didFinish: previous)

        XCTAssertEqual(fixture.page.widthUpdates, 0)
    }

    func test_unidentifiedDOMNotificationDoesNotRestoreOrConfigurePage() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.widthUpdates = 0
        fixture.app.activeComment = ["comment": "Still editing"]

        sendReady(to: fixture.page, token: nil, mainFrame: true)

        XCTAssertEqual(fixture.page.widthUpdates, 0)
        XCTAssertEqual(fixture.page.classifierUpdates, 0)
        XCTAssertEqual(fixture.app.activeComment?["comment"] as? String, "Still editing")
    }

    func test_visibleDocumentCanFinishDOMSetupAfterTemporaryPresentation() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let token = try tokenFromHTML(try XCTUnwrap(fixture.web.loads.first?.html))
        await delay(0.15)
        XCTAssertFalse(fixture.web.isHidden)

        fixture.page.viewWillDisappear(false)
        fixture.page.viewWillAppear(false)
        sendReady(to: fixture.page, token: token, mainFrame: true)

        XCTAssertEqual(fixture.page.classifierUpdates, 1)
        XCTAssertEqual(fixture.web.loads.count, 1)
    }

    func test_returningFromPresentationPreservesRestoredPositionWithHiddenToolbar() async {
        let app = StoryLoadAppDelegate()
        let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
        app.testPages = pages
        defer { app.testPages = nil }
        pages.appDelegate = app
        pages.storyToolbar = StoryToolbar()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        pages.toolbarScrollHandler.toolbarHeight = 44
        pages.toolbarScrollHandler.setOffset(44)
        let fixture = makeFixture(app: app)
        pages.currentPage = fixture.page
        fixture.page.drawStory()
        await drainMainQueue()
        await delay(0.15)
        fixture.page.setValue(true, forKey: "restoredStoryScrollPosition")
        fixture.web.scrollView.contentOffset = CGPoint(x: 0, y: 250)

        fixture.page.viewWillDisappear(false)
        fixture.page.viewWillAppear(false)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 250)
    }

    func test_sameHashTextViewStillSubmitsItsNewCompleteDocument() async {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.inTextView = true
        fixture.page.activeStory["original_text"] = "Full text replacement"
        fixture.page.drawStory()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 2)
        XCTAssertTrue(fixture.web.loads.first?.html.contains("Fixture article body") == true)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Full text replacement") == true)
        XCTAssertFalse(fixture.web.loads.last?.html.contains("Fixture article body") == true)
    }

    func test_delayedScrollRestoreStillRestoresTheSameStory() async {
        let fixture = makeFixture()
        let database = HeldStoryScrollQueue()
        fixture.app.setValue(database, forKey: "database")
        fixture.page.drawStory()
        await drainMainQueue()
        restoreScroll(on: fixture.page)
        await fulfillment(of: [database.started], timeout: 2)
        database.release()
        await delay(0.05)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 2_500)
    }

    func test_readyTokenMustMatchCurrentMainDocumentAndRunsOnce() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let token = try tokenFromHTML(try XCTUnwrap(fixture.web.loads.first?.html))

        sendReady(to: fixture.page, token: "obsolete", mainFrame: true)
        sendReady(to: fixture.page, token: token, mainFrame: false)
        XCTAssertEqual(fixture.page.classifierUpdates, 0)
        sendReady(to: fixture.page, token: token, mainFrame: true)
        sendReady(to: fixture.page, token: token, mainFrame: true)
        XCTAssertEqual(fixture.page.classifierUpdates, 1)
    }

    func test_delayedScrollRestoreCannotMoveAnotherStory() async {
        let fixture = makeFixture()
        let database = HeldStoryScrollQueue()
        fixture.app.setValue(database, forKey: "database")
        fixture.page.drawStory()
        await drainMainQueue()
        restoreScroll(on: fixture.page)
        await fulfillment(of: [database.started], timeout: 2)

        fixture.page.activeStory = story("second", body: "Latest body")
        fixture.page.drawStory()
        fixture.web.scrollView.contentOffset = .zero
        database.release()
        await delay(0.05)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 0)
    }

    func test_delayedScrollRestoreCannotOverrideManualScrolling() async {
        let app = StoryLoadAppDelegate()
        let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
        app.testPages = pages
        defer { app.testPages = nil }
        pages.appDelegate = app
        let fixture = makeFixture(app: app)
        pages.currentPage = fixture.page
        let database = HeldStoryScrollQueue()
        fixture.app.setValue(database, forKey: "database")
        fixture.page.drawStory()
        await drainMainQueue()
        restoreScroll(on: fixture.page)
        await fulfillment(of: [database.started], timeout: 2)

        fixture.web.trackedScroll.simulatesDragging = true
        fixture.web.scrollView.contentOffset = CGPoint(x: 0, y: 120)
        fixture.page.observeValue(forKeyPath: "contentOffset", of: fixture.web.scrollView,
                                  change: [.oldKey: NSValue(cgPoint: .zero),
                                           .newKey: NSValue(cgPoint: CGPoint(x: 0, y: 120))], context: nil)
        fixture.web.trackedScroll.simulatesDragging = false
        database.release()
        await delay(0.05)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 120)
    }

    func test_stalledWebKitSubresourceDoesNotKeepReadableStoryHidden() async throws {
        try await checkStalledStoryRendering(restoresPosition: false)
    }

    func test_DOMReadyRestoresSavedPositionAfterNativeWebKitLayout() async throws {
        try await checkStalledStoryRendering(restoresPosition: true)
    }

    func test_bootstrappedWebKitRendersFirstAndSecondStoriesWithPendingImages() async throws {
        try await checkStalledStoryRendering(restoresPosition: false, repeatsStory: true)
    }

    private func checkStalledStoryRendering(restoresPosition: Bool, repeatsStory: Bool = false) async throws {
        let resource = try HeldHTTPStoryResource()
        for _ in 0..<60 where resource.port == nil { await delay(0.05) }
        let imageURL = try XCTUnwrap(resource.imageURL)
        let configuration = WKWebViewConfiguration()
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        let page = makePage(web: web)
        page.allowsAppearanceCallbacks = false
        if restoresPosition { page.appDelegate.setValue(ImmediateStoryScrollQueue(), forKey: "database") }
        page.shareHTML = "<img src='\(imageURL)' width='30' height='30'>"
        page.activeStory = story("first", body: String(repeating: "<p>Readable article paragraph.</p>", count: 150))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(web)
        window.makeKeyAndVisible()
        defer {
            resource.stop()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        web.navigationDelegate = page
        // StoryDetailObjCViewController.m initializes every WKWebView with clearWebView before drawing a story.
        page.perform(NSSelectorFromString("clearWebView"))
        for _ in 0..<60 where page.finishedNavigations == 0 { await delay(0.05) }
        XCTAssertEqual(page.finishedNavigations, 1)
        page.finishedNavigations = 0
        let ready = expectation(description: "Full story DOM is ready while its image remains pending")
        page.readyObserver = { ready.fulfill() }
        page.drawStory()
        await fulfillment(of: [ready], timeout: 5)
        _ = try await web.evaluateJavaScript("window.nbTestFontReady=false; document.fonts.ready.then(()=>window.nbTestFontReady=true); window.nbTestFrames=0; requestAnimationFrame(function count(){window.nbTestFrames++; if(window.nbTestFrames<120)requestAnimationFrame(count);});")
        await delay(0.15)
        for _ in 0..<40 where web.scrollView.contentSize.height < web.bounds.height + 500 {
            window.layoutIfNeeded()
            await delay(0.05)
        }

        XCTAssertGreaterThan(resource.pendingCount, 0)
        XCTAssertFalse(web.isHidden)
        let body = try await web.evaluateJavaScript("document.querySelector('#NB-story').textContent") as? String
        XCTAssertTrue(body?.contains("Readable article paragraph") == true)
        XCTAssertEqual(page.finishedNavigations, 0)
        let layout = try await web.evaluateJavaScript("JSON.stringify({ready:document.readyState,body:document.body.scrollHeight,viewport:window.innerHeight,fonts:document.fonts.status,fontReady:window.nbTestFontReady,frames:window.nbTestFrames,paint:performance.getEntriesByType('paint'),font:getComputedStyle(document.querySelector('#NB-story')).fontFamily,story:document.querySelector('#NB-story').getBoundingClientRect().height,images:Array.from(document.images).map(i=>[i.src,i.complete,i.naturalWidth])})")
        print("STORY_HELD_RESOURCE_LAYOUT native=\(web.scrollView.contentSize) frame=\(web.frame) inWindow=\(web.window != nil) scene=\(window.windowScene?.activationState.rawValue ?? -1) dom=\(layout)")
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Readable story while image remains pending"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(web.scrollView.contentSize.height, web.bounds.height + 500)
        let readingPosition: CGFloat
        if restoresPosition {
            readingPosition = floor(web.scrollView.contentSize.height / 2)
            await delay(0.4)
        } else {
            readingPosition = 250
            web.scrollView.contentOffset = CGPoint(x: 0, y: readingPosition)
        }
        XCTAssertEqual(web.scrollView.contentOffset.y, readingPosition, accuracy: 2)
        resource.finish()
        await delay(0.15)
        XCTAssertEqual(web.scrollView.contentOffset.y, readingPosition, accuracy: 2)
        if repeatsStory {
            let previousHeight = web.scrollView.contentSize.height
            let secondReady = expectation(description: "Second story is ready on the same prepared WKWebView")
            page.readyObserver = { secondReady.fulfill() }
            page.activeStory = story("second", body: String(repeating: "<p>Second article paragraph.</p>", count: 220))
            page.drawStory()
            await fulfillment(of: [secondReady], timeout: 5)
            for _ in 0..<40 where web.scrollView.contentSize.height < previousHeight + 500 { await delay(0.05) }
            XCTAssertGreaterThan(resource.pendingCount, 0)
            XCTAssertGreaterThan(web.scrollView.contentSize.height, previousHeight + 500)
            let secondBody = try await web.evaluateJavaScript("document.querySelector('#NB-story').textContent.includes('Second article')") as? Bool
            XCTAssertEqual(secondBody, true)
            resource.finish()
        }
        page.webView = nil
    }

    func test_plainWebKitCanRenderWhileAnImageRemainsPending() async throws {
        try await checkPlainWebKitRendering(notifiesNative: false)
    }

    func test_plainWebKitCanRenderAfterCancelledDOMReadyNavigation() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true)
    }

    func test_generatedStoryHTMLRendersWithAnIndependentWebKitDelegate() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true)
    }

    func test_generatedStoryWithoutStylesRendersWithHeldImage() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true, stripPattern: "<style\\b[^>]*>[\\s\\S]*?</style>")
    }

    func test_generatedStoryWithoutScriptsRendersWithHeldImage() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true, stripPattern: "<script\\b[^>]*>[\\s\\S]*?</script>")
    }

    func test_generatedStoryWithoutViewportRendersWithHeldImage() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true, stripPattern: "<meta\\b[^>]*name=\"viewport\"[^>]*>")
    }

    func test_generatedStoryWithoutEmbeddedFontsRendersWithHeldImage() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true, stripPattern: "@font-face\\s*\\{[^}]+\\}")
    }

    func test_generatedStoryWithoutReadyNavigationRendersWithHeldImage() async throws {
        try await checkPlainWebKitRendering(notifiesNative: true, generatedStory: true, disableReadyNavigation: true)
    }

    private func checkPlainWebKitRendering(notifiesNative: Bool, generatedStory: Bool = false, stripPattern: String? = nil, disableReadyNavigation: Bool = false) async throws {
        let resource = try HeldHTTPStoryResource()
        for _ in 0..<60 where resource.port == nil { await delay(0.05) }
        let imageURL = try XCTUnwrap(resource.imageURL)
        let configuration = WKWebViewConfiguration()
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        let navigationDelegate = PlainStoryNavigationDelegate()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(web)
        window.makeKeyAndVisible()
        defer {
            resource.stop()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        web.isHidden = false
        web.navigationDelegate = navigationDelegate
        let notify = notifiesNative ? "<script>document.addEventListener('DOMContentLoaded',function(){window.location='http://ios.newsblur.com/notify-loaded';});</script>" : ""
        var html = "<html><body><img src='\(imageURL)' width='30' height='30'>" + String(repeating: "<p>Plain WebKit control paragraph.</p>", count: 150) + notify + "</body></html>"
        if generatedStory {
            let fixture = makeFixture()
            fixture.page.shareHTML = "<img src='\(imageURL)' width='30' height='30'>"
            fixture.page.activeStory = story("first", body: String(repeating: "<p>Readable article paragraph.</p>", count: 150))
            fixture.page.drawStory()
            await drainMainQueue()
            html = try XCTUnwrap(fixture.web.loads.last?.html)
        }
        if let stripPattern {
            html = try NSRegularExpression(pattern: stripPattern).stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "")
        }
        if disableReadyNavigation {
            let readyNavigation = "    window.location = url;\n}"
            XCTAssertEqual(html.components(separatedBy: readyNavigation).count, 2)
            html = html.replacingOccurrences(of: readyNavigation, with: "}")
        }
        web.loadHTMLString(html, baseURL: nil)
        for _ in 0..<60 where web.scrollView.contentSize.height < web.bounds.height + 500 {
            await delay(0.05)
        }
        print("STORY_PLAIN_WEBKIT native=\(web.scrollView.contentSize) notify=\(notifiesNative) generatedStory=\(generatedStory) stripped=\(stripPattern ?? "none") disableReady=\(disableReadyNavigation) pending=\(resource.pendingCount) suppressed=\(configuration.suppressesIncrementalRendering)")
        XCTAssertEqual(resource.pendingCount, 1)
        XCTAssertGreaterThan(web.scrollView.contentSize.height, web.bounds.height + 500)
    }

    private func makeFixture(app: NewsBlurAppDelegate = NewsBlurAppDelegate()) -> (page: StoryLoadPage, web: RecordedStoryLoadWebView, app: NewsBlurAppDelegate) {
        let web = RecordedStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        let page = makePage(web: web, app: app)
        return (page, web, page.appDelegate)
    }

    private func makePage(web: WKWebView, app: NewsBlurAppDelegate = NewsBlurAppDelegate()) -> StoryLoadPage {
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.isPremium = true
        let page = StoryLoadPage()
        page.appDelegate = app
        page.activeStory = story("first", body: "Fixture article body")
        page.loadViewIfNeeded()
        page.webView = web
        page.view.addSubview(web)
        web.isHidden = true
        return page
    }

    private func story(_ hash: String, body: String) -> NSMutableDictionary {
        ["story_hash": hash, "story_feed_id": 1, "story_title": "Fixture title", "story_content": body, "read_status": 1]
    }

    private func tokenFromHTML(_ html: String) throws -> String {
        let expression = try NSRegularExpression(pattern: #"name="newsblur-story-load" content="([^"]+)""#)
        let match = try XCTUnwrap(expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)))
        return (html as NSString).substring(with: match.range(at: 1))
    }

    private func sendReady(to page: StoryLoadPage, token: String?, mainFrame: Bool) {
        let suffix = token.map { "?load_id=" + $0 } ?? ""
        let action = StoryReadyAction(url: URL(string: "http://ios.newsblur.com/notify-loaded" + suffix)!, mainFrame: mainFrame)
        page.webView(page.webView, decidePolicyFor: unsafeBitCast(action, to: WKNavigationAction.self)) { policy in
            XCTAssertEqual(policy, .cancel)
        }
    }

    private func restoreScroll(on page: StoryLoadPage) {
        let selector = NSSelectorFromString("scrollToLastPosition:")
        typealias Call = @convention(c) (AnyObject, Selector, Bool) -> Void
        unsafeBitCast(page.method(for: selector), to: Call.self)(page, selector, false)
    }

    private func drainMainQueue() async { await delay(0.01) }

    private func delay(_ seconds: Double) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { continuation.resume() }
        }
    }
}

private final class StoryLoadAppDelegate: NewsBlurAppDelegate {
    var testPages: StoryPagesViewController?
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set { testPages = newValue }
    }
}

@MainActor private final class StoryLoadToolbarPages: StoryPagesViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func setTextButton() {}
    override func setTextButton(_ storyViewController: StoryDetailViewController!) {}
    override func resizeScrollView() {}
    override func updateUITestTraverseFadeProbe() {}
}

@MainActor private final class StoryLoadPage: StoryDetailViewController {
    var widthUpdates = 0
    var classifierUpdates = 0
    var finishedNavigations = 0
    var shareHTML = "Fixture sharing"
    var readyObserver: (() -> Void)?
    var allowsAppearanceCallbacks = true

    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewWillAppear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewWillAppear(animated) } }
    override func viewWillDisappear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewWillDisappear(animated) } }
    override func viewDidAppear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewDidAppear(animated) } }
    override func viewDidDisappear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewDidDisappear(animated) } }
    override func drawStory() {
        if webView is RealStoryLoadWebView { print("STORY_REAL_DRAW \(Thread.callStackSymbols.prefix(10))") }
        super.drawStory()
    }
    override func getHeader() -> String! { "<h1>Fixture header</h1>" }
    override func getShareBar() -> String! { shareHTML }
    override func getComments() -> String! { "Fixture comments" }
    override func changeWebViewWidth() {
        widthUpdates += 1
        if webView is RealStoryLoadWebView { super.changeWebViewWidth() }
    }
    override func checkTryFeedStory() {}
    @objc(storeScrollPosition:) func ignorePositionStorage(_ queue: Bool) {}
    @objc(getSideOptions) func fixtureSideOptions() -> String { "Fixture side options" }
    @objc(applyClassifierHighlights) func recordClassifierHighlights() {
        classifierUpdates += 1
        let observer = readyObserver
        readyObserver = nil
        observer?()
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedNavigations += 1
        super.webView(webView, didFinish: navigation)
    }

    deinit {
        // StoryDetailLoadingTests.swift owns its web view without installing StoryDetailObjCViewController.m's KVO observer.
        webView = nil
    }
}

@MainActor private final class RecordedStoryLoadWebView: WKWebView {
    struct Load { let html: String; let baseURL: URL?; let navigation: WKNavigation }
    var loads: [Load] = []
    let trackedScroll = StoryLoadScrollView()
    override var scrollView: UIScrollView { trackedScroll }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        trackedScroll.frame = frame
        trackedScroll.contentSize = CGSize(width: frame.width, height: 5_000)
    }
    required init?(coder: NSCoder) { fatalError("StoryDetailLoadingTests.swift creates web views programmatically") }
    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        // StoryDetailLoadingTests.swift uses unique opaque identities; no fake navigation reaches WebKit.
        let navigation = unsafeBitCast(NSObject(), to: WKNavigation.self)
        loads.append(Load(html: string, baseURL: baseURL, navigation: navigation))
        return navigation
    }
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        completionHandler?(nil, nil)
    }
}

@MainActor private final class StoryLoadScrollView: UIScrollView {
    var simulatesDragging = false
    override var isDragging: Bool { simulatesDragging }
}

private final class StoryReadyFrame: NSObject {
    @objc let isMainFrame: Bool
    init(mainFrame: Bool) { isMainFrame = mainFrame }
}

private final class StoryReadyAction: NSObject {
    @objc let request: URLRequest
    @objc let sourceFrame: StoryReadyFrame
    init(url: URL, mainFrame: Bool) {
        request = URLRequest(url: url)
        sourceFrame = StoryReadyFrame(mainFrame: mainFrame)
    }
}

private final class HeldStoryScrollQueue: NSObject {
    let started = XCTestExpectation(description: "StoryDetailLoadingTests.swift held the saved-position query")
    private let lock = NSLock()
    private var pending: ((AnyObject) -> Void)?

    @objc(inDatabase:) func inDatabase(_ block: @escaping (AnyObject) -> Void) {
        lock.lock()
        pending = block
        lock.unlock()
        started.fulfill()
    }

    func release() {
        lock.lock()
        let block = pending
        pending = nil
        lock.unlock()
        DispatchQueue.global().async { block?(StoryScrollDatabase()) }
    }
}

private final class StoryScrollDatabase: NSObject {
    @objc(executeQuery:) func executeQuery(_ sql: String) -> StoryScrollCursor { StoryScrollCursor() }
}

private final class ImmediateStoryScrollQueue: NSObject {
    @objc(inDatabase:) func inDatabase(_ block: (AnyObject) -> Void) { block(StoryScrollDatabase()) }
}

private final class StoryScrollCursor: NSObject {
    private var read = false
    @objc func next() -> Bool { defer { read = true }; return !read }
    @objc func resultDictionary() -> NSDictionary { ["scroll": 500, "story_hash": "first"] }
    @objc func close() {}
}

@MainActor private final class RealStoryLoadWebView: WKWebView {
    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        // StoryDetailLoadingTests.swift retains the production HTTPS document origin for real WebKit checks.
        print("STORY_REAL_SUBMISSION length=\(string.count) plain=\(string.contains("Plain WebKit")) full=\(string.contains("Readable article")) trace=\(Thread.callStackSymbols.prefix(8))")
        return super.loadHTMLString(string, baseURL: baseURL ?? URL(string: "https://newsblur.com/"))
    }
}

@MainActor private final class HeldHTTPStoryResource {
    private let listener: NWListener
    private var connections = [ObjectIdentifier: NWConnection]()
    private var pending = [ObjectIdentifier: NWConnection]()
    private let data = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { context in
        UIColor.clear.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    var port: UInt16? {
        guard let value = listener.port?.rawValue, value > 0 else { return nil }
        return value
    }
    var imageURL: String? { port.map { "http://localhost:\($0)/avatar.png" } }
    var pendingCount: Int { pending.count }

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                print("STORY_HTTP_CONNECTION \(connection.endpoint)")
                self.connections[ObjectIdentifier(connection)] = connection
                connection.start(queue: .main)
                self.receiveRequest(connection, received: Data())
            }
        }
        listener.start(queue: .main)
    }

    private func receiveRequest(_ connection: NWConnection, received: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] bytes, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = received
            if let bytes { request.append(bytes) }
            guard error == nil, request.count < 16_384 else { connection.cancel(); return }
            guard let end = request.range(of: Data("\r\n\r\n".utf8)) else {
                if complete { connection.cancel() }
                else { self.receiveRequest(connection, received: request) }
                return
            }
            let headers = String(decoding: request[..<end.upperBound], as: UTF8.self)
            guard headers.hasPrefix("GET /avatar.png HTTP/") else { connection.cancel(); return }
            print("STORY_HELD_HTTP_IMAGE \(self.imageURL ?? "")")
            self.pending[ObjectIdentifier(connection)] = connection
            let response = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: \(self.data.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
        }
    }

    func finish() {
        let waiting = Array(pending.values)
        pending.removeAll()
        for connection in waiting {
            connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    func stop() {
        listener.cancel()
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        pending.removeAll()
    }
}

@MainActor private final class PlainStoryNavigationDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.host == "ios.newsblur.com" ? .cancel : .allow)
    }
}

@MainActor private final class HeldStoryResource: NSObject, WKURLSchemeHandler {
    private var pending = [ObjectIdentifier: WKURLSchemeTask]()
    var pendingCount: Int { pending.count }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard urlSchemeTask.request.url?.host == "resource", urlSchemeTask.request.url?.path == "/avatar.png" else {
            print("STORY_UNEXPECTED_RESOURCE \(urlSchemeTask.request.url?.absoluteString ?? "nil")")
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable))
            return
        }
        print("STORY_HELD_RESOURCE \(urlSchemeTask.request.url?.absoluteString ?? "nil") mime=image/png")
        pending[ObjectIdentifier(urlSchemeTask)] = urlSchemeTask
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        pending.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
    }
    func finish() {
        let tasks = Array(pending.values)
        pending.removeAll()
        let data = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        for task in tasks {
            task.didReceive(URLResponse(url: task.request.url!, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
        }
    }
}
