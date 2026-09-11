import Network
import ObjectiveC.runtime
import UIKit
import WebKit
import SQLite3
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

    func test_webContentProcessReplacementPreparesFontsAgainBeforeCurrentStory() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.web.loads.removeAll()

        fixture.page.webViewWebContentProcessDidTerminate(fixture.web)
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 1)
        XCTAssertTrue(fixture.web.loads.first?.html.contains("data:font/otf;base64,") == true)
        XCTAssertFalse(fixture.web.loads.first?.html.contains("Fixture article") == true)
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.first?.navigation))
        await drainMainQueue()
        XCTAssertEqual(fixture.web.loads.count, 2)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Fixture article body") == true)
    }

    func test_replacedBootstrapCannotReleaseTheNextDocumentsFontGate() async throws {
        let fixture = makeFixture()
        fixture.web.defersAsyncJavaScript = true
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.activeStory = story("second", body: "Latest gated story")
        fixture.page.drawStory()
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        await drainMainQueue()

        XCTAssertEqual(fixture.web.asyncCompletions.count, 2)
        _ = try XCTUnwrap(fixture.web.asyncCompletions.first)
        fixture.web.asyncCompletions.removeFirst()(true, nil)
        XCTAssertEqual(fixture.web.loads.count, 2)
        _ = try XCTUnwrap(fixture.web.asyncCompletions.first)
        fixture.web.asyncCompletions.removeFirst()(true, nil)
        XCTAssertEqual(fixture.web.loads.count, 3)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Latest gated story") == true)
    }

    func test_failedFontPreparationFallsBackWithoutClaimingReadinessOrRetrying() async throws {
        let fixture = makeFixture()
        fixture.web.defersAsyncJavaScript = true
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.first?.navigation))
        let finishFonts = try XCTUnwrap(fixture.web.asyncCompletions.first)

        finishFonts(nil, NSError(domain: "StoryDetailLoadingTests.swift", code: 1))

        XCTAssertEqual(fixture.page.value(forKey: "preparedWebViewFonts") as? Bool, false)
        XCTAssertEqual(fixture.web.loads.count, 2)
        XCTAssertFalse(fixture.web.loads.last?.html.contains("Fixture article body") == true)
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        XCTAssertEqual(fixture.web.loads.count, 3)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Fixture article body") == true)
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        XCTAssertFalse(fixture.web.loads.last?.html.contains("data:font/otf;base64,") == true)
    }

    func test_obsoleteWebKitTerminationCannotClearAReplacementView() async {
        let fixture = makeFixture()
        let replacement = RecordedStoryLoadWebView(frame: fixture.web.frame, configuration: WKWebViewConfiguration())
        fixture.page.webView = replacement

        fixture.page.webViewWebContentProcessDidTerminate(fixture.web)
        await drainMainQueue()

        XCTAssertTrue(replacement.loads.isEmpty)
    }

    func test_idleBootstrapMayFinishAfterColdWebKitStartupAndPrepareLaterReuse() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        let bootstrap = try XCTUnwrap(fixture.web.loads.last?.navigation)
        await delay(1.1)

        XCTAssertEqual(fixture.page.value(forKey: "failedWebViewFontPreparation") as? Bool, false)
        XCTAssertNotNil(fixture.page.value(forKey: "fontWarmupNavigation"))
        fixture.page.webView(fixture.web, didFinish: bootstrap)
        XCTAssertEqual(fixture.page.value(forKey: "preparedWebViewFonts") as? Bool, true)

        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.activeStory = story("adjacent", body: "Later adjacent article")
        fixture.page.drawStory()
        await drainMainQueue()
        XCTAssertEqual(fixture.web.loads.count, 3)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Later adjacent article") == true)
    }

    func test_storyQueuedDuringColdBootstrapGetsItsOwnBoundedWait() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        await delay(1.1)
        fixture.page.drawStory()
        await drainMainQueue()

        XCTAssertEqual(fixture.web.loads.count, 1, "StoryDetailObjCViewController.m measures the fallback deadline from article demand, not idle process startup.")
        await delay(1.1)
        XCTAssertEqual(fixture.web.loads.count, 2)
        XCTAssertFalse(fixture.web.loads.last?.html.contains("Fixture article body") == true)
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        XCTAssertEqual(fixture.web.loads.count, 3)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Fixture article body") == true)
    }

    func test_reusingPageDoesNotApplyTheFormerArticlesBootstrapDeadline() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        let bootstrap = try XCTUnwrap(fixture.web.loads.last?.navigation)
        fixture.page.drawStory()
        await delay(0.6)
        fixture.page.activeStory = story("second", body: "Latest waiting article")
        fixture.page.drawStory()
        await delay(0.55)

        XCTAssertEqual(fixture.page.value(forKey: "failedWebViewFontPreparation") as? Bool, false)
        XCTAssertEqual(fixture.web.loads.count, 1)
        fixture.page.webView(fixture.web, didFinish: bootstrap)
        XCTAssertTrue(fixture.web.loads.last?.html.contains("Latest waiting article") == true)
        XCTAssertEqual(fixture.web.loads.count, 2)
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

    func test_elapsedRevealDelayDoesNotExposeAnUnreadyArticle() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let token = try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html)
        await delay(0.15)

        XCTAssertTrue(fixture.web.isHidden, "Submitting HTML and waiting 100 ms does not establish a drawable article")
        sendReady(to: fixture.page, token: token, mainFrame: true)
        await delay(0.15)
        XCTAssertFalse(fixture.web.isHidden, "The current ready article must still become visible")
    }

    func test_staleDOMReadinessDoesNotExposeAReplacementArticle() async throws {
        let fixture = makeFixture()
        fixture.page.perform(NSSelectorFromString("clearWebView"))
        fixture.page.webView(fixture.web, didFinish: try XCTUnwrap(fixture.web.loads.last?.navigation))
        fixture.page.drawStory()
        await drainMainQueue()
        let previous = try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html)
        fixture.page.clearStory()
        fixture.page.activeStory = story("second", body: "Latest body")
        fixture.page.drawStory()
        await drainMainQueue()
        let current = try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html)

        sendReady(to: fixture.page, token: previous, mainFrame: true)
        sendReady(to: fixture.page, token: current, mainFrame: false)
        await delay(0.15)
        XCTAssertTrue(fixture.web.isHidden, "Only the current main-frame document may release presentation")
        sendReady(to: fixture.page, token: current, mainFrame: true)
        await delay(0.15)
        XCTAssertFalse(fixture.web.isHidden)
    }

    func test_actualWebKitDoesNotRevealWhileTheArticleParserIsBlocked() async throws {
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        let page = makePage(web: web)
        page.allowsAppearanceCallbacks = false
        page.activeStory = story("blocked-parser", body: "<p>Article must exist before it becomes visible.</p>")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = web.frame
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(web)
        window.makeKeyAndVisible()
        let parser = HeldStoryParser()
        defer {
            parser.release()
            window.isHidden = true
            previousKeyWindow?.makeKey()
            page.webView = nil
        }
        web.navigationDelegate = page
        page.perform(NSSelectorFromString("clearWebView"))
        for _ in 0..<60 where page.value(forKey: "preparedWebViewFonts") as? Bool != true { await delay(0.05) }
        XCTAssertEqual(page.value(forKey: "preparedWebViewFonts") as? Bool, true)
        // StoryDetailLoadingTests.swift pauses the actual parser via its UI delegate, without a visible dialog or mixed-content request.
        web.uiDelegate = parser
        web.configuration.userContentController.addUserScript(WKUserScript(source: "alert('hold-article-parser');", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let ready = expectation(description: "The unblocked current article completes DOM preparation")
        page.readyObserver = { ready.fulfill() }
        page.drawStory()
        for _ in 0..<60 where !parser.isHeld { await delay(0.05) }
        XCTAssertTrue(parser.isHeld)
        await delay(0.15)
        XCTAssertTrue(web.isHidden, "The real WKWebView must not expose its blank, unfinished document")

        parser.release()
        await fulfillment(of: [ready], timeout: 5)
        await delay(0.15)
        XCTAssertFalse(web.isHidden)
        let body = try await web.evaluateJavaScript("document.querySelector('#NB-story').textContent") as? String
        XCTAssertTrue(body?.contains("Article must exist") == true)
    }

    func test_nativeSelectionKeepsCurrentArticleUntilSelectedDocumentIsPrepared() async throws {
        let fixture = makePresentationFixture()
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()

        XCTAssertTrue(fixture.pages.currentPage === fixture.original)
        XCTAssertEqual(fixture.pages.pageChanges, [])
        XCTAssertEqual(fixture.app.presentations, 0)
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        sendReady(to: selected, token: token, mainFrame: true)
        await delay(0.1)

        XCTAssertTrue(fixture.pages.currentPage === selected)
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-3")
        XCTAssertEqual(fixture.pages.pageChanges, [1], "Native navigation takes the visible location, not raw index 3")
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertEqual(fixture.pages.hiddenAtNavigation, [false])
        XCTAssertEqual(fixture.pages.unreadyAtNavigation, [false])
    }

    func test_rapidNativeSelectionsOnlyPresentLatestDocument() async throws {
        let fixture = makePresentationFixture()
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let old = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
        await drainMainQueue()
        let latest = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        sendReady(to: selected, token: old, mainFrame: true)
        await drainMainQueue()
        XCTAssertEqual(fixture.app.presentations, 0)
        XCTAssertTrue(fixture.pages.currentPage === fixture.original)
        sendReady(to: selected, token: latest, mainFrame: true)
        await delay(0.1)
        XCTAssertEqual(fixture.pages.pageChanges, [2])
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-9")
        XCTAssertEqual(fixture.app.presentations, 1)
    }

    func test_returnToFeedsCancelsNativePresentationAndReleasesStagingView() async throws {
        let fixture = makePresentationFixture()
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        fixture.app.showFeedsList(animated: false)
        sendReady(to: selected, token: token, mainFrame: true)
        await delay(0.1)
        XCTAssertEqual(fixture.app.presentations, 0)
        XCTAssertTrue(fixture.pages.currentPage === fixture.original)
        XCTAssertNil(fixture.pages.value(forKey: "storyPreparationHost"))
        XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationCompletion"))
    }

    func test_changedFeedRequestCannotPresentAnOldPreparedArticle() async throws {
        let fixture = makePresentationFixture()
        let feed = FeedDetailViewController()
        fixture.app.testFeed = feed
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        feed.fetchRequestId += 1
        sendReady(to: selected, token: token, mainFrame: true)
        await delay(0.1)
        XCTAssertEqual(fixture.app.presentations, 0)
        XCTAssertTrue(fixture.pages.currentPage === fixture.original)
        XCTAssertNil(fixture.pages.value(forKey: "storyPreparationHost"))
    }

    func test_preparationUsesTargetViewportAndRechecksGeometryBeforeNativePresentation() async throws {
        for width: CGFloat in [375, 390, 768] {
            let fixture = makePresentationFixture(width: width)
            fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
            await drainMainQueue()
            let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
            let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
            XCTAssertEqual(web.bounds.width, width)
            let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
            web.defersAsyncJavaScript = true
            sendReady(to: selected, token: token, mainFrame: true)
            await drainMainQueue()
            XCTAssertEqual(fixture.app.presentations, 0)
            XCTAssertFalse(web.asyncCompletions.isEmpty)
            fixture.pages.scrollView.frame.size.width = width - 20
            let completion = try XCTUnwrap(web.asyncCompletions.first)
            web.asyncCompletions.removeFirst()
            completion(true, nil)
            XCTAssertEqual(fixture.app.presentations, 0, "An obsolete viewport must not release native presentation")
            for _ in 0..<4 where !web.asyncCompletions.isEmpty {
                web.asyncCompletions.removeFirst()(true, nil)
                await drainMainQueue()
            }
            XCTAssertEqual(web.bounds.width, width - 20)
            XCTAssertEqual(fixture.app.presentations, 1)
            XCTAssertEqual(fixture.pages.unreadyAtNavigation, [false])
        }
    }

    func test_stagedArticleSurvivesNeighborRelayoutWithoutBeingReplacedOrMoved() async throws {
        let fixture = makePresentationFixture()
        fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let originalFrame = selected.view.frame
        fixture.pages.applyNewIndex(1, pageController: selected)
        XCTAssertEqual(selected.activeStoryId, "item-9")
        XCTAssertEqual(selected.pageIndex, 2)
        XCTAssertEqual(selected.view.frame, originalFrame)
        fixture.pages.cancelPendingStoryPresentation()
    }

    func test_explicitNextOrSwipeCancelsStagedSelectionBeforeNormalPageNavigation() throws {
        // StoryDetailLoadingTests.swift keeps Objective-C navigation exceptions visible to synchronous XCTest.
        func settle() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }
        for swipe in [false, true] {
            let fixture = makePresentationFixture()
            fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
            settle()
            let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
            let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
            let stale = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
            XCTAssertEqual(selected.pageIndex, 2)
            if swipe {
                fixture.pages.scrollViewWillBeginDragging(fixture.pages.scrollView)
                let bounds = fixture.pages.scrollView.bounds
                fixture.pages.scrollView.contentOffset = fixture.pages.isHorizontal ? CGPoint(x: bounds.width, y: 0) : CGPoint(x: 0, y: bounds.height)
                fixture.pages.scrollViewDidScroll(fixture.pages.scrollView)
                XCTAssertEqual(fixture.pages.currentPage.pageIndex, 1)
                XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-3")
            } else {
                fixture.pages.changeToNextPage(nil)
                XCTAssertEqual(fixture.pages.pageChanges, [1])
            }
            XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationCompletion"))
            XCTAssertNil(fixture.pages.value(forKey: "storyPreparationHost"))
            XCTAssertTrue(selected.view.superview === fixture.pages.scrollView)
            settle()
            sendReady(to: selected, token: stale, mainFrame: true)
            settle()
            XCTAssertEqual(fixture.app.presentations, 0)
        }
    }

    func test_failedSelectedNavigationReleasesStagingAndCanBeRetried() async throws {
        for provisional in [false, true] {
            let fixture = makePresentationFixture()
            fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
            await drainMainQueue()
            let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
            let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
            let failed = try XCTUnwrap(web.loads.last?.navigation)
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotLoadFromNetwork)
            if provisional { selected.webView(web, didFailProvisionalNavigation: failed, withError: error) }
            else { selected.webView(web, didFail: failed, withError: error) }
            XCTAssertEqual(fixture.app.presentations, 0)
            XCTAssertTrue(fixture.pages.currentPage === fixture.original)
            XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationCompletion"))
            XCTAssertNil(fixture.pages.value(forKey: "storyPreparationHost"))
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
            await drainMainQueue()
            // StoryDetailLoadingTests.swift rejects the earlier navigation failure during the fresh retry.
            selected.webView(web, didFail: failed, withError: error)
            XCTAssertNotNil(fixture.pages.value(forKey: "pendingPresentationCompletion"))
            sendReady(to: selected, token: try tokenFromHTML(XCTUnwrap(web.loads.last).html), mainFrame: true)
            await delay(0.1)
            XCTAssertEqual(fixture.app.presentations, 1)
        }
    }

    func test_stagedPhoneUsesItsActualWindowSafeAreaBeforeNativePresentation() async throws {
        let fixture = makePresentationFixture(width: 375)
        fixture.pages.storyToolbar = StoryToolbar()
        fixture.pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        fixture.pages.toolbarScrollHandler.setOffset(44)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = StoryPresentationWindow(windowScene: scene)
        let navigation = UINavigationController(rootViewController: UIViewController())
        fixture.app.feedsNavigationController = navigation
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer {
            fixture.pages.cancelPendingStoryPresentation()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        XCTAssertNil(fixture.pages.view.window)
        XCTAssertTrue(selected.webView.window === window)
        XCTAssertEqual(fixture.pages.toolbarScrollHandler.toolbarOffset, 0)
        XCTAssertEqual(selected.webView.scrollView.contentInset.top, 64, accuracy: 0.5)
    }

    func test_restorationJavaScriptErrorDoesNotStrandCurrentDocumentPresentation() async throws {
        let fixture = makePresentationFixture()
        fixture.app.setValue(ImmediateStoryScrollQueue(hasSavedPosition: false), forKey: "database")
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        web.defersAsyncJavaScript = true
        sendReady(to: selected, token: token, mainFrame: true)
        for _ in 0..<30 where web.asyncCompletions.isEmpty { await drainMainQueue() }
        let restore = try XCTUnwrap(web.asyncCompletions.first)
        web.asyncCompletions.removeFirst()
        restore(nil, NSError(domain: WKErrorDomain, code: WKError.javaScriptExceptionOccurred.rawValue))
        XCTAssertEqual(selected.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
        XCTAssertEqual(fixture.app.presentations, 0)
        let render = try XCTUnwrap(web.asyncCompletions.first)
        web.asyncCompletions.removeFirst()
        render(true, nil)
        XCTAssertEqual(fixture.app.presentations, 1)
    }

    func test_firstFolderArticleKeepsPreparedInsetThroughNativeHandoff() async throws {
        try await assertFirstArticleInsetThroughNativeHandoff(isRiver: true)
    }

    func test_firstSingleFeedArticleKeepsPreparedInsetThroughNativeHandoff() async throws {
        try await assertFirstArticleInsetThroughNativeHandoff(isRiver: false)
    }

    func test_savedReadingPositionSurvivesTheDetachedNativeHandoff() async throws {
        try await assertFirstArticleInsetThroughNativeHandoff(isRiver: false, savedPosition: 100)
    }

    func test_hiddenToolbarKeepsItsOffsetThroughTheDetachedNativeHandoff() async throws {
        try await assertFirstArticleInsetThroughNativeHandoff(isRiver: true, toolbarOffset: 44)
    }

    func test_attachedArticleWindowTakesPriorityOverThePresentingNavigationWindow() throws {
        let fixture = makePresentationFixture(width: 375)
        fixture.pages.storyToolbar = StoryToolbar()
        fixture.pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let articleWindow = StoryPresentationWindow(windowScene: scene)
        let sourceWindow = StoryPresentationWindow(windowScene: scene)
        sourceWindow.testSafeAreaTop = 47
        let navigation = UINavigationController(rootViewController: UIViewController())
        fixture.app.feedsNavigationController = navigation
        sourceWindow.rootViewController = navigation
        sourceWindow.isHidden = false
        articleWindow.rootViewController = fixture.pages
        articleWindow.makeKeyAndVisible()
        defer {
            articleWindow.isHidden = true
            sourceWindow.isHidden = true
            previousKeyWindow?.makeKey()
        }
        XCTAssertTrue(fixture.pages.view.window === articleWindow)
        XCTAssertTrue(navigation.view.window === sourceWindow)
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 1), 64, accuracy: 0.5)
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 0), 64, accuracy: 0.5)
        articleWindow.testSafeAreaTop = 24
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 1), 68, accuracy: 0.5)
    }

    private func assertFirstArticleInsetThroughNativeHandoff(isRiver: Bool, savedPosition: Int? = nil, toolbarOffset: CGFloat = 0) async throws {
        let fixture = makePresentationFixture(width: 375)
        fixture.app.storiesCollection.isRiverView = isRiver
        fixture.pages.storyToolbar = StoryToolbar()
        fixture.pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        fixture.pages.runsActualPageChanges = true
        fixture.app.setValue(ImmediateStoryScrollQueue(hasSavedPosition: savedPosition != nil, position: savedPosition ?? 0), forKey: "database")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = StoryPresentationWindow(windowScene: scene)
        let navigation = UINavigationController(rootViewController: UIViewController())
        fixture.app.feedsNavigationController = navigation
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer {
            fixture.pages.cancelPendingStoryPresentation()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }

        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.nextPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        XCTAssertEqual(web.scrollView.contentInset.top, 64, accuracy: 0.5)
        fixture.pages.toolbarScrollHandler.setOffset(toolbarOffset)
        sendReady(to: selected, token: try tokenFromHTML(XCTUnwrap(web.loads.last).html), mainFrame: true)
        for _ in 0..<60 where fixture.app.presentations == 0 { await delay(0.02) }

        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertTrue(fixture.pages.currentPage === selected)
        XCTAssertNil(selected.webView.window)
        XCTAssertNotNil(navigation.view.window)
        print("FIRST_ARTICLE_HANDOFF river=\(isRiver) inset=\(web.scrollView.contentInset.top) offset=\(web.scrollView.contentOffset.y) resolved=\(fixture.pages.topInset(forNavigationBarAlpha: 1))")
        // StoryDetailLoadingTests.swift exercises the real page change after WebKit leaves its preparation host, before the native push attaches the controller.
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 1), 64, accuracy: 0.5)
        XCTAssertEqual(web.scrollView.contentInset.top, 64, accuracy: 0.5)
        let expectedOffset = savedPosition.map { floor(CGFloat($0) / 1000 * web.scrollView.contentSize.height) } ?? (-64 + toolbarOffset)
        XCTAssertEqual(web.scrollView.contentOffset.y, expectedOffset, accuracy: 0.5)
        XCTAssertEqual(fixture.pages.toolbarScrollHandler.toolbarOffset, toolbarOffset, accuracy: 0.5)
    }

    func test_realWebKitPaintsStagedArticleBeforeNativePushWhileImageIsPending() async throws {
        let resource = try HeldHTTPStoryResource()
        for _ in 0..<60 where resource.port == nil { await delay(0.05) }
        let imageURL = try XCTUnwrap(resource.imageURL)
        let fixture = makePresentationFixture()
        let collection = fixture.app.storiesCollection
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        let page = makePage(web: web, app: fixture.app)
        fixture.app.storiesCollection = collection
        page.allowsAppearanceCallbacks = false
        page.shareHTML = "<img src='\(imageURL)' width='30' height='30'>"
        fixture.stories[3]["story_content"] = String(repeating: "<p>Readable prepared article paragraph.</p>", count: 150)
        fixture.pages.nextPage.willMove(toParent: nil)
        fixture.pages.nextPage.view.removeFromSuperview()
        fixture.pages.nextPage.removeFromParent()
        fixture.pages.nextPage = page
        fixture.pages.addChild(page)
        fixture.pages.scrollView.addSubview(page.view)
        page.didMove(toParent: fixture.pages)
        web.navigationDelegate = page
        page.perform(NSSelectorFromString("clearWebView"))
        for _ in 0..<60 where page.value(forKey: "preparedWebViewFonts") as? Bool != true { await delay(0.05) }
        XCTAssertEqual(page.value(forKey: "preparedWebViewFonts") as? Bool, true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let titles = UIViewController()
        titles.view.backgroundColor = .magenta
        let navigation = UINavigationController(rootViewController: titles)
        fixture.app.feedsNavigationController = navigation
        fixture.pages.navigationForPresentation = navigation
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer {
            fixture.pages.cancelPendingStoryPresentation()
            resource.stop()
            window.isHidden = true
            previousKeyWindow?.makeKey()
            page.webView = nil
        }
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        for _ in 0..<100 where fixture.app.presentations == 0 { await delay(0.02) }
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertTrue(navigation.topViewController === fixture.pages)
        XCTAssertGreaterThan(resource.pendingCount, 0)
        XCTAssertTrue(fixture.pages.currentPage === page)
        XCTAssertEqual(fixture.pages.unreadyAtNavigation, [false])
        // StoryDetailLoadingTests.swift captures the actual native push, with the controlled remote image still held.
        await delay(0.1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Prepared article during native push with pending image"
        attachment.lifetime = .keepAlways
        add(attachment)
        let hasBody = try await web.evaluateJavaScript("document.querySelector('#NB-story').textContent.includes('Readable prepared')") as? Bool
        XCTAssertEqual(hasBody, true)
        let paint = try await web.evaluateJavaScript("JSON.stringify({paint:performance.getEntriesByType('paint'),width:window.innerWidth,body:document.body.scrollHeight})")
        print("STORY_PREPARED_NATIVE_PUSH \(paint)")
    }

    private func makePresentationFixture(width: CGFloat = 390) -> (app: StoryPresentationApp, pages: StoryPresentationPages, original: StoryLoadPage, stories: [NSMutableDictionary]) {
        let app = StoryPresentationApp()
        let pages = StoryPresentationPages()
        pages.appDelegate = app
        app.storyPagesViewController = pages
        app.detailViewController = StoryPresentationDetail()
        let allPages = (0..<3).map { _ -> StoryLoadPage in
            let page = makeFixture(app: app).page
            page.allowsAppearanceCallbacks = false
            page.setValue(true, forKey: "preparedWebViewFonts")
            return page
        }
        let stories = (0..<10).map { story("item-\($0)", body: "Article \($0)") }
        app.storiesCollection.activeFeedStories = stories
        app.storiesCollection.storyCount = Int32(stories.count)
        app.storiesCollection.storyLocationsCount = 3
        app.storiesCollection.activeFeedStoryLocationIds = NSMutableArray(array: ["item-0", "item-3", "item-9"])
        app.storiesCollection.activeFeedStoryLocations = NSMutableArray(array: [0, 3, 9])
        app.activeStory = stories[0] as? [AnyHashable: Any]
        pages.loadViewIfNeeded()
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: width, height: 844))
        pages.scrollView.contentSize = CGSize(width: width * 3, height: 844 * 3)
        pages.view.addSubview(pages.scrollView)
        pages.currentPage = allPages[0]
        pages.nextPage = allPages[1]
        pages.previousPage = allPages[2]
        for (index, page) in allPages.enumerated() {
            page.pageIndex = index == 0 ? 0 : -2
            pages.addChild(page)
            pages.scrollView.addSubview(page.view)
            page.didMove(toParent: pages)
        }
        allPages[0].activeStory = stories[0]
        allPages[0].activeStoryId = "item-0"
        allPages[0].hasStory = true
        allPages[0].webView.isHidden = false
        return (app, pages, allPages[0], stories)
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
        let initial = try tokenFromHTML(try XCTUnwrap(fixture.web.loads.first?.html))
        sendReady(to: fixture.page, token: initial, mainFrame: true)
        // StoryDetailLoadingTests.swift models a visible Text/RSS redraw covered by a modal before the replacement DOM finishes.
        fixture.page.drawStory()
        await drainMainQueue()
        let replacement = try tokenFromHTML(try XCTUnwrap(fixture.web.loads.last?.html))
        XCTAssertFalse(fixture.web.isHidden)
        fixture.page.viewWillDisappear(false)
        fixture.page.viewWillAppear(false)
        sendReady(to: fixture.page, token: replacement, mainFrame: true)

        XCTAssertEqual(fixture.page.classifierUpdates, 2)
        XCTAssertEqual(fixture.web.loads.count, 2)
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

    func test_zeroOrMissingSavedPositionStartsBelowTheActualToolbarAcrossReadyTiming() async throws {
        for savedPosition in [Int?.none, 0] {
            for toolbarOffset: CGFloat in [0, 44] {
                for readyBeforeReveal in [false, true] {
                    let app = StoryLoadAppDelegate()
                    let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
                    app.testPages = pages
                    defer { app.testPages = nil }
                    pages.appDelegate = app
                    pages.storyToolbar = StoryToolbar()
                    pages.toolbarScrollHandler = StoryToolbarScrollHandler()
                    pages.toolbarScrollHandler.setOffset(toolbarOffset)
                    app.setValue(ImmediateStoryScrollQueue(hasSavedPosition: savedPosition != nil,
                                                          position: savedPosition ?? 0), forKey: "database")
                    let fixture = makeFixture(app: app)
                    pages.currentPage = fixture.page
                    fixture.page.drawStory()
                    await drainMainQueue()
                    fixture.page.viewWillAppear(false)
                    let topRest = -fixture.web.scrollView.adjustedContentInset.top + toolbarOffset
                    XCTAssertLessThan(topRest, 0)
                    // StoryDetailLoadingTests.swift models the new WK document resetting its native offset after appearance.
                    fixture.web.scrollView.contentOffset = .zero
                    let token = try tokenFromHTML(try XCTUnwrap(fixture.web.loads.last?.html))
                    if !readyBeforeReveal { await delay(0.15) }
                    sendReady(to: fixture.page, token: token, mainFrame: true)
                    await delay(0.2)

                    XCTAssertEqual(fixture.web.scrollView.contentOffset.y, topRest, accuracy: 0.5,
                                   "saved=\(String(describing: savedPosition)) toolbar=\(toolbarOffset) earlyReady=\(readyBeforeReveal)")
                }
            }
        }
    }

    func test_realWebKitReopenAtSavedZeroPreservesTheVisibleHeaderCoordinates() async throws {
        let app = StoryLoadAppDelegate()
        let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
        app.testPages = pages
        defer { app.testPages = nil }
        pages.appDelegate = app
        pages.storyToolbar = StoryToolbar()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        app.setValue(ImmediateStoryScrollQueue(position: 0), forKey: "database")
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        let page = makePage(web: web, app: app)
        pages.currentPage = page
        page.allowsAppearanceCallbacks = false
        page.activeStory = story("first", body: String(repeating: "<p>Reading from the exact beginning.</p>", count: 150))
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = page
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pages
        pages.view.addSubview(page.view)
        pages.view.addSubview(pages.storyToolbar)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKeyWindow?.makeKey(); page.webView = nil }
        page.perform(NSSelectorFromString("clearWebView"))
        for _ in 0..<60 where page.value(forKey: "preparedWebViewFonts") as? Bool != true { await delay(0.05) }
        XCTAssertEqual(page.value(forKey: "preparedWebViewFonts") as? Bool, true)

        let firstReady = expectation(description: "Initial real document is ready")
        page.readyObserver = { firstReady.fulfill() }
        page.drawStory()
        await fulfillment(of: [firstReady], timeout: 5)
        await delay(0.2)
        XCTAssertTrue(requestScrollToTop(on: page))
        let expectedOffset = -web.scrollView.adjustedContentInset.top
        web.scrollView.setContentOffset(CGPoint(x: 0, y: expectedOffset), animated: false)
        await delay(0.05)
        let before = try await web.evaluateJavaScript("document.querySelector('h1').getBoundingClientRect().top")
        XCTAssertLessThan(expectedOffset, 0)

        let reopenedReady = expectation(description: "Reopened real document is ready")
        page.readyObserver = { reopenedReady.fulfill() }
        let finishedBeforeClear = page.finishedNavigations
        page.clearStory()
        // StoryDetailLoadingTests.swift lets the back-navigation blank document finish before reopening.
        for _ in 0..<60 where page.finishedNavigations == finishedBeforeClear { await delay(0.05) }
        XCTAssertGreaterThan(page.finishedNavigations, finishedBeforeClear)
        print("STORY_TOP_CLEARED native=\(web.scrollView.contentOffset.y) inset=\(web.scrollView.adjustedContentInset.top)")
        page.drawStory()
        await drainMainQueue()
        page.allowsAppearanceCallbacks = true
        page.viewWillAppear(false)
        page.allowsAppearanceCallbacks = false
        await fulfillment(of: [reopenedReady], timeout: 5)
        await delay(0.2)
        let after = try await web.evaluateJavaScript("document.querySelector('h1').getBoundingClientRect().top")
        print("STORY_TOP_REOPEN before_native=\(expectedOffset) after_native=\(web.scrollView.contentOffset.y) inset=\(web.scrollView.adjustedContentInset.top) toolbar=\(pages.toolbarScrollHandler.toolbarOffset) before_header=\(before) after_header=\(after)")
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Reopened article at saved zero with custom toolbar"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(web.scrollView.contentOffset.y, expectedOffset, accuracy: 0.5)
        XCTAssertEqual(after as? Double, before as? Double)
    }

    func test_zeroPositionWaitingForLayoutCannotOverrideKeyboardScrollOrPageReuse() async throws {
        for reusesPage in [false, true] {
            let app = StoryLoadAppDelegate()
            app.setValue(ImmediateStoryScrollQueue(position: 0), forKey: "database")
            let fixture = makeFixture(app: app)
            fixture.page.drawStory()
            await delay(0.15)
            fixture.web.defersAsyncJavaScript = true
            restoreScroll(on: fixture.page)
            for _ in 0..<40 where fixture.web.asyncCompletions.isEmpty { await delay(0.01) }
            let completeLayout = try XCTUnwrap(fixture.web.asyncCompletions.first)

            if reusesPage {
                fixture.page.activeStory = story("replacement", body: "Replacement document")
                fixture.page.drawStory()
                await drainMainQueue()
                fixture.web.scrollView.contentOffset.y = 300
            } else {
                fixture.page.scrollPageDown(nil)
            }
            let currentOffset = fixture.web.scrollView.contentOffset.y
            XCTAssertGreaterThan(currentOffset, 0)
            completeLayout(true, nil)

            XCTAssertEqual(fixture.web.scrollView.contentOffset.y, currentOffset)
        }
    }

    func test_realScrollPositionWriterRoundTripsTopSentinelAndPositiveProgress() async throws {
        for position in [0, 1, 2, 500] {
            let app = StoryLoadAppDelegate()
            let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
            app.testPages = pages
            defer { app.testPages = nil }
            pages.appDelegate = app
            pages.storyToolbar = StoryToolbar()
            pages.toolbarScrollHandler = StoryToolbarScrollHandler()
            let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("story-scroll-\(UUID().uuidString).sqlite")
            var connection: OpaquePointer?
            XCTAssertEqual(sqlite3_open(databaseURL.path, &connection), SQLITE_OK)
            XCTAssertEqual(sqlite3_exec(connection, "CREATE TABLE story_scrolls (story_feed_id INTEGER, story_hash TEXT, story_timestamp INTEGER, scroll INTEGER)", nil, nil, nil), SQLITE_OK)
            let database = try XCTUnwrap(FMDatabaseQueue(path: databaseURL.path))
            defer { database.close(); sqlite3_close(connection); try? FileManager.default.removeItem(at: databaseURL) }
            app.setValue(database, forKey: "database")
            let fixture = makeFixture(app: app)
            pages.currentPage = fixture.page
            fixture.page.activeStory["story_timestamp"] = 1_700_000_000

            // NewsBlurAppDelegate.m encodes a stored top as one; use its real SQLite writer instead of a position spy.
            app.markScrollPosition(position, inStory: fixture.page.activeStory as? [AnyHashable: Any])
            var stored: Int?
            for _ in 0..<100 where stored == nil {
                var statement: OpaquePointer?
                XCTAssertEqual(sqlite3_prepare_v2(connection, "SELECT scroll FROM story_scrolls", -1, &statement, nil), SQLITE_OK)
                if sqlite3_step(statement) == SQLITE_ROW { stored = Int(sqlite3_column_int(statement, 0)) }
                sqlite3_finalize(statement)
                if stored == nil { await delay(0.01) }
            }
            XCTAssertEqual(stored, max(1, position))
            fixture.page.drawStory()
            await delay(0.15)
            fixture.page.viewWillAppear(false)
            fixture.web.scrollView.contentOffset = .zero
            restoreScroll(on: fixture.page)
            for _ in 0..<100 where fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == true { await delay(0.01) }

            let expected = position <= 1 ? -fixture.web.scrollView.adjustedContentInset.top : floor(CGFloat(position) / 1000 * fixture.web.scrollView.contentSize.height)
            XCTAssertEqual(fixture.web.scrollView.contentOffset.y, expected, accuracy: 0.5, "input=\(position), persisted=\(String(describing: stored))")
        }
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

    func test_firstPaintCallbackCannotRestoreAReusedPage() async throws {
        let fixture = makeFixture()
        fixture.app.setValue(ImmediateStoryScrollQueue(), forKey: "database")
        fixture.web.defersAsyncJavaScript = true
        fixture.page.drawStory()
        await drainMainQueue()
        restoreScroll(on: fixture.page)
        for _ in 0..<60 where fixture.web.asyncCompletions.isEmpty { await delay(0.01) }
        let complete = try XCTUnwrap(fixture.web.asyncCompletions.first)

        fixture.page.activeStory = story("second", body: "New article before the old native frame arrives")
        fixture.page.drawStory()
        fixture.web.scrollView.contentOffset = .zero
        complete(true, nil)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 0)
    }

    func test_disappearingAtZeroOffsetCannotOverwriteAPendingSavedPosition() async throws {
        let app = StoryScrollStoreAppDelegate()
        let fixture = makeFixture(app: app)
        let database = HeldStoryScrollQueue()
        app.setValue(database, forKey: "database")
        fixture.page.recordsPosition = true
        fixture.page.drawStory()
        await drainMainQueue()
        sendReady(to: fixture.page, token: try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html), mainFrame: true)
        fixture.web.scrollView.contentInset = .zero
        fixture.web.scrollView.contentOffset = .zero
        await fulfillment(of: [database.started], timeout: 2)

        fixture.page.viewWillDisappear(false)
        await delay(0.05)
        XCTAssertTrue(app.positions.isEmpty)

        database.release()
        await delay(0.05)
        fixture.page.viewWillDisappear(false)
        await delay(0.05)
        XCTAssertEqual(app.positions, [500])
    }

    func test_keyboardScrollCancelsPendingRestorationAndStillStoresProgress() async {
        for up in [false, true] {
            let app = StoryScrollStoreAppDelegate()
            let fixture = makeFixture(app: app)
            let database = HeldStoryScrollQueue()
            app.setValue(database, forKey: "database")
            fixture.page.recordsPosition = true
            fixture.page.drawStory()
            await delay(0.15)
            fixture.web.scrollView.contentInset = .zero
            fixture.web.scrollView.contentOffset = CGPoint(x: 0, y: up ? 1_600 : 0)
            restoreScroll(on: fixture.page)
            await fulfillment(of: [database.started], timeout: 2)

            if up { fixture.page.scrollPageUp(nil) }
            else { fixture.page.scrollPageDown(nil) }
            let keyboardPosition = fixture.web.scrollView.contentOffset.y
            fixture.page.viewWillDisappear(false)
            await delay(0.05)
            XCTAssertEqual(app.positions, [Int(floor(keyboardPosition / 5_000 * 1_000))])
            database.release()
            await delay(0.05)
            XCTAssertEqual(fixture.web.scrollView.contentOffset.y, keyboardPosition)
        }
    }

    func test_freshStoryWithoutSavedPositionRecordsKeyboardProgress() async {
        let app = StoryScrollStoreAppDelegate()
        let fixture = makeFixture(app: app)
        app.setValue(ImmediateStoryScrollQueue(hasSavedPosition: false), forKey: "database")
        fixture.page.recordsPosition = true
        fixture.page.drawStory()
        await delay(0.15)
        restoreScroll(on: fixture.page)
        await delay(0.05)

        fixture.page.scrollPageDown(nil)
        let keyboardPosition = fixture.web.scrollView.contentOffset.y
        fixture.page.viewWillDisappear(false)
        await delay(0.05)

        XCTAssertGreaterThan(keyboardPosition, 0)
        XCTAssertEqual(app.positions, [Int(floor(keyboardPosition / 5_000 * 1_000))])
    }

    func test_statusBarScrollToInsetTopStoresZeroAndClearsTheOldRestorationFraction() async {
        let app = StoryScrollStoreAppDelegate()
        let fixture = makeFixture(app: app)
        app.setValue(ImmediateStoryScrollQueue(), forKey: "database")
        fixture.page.recordsPosition = true
        fixture.page.drawStory()
        await delay(0.15)
        restoreScroll(on: fixture.page)
        await delay(0.05)
        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 2_500)
        fixture.web.scrollView.contentInset.top = 64

        XCTAssertTrue(requestScrollToTop(on: fixture.page))
        fixture.web.scrollView.contentOffset.y = -fixture.web.scrollView.adjustedContentInset.top
        fixture.page.viewWillDisappear(false)
        await delay(0.05)

        XCTAssertEqual(app.positions, [0])
        XCTAssertEqual(fixture.page.value(forKey: "scrollPct") as? Double, 0)
    }

    func test_statusBarTopCancelsAnOutstandingSavedPositionRead() async {
        let app = StoryScrollStoreAppDelegate()
        let fixture = makeFixture(app: app)
        let database = HeldStoryScrollQueue()
        app.setValue(database, forKey: "database")
        fixture.page.recordsPosition = true
        fixture.page.drawStory()
        await delay(0.15)
        restoreScroll(on: fixture.page)
        await fulfillment(of: [database.started], timeout: 2)
        fixture.web.scrollView.contentInset.top = 64

        XCTAssertTrue(requestScrollToTop(on: fixture.page))
        fixture.web.scrollView.contentOffset.y = -64
        fixture.page.viewWillDisappear(false)
        database.release()
        await delay(0.05)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, -64)
        XCTAssertEqual(app.positions, [0])
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
    }

    func test_statusBarTopCancelsSavedRestorationWaitingForNativeLayout() async throws {
        let fixture = makeFixture()
        fixture.app.setValue(ImmediateStoryScrollQueue(), forKey: "database")
        fixture.web.defersAsyncJavaScript = true
        fixture.page.drawStory()
        await delay(0.15)
        restoreScroll(on: fixture.page)
        for _ in 0..<60 where fixture.web.asyncCompletions.isEmpty { await delay(0.01) }
        let complete = try XCTUnwrap(fixture.web.asyncCompletions.first)
        fixture.web.scrollView.contentInset.top = 64

        XCTAssertTrue(requestScrollToTop(on: fixture.page))
        fixture.web.scrollView.contentOffset.y = -64
        complete(true, nil)

        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, -64)
        XCTAssertEqual(fixture.page.value(forKey: "scrollPct") as? Double, 0)
    }

    func test_queuedPositionAfterStatusBarTopStoresZeroOnlyForTheSameDocument() async {
        for reusesPage in [false, true] {
            let app = StoryScrollStoreAppDelegate()
            let fixture = makeFixture(app: app)
            fixture.page.activeStory = story("status-top-queue-\(reusesPage)", body: "Queued article")
            fixture.page.recordsPosition = true
            fixture.page.drawStory()
            await delay(0.15)
            fixture.page.setValue(true, forKey: "hasScrolled")
            fixture.web.scrollView.contentOffset.y = 2_500
            fixture.page.ignorePositionStorage(true)

            XCTAssertTrue(requestScrollToTop(on: fixture.page))
            fixture.web.scrollView.contentInset.top = 64
            fixture.web.scrollView.contentOffset.y = -64
            if reusesPage {
                fixture.page.activeStory = story("replacement", body: "Replacement article")
                fixture.page.drawStory()
                await drainMainQueue()
                fixture.web.scrollView.contentOffset.y = 1_000
            }
            await delay(2.1)

            XCTAssertEqual(app.positions, reusesPage ? [] : [0])
        }
    }

    func test_completedStatusBarTopPersistsBeforeLeavingAndRejectsAReusedPage() async {
        for reusesPage in [false, true] {
            let app = StoryScrollStoreAppDelegate()
            let fixture = makeFixture(app: app)
            fixture.page.recordsPosition = true
            fixture.page.drawStory()
            await delay(0.15)
            fixture.web.scrollView.contentInset.top = 64
            fixture.web.scrollView.contentOffset.y = 2_500
            XCTAssertTrue(requestScrollToTop(on: fixture.page))
            fixture.web.scrollView.contentOffset.y = -64
            if reusesPage {
                fixture.page.activeStory = story("replacement", body: "Replacement article")
                fixture.page.drawStory()
                await drainMainQueue()
                fixture.page.setValue(true, forKey: "hasScrolled")
                fixture.web.scrollView.contentOffset.y = 1_000
            }

            let selector = NSSelectorFromString("scrollViewDidScrollToTop:")
            XCTAssertTrue(fixture.page.responds(to: selector), "StoryDetailObjCViewController.m must persist the explicit completed native action.")
            if fixture.page.responds(to: selector) {
                typealias Call = @convention(c) (AnyObject, Selector, UIScrollView) -> Void
                unsafeBitCast(fixture.page.method(for: selector), to: Call.self)(fixture.page, selector, fixture.web.scrollView)
                await delay(0.05)
                XCTAssertEqual(app.positions, reusesPage ? [] : [0])
            }
        }
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

    func test_threeHiddenPageBootstrapsPrepareBeforeTheirContainerEntersAWindow() async throws {
        try await checkStalledStoryRendering(restoresPosition: false, repeatsStory: true, preparesOffWindow: true)
    }

    private func checkStalledStoryRendering(restoresPosition: Bool, repeatsStory: Bool = false,
                                           preparesOffWindow: Bool = false) async throws {
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
        var detachedPages: [StoryLoadPage] = []
        if preparesOffWindow {
            let container = UIScrollView(frame: web.frame)
            container.contentSize = CGSize(width: web.bounds.width * 3, height: web.bounds.height)
            for index in 0..<3 {
                let child = index == 0 ? page : makePage(web: RealStoryLoadWebView(frame: web.frame, configuration: WKWebViewConfiguration()))
                child.allowsAppearanceCallbacks = false
                let childWeb = try XCTUnwrap(child.webView as? RealStoryLoadWebView)
                childWeb.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                childWeb.scrollView.contentInsetAdjustmentBehavior = .never
                childWeb.navigationDelegate = child
                // StoryPagesObjCViewController.m first loads each child view, then adds it to its off-window scroll view.
                child.perform(NSSelectorFromString("clearWebView"))
                child.view.frame = container.bounds.offsetBy(dx: CGFloat(index) * container.bounds.width, dy: 0)
                container.addSubview(child.view)
                window.rootViewController?.addChild(child)
                detachedPages.append(child)
            }
            for _ in 0..<40 where detachedPages.contains(where: { $0.value(forKey: "fontWarmupNavigation") != nil }) {
                await delay(0.05)
            }
            for (index, child) in detachedPages.enumerated() {
                let childWeb = try XCTUnwrap(child.webView as? RealStoryLoadWebView)
                let stages = try await childWeb.evaluateJavaScript("JSON.stringify({stage:window.nbTestFontStage,fonts:document.fonts.status,faces:Array.from(document.fonts,f=>[f.family,f.status]),width:document.body?.offsetWidth,height:document.body?.offsetHeight})")
                print("STORY_HIDDEN_BOOTSTRAP index=\(index) didFinish=\(child.finishedNavigations) fontCalls=\(childWeb.fontPreparationCalls) inWindow=\(childWeb.window != nil) windowHidden=\(window.isHidden) stages=\(stages)")
                XCTAssertEqual(child.value(forKey: "preparedWebViewFonts") as? Bool, true)
                XCTAssertEqual(child.value(forKey: "failedWebViewFontPreparation") as? Bool, false)
            }
            window.rootViewController?.view.addSubview(container)
        } else {
            window.rootViewController?.view.addSubview(web)
        }
        window.makeKeyAndVisible()
        defer {
            resource.stop()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        web.navigationDelegate = page
        // StoryDetailObjCViewController.m initializes every WKWebView with clearWebView before drawing a story.
        if !preparesOffWindow { page.perform(NSSelectorFromString("clearWebView")) }
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
            page.perform(NSSelectorFromString("clearWebView"))
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

    private func checkPlainWebKitRendering(notifiesNative: Bool) async throws {
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
        let html = "<html><body><img src='\(imageURL)' width='30' height='30'>" + String(repeating: "<p>Plain WebKit control paragraph.</p>", count: 150) + notify + "</body></html>"
        web.loadHTMLString(html, baseURL: nil)
        for _ in 0..<60 where web.scrollView.contentSize.height < web.bounds.height + 500 {
            await delay(0.05)
        }
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

    private func requestScrollToTop(on page: StoryLoadPage) -> Bool {
        let selector = NSSelectorFromString("scrollViewShouldScrollToTop:")
        typealias Call = @convention(c) (AnyObject, Selector, UIScrollView) -> Bool
        return unsafeBitCast(page.method(for: selector), to: Call.self)(page, selector, page.webView.scrollView)
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

private final class StoryScrollStoreAppDelegate: NewsBlurAppDelegate {
    private let lock = NSLock()
    private var savedPositions: [Int] = []
    var positions: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return savedPositions
    }
    override func markScrollPosition(_ position: Int, inStory story: [AnyHashable: Any]!) {
        lock.lock()
        savedPositions.append(position)
        lock.unlock()
    }
}

@MainActor private class StoryLoadToolbarPages: StoryPagesViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func setTextButton() {}
    override func setTextButton(_ storyViewController: StoryDetailViewController!) {}
    override func resizeScrollView() {}
    override func updateUITestTraverseFadeProbe() {}
}

@MainActor private final class StoryPresentationApp: NewsBlurAppDelegate {
    var testPages: StoryPagesViewController?
    var testDetail: DetailViewController?
    var testFeed: FeedDetailViewController?
    override var feedDetailViewController: FeedDetailViewController! { testFeed }
    var presentations = 0
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set { testPages = newValue }
    }
    override var detailViewController: DetailViewController! {
        get { testDetail }
        set { testDetail = newValue }
    }
    override func showDetailViewController(_ vc: UIViewController, sender: Any?) { presentations += 1 }
    override func isFeed(inTextView feedId: Any!) -> Bool { false }
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {}
}

@MainActor private final class StoryPresentationWindow: UIWindow {
    var testSafeAreaTop: CGFloat = 20
    override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: testSafeAreaTop, left: 0, bottom: 0, right: 0) }
}

