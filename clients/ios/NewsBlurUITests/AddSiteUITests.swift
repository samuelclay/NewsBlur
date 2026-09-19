import XCTest
import UIKit

final class AddSiteUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-newsblur-ui-testing",
            "-newsblur-ui-test-screen",
            "add-site",
            "-ApplePersistenceIgnoreState",
            "YES",
        ]
    }

    func test_addSiteSheetLaunchesInUiTestMode() {
        app.launch()

        XCTAssertTrue(app.textFields["add-site-url-field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["add-site-submit-button"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["add-site-folder-menu"].frame.midY,
                       app.buttons["add-site-submit-button"].frame.midY, accuracy: 3)
    }

    func test_addSiteStartsAtHalfHeightWithoutKeyboard() {
        app.launch()
        let field = app.textFields["add-site-url-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        // AddSiteUITests.swift checks the initial presentation before explicitly requesting text input.
        XCTAssertGreaterThan(field.frame.minY, app.frame.height * 0.45)
        XCTAssertLessThan(field.frame.minY, app.frame.height * 0.75)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "add-site-half-height-keyboard-hidden"
        attachment.lifetime = .keepAlways
        add(attachment)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    func test_quickAddShowsSourceShortcutsAndOpensYouTube() {
        app.launch()
        let shortcut = app.buttons["add-site-discover-youtube"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "quick-add-discovery-shortcuts"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(shortcut.isHittable)
        shortcut.tap()
        XCTAssertTrue(app.buttons["discover-tab-youtube"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Practical Engineering"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["discover-tab-youtube"].isSelected)
        XCTAssertTrue(app.buttons["discover-tab-youtube"].isHittable)
    }

    func test_addSiteAutocompleteSelectionAndSubmitDismissesSheet() {
        app.launch()

        let urlField = app.textFields["add-site-url-field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))

        urlField.tap()
        urlField.typeText("swift")

        let firstResult = app.buttons["add-site-autocomplete-row-0"]
        XCTAssertTrue(firstResult.waitForExistence(timeout: 10))
        firstResult.tap()

        XCTAssertEqual(urlField.value as? String, "https://ui-test.newsblur.example/swift.xml")

        let addButton = app.buttons["add-site-submit-button"]
        XCTAssertTrue(addButton.isEnabled)
        addButton.tap()

        XCTAssertTrue(urlField.waitForDisappearance(timeout: 10))
    }
}

private extension XCUIElement {
    func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

final class DiscoverSitesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func test_liveClayPadPopularPreviewKeepsStoryTitlesVisible() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        capture("claypad-discovery-before-preview")
        openLiveDiscovery()
        let popular = app.buttons["discover-tab-popular"]
        XCTAssertTrue(popular.waitForExistence(timeout: 10))
        popular.tap()
        let preview = app.buttons["Try The Guardian"]
        XCTAssertTrue(preview.waitForExistence(timeout: 30))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.75))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.68)),
                   withVelocity: XCUIGestureVelocity(rawValue: 120), thenHoldForDuration: 0.5)
        capture("claypad-popular-scrolled-before-try")
        XCTAssertTrue(isOnscreen(preview))
        let point = preview.frame
        XCTAssertGreaterThan(point.minY, app.frame.height * 0.23,
                             "The Try button must be below the fixed discovery header")
        app.coordinate(withNormalizedOffset: CGVector(dx: point.midX / app.frame.width,
                                                       dy: point.midY / app.frame.height)).tap()
        let titles = app.tables["story-titles-list"].firstMatch
        let visibleTitles = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard titles.exists else { return false }
            let rows = titles.cells.allElementsBoundByIndex.prefix(4).filter { self.isOnscreen($0) }
            return !rows.isEmpty && rows.allSatisfy { $0.label.hasPrefix("The Guardian,") }
        }, object: nil)
        let result = XCTWaiter.wait(for: [visibleTitles], timeout: 30)
        capture("claypad-popular-try-three-columns")
        XCTAssertEqual(result, .completed, "Try must display story titles beside the article on iPad")
        XCTAssertGreaterThan(titles.frame.width, 150)
        XCTAssertLessThan(titles.frame.maxX, app.frame.width - 150)
        let nextTitleIdentifier = try XCTUnwrap(titles.cells.allElementsBoundByIndex.prefix(4).first {
            isOnscreen($0) && $0.label.hasPrefix("The Guardian,")
                && !$0.isSelected
        }?.identifier)
        let nextTitle = titles.cells[nextTitleIdentifier]
        nextTitle.tap()
        let selectedTitle = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"),
                                                      object: nextTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [selectedTitle], timeout: 5), .completed,
                       "Visible story titles must respond to taps")
        XCTAssertTrue(app.buttons["discover-preview-back"].exists)
        app.buttons["discover-preview-back"].tap()
        XCTAssertTrue(popular.waitForExistence(timeout: 5))
        XCTAssertTrue(popular.isSelected)
        XCTAssertEqual(preview.frame.minY, point.minY, accuracy: 3,
                       "Returning to Discover must preserve the scrolled Popular page")
        capture("claypad-popular-return-preserves-discovery")
