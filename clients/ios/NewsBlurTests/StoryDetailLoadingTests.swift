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
        // StoryDetailLoadingTests.swift arms the real deadline, then reuses the page in the same main-actor turn.
        fixture.page.perform(NSSelectorFromString("loadStory"))
        let firstGeneration = try XCTUnwrap(fixture.page.value(forKey: "storyLoadGeneration") as? UInt)
        XCTAssertEqual(fixture.page.value(forKey: "fontPreparationWaitGeneration") as? UInt, firstGeneration)
        fixture.page.holdsStoryLoading = true
        defer { fixture.page.holdsStoryLoading = false }
        fixture.page.activeStory = story("second", body: "Latest waiting article")
        fixture.page.drawStory()
        XCTAssertNotEqual(fixture.page.value(forKey: "storyLoadGeneration") as? UInt, firstGeneration)
        XCTAssertTrue((fixture.page.value(forKey: "fullStoryHTML") as? String)?.contains("Latest waiting article") == true)
        // StoryDetailLoadingTests.swift holds only the newer load request so its own valid deadline cannot race this stale-deadline check.
        await delay(1.1)

        XCTAssertEqual(fixture.page.value(forKey: "failedWebViewFontPreparation") as? Bool, false)
        XCTAssertEqual(fixture.web.loads.count, 1)
        // StoryDetailLoadingTests.swift compares the fixture's opaque NSObject token without casting its runtime class to WKNavigation.
        XCTAssertTrue(fixture.page.value(forKey: "fontWarmupNavigation") as AnyObject? === bootstrap)
        fixture.page.holdsStoryLoading = false
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

    func test_notificationPreparationSurvivesInitialPagerLayoutBeforeItsRealDocumentIsReady() async throws {
        try await assertNotificationPreparation(database: nil, savedPosition: nil)
    }

    func test_notificationPreparationRestoresItsSQLitePositionBeforePresentingTheRealDocument() async throws {
        for savedPosition in [nil, 1, 500] as [Int?] {
            let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("notification-scroll-\(UUID().uuidString).sqlite")
            var connection: OpaquePointer?
            XCTAssertEqual(sqlite3_open(databaseURL.path, &connection), SQLITE_OK)
            XCTAssertEqual(sqlite3_exec(connection, "CREATE TABLE story_scrolls (story_feed_id INTEGER, story_hash TEXT, story_timestamp INTEGER, scroll INTEGER)", nil, nil, nil), SQLITE_OK)
            if let savedPosition {
                XCTAssertEqual(sqlite3_exec(connection, "INSERT INTO story_scrolls VALUES (1, 'item-9', 1700000000, \(savedPosition))", nil, nil, nil), SQLITE_OK)
            }
            let database = try XCTUnwrap(FMDatabaseQueue(path: databaseURL.path))
            defer {
                database.close()
                sqlite3_close(connection)
                try? FileManager.default.removeItem(at: databaseURL)
            }
            try await assertNotificationPreparation(database: database, savedPosition: savedPosition)
        }
    }

    private func assertNotificationPreparation(database: FMDatabaseQueue?, savedPosition: Int?) async throws {
        let fixture = makePresentationFixture()
        fixture.app.setValue(database, forKey: "database")
        let collection = fixture.app.storiesCollection
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        // StoryDetailObjCViewController.m configures this on its normal web view; the
        // replacement fixture must also prevent UIKit from adding the navigation inset.
        web.scrollView.contentInsetAdjustmentBehavior = .never
        let page = makePage(web: web, app: fixture.app)
        fixture.app.storiesCollection = collection
        var restoredContentSize: CGSize?
        var hiddenAtEntrance = false
        web.restorationFrameObserver = { restoredContentSize = $0 }
        fixture.pages.beforeNavigation = { current in
            hiddenAtEntrance = current.webView.isHidden || current.webView.alpha == 0
        }
        page.allowsAppearanceCallbacks = false
        fixture.stories[9]["story_content"] = String(repeating: "<p>The older notification's actual article must be presented.</p>", count: database == nil ? 1 : 120)
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
        titles.view.backgroundColor = .systemBackground
        let navigation = UINavigationController(rootViewController: titles)
        fixture.app.feedsNavigationController = navigation
        fixture.pages.navigationForPresentation = navigation
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer {
            fixture.pages.scrollView.delegate = nil
            fixture.pages.cancelPendingStoryPresentation()
            fixture.pages.beforeNavigation = nil
            fixture.app.setValue(nil, forKey: "database")
            web.restorationFrameObserver = nil
            web.stopLoading()
            web.navigationDelegate = nil
            window.isHidden = true
            previousKeyWindow?.makeKey()
            page.webView = nil
        }

        // StoryDetailLoadingTests.swift reproduces the reset pager present when a feed
        // notification selects its first article, including native sizing and scroll callbacks.
        fixture.pages.resetPages()
        fixture.pages.runsActualScrollSizing = true
        fixture.pages.scrollView.delegate = fixture.pages
        fixture.pages.scrollingToPage = 0
        collection?.notificationStory = fixture.stories[9] as? [AnyHashable: Any]
        fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
        fixture.app.loadStoryDetailView(animated: false)
        for _ in 0..<100 where fixture.app.presentations == 0 { await delay(0.05) }

        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "item-9",
                       "Initial layout must not replace the notification selection with the pager's old row")
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertTrue(navigation.topViewController === fixture.pages)
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-9")
        XCTAssertEqual(fixture.pages.pageChanges, [2])
        XCTAssertEqual(fixture.pages.unreadyAtNavigation, [true])
        XCTAssertTrue(hiddenAtEntrance)
        for _ in 0..<200 where !page.readyForPresentation { await delay(0.025) }
        XCTAssertTrue(page.readyForPresentation)
        let body = try await web.evaluateJavaScript("document.querySelector('#NB-story')?.textContent") as? String
        XCTAssertTrue(body?.contains("older notification's actual article") == true)
        if database != nil {
            // StoryDetailLoadingTests.swift reads an isolated SQLite row and requires restoration before revealing the early reader's document.
            XCTAssertEqual(page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
            XCTAssertGreaterThan(web.scrollView.contentSize.height, 2 * web.bounds.height)
            let restoredSize = try XCTUnwrap(restoredContentSize)
            let restoredOffset = web.scrollView.contentOffset
            let restoredInset = web.scrollView.adjustedContentInset
            XCTAssertGreaterThan(restoredSize.height, 2 * web.bounds.height)
            let expectedPosition = (savedPosition ?? 0) > 1 ?
                floor(CGFloat(savedPosition ?? 0) / 1_000 * restoredSize.height) : -restoredInset.top
            XCTAssertEqual(restoredOffset.y, expectedPosition, accuracy: 2,
                           "SQLite position must be restored before the early reader reveals its document")
            XCTAssertEqual(page.value(forKey: "restoredStoryScrollPosition") as? Bool, (savedPosition ?? 0) > 1)
        }
    }

    func test_storyReadinessMessagesOnlyAcceptTheCurrentMainFrameStringToken() async throws {
        let fixture = makeFixture()
        fixture.page.drawStory()
        await drainMainQueue()
        let token = try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html)
        let handler = StoryReadyMessageHandler(page: fixture.page)
        func send(web: WKWebView?, mainFrame: Bool = true, body: Any, name: String = "newsblurStoryReady") {
            let message = StoryReadyScriptMessage(web: web, mainFrame: mainFrame, body: body, name: name)
            handler.userContentController(fixture.web.configuration.userContentController,
                                          didReceive: unsafeBitCast(message, to: WKScriptMessage.self))
        }
        let anotherWeb = WKWebView(frame: .zero)
        send(web: anotherWeb, body: token)
        send(web: nil, body: token)
        send(web: fixture.web, mainFrame: false, body: token)
        send(web: fixture.web, body: token, name: "anotherHandler")
        send(web: fixture.web, body: NSNumber(value: Int(token) ?? -1))
        send(web: fixture.web, body: NSNull())
        send(web: fixture.web, body: "stale-token")
        fixture.page.hasStory = false
        send(web: fixture.web, body: token)
        fixture.page.hasStory = true
        let currentStory = fixture.page.activeStory
        fixture.page.activeStory = story("another-hash", body: "Another document")
        send(web: fixture.web, body: token)
        fixture.page.activeStory = currentStory
        XCTAssertEqual(fixture.page.classifierUpdates, 0)
        XCTAssertTrue(fixture.web.isHidden)

        send(web: fixture.web, body: token)
        send(web: fixture.web, body: token)
        XCTAssertEqual(fixture.page.classifierUpdates, 1, "The valid current document is accepted exactly once")
        XCTAssertFalse(fixture.web.isHidden)
        fixture.page.drawStory()
        await drainMainQueue()
        let replacementToken = try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html)
        XCTAssertNotEqual(replacementToken, token)
        send(web: fixture.web, body: token)
        XCTAssertEqual(fixture.page.classifierUpdates, 1, "An outgoing document cannot release the replacement")
        send(web: fixture.web, body: replacementToken)
        XCTAssertEqual(fixture.page.classifierUpdates, 2)
    }

    func test_installedStoryReadinessHandlerDoesNotRetainItsPage() async {
        let web = RecordedStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        weak var releasedPage: StoryLoadPage?
        autoreleasepool {
            let page = makePage(web: web)
            releasedPage = page
            page.perform(NSSelectorFromString("clearWebView"))
            XCTAssertFalse(web.loads.isEmpty, "The production load path must install the handler before the page is released")
        }
        await drainMainQueue()
        XCTAssertNil(releasedPage, "The live WKUserContentController must hold only a weak reference to its page")
    }

    func test_outgoingDOMReadinessDoesNotNavigateOrCancelItsFullTextReplacement() async throws {
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: WKWebViewConfiguration())
        let page = makePage(web: web)
        page.allowsAppearanceCallbacks = false
        page.activeStory = story("notification-replacement", body: "<p>Original feed document.</p>")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(web)
        window.makeKeyAndVisible()
        defer {
            page.readyObserver = nil
            page.navigationActionObserver = nil
            page.finishStoryPresentation()
            web.stopLoading()
            web.navigationDelegate = nil
            window.isHidden = true
            previousKeyWindow?.makeKey()
            page.webView = nil
        }
        var readinessNavigations: [URL] = []
        page.navigationActionObserver = { action in
            if let url = action.request.url, url.host == "ios.newsblur.com", url.path == "/notify-loaded" {
                readinessNavigations.append(url)
            }
        }
        web.navigationDelegate = page
        page.perform(NSSelectorFromString("clearWebView"))
        for _ in 0..<60 where page.value(forKey: "preparedWebViewFonts") as? Bool != true { await delay(0.05) }
        XCTAssertEqual(page.value(forKey: "preparedWebViewFonts") as? Bool, true)

        let replaced = expectation(description: "The actual replacement full-text document reports DOM readiness")
        var readyGenerations: [Int] = []
        page.readyObserver = {
            readyGenerations.append(page.value(forKey: "storyLoadGeneration") as? Int ?? -1)
            page.readyObserver = {
                readyGenerations.append(page.value(forKey: "storyLoadGeneration") as? Int ?? -1)
                replaced.fulfill()
            }
            // StoryDetailLoadingTests.swift submits a same-story text replacement while
            // the outgoing document's real native readiness callback is still on the stack.
            page.activeStory["original_text"] = String(repeating: "<p>Replacement full text remains readable.</p>", count: 80)
            page.inTextView = true
            page.drawStory()
            page.prepareCurrentStoryForPresentation()
            page.perform(NSSelectorFromString("loadStory"))
        }
        page.drawStory()
        await fulfillment(of: [replaced], timeout: 5)
        for _ in 0..<60 where !page.readyForPresentation { await delay(0.05) }
        XCTAssertEqual(readyGenerations.count, 2)
        if readyGenerations.count == 2 { XCTAssertGreaterThan(readyGenerations[1], readyGenerations[0]) }
        XCTAssertTrue(readinessNavigations.isEmpty,
                      "DOM readiness must not start a URL navigation that can cancel a replacement load: \(readinessNavigations)")
        XCTAssertEqual(page.activeStoryId, "notification-replacement")
        XCTAssertTrue(page.readyForPresentation)
        XCTAssertFalse(web.isHidden)
        let body = try await web.evaluateJavaScript("document.querySelector('#NB-story')?.textContent") as? String
        XCTAssertTrue(body?.contains("Replacement full text remains readable") == true)
        XCTAssertFalse(body?.contains("Original feed document") == true)
    }

    func test_titlePaneSelectionsRequestAnimationOnIPadAndMac() {
        for isMac in [false, true] {
            for presentation in [FullscreenSidebarPresentation.fullscreen, .storyTitles, .feeds] {
                XCTAssertTrue(StorySelectionAnimationDecision.shouldAnimateSelection(
                    isPhoneOrCompact: false, usesNativeFullscreenSidebar: true,
                    presentation: presentation, isMac: isMac),
                    "A visible article should animate when another title is selected: Mac=\(isMac), presentation=\(presentation)")
            }
        }
    }

    func test_preparedTitlePaneSelectionDoesNotJumpBeforeItsAnimationBegins() async throws {
        let defaults = UserDefaults.standard
        let originalDirection = defaults.object(forKey: "scroll_stories_horizontally")
        defer {
            if let originalDirection { defaults.set(originalDirection, forKey: "scroll_stories_horizontally") }
            else { defaults.removeObject(forKey: "scroll_stories_horizontally") }
        }
        for horizontal in [true, false] {
            defaults.set(horizontal, forKey: "scroll_stories_horizontally")
            for (start, target) in [(0, 1), (0, 20), (20, 0)] {
                let fixture = makePresentationFixture(width: 600)
                fixture.pages.regularPane = true
                fixture.pages.scrollView.contentInsetAdjustmentBehavior = .never
                fixture.app.compactWidthOverride = false
                let stories = (0..<24).map { story("scan-\($0)", body: "Article \($0)") }
                fixture.app.storiesCollection.activeFeedStories = stories
                fixture.app.storiesCollection.storyCount = Int32(stories.count)
                fixture.app.storiesCollection.storyLocationsCount = Int32(stories.count)
                fixture.app.storiesCollection.activeFeedStoryLocations = NSMutableArray(array: Array(stories.indices))
                fixture.app.storiesCollection.activeFeedStoryLocationIds = NSMutableArray(array: stories.indices.map { "scan-\($0)" })
                fixture.original.activeStory = stories[start]
                fixture.original.activeStoryId = "scan-\(start)"
                fixture.original.pageIndex = start
                fixture.app.activeStory = stories[start] as? [AnyHashable: Any]
                let viewport = fixture.pages.scrollView.bounds.size
                fixture.pages.scrollView.contentSize = CGSize(width: horizontal ? viewport.width * 24 : viewport.width,
                                                               height: horizontal ? viewport.height : viewport.height * 24)
                let sourceOffset = CGPoint(x: horizontal ? CGFloat(start) * viewport.width : 0,
                                           y: horizontal ? 0 : CGFloat(start) * viewport.height)
                fixture.original.view.frame = CGRect(origin: sourceOffset, size: viewport)
                fixture.pages.scrollView.contentOffset = sourceOffset
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
                let window = UIWindow(windowScene: scene)
                window.rootViewController = fixture.pages
                window.makeKeyAndVisible()
                let motion = StorySelectionFrameRecorder(view: fixture.original.view, window: window, horizontal: horizontal)
                defer {
                    motion.stop()
                    fixture.pages.beforeNavigation = nil
                    fixture.pages.cancelPendingStoryPresentation()
                    window.isHidden = true
                    window.rootViewController = nil
                    previousKeyWindow?.makeKey()
                }
                let enteredAnimation = expectation(description: "Prepared title selection reaches the animation boundary")
                fixture.pages.beforeNavigation = { _ in enteredAnimation.fulfill() }
                fixture.app.activeStory = stories[target] as? [AnyHashable: Any]
                fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": target, "animated": true])
                await drainMainQueue()
                XCTAssertTrue(fixture.pages.currentPage === fixture.original)
                XCTAssertEqual(fixture.pages.scrollView.contentOffset, sourceOffset)
                let selected = try XCTUnwrap(fixture.pages.value(forKey: "pendingPresentationPage") as? StoryLoadPage)
                let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
                motion.start()
                let began = CACurrentMediaTime()
                sendReady(to: selected, token: try tokenFromHTML(XCTUnwrap(web.loads.last).html), mainFrame: true)
                await fulfillment(of: [enteredAnimation], timeout: 2)
                motion.stop()
                let positions = Set(motion.positions.map { Int(($0 * 10).rounded()) })
                XCTAssertGreaterThanOrEqual(positions.count, 3,
                    "A title selection must show intermediate positions, not an immediate jump. start=\(start), target=\(target), horizontal=\(horizontal), positions=\(motion.positions)")
                XCTAssertTrue(selected.readyForPresentation, "The destination must still be painted before starting its transition")
                print("STORY_TITLE_SELECTION start=\(start) target=\(target) horizontal=\(horizontal) presented_positions=\(positions.count) ready_to_completion_ms=\((CACurrentMediaTime() - began) * 1000)")
            }
        }
    }

    func test_realPaintedArticlesScanToDistantSelectionWithoutReadingSkippedStories() async throws {
        try await checkRealPaintedArticleSelection(replacesTextDuringMotion: false)
    }

    func test_fullTextArrivingDuringRealPageMotionWaitsBehindPaintedContent() async throws {
        try await checkRealPaintedArticleSelection(replacesTextDuringMotion: true)
    }

    private func checkRealPaintedArticleSelection(replacesTextDuringMotion: Bool) async throws {
        let defaults = UserDefaults.standard
        let originalDirection = defaults.object(forKey: "scroll_stories_horizontally")
        defaults.set(true, forKey: "scroll_stories_horizontally")
        defer {
            if let originalDirection { defaults.set(originalDirection, forKey: "scroll_stories_horizontally") }
            else { defaults.removeObject(forKey: "scroll_stories_horizontally") }
        }
        let fixture = makePresentationFixture(width: 390)
        fixture.pages.regularPane = true
        fixture.pages.scrollView.contentInsetAdjustmentBehavior = .never
        fixture.app.compactWidthOverride = false
        let collection = fixture.app.storiesCollection!
        let realPages = (0..<3).map { _ -> StoryLoadPage in
            let web = RealStoryLoadWebView(frame: fixture.pages.scrollView.bounds, configuration: WKWebViewConfiguration())
            web.scrollView.contentInsetAdjustmentBehavior = .never
            let page = makePage(web: web, app: fixture.app)
            page.allowsAppearanceCallbacks = false
            web.navigationDelegate = page
            return page
        }
        fixture.app.storiesCollection = collection
        for page in fixture.pages.children {
            page.willMove(toParent: nil)
            page.view.removeFromSuperview()
            page.removeFromParent()
        }
        fixture.pages.currentPage = realPages[0]
        fixture.pages.nextPage = realPages[1]
        fixture.pages.previousPage = realPages[2]
        for page in realPages {
            fixture.pages.addChild(page)
            fixture.pages.scrollView.addSubview(page.view)
            page.didMove(toParent: fixture.pages)
            page.pageIndex = -2
        }
        let stories = (0..<24).map { index -> NSMutableDictionary in
            let article = story("painted-\(index)", body: "<h2>Article \(index + 1)</h2>" + String(repeating: "<p>Prepared article \(index + 1). This text remains readable while the title selection moves between pages.</p>", count: 60))
            article["id"] = "painted-\(index)"
            article["read_status"] = 0
            return article
        }
        stories[0]["read_status"] = 1
        stories[20]["read_status"] = 1
        // StoryDetailLoadingTests.swift controls destination readiness while the neighbor completes selection's new paint check.
        stories[20]["story_content"] = "<script>alert('hold destination until its intermediate article is prepared')</script>" +
            (stories[20]["story_content"] as? String ?? "")
        collection.activeFeedStories = stories
        collection.storyCount = Int32(stories.count)
        collection.storyLocationsCount = Int32(stories.count)
        collection.activeFeedStoryLocations = NSMutableArray(array: Array(stories.indices))
        collection.activeFeedStoryLocationIds = NSMutableArray(array: stories.indices.map { "painted-\($0)" })
        fixture.pages.scrollView.contentSize = CGSize(width: 390 * 24, height: 844)
        fixture.app.activeStory = stories[0] as? [AnyHashable: Any]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = fixture.pages
        window.makeKeyAndVisible()
        let motion = StorySelectionFrameRecorder(view: realPages[0].view, window: window, horizontal: true)
        let parser = HeldStoryParser()
        let destinationParser = HeldStoryParser()
        realPages[2].webView.uiDelegate = destinationParser
        defer {
            destinationParser.release()
            parser.release()
            motion.stop()
            fixture.pages.beforeNavigation = nil
            fixture.pages.selectionTransitionStarted = nil
            fixture.pages.cancelPendingStoryPresentation()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
            for page in realPages { page.webView.stopLoading(); page.webView = nil }
        }
        for page in realPages { page.perform(NSSelectorFromString("clearWebView")) }
        await waitForState("All three WebKit pages finish their bundled-font bootstrap") {
            realPages.allSatisfy { $0.value(forKey: "preparedWebViewFonts") as? Bool == true }
        }
        guard realPages.allSatisfy({ $0.value(forKey: "preparedWebViewFonts") as? Bool == true }) else { return }
        for index in 0...1 {
            let page = realPages[index]
            page.pageIndex = index
            page.activeStory = stories[index]
            page.activeStoryId = "painted-\(index)"
            page.hasStory = true
            page.drawStory()
            page.prepareCurrentStoryForPresentation()
        }
        await waitForState("Both initial articles are painted before selecting a distant story") {
            realPages[0].readyForPresentation && realPages[1].readyForPresentation
        }
        guard realPages[0].readyForPresentation && realPages[1].readyForPresentation else { return }
        for index in 0...1 {
            realPages[index].finishStoryPresentation()
            realPages[index].view.frame = CGRect(x: CGFloat(index) * 390, y: 0, width: 390, height: 844)
        }
        realPages[0].webView.scrollView.contentOffset.y = 280
        let initialReadingPosition = realPages[0].webView.scrollView.contentOffset.y
        let started = expectation(description: "The prepared destination starts its real article scan")
        let completed = expectation(description: "Real article selection finishes its visible scan")
        fixture.pages.beforeNavigation = { _ in completed.fulfill() }
        fixture.pages.selectionTransitionStarted = { passingPages in
            XCTAssertEqual(Set(passingPages.compactMap(\.activeStoryId)), Set(["painted-0", "painted-1", "painted-20"]))
            XCTAssertTrue(passingPages.allSatisfy { $0.readyForPresentation && !$0.webView.isHidden })
            if replacesTextDuringMotion {
                guard let target = passingPages.first(where: { $0.activeStoryId == "painted-20" }) else {
                    XCTFail("The real selection animation must contain the destination article")
                    started.fulfill()
                    return
                }
                target.webView.uiDelegate = parser
                (target.webView as? RealStoryLoadWebView)?.selectionLoadObserver = { html in
                    print("TITLE_REPLACEMENT_SUBMISSION replacement=\(html.contains("Full text replacement")) parser=\(html.contains("hold replacement"))")
                }
                let fullText = "<script>alert('hold replacement until its painted cover is visible')</script><h2>Full text replacement</h2>" + String(repeating: "<p>Prepared article 21, with its full text now available.</p>", count: 60)
                target.perform(NSSelectorFromString("finishFetchText:storyId:"), with: fullText, with: "painted-20")
                XCTAssertTrue(target.inTextView)
                XCTAssertEqual(target.activeStory["original_text"] as? String, fullText)
            }
            started.fulfill()
        }
        motion.start()
        fixture.app.activeStory = stories[20] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 20, "animated": true])
        XCTAssertFalse(realPages[1].readyForPresentation, "Selection must start a fresh paint check for the intermediate article")
        await waitForState("The intermediate article finishes its second paint check while destination parsing is held") {
            destinationParser.isHeld && realPages[1].readyForPresentation
        }
        guard destinationParser.isHeld && realPages[1].readyForPresentation else { return }
        destinationParser.release()
        await fulfillment(of: [started], timeout: 15)
        await delay(0.12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Real painted articles during a twenty-story selection scan"
        attachment.lifetime = .keepAlways
        add(attachment)
        if replacesTextDuringMotion {
            for _ in 0..<100 where !parser.isHeld { await delay(0.01) }
            XCTAssertTrue(parser.isHeld)
            XCTAssertEqual(fixture.pages.pageChanges, [], "The selected replacement is still parsing and cannot be presented yet")
            let cover = try XCTUnwrap(fixture.pages.value(forKey: "storySelectionRedrawCover") as? UIView)
            XCTAssertTrue(cover.window === window)
            XCTAssertFalse(cover.isHidden)
            XCTAssertEqual(cover.alpha, 1)
            XCTAssertEqual(cover.bounds.size, fixture.pages.scrollView.bounds.size)
            XCTAssertFalse(try XCTUnwrap(cover.subviews.first).bounds.isEmpty)
            // StoryDetailLoadingTests.swift observes the displayed cover after its compositor commit, while parsing remains held.
            let committedFrameCount = motion.positions.count + 2
            for _ in 0..<100 where motion.positions.count < committedFrameCount { await delay(0.01) }
            XCTAssertGreaterThanOrEqual(motion.positions.count, committedFrameCount)
            XCTAssertTrue(parser.isHeld)
            let coverImage = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let coverAttachment = XCTAttachment(image: coverImage)
            coverAttachment.name = "Hierarchy capture while frozen destination covers held replacement"
            coverAttachment.lifetime = .keepAlways
            add(coverAttachment)
            parser.release()
        }
        await fulfillment(of: [completed], timeout: 3)
        motion.stop()
        XCTAssertGreaterThanOrEqual(Set(motion.positions.map { Int($0.rounded()) }).count, 5)
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "painted-20")
        XCTAssertEqual(realPages[0].webView.scrollView.contentOffset.y, initialReadingPosition, accuracy: 1)
        XCTAssertEqual(fixture.pages.children.count, 3)
        XCTAssertTrue(realPages.allSatisfy { $0.view.superview === fixture.pages.scrollView && $0.webView.superview === $0.view })
        XCTAssertEqual(stories.enumerated().filter { ($0.element["read_status"] as? Int) == 1 }.map(\.offset), [0, 20])
        let body = try await fixture.pages.currentPage.webView.evaluateJavaScript("document.querySelector('#NB-story').textContent") as? String
        XCTAssertTrue(body?.contains("Prepared article 21") == true)
        if replacesTextDuringMotion { XCTAssertTrue(body?.contains("Full text replacement") == true) }
        print("STORY_TITLE_SELECTION_SCAN presented_positions=\(motion.positions) other_unread=22 controllers=\(fixture.pages.children.count)")
    }

    func test_interruptedTitleSelectionRestoresViewsAndOnlyCompletesTheCurrentRequest() async throws {
        for interruption in ["reselect", "cancel", "resize", "redraw", "redraw-reselect", "redraw-cancel", "new-feed"] {
            let fixture = makePresentationFixture(width: 600)
            fixture.pages.regularPane = true
            fixture.app.compactWidthOverride = false
            fixture.pages.scrollView.contentInsetAdjustmentBehavior = .never
            let feed = FeedDetailViewController()
            fixture.app.testFeed = feed
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.rootViewController = fixture.pages
            window.makeKeyAndVisible()
            defer {
                fixture.pages.cancelPendingStoryPresentation()
                window.isHidden = true
                window.rootViewController = nil
                previousKeyWindow?.makeKey()
            }
            fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
            await drainMainQueue()
            let selected = try XCTUnwrap(fixture.pages.value(forKey: "pendingPresentationPage") as? StoryLoadPage)
            let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
            let selectedToken = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
            sendReady(to: selected, token: selectedToken, mainFrame: true)
            for _ in 0..<50 where fixture.pages.value(forKey: "storySelectionTransitionHost") == nil { await delay(0.01) }
            XCTAssertNotNil(fixture.pages.value(forKey: "storySelectionTransitionHost"), interruption)
            XCTAssertEqual(fixture.pages.pageChanges, [])
            switch interruption {
            case "reselect":
                fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
                fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
                await drainMainQueue()
                XCTAssertTrue(fixture.pages.currentPage === selected)
                XCTAssertEqual(fixture.app.presentations, 0)
                XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "item-9")
                let latest = try XCTUnwrap(fixture.pages.value(forKey: "pendingPresentationPage") as? StoryLoadPage)
                let latestWeb = try XCTUnwrap(latest.webView as? RecordedStoryLoadWebView)
                sendReady(to: latest, token: try tokenFromHTML(XCTUnwrap(latestWeb.loads.last).html), mainFrame: true)
                await waitForState("The reselected article completes its presentation") { !fixture.pages.pageChanges.isEmpty }
                XCTAssertEqual(fixture.pages.pageChanges, [2])
                XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-9")
            case "cancel":
                fixture.pages.cancelPendingStoryPresentation()
                await delay(0.35)
                XCTAssertTrue(fixture.pages.currentPage === fixture.original)
                XCTAssertEqual(fixture.app.presentations, 0)
            case "resize":
                fixture.pages.scrollView.frame.size.width = 500
                fixture.pages.viewDidLayoutSubviews()
                XCTAssertTrue(fixture.pages.currentPage === selected)
                XCTAssertEqual(fixture.pages.currentPage.view.bounds.width, 500)
                XCTAssertEqual(fixture.pages.pageChanges, [1])
            case "redraw", "redraw-reselect", "redraw-cancel":
                let previousLoadCount = web.loads.count
                selected.activeStory["story_content"] = "Full text replaced this same story while its page was moving"
                selected.drawStory()
                // StoryDetailLoadingTests.swift waits for the animator to submit the replacement document before sending that document's readiness token.
                await waitForState("The \(interruption) replacement reaches its covered paint gate") {
                    web.loads.count > previousLoadCount && selected.hasStory &&
                        fixture.pages.value(forKey: "storySelectionRedrawCover") != nil
                }
                XCTAssertEqual(fixture.app.presentations, 0, "A same-hash replacement must paint before completing the selection")
                let replacement = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
                XCTAssertNotEqual(replacement, selectedToken)
                if interruption == "redraw-cancel" {
                    fixture.pages.cancelPendingStoryPresentation()
                    sendReady(to: selected, token: replacement, mainFrame: true)
                    await delay(0.1)
                    XCTAssertEqual(fixture.app.presentations, 0)
                } else if interruption == "redraw-reselect" {
                    fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
                    fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
                    await drainMainQueue()
                    let latest = try XCTUnwrap(fixture.pages.value(forKey: "pendingPresentationPage") as? StoryLoadPage)
                    let latestWeb = try XCTUnwrap(latest.webView as? RecordedStoryLoadWebView)
                    sendReady(to: selected, token: replacement, mainFrame: true)
                    await drainMainQueue()
                    XCTAssertEqual(fixture.app.presentations, 0)
                    sendReady(to: latest, token: try tokenFromHTML(XCTUnwrap(latestWeb.loads.last).html), mainFrame: true)
                    await waitForState("The newer article completes after a deferred redraw") { !fixture.pages.pageChanges.isEmpty }
                    XCTAssertEqual(fixture.pages.pageChanges, [2])
                    XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-9")
                    XCTAssertEqual(fixture.pages.unreadyAtNavigation, [false])
                } else {
                    sendReady(to: selected, token: replacement, mainFrame: true)
                    await waitForState("The replacement article completes after its readiness signal") { !fixture.pages.pageChanges.isEmpty }
                    XCTAssertEqual(fixture.pages.pageChanges, [1])
                    XCTAssertEqual(fixture.pages.unreadyAtNavigation, [false])
                }
            default:
                feed.fetchRequestId += 1
                await waitForState("The obsolete feed selection releases its pending completion") {
                    fixture.pages.value(forKey: "pendingPresentationCompletion") == nil
                }
                XCTAssertTrue(fixture.pages.currentPage === fixture.original)
                XCTAssertEqual(fixture.app.presentations, 0)
            }
            XCTAssertNil(fixture.pages.value(forKey: "storySelectionTransitionHost"), interruption)
            XCTAssertNil(fixture.pages.value(forKey: "storySelectionRedrawCover"), interruption)
            XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationCompletion"), interruption)
            let pages = [fixture.pages.currentPage!, fixture.pages.nextPage!, fixture.pages.previousPage!]
            XCTAssertEqual(fixture.pages.children.count, 3)
            XCTAssertTrue(pages.allSatisfy { $0.view.superview === fixture.pages.scrollView && $0.webView.superview === $0.view }, interruption)
        }
    }

    func test_actualNextButtonRevealsThePartlyVisibleFourthTitleWithoutInterruptingEitherPane() async throws {
        let defaults = UserDefaults.standard
        let keys = ["scroll_stories_horizontally", "default_mark_read_filter"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defaults.set(true, forKey: keys[0])
        defaults.set("scroll", forKey: keys[1])
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        let fixture = makePresentationFixture(width: 660)
        let pages = fixture.pages
        pages.regularPane = true
        pages.runsActualPageChanges = true
        pages.setValue(true, forKey: "doneInitialRefresh")
        fixture.app.compactWidthOverride = false
        fixture.app.selectedIntelligence = 0
        fixture.app.recentlyReadStories = NSMutableDictionary()
        fixture.app.unreadStoryHashes = NSMutableDictionary()
        fixture.app.recentlyReadFeeds = NSMutableSet()
        fixture.app.readStories = NSMutableArray()
        fixture.app.dictFeeds = ["1": ["id": 1, "feed_title": "Landscape reading", "active": 1]]
        fixture.app.dictUnreadCounts = ["1": ["nt": 27, "ps": 0, "ng": 0]]
        let collection = NextButtonReadingStories()
        collection.appDelegate = fixture.app
        collection.activeFeed = fixture.app.dictFeeds["1"] as? [AnyHashable: Any]
        collection.feedPage = 1
        let stories = (0..<30).map { index -> NSMutableDictionary in
            let value = story("next-button-\(index)", body: "<h2>Article \(index + 1)</h2>" + String(repeating: "<p>Prepared article \(index + 1). The Next button keeps the title list and this article moving smoothly together.</p>", count: 30))
            value["story_title"] = "Article \(index + 1): reading across the landscape story list"
            value["read_status"] = index < 3 ? 1 : 0
            value["story_timestamp"] = 1_800_000_000 - index
            value["intelligence"] = ["feed": 0, "author": 0, "tags": 0, "title": 0]
            return value
        }
        collection.activeFeedStories = stories
        collection.storyCount = Int32(stories.count)
        collection.calculateStoryLocations()
        fixture.app.storiesCollection = collection
        fixture.app.activeStory = stories[2] as? [AnyHashable: Any]
        let feed = NextButtonReadingFeed()
        fixture.app.testFeed = feed
        feed.appDelegate = fixture.app
        feed.storiesCollection = collection
        feed.dashboardIndex = -1
        feed.pageFinished = true
        feed.textSize = .long
        feed.view = UIView(frame: CGRect(x: 0, y: 38, width: 440, height: 700))
        let table = NextButtonReadingTable(frame: feed.view.bounds, style: .plain)
        table.estimatedRowHeight = 44
        table.contentInsetAdjustmentBehavior = .never
        feed.storyTitlesTable = table
        feed.messageView = UIView()
        feed.messageView.isHidden = true
        feed.setValue(NSCache<NSString, NSString>(), forKey: "storyPreviewTextCache")
        feed.setValue(NSCache<NSString, NSNumber>(), forKey: "storyHeightCache")
        table.dataSource = feed
        table.delegate = feed
        feed.view.addSubview(table)
        let root = UIViewController()
        root.view = UIView(frame: CGRect(x: 0, y: 0, width: 1100, height: 768))
        root.view.backgroundColor = .systemBackground
        root.addChild(feed)
        root.view.addSubview(feed.view)
        feed.didMove(toParent: root)
        root.addChild(pages)
        root.view.addSubview(pages.view)
        pages.didMove(toParent: root)
        pages.view.frame = CGRect(x: 440, y: 38, width: 660, height: 700)
        pages.scrollView.frame = pages.view.bounds
        pages.scrollView.contentInsetAdjustmentBehavior = .never
        pages.scrollView.contentSize = CGSize(width: 660 * 30, height: 700)
        let next = UIButton(type: .system)
        next.frame = CGRect(x: 960, y: 0, width: 120, height: 38)
        next.setTitle("Next unread →", for: .normal)
        next.addTarget(pages, action: NSSelectorFromString("doNextUnreadStory:"), for: .touchUpInside)
        root.view.addSubview(next)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = root.view.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()
        let articlePages = [pages.currentPage!, pages.nextPage!, pages.previousPage!]
        let initialLocations = [2, 3, 1]
        let motion = StorySelectionFrameRecorder(view: pages.currentPage.view, window: window, horizontal: true)
        let titles = NextButtonReadingRecorder(table: table, window: window, target: IndexPath(row: 3, section: 0))
        defer {
            motion.stop()
            titles.stop()
            table.delegate = nil
            pages.scrollView.delegate = nil
            pages.cancelPendingStoryPresentation()
            feed.cancelMarkStoryReadTimer()
            if ReadTimeTracker.shared.currentStoryHash?.hasPrefix("next-button-") == true {
                let hash = ReadTimeTracker.shared.currentStoryHash!
                ReadTimeTracker.shared.stopTracking()
                _ = ReadTimeTracker.shared.getAndResetReadTime(storyHash: hash)
            }
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
            for page in articlePages { page.webView.stopLoading(); page.webView = nil }
        }
        for (page, location) in zip(articlePages, initialLocations) {
            page.webView.removeFromSuperview()
            let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 660, height: 700), configuration: WKWebViewConfiguration())
            web.scrollView.contentInsetAdjustmentBehavior = .never
            page.webView = web
            page.view.addSubview(web)
            web.navigationDelegate = page
            page.view.frame = CGRect(x: CGFloat(location) * 660, y: 0, width: 660, height: 700)
            page.pageIndex = location
            page.activeStory = stories[location]
            page.activeStoryId = "next-button-\(location)"
            page.hasStory = true
            page.drawStory()
            page.prepareCurrentStoryForPresentation()
        }
        for _ in 0..<200 where articlePages.contains(where: { !$0.readyForPresentation }) { await delay(0.025) }
        XCTAssertTrue(articlePages.allSatisfy(\.readyForPresentation))
        for page in articlePages { page.finishStoryPresentation() }
        pages.scrollView.contentOffset = CGPoint(x: 2 * 660, y: 0)
        pages.scrollView.delegate = pages
        table.reloadData()
        table.layoutIfNeeded()
        table.selectRow(at: IndexPath(row: 2, section: 0), animated: false, scrollPosition: .none)
        let target = IndexPath(row: 3, section: 0)
        XCTAssertTrue(feed.isMarkReadOnScroll)
        XCTAssertTrue(table.bounds.intersects(table.rectForRow(at: target)))
        XCTAssertFalse(table.bounds.contains(table.rectForRow(at: target)))
        func attachPanes(_ name: String) {
            let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            })
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        attachPanes("Landscape before Next: third article open and fourth title partly visible")
        titles.start()
        motion.start()
        // StoryDetailLoadingTests.swift waits for the captured setup geometry to reach two displayed frames before starting a new UIKit animation.
        for _ in 0..<100 where titles.sampleTimes.count < 3 { await delay(0.005) }
        XCTAssertGreaterThanOrEqual(titles.sampleTimes.count, 3)
        XCTAssertEqual(pages.scrollView.layer.presentation()?.bounds.origin.x ?? -1, 2 * 660, accuracy: 0.5)
        XCTAssertEqual(pages.currentPage.pageIndex, 2)
        XCTAssertTrue(articlePages.allSatisfy(\.readyForPresentation))
        XCTAssertTrue(UIView.areAnimationsEnabled)
        table.rowReloads = 0
        feed.events.removeAll()
        feed.eventTimes.removeAll()
        let titlesFinished = expectation(description: "The native title reveal animation completes")
        feed.titleScrollDidFinish = { titlesFinished.fulfill() }
        let nextTappedAt = CACurrentMediaTime()
        // StoryDetailLoadingTests.swift drives the same UIButton action and real pager/list/read callbacks as the landscape app.
        next.sendActions(for: .touchUpInside)
        // StoryDetailLoadingTests.swift leaves both animations untouched while sampling; drawHierarchy(afterScreenUpdates:true) can complete UIKit animations.
        await fulfillment(of: [titlesFinished], timeout: 15)
        await waitForState("The completed title and article positions reach their displayed frames") {
            guard let titleOffset = titles.offsets.last, let articlePosition = motion.positions.last else { return false }
            let finalArticlePosition = articlePages[0].view.convert(CGPoint.zero, to: window).x
            return abs(titleOffset - table.contentOffset.y) < 0.5 &&
                abs(articlePosition - finalArticlePosition) < 0.5 && pages.currentPage.pageIndex == 3
        }
        titles.stop()
        motion.stop()
        XCTAssertEqual(Array(feed.events.prefix(3)), ["select", "read:next-button-3", "redraw"])
        XCTAssertEqual(pages.currentPage.activeStoryId, "next-button-3")
        XCTAssertEqual(table.indexPathForSelectedRow, target)
        XCTAssertTrue(table.bounds.contains(table.rectForRow(at: target)), "The completed reveal must show the entire fourth title")
        XCTAssertEqual(collection.syncedHashes, ["next-button-3"])
        XCTAssertFalse(collection.isStoryUnread(collection.activeFeedStories[3] as? [AnyHashable: Any]))
        XCTAssertTrue(collection.isStoryUnread(collection.activeFeedStories[4] as? [AnyHashable: Any]))
        XCTAssertEqual(table.rowReloads, 0, "The Next read update must preserve the ongoing title reveal")
        XCTAssertGreaterThan(Set(titles.offsets.map { Int($0.rounded()) }).count, 5)
        XCTAssertGreaterThan(Set(titles.cellPositions.map { Int($0.rounded()) }).count, 5)
        XCTAssertGreaterThan(Set(motion.positions.map { Int($0.rounded()) }).count, 5, "The article must keep its normal page animation")
        for (earlier, later) in zip(titles.offsets, titles.offsets.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later + 0.5, earlier, "Title table bounds must not jump backwards")
        }
        for (earlier, later) in zip(titles.cellPositions, titles.cellPositions.dropFirst()) {
            XCTAssertLessThanOrEqual(later, earlier + 0.5, "The drawn fourth cell must continuously move up into view")
        }
        func assertContinuous(_ values: [CGFloat], times: [CFTimeInterval], frameDurations: [CFTimeInterval], name: String) {
            guard values.count > 1 else { return }
            let travel = abs((values.last ?? 0) - (values.first ?? 0))
            for index in 1..<values.count {
                let elapsed = times[index] - times[index - 1]
                let maximumStep = NextButtonReadingRecorder.maximumContinuousStep(
                    travel: travel, elapsed: elapsed, frameDuration: frameDurations[index])
                XCTAssertLessThanOrEqual(abs(values[index] - values[index - 1]), maximumStep,
                                         "\(name) jumped in \(elapsed)s: \(values[index - 1]) → \(values[index])")
            }
        }
        assertContinuous(titles.offsets, times: titles.sampleTimes, frameDurations: titles.frameDurations, name: "Title table")
        assertContinuous(titles.cellPositions, times: titles.cellSampleTimes, frameDurations: titles.cellFrameDurations, name: "Drawn target cell")
        let body = try await pages.currentPage.webView.evaluateJavaScript("document.querySelector('#NB-story').textContent") as? String
        XCTAssertTrue(body?.contains("Prepared article 4") == true)
        attachPanes("Landscape after Next: fourth title selected and read beside the actual fourth article")
        print("NEXT_BUTTON_LANDSCAPE reloads=\(table.rowReloads) callbacks=\(feed.events) callback_times=\(feed.eventTimes.map { $0 - nextTappedAt }) times=\(titles.sampleTimes.map { $0 - nextTappedAt }) table=\(titles.offsets) drawn_cell=\(titles.cellPositions) article=\(motion.positions)")
    }

    func test_nextButtonMotionSamplingAllowsOneDisplayFrameButRejectsASnapAfterADelayedCallback() {
        // StoryDetailLoadingTests.swift replays the hosted trace that missed the 155.67-point
        // presentation snapshot: 111 → 204.67 was reported only 13.47 ms apart after a callback gap.
        let times: [CFTimeInterval] = [0.1277251667, 0.1443918333, 0.2642516667, 0.2777251667,
                                      0.2943918333, 0.3110585, 0.3277251667, 0.3443918333,
                                      0.3610585, 0.3777251667, 0.3943918333, 1.5831730417]
        let offsets: [CGFloat] = [0, 0, 111, 204.6666666667, 257, 311, 365, 417.3333333333,
                                  466.6666666667, 511, 549.3333333333, 622]
        func excessiveSteps(_ positions: [CGFloat]) -> [Int] {
            let travel = abs(positions.last! - positions.first!)
            return (1..<positions.count).filter { index in
                abs(positions[index] - positions[index - 1]) > NextButtonReadingRecorder.maximumContinuousStep(
                    travel: travel, elapsed: times[index] - times[index - 1], frameDuration: 1.0 / 60)
            }
        }
        XCTAssertTrue(excessiveSteps(offsets).isEmpty)
        XCTAssertTrue(excessiveSteps(offsets.map { 660 - $0 }).isEmpty, "Drawn cell geometry has the same sampling tolerance")

        var jumpedOffsets = offsets
        jumpedOffsets[3] = 400
        XCTAssertTrue(excessiveSteps(jumpedOffsets).contains(3), "The preceding 119.86 ms gap must not excuse a new sudden jump")
        var snappedOffsets = offsets
        for index in 3..<snappedOffsets.count { snappedOffsets[index] = 622 }
        XCTAssertTrue(excessiveSteps(snappedOffsets).contains(3), "A snap to the destination must still fail")
    }

    func test_refreshWhileASelectedArticleIsPaintingDoesNotReturnToThePreviousStory() async throws {
        let fixture = makePresentationFixture()
        fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.value(forKey: "pendingPresentationPage") as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        fixture.pages.refreshPages()
        XCTAssertEqual(fixture.pages.pageChanges, [], "A background refresh must wait for the selected article, not navigate back")
        XCTAssertEqual(selected.pageIndex, 2)
        sendReady(to: selected, token: token, mainFrame: true)
        await delay(0.1)
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-9")
        XCTAssertEqual(fixture.app.presentations, 1)
    }

    func test_readerEntranceDoesNotWaitForArticleReadiness() async throws {
        let fixture = makePresentationFixture()
        fixture.app.compactWidthOverride = true
        fixture.app.feedsNavigationController = UINavigationController(rootViewController: UIViewController())
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()

        XCTAssertEqual(fixture.app.presentations, 1, "StoryDetailLoadingTests.swift requires the reader shell to open before WebKit is ready")
        XCTAssertEqual(fixture.pages.currentPage.activeStoryId, "item-3")
        XCTAssertFalse(fixture.pages.currentPage.readyForPresentation)
        XCTAssertTrue(fixture.pages.currentPage.webView.isHidden || fixture.pages.currentPage.webView.alpha < 0.01,
                      "The unfinished story must remain invisible during the early reader entrance")
    }

    func test_earlyReaderKeepsArticleInvisibleUntilFinalLayoutAndFadesOnlyOnce() async throws {
        let tracker = ReadTimeTracker.shared
        let previousTrackingHash = tracker.currentStoryHash
        defer {
            tracker.stopTracking()
            if let previousTrackingHash { tracker.startTracking(storyHash: previousTrackingHash) }
        }
        let fixture = makePresentationFixture()
        fixture.app.compactWidthOverride = true
        fixture.app.feedsNavigationController = UINavigationController(rootViewController: UIViewController())
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        web.defersAsyncJavaScript = true
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        sendReady(to: selected, token: token, mainFrame: true)
        await drainMainQueue()
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertFalse(web.isHidden, "WebKit must still paint the invisible document")
        XCTAssertEqual(web.alpha, 0)
        XCTAssertTrue(web.accessibilityElementsHidden)
        XCTAssertFalse(selected.readyForPresentation)
        XCTAssertNil(tracker.currentStoryHash, "Preparing invisible HTML is not reading time")
        let render = try XCTUnwrap(web.asyncCompletions.first)
        web.asyncCompletions.removeFirst()
        render(true, nil)
        await delay(0.2)
        XCTAssertTrue(selected.readyForPresentation)
        XCTAssertEqual(web.alpha, 1)
        XCTAssertFalse(web.accessibilityElementsHidden)
        XCTAssertEqual(tracker.currentStoryHash, "item-3")
        XCTAssertEqual(fixture.app.presentations, 1, "Readiness must not push the reader a second time")
        XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationPage"))
    }

    func test_backDuringEarlyEntranceRejectsLateReadiness() async throws {
        let fixture = makePresentationFixture()
        fixture.app.compactWidthOverride = true
        fixture.app.feedsNavigationController = UINavigationController(rootViewController: UIViewController())
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        web.defersAsyncJavaScript = true
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        sendReady(to: selected, token: token, mainFrame: true)
        await drainMainQueue()
        let render = try XCTUnwrap(web.asyncCompletions.first)
        fixture.app.showFeedsList(animated: false)
        render(true, nil)
        sendReady(to: selected, token: token, mainFrame: true)
        XCTAssertTrue(web.isHidden)
        XCTAssertFalse(selected.readyForPresentation)
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationPage"))
        XCTAssertFalse(selected.hasStory)
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let reopened = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let reopenedWeb = try XCTUnwrap(reopened.webView as? RecordedStoryLoadWebView)
        reopenedWeb.defersAsyncJavaScript = false
        sendReady(to: reopened, token: try tokenFromHTML(XCTUnwrap(reopenedWeb.loads.last).html), mainFrame: true)
        await delay(0.2)
        XCTAssertTrue(reopened.readyForPresentation)
        XCTAssertFalse(reopenedWeb.isHidden)
        XCTAssertEqual(reopenedWeb.alpha, 1)
        XCTAssertEqual(fixture.app.presentations, 2)
    }

    func test_earlyEntranceSurvivesLayoutWithoutReloadingItsDocument() async throws {
        let fixture = makePresentationFixture()
        fixture.app.compactWidthOverride = true
        fixture.app.feedsNavigationController = UINavigationController(rootViewController: UIViewController())
        fixture.pages.runsActualPageChanges = true
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        XCTAssertEqual(web.loads.filter { $0.html.contains("Article 3") }.count, 1)
        let navigationCount = web.loads.count // StoryDetailLoadingTests.swift includes clearWebView's empty reset document.
        fixture.pages.scrollView.frame.size.width = 600
        fixture.pages.applyNewIndex(1, pageController: selected)
        XCTAssertEqual(web.loads.count, navigationCount)
        XCTAssertEqual(web.alpha, 0)
        sendReady(to: selected, token: try tokenFromHTML(XCTUnwrap(web.loads.last).html), mainFrame: true)
        await delay(0.2)
        XCTAssertEqual(web.bounds.width, 600)
        XCTAssertEqual(web.alpha, 1)
        XCTAssertEqual(fixture.app.presentations, 1)
    }

    func test_changedFeedDuringEarlyEntranceCannotRevealTheOldStory() async throws {
        let fixture = makePresentationFixture()
        fixture.app.compactWidthOverride = true
        fixture.app.feedsNavigationController = UINavigationController(rootViewController: UIViewController())
        let feed = FeedDetailViewController()
        fixture.app.testFeed = feed
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        await drainMainQueue()
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        let token = try tokenFromHTML(XCTUnwrap(web.loads.last).html)
        feed.fetchRequestId += 1
        sendReady(to: selected, token: token, mainFrame: true)
        await drainMainQueue()
        XCTAssertTrue(web.isHidden)
        XCTAssertFalse(selected.hasStory)
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertNil(fixture.pages.value(forKey: "pendingPresentationPage"))
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

    func test_explicitNextOrSwipeCancelsStagedSelectionBeforeNormalPageNavigation() async throws {
        for swipe in [false, true] {
            let fixture = makePresentationFixture()
            fixture.app.activeStory = fixture.stories[9] as? [AnyHashable: Any]
            fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 2, "animated": true])
            // StoryDetailLoadingTests.swift yields for StoryDetailObjCViewController.m's queued HTML load.
            await drainMainQueue()
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
            await drainMainQueue()
            sendReady(to: selected, token: stale, mainFrame: true)
            await drainMainQueue()
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

    func test_earlyPhoneUsesItsPresentingWindowSafeAreaBeforeAttachment() async throws {
        let fixture = makePresentationFixture(width: 375)
        configurePhoneToolbar(app: fixture.app, pages: fixture.pages)
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
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        XCTAssertNil(fixture.pages.view.window)
        XCTAssertNil(selected.webView.window)
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
        await waitForState("Saved-position query reaches the held JavaScript restoration callback") {
            !web.asyncCompletions.isEmpty
        }
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
        configurePhoneToolbar(app: fixture.app, pages: fixture.pages)
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
        articleWindow.testSafeAreaTop = 0
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 1), 44, accuracy: 0.5,
                       "An attached landscape window with no status bar must not receive a portrait or notched-device inset")
        XCTAssertEqual(fixture.pages.topInset(forNavigationBarAlpha: 0), 44, accuracy: 0.5)
    }

    private func assertFirstArticleInsetThroughNativeHandoff(isRiver: Bool, savedPosition: Int? = nil, toolbarOffset: CGFloat = 0) async throws {
        let fixture = makePresentationFixture(width: 375)
        fixture.app.storiesCollection.isRiverView = isRiver
        configurePhoneToolbar(app: fixture.app, pages: fixture.pages)
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
        let selected = try XCTUnwrap(fixture.pages.currentPage as? StoryLoadPage)
        let web = try XCTUnwrap(selected.webView as? RecordedStoryLoadWebView)
        XCTAssertEqual(web.scrollView.contentInset.top, 64, accuracy: 0.5)
        fixture.pages.toolbarScrollHandler.setOffset(toolbarOffset)
        sendReady(to: selected, token: try tokenFromHTML(XCTUnwrap(web.loads.last).html), mainFrame: true)
        for _ in 0..<60 where !selected.readyForPresentation { await delay(0.02) }

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

    func test_realWebKitRevealsEarlyReaderWhileRemoteImageIsStillPending() async throws {
        let resource = try HeldHTTPStoryResource()
        for _ in 0..<60 where resource.port == nil { await delay(0.05) }
        let imageURL = try XCTUnwrap(resource.imageURL)
        let fixture = makePresentationFixture()
        // StoryDetailLoadingTests.swift exercises compact native navigation on both phone and iPad test hosts.
        fixture.app.compactWidthOverride = true
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
        // StoryDetailLoadingTests.swift observes the independent image request because DOM readiness can arrive before the local server receives it.
        let heldImage = expectation(description: "The early reader's image request reaches the held resource")
        resource.observeNextRequest { heldImage.fulfill() }
        fixture.app.activeStory = fixture.stories[3] as? [AnyHashable: Any]
        XCTAssertTrue(fixture.pages.shouldOpenReaderImmediately(), "The fixture must enter the reader before article readiness")
        fixture.app.perform(NSSelectorFromString("deferredChangePage:"), with: ["location": 1, "animated": true])
        for _ in 0..<100 where fixture.app.presentations == 0 { await delay(0.02) }
        XCTAssertEqual(fixture.app.presentations, 1)
        XCTAssertTrue(navigation.topViewController === fixture.pages)
        for _ in 0..<200 where !page.readyForPresentation { await delay(0.025) }
        XCTAssertTrue(page.readyForPresentation)
        await fulfillment(of: [heldImage], timeout: 15)
        XCTAssertGreaterThan(resource.pendingCount, 0)
        XCTAssertTrue(fixture.pages.currentPage === page)
        XCTAssertEqual(fixture.pages.unreadyAtNavigation, [true])
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

    func test_regularReaderRelayoutKeepsLiveScrollPositionInsteadOfSavedTop() async throws {
        let fixture = makePresentationFixture(width: 700)
        fixture.pages.regularPane = true
        fixture.app.setValue(ImmediateStoryScrollQueue(position: 1), forKey: "database")
        let page = fixture.original
        page.drawStory()
        await drainMainQueue()
        let web = try XCTUnwrap(page.webView as? RecordedStoryLoadWebView)
        sendReady(to: page, token: try tokenFromHTML(try XCTUnwrap(web.loads.last?.html)), mainFrame: true)
        await waitForState("Initial saved scroll restoration completes") {
            page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
        }
        web.scrollView.contentOffset.y = 1250
        page.setValue(true, forKey: "hasScrolled")
        // StoryPagesObjCViewController.m reorients the iPad reader when an image overlay returns.
        fixture.pages.reorientPages()
        await waitForState("Reader relayout finishes") {
            page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
        }
        XCTAssertEqual(web.scrollView.contentOffset.y, 1250, accuracy: 0.5,
                       "Returning from an image must preserve the live position even when the saved position is top")
    }

    func test_readerResizePreservesLiveFractionIncludingTopInsteadOfStaleSavedProgress() async throws {
        for initialOffset: CGFloat in [0, 1250] {
            let fixture = makeFixture()
            fixture.app.setValue(ImmediateStoryScrollQueue(position: 500), forKey: "database")
            fixture.page.drawStory()
            await drainMainQueue()
            sendReady(to: fixture.page, token: try tokenFromHTML(try XCTUnwrap(fixture.web.loads.last?.html)), mainFrame: true)
            await waitForState("Initial saved scroll restoration completes") {
                fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
            }
            fixture.web.scrollView.contentOffset.y = initialOffset
            let coordinator = StoryResizeCoordinator()
            fixture.page.viewWillTransition(to: CGSize(width: 700, height: 600), with: coordinator)
            // StoryDetailLoadingTests.swift models WebKit's content reflow between capturing and restoring progress.
            fixture.web.scrollView.contentSize.height = 4000
            coordinator.runAnimations()
            await waitForState("Resize restores live reading progress") {
                fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
            }
            let expected = initialOffset > 0 ? initialOffset / 5000 * 4000 : -fixture.web.scrollView.adjustedContentInset.top
            XCTAssertEqual(fixture.web.scrollView.contentOffset.y, expected, accuracy: 0.5)
        }
    }

    func test_readerResizeDoesNotOverrideDraggingAfterWebKitReflow() async throws {
        let fixture = makeFixture()
        fixture.app.setValue(ImmediateStoryScrollQueue(position: 1), forKey: "database")
        fixture.page.drawStory()
        await drainMainQueue()
        sendReady(to: fixture.page, token: try tokenFromHTML(try XCTUnwrap(fixture.web.loads.last?.html)), mainFrame: true)
        await waitForState("Initial saved scroll restoration completes") {
            fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
        }
        fixture.web.scrollView.contentOffset.y = 1250
        fixture.web.defersAsyncJavaScript = true
        let coordinator = StoryResizeCoordinator()
        fixture.page.viewWillTransition(to: CGSize(width: 700, height: 600), with: coordinator)
        coordinator.runAnimations()
        await waitForState("Resize waits for WebKit layout") { !fixture.web.asyncCompletions.isEmpty }
        fixture.web.trackedScroll.simulatesDragging = true
        fixture.web.scrollView.contentOffset.y = 1800
        fixture.web.asyncCompletions.removeFirst()(true, nil)
        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 1800)
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
    }

    func test_readerResizeIgnoresPositionCapturedBeforeNewStoryOrExplicitScroll() async throws {
        for replacesStory in [false, true] {
            let fixture = makeFixture()
            fixture.app.setValue(ImmediateStoryScrollQueue(position: 1), forKey: "database")
            fixture.page.drawStory()
            await drainMainQueue()
            sendReady(to: fixture.page, token: try tokenFromHTML(try XCTUnwrap(fixture.web.loads.last?.html)), mainFrame: true)
            await waitForState("Initial saved scroll restoration completes") {
                fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
            }
            fixture.web.scrollView.contentOffset.y = 1250
            let coordinator = StoryResizeCoordinator()
            fixture.page.viewWillTransition(to: CGSize(width: 700, height: 600), with: coordinator)
            if replacesStory {
                fixture.page.drawStory()
            } else {
                XCTAssertTrue(requestScrollToTop(on: fixture.page))
            }
            fixture.web.scrollView.contentOffset.y = 0
            fixture.web.defersAsyncJavaScript = true
            coordinator.runAnimations()
            await drainMainQueue()
            XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false,
                           "A stale size transition must not start another saved-position restoration")
            XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 0)
        }
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
        configurePhoneToolbar(app: app, pages: pages)
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
                    configurePhoneToolbar(app: app, pages: pages)
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
                    await waitForState("Saved top restoration completes") {
                        fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
                    }

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
        configurePhoneToolbar(app: app, pages: pages)
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
            await waitForState("Saved position reaches the held layout callback") {
                !fixture.web.asyncCompletions.isEmpty
            }
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