@MainActor private final class StoryPresentationDetail: DetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func collapseFeedListIfNeededForStory() {}
}

@MainActor private final class StoryPresentationPages: StoryLoadToolbarPages {
    weak var navigationForPresentation: UINavigationController?
    var pageChanges: [Int] = []
    var hiddenAtNavigation: [Bool] = []
    var unreadyAtNavigation: [Bool] = []
    var runsActualPageChanges = false
    override func changePage(_ pageIndex: Int, animated: Bool) {
        pageChanges.append(pageIndex)
        hiddenAtNavigation.append(currentPage.webView.isHidden)
        unreadyAtNavigation.append(!currentPage.readyForPresentation)
        if runsActualPageChanges { super.changePage(pageIndex, animated: animated) }
        navigationForPresentation?.pushViewController(self, animated: animated)
    }
    override func animate(intoPlace animated: Bool) {}
    // StoryDetailLoadingTests.swift supplies no storyboard toolbar and keeps navigation on the isolated account.
    override func updateStoryTitleNavigationButtons() {}
}

@MainActor private final class StoryLoadPage: StoryDetailViewController {
    var widthUpdates = 0
    var classifierUpdates = 0
    var finishedNavigations = 0
    var shareHTML = "Fixture sharing"
    var readyObserver: (() -> Void)?
    var allowsAppearanceCallbacks = true
    var recordsPosition = false

    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewWillAppear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewWillAppear(animated) } }
    override func viewWillDisappear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewWillDisappear(animated) } }
    override func viewDidAppear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewDidAppear(animated) } }
    override func viewDidDisappear(_ animated: Bool) { if allowsAppearanceCallbacks { super.viewDidDisappear(animated) } }
    override func getHeader() -> String! { "<h1>Fixture header</h1>" }
    override func getShareBar() -> String! { shareHTML }
    override func getComments() -> String! { "Fixture comments" }
    override func changeWebViewWidth() {
        widthUpdates += 1
        if webView is RealStoryLoadWebView { super.changeWebViewWidth() }
    }
    override func checkTryFeedStory() {}
    @objc(storeScrollPosition:) func ignorePositionStorage(_ queue: Bool) {
        guard recordsPosition else { return }
        let selector = NSSelectorFromString("storeScrollPosition:")
        typealias Call = @convention(c) (AnyObject, Selector, Bool) -> Void
        let implementation = class_getMethodImplementation(StoryDetailObjCViewController.self, selector)!
        unsafeBitCast(implementation, to: Call.self)(self, selector, queue)
    }
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
    var defersAsyncJavaScript = false
    var asyncCompletions: [(Any?, Error?) -> Void] = []
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
    override func __callAsyncJavaScript(_ functionBody: String, arguments: [String: Any]?, inFrame frame: WKFrameInfo?, in contentWorld: WKContentWorld, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        if defersAsyncJavaScript {
            if let completionHandler { asyncCompletions.append(completionHandler) }
        } else {
            completionHandler?(true, nil)
        }
    }
}