#endif
    }

    func test_liveClayPadPagerMovesWhileFingerIsDownAndCancelsPartialDrag() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        openLiveDiscovery()
        app.buttons["discover-tab-search"].tap()
        capture("claypad-pager-before-partial-drag")
        // AddSiteUITests.swift holds the drag for an external physical-device screenshot of both pages in flight.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.7))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.64, dy: 0.7)),
                   withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 8)
        let stayedOnSearch = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"),
                                                       object: app.buttons["discover-tab-search"])
        XCTAssertEqual(XCTWaiter.wait(for: [stayedOnSearch], timeout: 5), .completed,
                       "Releasing a partial drag without momentum should return to the current page")
        capture("claypad-pager-after-cancelled-drag")
#endif
    }

    func test_liveClayPadAddSheetUsesQuarterHeightAndLargeShortcuts() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        let field = app.textFields["add-site-url-field"]
        if !field.exists { app.buttons["feed-list-add"].tap() }
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("claypad-add-sheet-size-and-shortcuts")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertGreaterThan(field.frame.minY, app.frame.height * 0.65,
                             "The iPad quick-add sheet should open around quarter height")
        let youtube = app.buttons["add-site-discover-youtube"]
        XCTAssertTrue(youtube.exists)
        XCTAssertGreaterThanOrEqual(youtube.frame.height, 70)
        XCTAssertGreaterThanOrEqual(youtube.frame.width, 70)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        capture("claypad-add-sheet-keyboard-expanded")
        youtube.tap()
        XCTAssertTrue(app.buttons["discover-tab-youtube"].waitForExistence(timeout: 5))
#endif
    }

    func test_liveClayPadSwipesBetweenAllSourcesAndStopsAtEnds() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.activate()
        openLiveDiscovery()
        app.buttons["discover-tab-search"].tap()
        let sources = ["search", "webFeed", "popular", "youtube", "reddit", "newsletters", "podcasts", "googleNews"]
        func swipe(left: Bool, y: CGFloat) {
            app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.86 : 0.46, dy: y))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.46 : 0.86, dy: y)))
        }
        func expect(_ source: String) {
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"),
                                                     object: app.buttons["discover-tab-\(source)"])
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        }
        swipe(left: false, y: 0.6)
        expect("search")
        for (index, source) in sources.dropFirst().enumerated() {
            // AddSiteUITests.swift pages across source content while horizontal control rows keep their own gestures.
            let y: CGFloat = [0.7, 0.55, 0.65, 0.55, 0.65, 0.65, 0.55][index]
            swipe(left: true, y: y)
            expect(source)
            capture("claypad-discover-swipe-\(source)")
        }
        swipe(left: true, y: 0.6)
        expect("googleNews")
        for source in sources.dropLast().reversed() {
            swipe(left: false, y: 0.65)
            expect(source)
        }