#if targetEnvironment(macCatalyst)
    func test_regularMacArticleRestoresZeroWithoutAPhoneToolbarInset() async throws {
        let app = StoryLoadAppDelegate()
        app.compactWidthOverride = false
        let pages = StoryLoadToolbarPages(nibName: nil, bundle: nil)
        app.testPages = pages
        defer { app.testPages = nil }
        pages.appDelegate = app
        pages.storyToolbar = StoryToolbar()
        pages.storyToolbar.isHidden = true
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        app.setValue(ImmediateStoryScrollQueue(position: 0), forKey: "database")
        let fixture = makeFixture(app: app)
        pages.currentPage = fixture.page
        fixture.page.drawStory()
        await drainMainQueue()
        fixture.page.viewWillAppear(false)
        fixture.web.scrollView.contentOffset.y = 777

        sendReady(to: fixture.page, token: try tokenFromHTML(XCTUnwrap(fixture.web.loads.last).html), mainFrame: true)
        for _ in 0..<100 where fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == true {
            await delay(0.01)
        }

        XCTAssertFalse(pages.useCustomToolbar)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 1), 0)
        XCTAssertEqual(fixture.web.scrollView.adjustedContentInset.top, 0)
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 0)
    }
#endif

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
            await waitForState("Production SQLite writer persists scroll position") {
                var statement: OpaquePointer?
                XCTAssertEqual(sqlite3_prepare_v2(connection, "SELECT scroll FROM story_scrolls", -1, &statement, nil), SQLITE_OK)
                if sqlite3_step(statement) == SQLITE_ROW { stored = Int(sqlite3_column_int(statement, 0)) }
                sqlite3_finalize(statement)
                return stored != nil
            }
            XCTAssertEqual(stored, max(1, position))
            fixture.page.drawStory()
            await delay(0.15)
            fixture.page.viewWillAppear(false)
            fixture.web.scrollView.contentOffset = .zero
            restoreScroll(on: fixture.page)
            await waitForState("Persisted scroll position restoration completes") {
                fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
            }

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
        await waitForState("The saved-position query reaches its held first-paint callback") {
            !fixture.web.asyncCompletions.isEmpty
        }
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
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, true)
        // StoryDetailLoadingTests.swift must capture the low-priority database read before releasing it; a timed-out wait must not consume an empty fixture.
        let queryStarted = await XCTWaiter.fulfillment(of: [database.started], timeout: 15)
        XCTAssertEqual(queryStarted, .completed, "The saved-position query must be held before the page disappears")
        guard queryStarted == .completed else { return }

        fixture.page.viewWillDisappear(false)
        await delay(0.05)
        XCTAssertTrue(app.positions.isEmpty)

        let restored = expectation(description: "The held saved-position result reaches its main-queue restoration callback")
        database.release { restored.fulfill() }
        await fulfillment(of: [restored], timeout: 15)
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, fixture.web.scrollView.contentSize.height / 2)
        let stored = expectation(description: "Restored progress reaches the asynchronous position writer")
        app.observeNextPosition { _ in stored.fulfill() }
        fixture.page.viewWillDisappear(false)
        await fulfillment(of: [stored], timeout: 15)
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
            let stored = expectation(description: "Keyboard progress reaches the asynchronous position writer")
            app.observeNextPosition { _ in stored.fulfill() }
            XCTAssertTrue(fixture.page.hasStory)
            XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
            XCTAssertEqual(fixture.page.value(forKey: "hasScrolled") as? Bool, true)
            fixture.page.viewWillDisappear(false)
            await fulfillment(of: [stored], timeout: 2)
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
        let stored = expectation(description: "Fresh article keyboard progress reaches the asynchronous position writer")
        app.observeNextPosition { _ in stored.fulfill() }
        XCTAssertTrue(fixture.page.hasStory)
        XCTAssertEqual(fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool, false)
        XCTAssertEqual(fixture.page.value(forKey: "hasScrolled") as? Bool, true)
        fixture.page.viewWillDisappear(false)
        await fulfillment(of: [stored], timeout: 2)

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
        await waitForState("Saved position is restored before status-bar scrolling") {
            fixture.page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false
        }
        XCTAssertEqual(fixture.web.scrollView.contentOffset.y, 2_500)
        fixture.web.scrollView.contentInset.top = 64

        XCTAssertTrue(requestScrollToTop(on: fixture.page))
        fixture.web.scrollView.contentOffset.y = -fixture.web.scrollView.adjustedContentInset.top
        let stored = expectation(description: "Status-bar top reaches the asynchronous position writer")
        app.observeNextPosition { _ in stored.fulfill() }
        fixture.page.viewWillDisappear(false)
        await fulfillment(of: [stored], timeout: 2)

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
        let stored = expectation(description: "Status-bar top reaches the asynchronous position writer while the old read is pending")
        let oldReadDelivered = expectation(description: "The cancelled saved-position result reaches its main-queue guard")
        app.observeNextPosition { _ in stored.fulfill() }
        fixture.page.viewWillDisappear(false)
        database.release { oldReadDelivered.fulfill() }
        await fulfillment(of: [stored, oldReadDelivered], timeout: 2)

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

            let stored = reusesPage ? nil : expectation(description: "Completed status-bar scroll reaches the asynchronous position writer")
            if let stored { app.observeNextPosition { _ in stored.fulfill() } }
            let storageRequests = fixture.page.positionStorageRequests
            let selector = NSSelectorFromString("scrollViewDidScrollToTop:")
            XCTAssertTrue(fixture.page.responds(to: selector), "StoryDetailObjCViewController.m must persist the explicit completed native action.")
            if fixture.page.responds(to: selector) {
                typealias Call = @convention(c) (AnyObject, Selector, UIScrollView) -> Void
                unsafeBitCast(fixture.page.method(for: selector), to: Call.self)(fixture.page, selector, fixture.web.scrollView)
                XCTAssertEqual(fixture.page.positionStorageRequests - storageRequests, reusesPage ? 0 : 1,
                               "A reused document must reject the old scroll completion before scheduling persistence")
                if let stored { await fulfillment(of: [stored], timeout: 5) }
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

    func test_imageWithoutSourceDoesNotBlockStoryPresentation() async throws {
        try await checkStalledStoryRendering(restoresPosition: false, includesSourcelessImage: true)
    }

    func test_optionalVideoSetupFailureDoesNotBlockStoryPresentation() async throws {
        try await checkStalledStoryRendering(restoresPosition: false, failsVideoSetup: true)
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
                                           preparesOffWindow: Bool = false, includesSourcelessImage: Bool = false,
                                           failsVideoSetup: Bool = false) async throws {
        let resource = try HeldHTTPStoryResource()
        for _ in 0..<60 where resource.port == nil { await delay(0.05) }
        let imageURL = try XCTUnwrap(resource.imageURL)
        let configuration = WKWebViewConfiguration()
        let web = RealStoryLoadWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        web.failsVideoSetup = failsVideoSetup
        let page = makePage(web: web)
        page.allowsAppearanceCallbacks = false
        if restoresPosition { page.appDelegate.setValue(ImmediateStoryScrollQueue(), forKey: "database") }
        page.shareHTML = "<img src='\(imageURL)' width='30' height='30'>"
        let missingImage = includesSourcelessImage ? "<img id='missing-source' alt='Image without a source'>" : ""
        page.activeStory = story("first", body: missingImage + String(repeating: "<p>Readable article paragraph.</p>", count: 150))
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
            await waitForState("All off-window bootstrap font promises complete") {
                detachedPages.allSatisfy { $0.value(forKey: "preparedWebViewFonts") as? Bool == true }
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
        await waitForState("Bootstrap navigation and font preparation complete") {
            page.finishedNavigations > 0 && page.value(forKey: "preparedWebViewFonts") as? Bool == true
        }
        XCTAssertEqual(page.finishedNavigations, 1)
        page.finishedNavigations = 0
        let imageRequested = expectation(description: "Story image reaches the held HTTP resource")
        resource.observeNextRequest { imageRequested.fulfill() }
        let ready = expectation(description: "Full story DOM is ready while its image remains pending")
        page.readyObserver = { ready.fulfill() }
        page.drawStory()
        await fulfillment(of: [ready, imageRequested], timeout: 15)
        _ = try await web.evaluateJavaScript("window.nbTestFontReady=false; document.fonts.ready.then(()=>window.nbTestFontReady=true); window.nbTestFrames=0; requestAnimationFrame(function count(){window.nbTestFrames++; if(window.nbTestFrames<120)requestAnimationFrame(count);});")
        await waitForState("Ready article receives its first native WebKit layout while the image is held") {
            window.layoutIfNeeded()
            return web.scrollView.contentSize.height > web.bounds.height + 500
        }

        XCTAssertGreaterThan(resource.pendingCount, 0)
        XCTAssertFalse(web.isHidden)
        let body = try await web.evaluateJavaScript("document.querySelector('#NB-story').textContent") as? String
        XCTAssertTrue(body?.contains("Readable article paragraph") == true)
        if includesSourcelessImage {
            let imageClass = try await web.evaluateJavaScript("document.querySelector('#missing-source').className") as? String
            XCTAssertEqual(imageClass, "NB-small-image")
        }
        if failsVideoSetup {
            let attemptedVideoSetup = try await web.evaluateJavaScript("window.nbTestVideoSetupFailed === true") as? Bool
            XCTAssertEqual(attemptedVideoSetup, true)
        }
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
            await waitForState("Real WebKit saved position restoration and its scroll animation complete") {
                page.value(forKey: "awaitingStoryScrollRestoration") as? Bool == false &&
                    abs(web.scrollView.contentOffset.y - readingPosition) <= 2
            }
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
            let secondImage = expectation(description: "The second story's image request reaches the held resource")
            resource.observeNextRequest { secondImage.fulfill() }
            page.readyObserver = { secondReady.fulfill() }
            page.perform(NSSelectorFromString("clearWebView"))
            page.activeStory = story("second", body: String(repeating: "<p>Second article paragraph.</p>", count: 220))
            page.drawStory()
            await fulfillment(of: [secondReady, secondImage], timeout: 15)
            await waitForState("Second article receives its larger native WebKit layout") {
                web.scrollView.contentSize.height > previousHeight + 500
            }
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
            web.stopLoading()
            web.navigationDelegate = nil
            web.removeFromSuperview()
            resource.stop()
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        web.isHidden = false
        web.navigationDelegate = navigationDelegate
        let notify = notifiesNative ? "<script>document.addEventListener('DOMContentLoaded',function(){window.location='http://ios.newsblur.com/notify-loaded';});</script>" : ""
        let html = "<html><body><img src='\(imageURL)' width='30' height='30'>" + String(repeating: "<p>Plain WebKit control paragraph.</p>", count: 150) + notify + "</body></html>"
        // StoryDetailLoadingTests.swift waits for the independent network operation as
        // well as document layout; contentSize can grow before the image request arrives.
        let heldImage = expectation(description: "The plain WebKit image request reaches the held resource")
        resource.observeNextRequest { heldImage.fulfill() }
        web.loadHTMLString(html, baseURL: nil)
        await fulfillment(of: [heldImage], timeout: 3)
        for _ in 0..<60 where web.scrollView.contentSize.height < web.bounds.height + 500 {
            await delay(0.05)
        }
        XCTAssertEqual(resource.pendingCount, 1)
        XCTAssertGreaterThan(web.scrollView.contentSize.height, web.bounds.height + 500)
    }

    private func configurePhoneToolbar(app: StoryGeometryAppDelegate, pages: StoryLoadToolbarPages) {
        // StoryDetailLoadingTests.swift explicitly selects the phone layout instead of inheriting the test host's idiom.
        app.compactWidthOverride = true
        pages.customToolbarOverride = true
        pages.storyToolbar = StoryToolbar()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
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

    // StoryDetailLoadingTests.swift waits for observable work, not an assumed low-priority queue or WebKit startup speed.
    private func waitForState(_ description: String, timeout: TimeInterval = 15,
                              file: StaticString = #filePath, line: UInt = #line,
                              _ condition: () -> Bool) async {
        let deadline = CACurrentMediaTime() + timeout
        while !condition(), CACurrentMediaTime() < deadline { await delay(0.01) }
        XCTAssertTrue(condition(), description, file: file, line: line)
    }

    private func drainMainQueue() async { await delay(0.01) }

    private func delay(_ seconds: Double) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { continuation.resume() }
        }
    }
}