@MainActor private final class StoryLoadScrollView: UIScrollView {
    var simulatesDragging = false
    override var isDragging: Bool { simulatesDragging }
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(contentOffset, animated: false)
    }
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
    let hasSavedPosition: Bool
    let position: Int
    init(hasSavedPosition: Bool = true, position: Int = 500) { self.hasSavedPosition = hasSavedPosition; self.position = position }
    @objc(executeQuery:) func executeQuery(_ sql: String) -> StoryScrollCursor { StoryScrollCursor(hasSavedPosition: hasSavedPosition, position: position) }
}

private final class ImmediateStoryScrollQueue: NSObject {
    let hasSavedPosition: Bool
    let position: Int
    init(hasSavedPosition: Bool = true, position: Int = 500) { self.hasSavedPosition = hasSavedPosition; self.position = position }
    @objc(inDatabase:) func inDatabase(_ block: (AnyObject) -> Void) { block(StoryScrollDatabase(hasSavedPosition: hasSavedPosition, position: position)) }
}

private final class StoryScrollCursor: NSObject {
    private var read = false
    let hasSavedPosition: Bool
    let position: Int
    init(hasSavedPosition: Bool = true, position: Int = 500) { self.hasSavedPosition = hasSavedPosition; self.position = position }
    @objc func next() -> Bool { defer { read = true }; return hasSavedPosition && !read }
    @objc func resultDictionary() -> NSDictionary { ["scroll": position, "story_hash": "first"] }
    @objc func close() {}
}