#endif
    }

    func test_liveClayPadRedditTagsScrollWithoutChangingPages() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        openLiveDiscovery()
        let reddit = app.buttons["discover-tab-reddit"]
        reddit.tap()
        let tags = app.scrollViews["discover-category-row"].firstMatch
        XCTAssertTrue(tags.waitForExistence(timeout: 20))
        let anchor = try XCTUnwrap(tags.buttons.allElementsBoundByIndex.first { isOnscreen($0) })
        let anchorLabel = anchor.label
        let initialX = anchor.frame.minX
        let y = tags.frame.midY / app.frame.height
        capture("claypad-reddit-tags-before-drag")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: y))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: y)),
                   withVelocity: XCUIGestureVelocity(rawValue: 400), thenHoldForDuration: 0.5)
        capture("claypad-reddit-tags-after-drag")
        XCTAssertTrue(reddit.isSelected, "A horizontal tag-row drag must stay on Reddit")
        XCTAssertLessThan(tags.buttons[anchorLabel].frame.minX, initialX - 40,
                          "Dragging tags must move the tag row")
        for _ in 0..<2 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: y))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: y)),
                       withVelocity: XCUIGestureVelocity(rawValue: 400), thenHoldForDuration: 0.5)
            XCTAssertTrue(reddit.isSelected, "Tag-row gestures stay separate even at the row's leading edge")
        }
        capture("claypad-reddit-tags-back-at-start")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.65))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.65)))
        let movedToNewsletters = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"),
                                                           object: app.buttons["discover-tab-newsletters"])
        XCTAssertEqual(XCTWaiter.wait(for: [movedToNewsletters], timeout: 5), .completed,
                       "Dragging page content outside the tags must still change source")
#endif
    }

    private func openLiveDiscovery() {
        if app.buttons["discover-tab-popular"].exists { return }
        if app.buttons["discover-preview-back"].exists {
            app.buttons["discover-preview-back"].tap()
        } else {
            if !app.textFields["add-site-url-field"].exists { app.buttons["feed-list-add"].tap() }
            let shortcut = app.buttons["add-site-discover-popular"]
            XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
            shortcut.tap()
        }
        XCTAssertTrue(app.buttons["discover-tab-popular"].waitForExistence(timeout: 10))
    }

    func test_liveClayPadFolderPickerFitsBetweenTryAndAdd() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        openLiveDiscovery()
        app.buttons["discover-tab-popular"].tap()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let list = app.buttons["discover-view-mode-list"]
            XCTAssertTrue(list.waitForExistence(timeout: 15))
            XCTAssertEqual(list.label, "List")
            XCTAssertEqual(app.buttons["discover-view-mode-grid"].label, "Grid")
            list.tap()
            let picker = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-folder-picker-"))
                .firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 20))
            assertFolderPickerIsBesideAdd(picker)
            XCTAssertFalse(app.staticTexts["Add to folder"].exists)
            capture(orientation == .portrait ? "claypad-inline-folder-portrait" : "claypad-inline-folder-landscape")
            app.buttons["discover-view-mode-grid"].tap()
            assertFolderPickerIsBesideAdd(picker)
            capture(orientation == .portrait ? "claypad-compact-folder-grid-portrait" : "claypad-compact-folder-grid-landscape")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