private class StoryGeometryAppDelegate: NewsBlurAppDelegate {
    var compactWidthOverride: Bool?
    override var isCompactWidth: Bool { compactWidthOverride ?? super.isCompactWidth }
}

private final class StoryLoadAppDelegate: StoryGeometryAppDelegate {
    var testPages: StoryPagesViewController?
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set { testPages = newValue }
    }
}

private final class StoryScrollStoreAppDelegate: NewsBlurAppDelegate {
    private let lock = NSLock()
    private var savedPositions: [Int] = []
    private var nextPositionObserver: ((Int) -> Void)?
    var positions: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return savedPositions
    }
    override func markScrollPosition(_ position: Int, inStory story: [AnyHashable: Any]!) {
        lock.lock()
        savedPositions.append(position)
        let observer = nextPositionObserver
        nextPositionObserver = nil
        lock.unlock()
        observer?(position)
    }
    func observeNextPosition(_ observer: @escaping (Int) -> Void) {
        lock.lock()
        nextPositionObserver = observer
        lock.unlock()
    }
}

@MainActor private class StoryLoadToolbarPages: StoryPagesViewController {
    var customToolbarOverride: Bool?
    var runsActualScrollSizing = false
    override var useCustomToolbar: Bool { customToolbarOverride ?? super.useCustomToolbar }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func setTextButton() {}
    override func setTextButton(_ storyViewController: StoryDetailViewController!) {}
    override func resizeScrollView() { if runsActualScrollSizing { super.resizeScrollView() } }
    override func updateUITestTraverseFadeProbe() {}
}

