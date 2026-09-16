import XCTest

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

    private func launch(theme: String = "light") {
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "discover-sites",
                               "-newsblur-ui-test-theme", theme, "-ApplePersistenceIgnoreState", "YES"]
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
        let attachment = XCTAttachment(screenshot: app.screenshot())
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
        app.buttons["discover-folder-picker"].tap()
        let swift = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Swift")).firstMatch
        XCTAssertTrue(swift.waitForExistence(timeout: 5))
        swift.tap()
        enter("https://ui-test.newsblur.example/folder-required.xml", in: app.textFields["discover-search-field"])
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