#endif
    }

    private func requireLiveClayPad() throws {
        guard ProcessInfo.processInfo.environment["NEWSBLUR_LIVE_UI_TESTS"] == "1" else {
            throw XCTSkip("Run explicitly on signed-in ClayPad with TEST_RUNNER_NEWSBLUR_LIVE_UI_TESTS=1")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func test_liveClayPadStatusBarMatchesAllThemesAndPortraitLayout() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        let originalOrientation = XCUIDevice.shared.orientation
        XCUIDevice.shared.orientation = .landscapeRight
        defer {
            XCUIDevice.shared.orientation = originalOrientation
            app.launchArguments = []
            app.launch()
        }
        for theme in ["light", "sepia", "medium", "dark"] {
            app.launchArguments = ["-theme_style", theme, "-theme_light", "light", "-theme_dark", "dark"]
            app.launch()
            openLiveDiscovery()
            capture("claypad-discovery-status-\(theme)")
            let screenshot = XCUIScreen.main.screenshot().image
            // AddSiteUITests.swift applies the physical iPad screenshot's orientation before sampling pixels.
            let upright = UIGraphicsImageRenderer(size: screenshot.size).image { _ in
                screenshot.draw(at: .zero)
            }
            let image = try XCTUnwrap(upright.cgImage)
            XCTAssertGreaterThan(image.width, image.height, "Status-bar samples require the full landscape screenshot")
            let strip = try samplePixel(image, x: 0.8, y: 0.012)
            let navigation = try samplePixel(image, x: 0.8, y: 0.055)
            for component in 0..<3 {
                XCTAssertEqual(Double(strip[component]), Double(navigation[component]), accuracy: 3,
                               "Status-bar background must match the themed discovery navigation bar")
            }
        }
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["discover-tab-popular"].waitForExistence(timeout: 5))
        capture("claypad-discovery-portrait")
        app.buttons["feed-list-add"].tap()
        XCTAssertTrue(app.textFields["add-site-url-field"].waitForExistence(timeout: 5))
        capture("claypad-add-sheet-portrait")
        XCTAssertTrue(app.buttons["add-site-discover-youtube"].isHittable)
#endif
    }

    private func samplePixel(_ image: CGImage, x: CGFloat, y: CGFloat) throws -> [UInt8] {
        let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: CGFloat(image.width) * x,
                                                           y: CGFloat(image.height) * y,
                                                           width: 1, height: 1)))
        var components = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &components, width: 1, height: 1, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return components
    }

    private func launch(theme: String = "light", arguments: [String] = []) {
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "discover-sites",
                               "-newsblur-ui-test-theme", theme, "-ApplePersistenceIgnoreState", "YES"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["discover-tab-search"].waitForExistence(timeout: 15))
    }

    private func selectTab(_ name: String) {
        let tab = app.buttons["discover-tab-\(name)"]
        for _ in 0..<8 {
            if isOnscreen(tab) && tab.isHittable { break }
            let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-tab-"))
                .allElementsBoundByIndex.first { isOnscreen($0) }
            guard let visible else { XCTFail("No visible Discover tabs"); return }
            let y = visible.frame.midY / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: y))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: y)))
        }
        guard isOnscreen(tab) else {
            XCTFail("\(name) must be reachable without leaving Discover")
            return
        }
        XCTAssertTrue(tab.isHittable, "\(name) must be reachable without leaving Discover")
        tab.tap()
    }

    private func isOnscreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        // AddSiteUITests.swift avoids asking XCTest for activation points of clipped SwiftUI elements.
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0 else { return false }
        return app.frame.insetBy(dx: 2, dy: 2).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func enter(_ value: String, in field: XCUIElement, submit: Bool = false) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(value + (submit ? "\n" : ""))
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<10 {
            if isOnscreen(element) && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(isOnscreen(element) && element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_allSourcesRemainReachableAndRenderResults() {
        launch()
        XCTAssertTrue(app.staticTexts["The Daily Perspective"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1,240 subscribers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["18 stories/month"].exists)
        selectTab("webFeed")
        XCTAssertTrue(app.textFields["Enter a web page URL..."].waitForExistence(timeout: 5))
        for (tab, title) in [("popular", "The Daily Perspective"), ("youtube", "Practical Engineering"),
                             ("reddit", "r/science"), ("newsletters", "The Marginalian"), ("podcasts", "Radiolab")] {
            selectTab(tab)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "Missing \(tab) result")
            capture("discover-\(tab)")
        }
        selectTab("googleNews")
        XCTAssertTrue(app.staticTexts["Choose a Topic"].waitForExistence(timeout: 5))
        capture("discover-google-news")
    }

    func test_searchAndSourceSearchRenderServerResults() {
        launch()
        enter("swift", in: app.textFields["discover-search-field"])
        XCTAssertTrue(app.staticTexts["Swift by Sundell"].waitForExistence(timeout: 10))
        for (tab, result) in [("youtube", "Youtube Science Result"), ("reddit", "Reddit Science Result"),
                              ("podcasts", "Podcast Science Result")] {
            selectTab(tab)
            enter("science", in: app.textFields["discover-search-field"], submit: true)
            XCTAssertTrue(app.staticTexts[result].waitForExistence(timeout: 10))
            capture("discover-search-\(tab)")
        }
    }

    func test_categoryChipsFilterResultsAndExposeSubcategories() {
        launch()
        selectTab("youtube")
        let category = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Technology")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(category.frame.height, 44)
        category.tap()
        XCTAssertTrue(app.staticTexts["Technology sites"].waitForExistence(timeout: 10))
        let subcategory = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Engineering")).firstMatch
        XCTAssertTrue(subcategory.waitForExistence(timeout: 5))
        subcategory.tap()
        XCTAssertTrue(app.staticTexts["Engineering sites"].waitForExistence(timeout: 10))
        capture("discover-horizontal-category-chips")
    }

    func test_redditSearchKeepsCatalogResultsWhenUpstreamFails() {
        launch()
        selectTab("reddit")
        enter("catalog fallback", in: app.textFields["discover-search-field"], submit: true)
        XCTAssertTrue(app.staticTexts["Catalog Science"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add Catalog Science"].exists)
        XCTAssertFalse(app.staticTexts["Reddit API request failed."].exists)
        capture("discover-reddit-catalog-fallback")
    }

    func test_urlAddUsesSelectedNestedFolder() {
        launch()
        enter("https://ui-test.newsblur.example/folder-required.xml", in: app.textFields["discover-search-field"])
        assertFolderPicker(app.buttons["discover-folder-picker-url"], isBeside: app.buttons["discover-add-url"])
        app.buttons["discover-folder-picker-url"].tap()
        let swift = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Swift")).firstMatch
        XCTAssertTrue(swift.waitForExistence(timeout: 5))
        swift.tap()
        app.buttons["discover-add-url"].tap()
        XCTAssertTrue(app.otherElements["discover-added-success"].waitForExistence(timeout: 10)
                      || app.staticTexts["Site added"].exists)
        capture("discover-added-to-swift")
    }

    func test_urlFailureKeepsDialogOpenAndExplainsRecovery() {
        launch()
        enter("https://ui-test.newsblur.example/missing.xml", in: app.textFields["discover-search-field"])
        app.buttons["discover-add-url"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "No feed was found"))
            .firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["discover-add-url"].isEnabled)
        capture("discover-url-error")
    }

    func test_webFeedSelectsAndSubscribesToSecondVariant() {
        launch()
        selectTab("webFeed")
        enter("https://ui-test.newsblur.example/articles", in: app.textFields["Enter a web page URL..."])
        app.buttons["Analyze"].tap()
        let featured = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Featured stories")).firstMatch
        XCTAssertTrue(featured.waitForExistence(timeout: 10))
        scrollTo(featured)
        featured.tap()
        let subscribe = app.buttons["Subscribe to Web Feed"]
        scrollTo(subscribe)
        assertFolderPicker(app.buttons["discover-folder-picker-webfeed"], isBeside: subscribe)
        capture("discover-web-feed-configuration")
        subscribe.tap()
        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 10))
    }

    func test_webFeedDisplaysAnalysisError() {
        launch()
        selectTab("webFeed")
        enter("https://ui-test.newsblur.example/blocked", in: app.textFields["Enter a web page URL..."])
        app.buttons["Analyze"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "This page could not be accessed"))
            .firstMatch.waitForExistence(timeout: 10))
        capture("discover-web-feed-error")
    }

    func test_googleNewsTopicSubscription() {
        launch()
        selectTab("googleNews")
        let technology = app.buttons["Technology"].firstMatch
        XCTAssertTrue(technology.waitForExistence(timeout: 10))
        scrollTo(technology)
        technology.tap()
        let subscribe = app.buttons["Subscribe to Google News Feed"]
        scrollTo(subscribe)
        assertFolderPicker(app.buttons["discover-folder-picker-google-news"], isBeside: subscribe)
        capture("discover-google-news-topic")
        subscribe.tap()
        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 10))
    }

    func test_googleNewsDoesNotClaimAnUnrelatedSubscription() {
        launch()
        enter("https://ui-test.newsblur.example/another.xml", in: app.textFields["discover-search-field"], submit: true)
        app.buttons["discover-add-url"].tap()
        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 10))
        selectTab("googleNews")
        app.swipeUp()
        capture("discover-google-news-after-unrelated-add")
        XCTAssertFalse(app.staticTexts["Successfully subscribed to Google News feed"].exists)
    }

    func test_webFeedDetectsExistingRSSAndAddsIt() {
        launch()
        selectTab("webFeed")
        enter("https://ui-test.newsblur.example/rss", in: app.textFields["Enter a web page URL..."])
        app.buttons["Analyze"].tap()
        let add = app.buttons["Add feed"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        assertFolderPicker(app.buttons["discover-folder-picker-webfeed-detected"], isBeside: add)
        add.tap()
        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 10))
    }

    func test_newsletterURLConversionProducesSubscribableResult() {
        launch()
        selectTab("newsletters")
        enter("https://journal.substack.com", in: app.textFields["discover-search-field"], submit: true)
        XCTAssertTrue(app.staticTexts["https://journal.substack.com"].waitForExistence(timeout: 10))
        let add = app.buttons["Add https://journal.substack.com"]
        scrollTo(add)
        add.tap()
        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 10))
    }

    func test_previewResolvesUnlinkedFeedAndOpensReader() {
        launch()
        selectTab("popular")
        let preview = app.buttons["Try The Daily Perspective"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        scrollTo(preview)
        preview.tap()
        let firstStory = app.tables["story-titles-list"].cells["story-row-ui-story-swift-1"]
        XCTAssertTrue(firstStory.waitForExistence(timeout: 15))
        XCTAssertTrue(firstStory.label.contains("Swift Fixture Story One"))
        XCTAssertTrue(isOnscreen(firstStory) && firstStory.isHittable)
        capture("discover-preview-reader")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["discover-tab-popular"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["discover-tab-popular"].isSelected)
        XCTAssertTrue(app.staticTexts["The Daily Perspective"].exists)
    }

    func test_emptyPreviewAutomaticallyFetchesStoriesWithVisibleProgress() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(arguments: ["-newsblur-ui-test-empty-try-feed"])
        selectTab("popular")
        let preview = app.buttons["Try The Daily Perspective"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        preview.tap()
        let fetching = app.staticTexts["Fetching stories from this site..."]
        XCTAssertTrue(fetching.waitForExistence(timeout: 10), "An empty preview must visibly start fetching stories")
        capture("claypad-empty-preview-fetching-stories")
        let firstStory = app.tables["story-titles-list"].cells["story-row-ui-story-swift-1"]
        XCTAssertTrue(firstStory.waitForExistence(timeout: 20), "Fetched stories must populate the preview automatically")
        XCTAssertTrue(fetching.waitForDisappearance(timeout: 5))
        capture("claypad-empty-preview-stories-fetched")
    }

    func test_discoveryListPreviewsIncludeStoryExcerpts() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch()
        selectTab("popular")
        app.buttons["discover-view-mode-list"].tap()
        let preview = discoveryStoryPreview("ui-story-swift-2")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        capture("claypad-discovery-list-excerpts")
        let excerpt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Second preview excerpt includes the actual story & its context.")).firstMatch
        XCTAssertTrue(excerpt.exists || preview.label.contains("Second preview excerpt includes the actual story & its context."),
                      "List previews must show actual story text with HTML decoded")
    }

    func test_discoveryStoryPreviewOpensAndHighlightsExactStory() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch()
        selectTab("popular")
        app.buttons["discover-view-mode-list"].tap()
        let previewTitle = discoveryStoryPreview("ui-story-swift-2")
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 10))
        let beforeY = previewTitle.frame.minY
        capture("claypad-discovery-before-story-tap")
        previewTitle.tap()
        let selectedStory = app.tables["story-titles-list"].cells["story-row-ui-story-swift-2"]
        XCTAssertTrue(selectedStory.waitForExistence(timeout: 15))
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: selectedStory)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                       "The tapped story, not the first story, must be selected in the reader")
        assertArticleIsVisible(title: "Swift Fixture Story Two")
        capture("claypad-discovery-tapped-story-selected")
        app.buttons["discover-preview-back"].tap()
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(previewTitle.frame.minY, beforeY, accuracy: 3)
        XCTAssertTrue(app.buttons["discover-story-ui-story-swift-2"].isSelected)
        capture("claypad-discovery-returned-story-highlight")
    }

    func test_discoveryStoryPreviewOpensExactStoryWhenInitialFeedIsEmpty() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(arguments: ["-newsblur-ui-test-empty-try-feed"])
        selectTab("popular")
        app.buttons["discover-view-mode-list"].tap()
        let preview = discoveryStoryPreview("ui-story-swift-2")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        preview.tap()
        let story = app.tables["story-titles-list"].cells["story-row-ui-story-swift-2"]
        XCTAssertTrue(story.waitForExistence(timeout: 15))
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: story)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed)
        assertArticleIsVisible(title: "Swift Fixture Story Two")
        capture("claypad-discovery-exact-story-from-empty-feed")
        app.buttons["discover-preview-back"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.isSelected)
    }

    private func discoveryStoryPreview(_ hash: String) -> XCUIElement {
        let row = app.buttons["discover-story-\(hash)"]
        return row.exists ? row : app.staticTexts["discover-story-title-\(hash)"]
    }

    private func assertArticleIsVisible(title: String) {
        let link = app.webViews.links[title].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 20), "The tapped story's article must render")
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: link)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 10), .completed)
    }

    func test_liveClayPadListStoryPreviewOpensTheTappedStory() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the signed Alpha app on ClayPad")