@MainActor private final class StoryPresentationApp: StoryGeometryAppDelegate {
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
    var regularPane = false
    @objc(isPhoneOrCompact) func usesPhoneOrCompactLayout() -> Bool {
        !regularPane && (UIDevice.current.userInterfaceIdiom == .phone || appDelegate.isCompactWidth)
    }
    weak var navigationForPresentation: UINavigationController?
    var pageChanges: [Int] = []
    var hiddenAtNavigation: [Bool] = []
    var unreadyAtNavigation: [Bool] = []
    var runsActualPageChanges = false
    var beforeNavigation: ((StoryDetailViewController) -> Void)?
    var selectionTransitionStarted: (([StoryDetailViewController]) -> Void)?
    @objc(animatePreparedStorySelection:location:) func observeSelectionTransition(_ page: StoryDetailViewController, location: Int) {
        let selector = NSSelectorFromString("animatePreparedStorySelection:location:")
        typealias Call = @convention(c) (AnyObject, Selector, StoryDetailViewController, Int) -> Void
        let implementation = class_getMethodImplementation(StoryPagesObjCViewController.self, selector)!
        unsafeBitCast(implementation, to: Call.self)(self, selector, page, location)
        // StoryDetailLoadingTests.swift inspects the live transition at its start, before its short animation can complete between polling turns.
        guard let animator = value(forKey: "storySelectionAnimator") as? UIViewPropertyAnimator,
              animator.state == .active,
              let pages = value(forKey: "storySelectionTransitionPages") as? [StoryDetailViewController] else { return }
        let observer = selectionTransitionStarted
        selectionTransitionStarted = nil
        observer?(pages)
    }
    override func changePage(_ pageIndex: Int, animated: Bool) {
        pageChanges.append(pageIndex)
        hiddenAtNavigation.append(currentPage.webView.isHidden)
        unreadyAtNavigation.append(!currentPage.readyForPresentation)
        beforeNavigation?(currentPage)
        if runsActualPageChanges { super.changePage(pageIndex, animated: animated) }
        navigationForPresentation?.pushViewController(self, animated: animated)
    }
    override func animate(intoPlace animated: Bool) {}
    // StoryDetailLoadingTests.swift supplies no storyboard toolbar and keeps navigation on the isolated account.
    override func updateStoryTitleNavigationButtons() {}
}