@MainActor private final class HeldStoryParser: NSObject, WKUIDelegate {
    private var pending: (() -> Void)?
    var isHeld: Bool { pending != nil }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        pending = completionHandler
    }

    func release() {
        let completion = pending
        pending = nil
        completion?()
    }
}

@MainActor private final class RealStoryLoadWebView: WKWebView {
    var fontPreparationCalls = 0

    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        // StoryDetailLoadingTests.swift retains the production HTTPS document origin for real WebKit checks.
        return super.loadHTMLString(string, baseURL: baseURL ?? URL(string: "https://newsblur.com/"))
    }

    override func __callAsyncJavaScript(_ functionBody: String, arguments: [String: Any]?, inFrame frame: WKFrameInfo?, in contentWorld: WKContentWorld, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        var observedBody = functionBody
        if functionBody.contains("font.load()") {
            fontPreparationCalls += 1
            // StoryDetailLoadingTests.swift records the existing promise stages without initiating additional font work.
            observedBody = "window.nbTestFontStage='loading'; " + functionBody.replacingOccurrences(
                of: "await document.fonts.ready;", with: "window.nbTestFontStage='faces_loaded'; await document.fonts.ready; window.nbTestFontStage='set_ready';")
        }
        super.__callAsyncJavaScript(observedBody, arguments: arguments, inFrame: frame, in: contentWorld, completionHandler: completionHandler)
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