#else
        try requireLiveClayPad()
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.launch()
        openLiveDiscovery()
        app.buttons["discover-tab-popular"].tap()
        let mode = app.buttons["discover-view-mode-list"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        let previews = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-story-"))
        XCTAssertTrue(previews.firstMatch.waitForExistence(timeout: 30))
        var visible: [XCUIElement] = []
        for candidate in previews.allElementsBoundByIndex {
            if isOnscreen(candidate) { visible.append(candidate) }
            if visible.count == 2 { break }
        }
        XCTAssertGreaterThanOrEqual(visible.count, 2)
        let preview = visible[1]
        let hash = String(preview.identifier.dropFirst("discover-story-".count))
        let title = app.staticTexts["discover-story-title-\(hash)"].label
        let beforeY = preview.frame.minY
        capture("claypad-live-discovery-story-excerpts")
        preview.tap()
        let story = app.tables["story-titles-list"].cells["story-row-\(hash)"]
        XCTAssertTrue(story.waitForExistence(timeout: 30))
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: story)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed)
        assertArticleIsVisible(title: title)
        capture("claypad-live-discovery-exact-story-selected")
        app.buttons["discover-preview-back"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.isSelected)
        XCTAssertEqual(preview.frame.minY, beforeY, accuracy: 3)
        capture("claypad-live-discovery-selected-story-return")