@MainActor private final class StorySelectionFrameRecorder: NSObject {
    private weak var observedView: UIView?
    private weak var window: UIWindow?
    private let horizontal: Bool
    private var displayLink: CADisplayLink?
    private(set) var positions: [CGFloat] = []

    init(view: UIView, window: UIWindow, horizontal: Bool) {
        observedView = view
        self.window = window
        self.horizontal = horizontal
    }

    func start() {
        recordFrame()
        displayLink = CADisplayLink(target: self, selector: #selector(recordFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() { displayLink?.invalidate(); displayLink = nil }

    @objc private func recordFrame() {
        // StoryDetailLoadingTests.swift measures the actual presented article position through its animated ancestors.
        guard let layer = observedView?.layer.presentation(), let root = window?.layer.presentation() else { return }
        let point = layer.convert(CGPoint.zero, to: root)
        positions.append(horizontal ? point.x : point.y)
    }
}

private final class NextButtonReadingStories: StoriesCollection {
    var syncedHashes: [String] = []
    override func syncStory(asRead story: [AnyHashable: Any]!) {
        // StoryDetailLoadingTests.swift intercepts only server transport; local read state and counts use StoriesCollection.m.
        if let hash = story["story_hash"] as? String { syncedHashes.append(hash) }
    }
}

@MainActor private final class NextButtonReadingFeed: FeedDetailViewController {
    var events: [String] = []
    var eventTimes: [CFTimeInterval] = []
    var titleScrollDidFinish: (() -> Void)?
    override var isLegacyTable: Bool { true }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 200 }
    override func changeActiveFeedDetailRow() {
        events.append("select")
        eventTimes.append(CACurrentMediaTime())
        super.changeActiveFeedDetailRow()
    }
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        if !isScrolling {
            events.append("read:" + (story["story_hash"] as? String ?? "missing"))
            eventTimes.append(CACurrentMediaTime())
        }
        return super.markStoryReadIfNeeded(story, isScrolling: isScrolling)
    }
    override func redrawUnreadStory() {
        events.append("redraw")
        eventTimes.append(CACurrentMediaTime())
        super.redrawUnreadStory()
    }
    @objc(scrollViewDidEndScrollingAnimation:) func storyTitlesDidFinishScrolling(_ scroll: UIScrollView) {
        guard scroll === storyTitlesTable else { return }
        let completion = titleScrollDidFinish
        titleScrollDidFinish = nil
        completion?()
    }
    @objc(updateBottomNextFeedControlForScroll:) func omitUnrelatedPullToNextFeedChrome(_ scroll: UIScrollView) {}
}