#endif
    }

    func test_inlineFolderPickersShareSelectionAcrossSources() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch()
        XCTAssertFalse(app.buttons["discover-folder-picker"].exists)
        let pickers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-folder-picker-"))
        let picker = pickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        assertFolderPickerIsBesideAdd(picker)
        picker.tap()
        let swift = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Swift")).firstMatch
        XCTAssertTrue(swift.waitForExistence(timeout: 5))
        swift.tap()
        for tab in ["popular", "youtube", "reddit", "newsletters", "podcasts"] {
            selectTab(tab)
            let localPicker = pickers.firstMatch
            XCTAssertTrue(localPicker.waitForExistence(timeout: 10))
            XCTAssertTrue((localPicker.value as? String)?.contains("Swift") == true)
            assertFolderPickerIsBesideAdd(localPicker)
        }
        capture("claypad-discover-inline-shared-folder-picker")
    }

    private func assertFolderPickerIsBesideAdd(_ picker: XCUIElement) {
        let feedID = String(picker.identifier.dropFirst("discover-folder-picker-".count))
        let addButton = app.buttons["discover-add-feed-\(feedID)"]
        assertFolderPicker(picker, isBeside: addButton)
        let title = String(addButton.label.dropFirst("Add ".count))
        let tryButton = app.buttons["Try \(title)"]
        XCTAssertTrue(tryButton.exists)
        XCTAssertEqual(tryButton.frame.midY, picker.frame.midY, accuracy: 3)
        XCTAssertGreaterThanOrEqual(picker.frame.minX - tryButton.frame.maxX, 16,
                                   "The folder picker should be grouped with Add, with a clear gap after Try")
        let folderTitle = (picker.value as? String) ?? "Top Level"
        let titleWidth = (folderTitle as NSString).size(withAttributes: [
            .font: UIFont.preferredFont(forTextStyle: .subheadline)
        ]).width
        XCTAssertLessThanOrEqual(picker.frame.width, titleWidth + 48,
                                 "The folder picker should fit its title instead of filling the row")
    }

    private func assertFolderPicker(_ picker: XCUIElement, isBeside addButton: XCUIElement) {
        XCTAssertTrue(picker.exists)
        XCTAssertTrue(addButton.exists)
        XCTAssertEqual(picker.frame.midY, addButton.frame.midY, accuracy: 3)
        XCTAssertLessThanOrEqual(picker.frame.maxX, addButton.frame.minX)
        XCTAssertLessThanOrEqual(addButton.frame.minX - picker.frame.maxX, 12)
        XCTAssertGreaterThanOrEqual(picker.frame.height, 44)
    }

    func test_supportedThemesRenderDiscover() {
        for theme in ["light", "sepia", "medium", "dark"] {
            launch(theme: theme)
            XCTAssertTrue(app.staticTexts["The Daily Perspective"].waitForExistence(timeout: 10))
            capture("discover-theme-\(theme)")
            selectTab("webFeed")
            capture("discover-web-feed-theme-\(theme)")
            app.terminate()
        }
    }
}