@MainActor private final class NextButtonReadingTable: UITableView {
    var rowReloads = 0
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloads += 1
        super.reloadRows(at: indexPaths, with: animation)
    }
}

@MainActor private final class NextButtonReadingRecorder: NSObject {
    let table: UITableView
    let window: UIWindow
    let target: IndexPath
    private var displayLink: CADisplayLink?
    private(set) var offsets: [CGFloat] = []
    private(set) var cellPositions: [CGFloat] = []
    private(set) var sampleTimes: [CFTimeInterval] = []
    private(set) var cellSampleTimes: [CFTimeInterval] = []
    private(set) var frameDurations: [CFTimeInterval] = []
    private(set) var cellFrameDurations: [CFTimeInterval] = []

    static func maximumContinuousStep(travel: CGFloat, elapsed: CFTimeInterval, frameDuration: CFTimeInterval) -> CGFloat {
        // StoryDetailLoadingTests.swift allows one nominal frame of presentation/timestamp skew,
        // independent of any preceding callback delay; it never carries a stall forward as motion credit.
        max(60, travel * CGFloat(elapsed + frameDuration) * 8.5 + 2)
    }
    init(table: UITableView, window: UIWindow, target: IndexPath) {
        self.table = table
        self.window = window
        self.target = target
    }
    func start() {
        let link = CADisplayLink(target: self, selector: #selector(sample(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    func stop() { displayLink?.invalidate(); displayLink = nil }
    @objc private func sample(_ link: CADisplayLink) {
        guard let presentation = table.layer.presentation(), let root = window.layer.presentation() else { return }
        // StoryDetailLoadingTests.swift pairs presentation geometry with the displayed frame's timestamp, not a delayed main-thread callback's arrival time.
        offsets.append(presentation.bounds.origin.y)
        sampleTimes.append(link.timestamp)
        frameDurations.append(link.duration)
        if let cell = table.cellForRow(at: target)?.layer.presentation() {
            // StoryDetailLoadingTests.swift measures the actual cell through all animated ancestors, not only UITableView's model offset.
            cellPositions.append(cell.convert(CGPoint.zero, to: root).y)
            cellSampleTimes.append(link.timestamp)
            cellFrameDurations.append(link.duration)
        }
    }
}

@MainActor private final class StoryLoadPage: StoryDetailViewController {
    var widthUpdates = 0
    var classifierUpdates = 0
    var finishedNavigations = 0
    var shareHTML = "Fixture sharing"
    var readyObserver: (() -> Void)?
    var navigationActionObserver: ((WKNavigationAction) -> Void)?
    var allowsAppearanceCallbacks = true
    var recordsPosition = false
    var positionStorageRequests = 0
    var holdsStoryLoading = false

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
    @objc(loadStory) func loadFixtureStory() {
        guard !holdsStoryLoading else { return }
        let selector = NSSelectorFromString("loadStory")
        typealias Call = @convention(c) (AnyObject, Selector) -> Void
        let implementation = class_getMethodImplementation(StoryDetailObjCViewController.self, selector)!
        unsafeBitCast(implementation, to: Call.self)(self, selector)
    }
    @objc(storeScrollPosition:) func ignorePositionStorage(_ queue: Bool) {
        guard recordsPosition else { return }
        positionStorageRequests += 1
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

    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                          decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        navigationActionObserver?(navigationAction)
        super.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
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

private final class StoryReadyScriptMessage: NSObject {
    @objc let webView: WKWebView?
    @objc let frameInfo: StoryReadyFrame
    @objc let body: Any
    @objc let name: String
    init(web: WKWebView?, mainFrame: Bool, body: Any, name: String) {
        webView = web
        frameInfo = StoryReadyFrame(mainFrame: mainFrame)
        self.body = body
        self.name = name
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

    func release(completion: (() -> Void)? = nil) {
        lock.lock()
        let block = pending
        pending = nil
        lock.unlock()
        DispatchQueue.global().async {
            block?(StoryScrollDatabase())
            // StoryDetailLoadingTests.swift fences the main-queue result posted by StoryDetailObjCViewController.m before checking a cancelled restoration.
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
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
    var failsVideoSetup = false
    var restorationFrameObserver: ((CGSize) -> Void)?
    var selectionLoadObserver: ((String) -> Void)?

    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        // StoryDetailLoadingTests.swift retains the production HTTPS document origin for real WebKit checks.
        selectionLoadObserver?(string)
        // StoryDetailLoadingTests.swift injects a failing dependency before storyDetailView.js sets up media.
        let html = failsVideoSetup ? string.replacingOccurrences(of: "var loadImages = function() {", with:
            "$.fn.fitVids = function() { window.nbTestVideoSetupFailed = true; throw new Error('Video fixture failure'); }; var loadImages = function() {") : string
        return super.loadHTMLString(html, baseURL: baseURL ?? URL(string: "https://newsblur.com/"))
    }

    override func __callAsyncJavaScript(_ functionBody: String, arguments: [String: Any]?, inFrame frame: WKFrameInfo?, in contentWorld: WKContentWorld, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        var observedBody = functionBody
        if functionBody.contains("font.load()") {
            fontPreparationCalls += 1
            // StoryDetailLoadingTests.swift records the existing promise stages without initiating additional font work.
            observedBody = "window.nbTestFontStage='loading'; " + functionBody.replacingOccurrences(
                of: "await document.fonts.ready;", with: "window.nbTestFontStage='faces_loaded'; await document.fonts.ready; window.nbTestFontStage='set_ready';")
        }
        super.__callAsyncJavaScript(observedBody, arguments: arguments, inFrame: frame, in: contentWorld) { [weak self] result, error in
            if error == nil, functionBody == "await new Promise(requestAnimationFrame); await new Promise(requestAnimationFrame); return true;",
               let self {
                self.restorationFrameObserver?(self.scrollView.contentSize)
            }
            completionHandler?(result, error)
        }
    }
}

@MainActor private final class HeldHTTPStoryResource {
    private let listener: NWListener
    private var connections = [ObjectIdentifier: NWConnection]()
    private var pending = [ObjectIdentifier: NWConnection]()
    private var nextRequestObserver: (() -> Void)?
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

    func observeNextRequest(_ observer: @escaping () -> Void) { nextRequestObserver = observer }

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
            let observer = self.nextRequestObserver
            self.nextRequestObserver = nil
            observer?()
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
        nextRequestObserver = nil
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

@MainActor private final class StoryResizeCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    private var animations: [() -> Void] = []
    let containerView = UIView()
    let isAnimated = true
    let presentationStyle = UIModalPresentationStyle.none
    let initiallyInteractive = false
    let isInterruptible = true
    let isInteractive = false
    let isCancelled = false
    let transitionDuration: TimeInterval = 0.25
    let percentComplete: CGFloat = 0
    let completionVelocity: CGFloat = 1
    let completionCurve = UIView.AnimationCurve.easeInOut
    let targetTransform = CGAffineTransform.identity

    func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?,
                 completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
        animations.append { animation?(self); completion?(self) }
        return true
    }
    func animateAlongsideTransition(in view: UIView?, animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?,
                                    completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
        animate(alongsideTransition: animation, completion: completion)
    }
    func notifyWhenInteractionChanges(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func notifyWhenInteractionEnds(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }
    func runAnimations() {
        // StoryDetailLoadingTests.swift runs the resize callbacks after supplying the new document geometry.
        let pending = animations
        animations.removeAll()
        pending.forEach { $0() }
    }
}
