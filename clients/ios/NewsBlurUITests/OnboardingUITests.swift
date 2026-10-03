import XCTest

final class Test_OnboardingUI: XCTestCase {
    func test_entireBundleCardTogglesInclusion() {
        for theme in ["light", "sepia", "medium", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding",
                                   "-newsblur-ui-test-theme", theme]
            app.launch()
            let interest = app.buttons["onboarding.interest.all"]
            XCTAssertTrue(interest.waitForExistence(timeout: 15))
            interest.tap()
            let add = app.buttons["onboarding.addBundle"]
            XCTAssertTrue(add.waitForExistence(timeout: 15))
            let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discover-bundle-feed-'")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            // OnboardingUITests.swift hits header, story text, image edge, and footer independently.
            for (index, point) in [CGVector(dx: 0.3, dy: 0.06), CGVector(dx: 0.4, dy: 0.4),
                                   CGVector(dx: 0.93, dy: 0.4), CGVector(dx: 0.3, dy: 0.95)].enumerated() {
                if index == 3 {
                    card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
                        thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
                    XCTAssertEqual(card.value as? String, "Not included in bundle", "Scrolling a card must not toggle it.")
                }
                card.coordinate(withNormalizedOffset: point).tap()
                let included = index % 2 == 1
                XCTAssertEqual(card.value as? String, included ? "Included in bundle" : "Not included in bundle")
                XCTAssertEqual(add.label, "Add \(included ? 5 : 4) feeds to “My Favorites” folder")
                if index == 0 { screenshot("whole-card-excluded-" + theme) }
            }
            screenshot("whole-card-included-" + theme)
            app.buttons["Done"].tap()
            app.terminate()
        }
    }

    func test_iconsAppearProgressivelyAndBundleResistsSwipeDismissal() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-onboarding-progressive-icons"]
        app.launch()
        let card = app.buttons["onboarding.interest.all"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let first = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1 sources'"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [first], timeout: 5), .completed)
        screenshot("category-first-icon")
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '5 sources'"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 20), .completed)
        screenshot("category-five-icons")
        card.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let navigation = app.navigationBars.firstMatch
        navigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertTrue(done.isHittable, "Dragging the bundle sheet must leave Done available.")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 3))
        app.terminate()
    }

    func test_catalogLoadingAndHeaderLayout() {
        for theme in ["light", "sepia", "medium", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding",
                                   "-newsblur-ui-test-theme", theme, "-onboarding-slow-catalog"]
            app.launch()
            let loading = app.otherElements["onboarding.catalogLoading"].firstMatch
            XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 15))
            XCTAssertFalse(app.buttons["onboarding.interest.all"].exists, "No isolated bundle should precede the category catalog.")
            screenshot("catalog-loading-" + theme)
            let search = app.textFields["Search interests and sites"]
            let heading = app.staticTexts["Explore interests"]
            XCTAssertEqual(search.frame.midY, heading.frame.midY, accuracy: 14)
            XCTAssertGreaterThan(search.frame.minX, heading.frame.maxX)
            XCTAssertTrue(app.buttons["onboarding.interest.Books"].waitForExistence(timeout: 20))
            XCTAssertTrue(app.buttons["onboarding.interest.all"].exists)
            XCTAssertFalse(loading.exists)
            screenshot("catalog-ready-" + theme)
            app.terminate()
        }
    }

    func test_bundleShowsEditableChoicesBeforeOtherSourcesFinish() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-onboarding-progressive-previews"]
        app.launch()
        let science = app.buttons["onboarding.interest.Science"]
        XCTAssertTrue(science.waitForExistence(timeout: 15))
        science.tap()
        let add = app.buttons["onboarding.addBundle"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "The first source must be available before slower sources finish.")
        XCTAssertEqual(add.label, "Add 1 feed to “Science” folder")
        XCTAssertTrue(add.isEnabled)
        let folder = app.textFields["onboarding.bundleFolder"]
        folder.tap()
        folder.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Parenting\n")
        app.buttons["Include Independent Journal"].tap()
        XCTAssertTrue(app.staticTexts["Loading more feeds…"].exists)
        XCTAssertEqual(add.label, "Select feeds to add")
        screenshot("progressive-bundle-choices")
        XCTAssertTrue(app.staticTexts["Loading more feeds…"].waitForNonExistence(timeout: 30))
        XCTAssertEqual(add.label, "Add 4 feeds to “Parenting” folder", "Later sources must preserve folder edits and deselected feeds.")
        app.buttons["Done"].tap()
        app.terminate()
    }

    func test_pendingSubscriptionsStayQuietWhileChoosingAnotherBundle() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-onboarding-slow-additions", "-onboarding-slow-previews"]
        app.launch()
        let science = app.buttons["onboarding.interest.Science"]
        XCTAssertTrue(science.waitForExistence(timeout: 15))
        science.tap()
        let add = app.buttons["onboarding.addBundle"]
        XCTAssertTrue(add.waitForExistence(timeout: 60))
        add.tap()
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3))
        let technology = app.buttons["onboarding.interest.Technology"]
        technology.tap()
        XCTAssertTrue(app.staticTexts["Loading feeds to choose from…"].waitForExistence(timeout: 2))
        screenshot("quiet-background-additions")
        XCTAssertFalse(app.staticTexts["Loading your feeds…"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Adding ' AND label CONTAINS 'background'")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Loading feeds to choose from…").count, 1)
        XCTAssertFalse(app.buttons["onboarding.addBundle"].exists)
        app.buttons["Done"].tap()
        app.terminate()
    }

    func test_importSheetCanCloseEarlyWhileAdditionsContinue() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "reader", "-onboarding-slow-additions"]
        app.launch()
        let settings = app.buttons["feed-list-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        app.tables["grouped-action-menu"].staticTexts["Import or upload sites"].tap()
        XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 10))
        screenshot("import-presentation-before-close")
        let close = app.buttons["Close import and discovery"]
        XCTAssertTrue(close.waitForExistence(timeout: 3), "Import must be dismissible before finishing setup.")
        guard close.exists else { app.terminate(); return }
        if app.frame.width > 600 {
            let presentation = app.otherElements["onboarding-presentation"]
            XCTAssertTrue(presentation.exists)
            XCTAssertLessThan(presentation.frame.width, app.frame.width, "On iPad, import should float over the reader instead of covering the screen.")
            XCTAssertLessThan(presentation.frame.height, app.frame.height)
        }
        let science = app.buttons["onboarding.interest.Science"]
        for _ in 0..<4 where !science.isHittable { app.swipeUp() }
        XCTAssertTrue(close.isHittable, "Close must remain available after scrolling.")
        science.tap()
        let add = app.buttons["onboarding.addBundle"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].waitForNonExistence(timeout: 60))
        settings.tap()
        app.tables["grouped-action-menu"].staticTexts["Import or upload sites"].tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable, "The final page must also be dismissible.")
        close.tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        app.terminate()
    }

    func test_singleSearchFindsInterestsAndAddsSites() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding"]
        app.launch()
        let search = app.textFields["Search interests and sites"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        XCTAssertEqual(app.textFields.count, 1)
        XCTAssertFalse(app.staticTexts["Make room for curiosity."].exists)
        search.tap()
        search.typeText("Science")
        XCTAssertTrue(app.buttons["onboarding.interest.Science"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.interest.Design"].exists)
        let add = app.buttons["Add Science Daily"]
        for _ in 0..<3 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        screenshot("unified-search")
        add.tap()
        XCTAssertTrue(app.staticTexts["Subscribed"].waitForExistence(timeout: 10))
        for _ in 0..<4 where !app.buttons["Clear search"].isHittable { app.swipeDown() }
        app.buttons["Clear search"].tap()
        XCTAssertTrue(app.buttons["onboarding.interest.Design"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Science Daily"].exists)
        screenshot("search-cleared")
        app.terminate()
    }

    func test_existingAccountCanReopenImportAndBundles() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Import menu uses an isolated existing-account fixture")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "reader", "-newsblur-ui-test-animations"]
        app.launch()
        for attempt in 1...2 {
            let settings = app.buttons["feed-list-settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 15))
            settings.tap()
            let menu = app.tables["grouped-action-menu"]
            let action = menu.staticTexts["Import or upload sites"]
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            screenshot("import-menu-\(attempt)")
            action.tap()
            XCTAssertTrue(menu.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 10))
            app.buttons["Import OPML"].tap()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 15))
            app.buttons["Cancel"].tap()
            let science = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Science'")).firstMatch
            for _ in 0..<4 where !science.isHittable { app.swipeUp() }
            XCTAssertTrue(science.waitForExistence(timeout: 10))
            screenshot("existing-account-bundles-\(attempt)")
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
            app.buttons["Start reading"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.cells["feed-row-910001"].waitForExistence(timeout: 10), "Existing subscriptions must remain available after closing import.")
        }
        app.terminate()
        #endif
    }

    func test_bundleDoneClosesImmediatelyWhileLoading() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-onboarding-slow-previews"]
        app.launch()
        XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 15))
        if app.buttons["Continue to discovery"].exists { app.buttons["Continue to discovery"].tap() }
        let science = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Science'")).firstMatch
        XCTAssertTrue(science.waitForExistence(timeout: 10))
        for _ in 0..<3 where !science.isHittable { app.swipeUp() }
        science.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        XCTAssertTrue(done.isEnabled, "Done must remain available while bundle previews are loading.")
        XCTAssertTrue(app.staticTexts["Loading feeds to choose from…"].exists)
        XCTAssertFalse(app.buttons["onboarding.addBundle"].exists, "Loading must not show an Add 0 feeds action.")
        screenshot("bundle-loading")
        done.tap()
        XCTAssertTrue(science.waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["Choose feeds for your folder"].exists)
        app.terminate()
    }

    func test_bundleActionReflectsFolderNameSelectionAndSingularCount() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding"]
        app.launch()
        let science = app.buttons["onboarding.interest.Science"]
        XCTAssertTrue(science.waitForExistence(timeout: 15))
        for _ in 0..<4 where !science.isHittable { app.swipeUp() }
        science.tap()
        let add = app.buttons["onboarding.addBundle"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertEqual(add.label, "Add 5 feeds to “Science” folder")
        let folder = app.textFields["onboarding.bundleFolder"]
        folder.tap()
        let existing = folder.value as? String ?? "Science"
        folder.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + "Parenting\n")
        XCTAssertEqual(add.label, "Add 5 feeds to “Parenting” folder")
        for title in ["Independent Journal", "The Marginalian", "Practical Engineering", "r/science", "Radiolab"] {
            let include = app.buttons["Include " + title]
            XCTAssertTrue(include.exists)
            include.tap()
            if title == "Independent Journal" { XCTAssertEqual(add.label, "Add 4 feeds to “Parenting” folder") }
        }
        XCTAssertEqual(add.label, "Select feeds to add")
        XCTAssertFalse(add.isEnabled)
        screenshot("bundle-empty-selection")
        app.buttons["Include Radiolab"].tap()
        XCTAssertEqual(add.label, "Add 1 feed to “Parenting” folder")
        XCTAssertTrue(add.isEnabled)
        screenshot("bundle-renamed-folder")
        app.buttons["Done"].tap()
        app.terminate()
    }

    func test_visibleSignupFieldsAndReturningUserMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding-account", "-last_auth_method", ""]
        app.launch()
        let create = app.buttons["New to NewsBlur? Create an account"]
        if create.waitForExistence(timeout: 5) { create.tap() }
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Username"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign in with Apple"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Sign in with Google"].exists)
        screenshot("account")
        app.swipeUp()
        app.buttons["Already have an account? Sign in"].tap()
        XCTAssertTrue(app.textFields["Username or email"].exists)
        XCTAssertFalse(app.textFields["Email"].exists)
        app.terminate()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding-account", "-last_auth_method", "google"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Last used"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Username or email"].exists)
        screenshot("last-used")
        app.terminate()
    }

    func test_completionWithoutFeedsStaysReady() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 15))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["onboarding.summary"].exists)
        XCTAssertFalse(app.buttons["Back to feeds"].exists)
        XCTAssertTrue(app.staticTexts["Your reader is ready. Add feeds anytime from Add + Discover Sites."].exists)
        screenshot("complete-empty-phone")
        app.swipeUp()
        screenshot("complete-community-phone")
        XCTAssertTrue(app.buttons["Start reading"].isHittable)
        app.buttons["Start reading"].tap()
        XCTAssertTrue(app.staticTexts["You’re all set up."].waitForNonExistence(timeout: 5))
        app.terminate()
    }

    func test_completionRecapAcrossThemes() {
        for theme in ["light", "sepia", "medium", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-newsblur-ui-test-theme", theme]
            app.launch()
            let science = app.buttons["onboarding.interest.Science"]
            XCTAssertTrue(science.waitForExistence(timeout: 15))
            for _ in 0..<4 where !science.isHittable { app.swipeUp() }
            science.tap()
            let add = app.buttons["onboarding.addBundle"]
            XCTAssertTrue(add.waitForExistence(timeout: 10))
            app.textFields["onboarding.bundleFolder"].tap()
            app.textFields["onboarding.bundleFolder"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Weekend Reading\n")
            add.tap()
            XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3))
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Weekend Reading'")).firstMatch.exists)
            XCTAssertFalse(app.buttons["Back to feeds"].exists)
            XCTAssertFalse(app.staticTexts["Good luck, and happy reading."].exists)
            XCTAssertFalse(app.staticTexts["Loading your feeds…"].exists)
            XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS '@samuelclay on X'")).firstMatch.exists)
            XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS '@NewsBlur on X'")).firstMatch.exists)
            screenshot("recap-" + theme)
            app.buttons["Start reading"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForNonExistence(timeout: 5))
            app.terminate()
        }
    }

    func test_importDiscoveryBundlesAndFinishAcrossThemes() {
        for theme in ["light", "sepia", "medium", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-newsblur-ui-test-theme", theme]
            app.launch()
            XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 15))
            let all = app.buttons["onboarding.interest.all"]
            let firstInterest = app.buttons["onboarding.interest.Books"]
            XCTAssertTrue(firstInterest.waitForExistence(timeout: 10))
            XCTAssertEqual(all.frame.height, firstInterest.frame.height, accuracy: 1, "Cards must keep equal heights when their titles wrap.")
            if app.frame.width > 600 {
                XCTAssertEqual(all.frame.minY, firstInterest.frame.minY, accuracy: 1)
                XCTAssertGreaterThan(firstInterest.frame.minX, all.frame.maxX)
                XCTAssertGreaterThan(app.buttons["onboarding.interest.Science"].frame.minY, all.frame.maxY, "Wide layouts must show two cards per row.")
            }
            screenshot("import-" + theme)
            app.buttons["Import OPML"].tap()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 15))
            app.buttons["Cancel"].tap()
            let science = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Science'")).firstMatch
            for _ in 0..<4 where !science.isHittable { app.swipeUp() }
            XCTAssertTrue(science.waitForExistence(timeout: 10))
            screenshot("discovery-" + theme)
            science.tap()
            XCTAssertTrue(app.staticTexts["Choose feeds for your folder"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["onboarding.addBundle"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["Include Independent Journal"].exists)
            screenshot("bundle-" + theme)
            app.buttons["onboarding.addBundle"].tap()
            XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3))
            XCTAssertEqual(science.value as? String, "5 feeds added")
            screenshot("category-added-" + theme)
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["Back to feeds"].exists)
            XCTAssertFalse(app.staticTexts["Good luck, and happy reading."].exists)
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Science'")).firstMatch.exists)
            XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS '@samuelclay on X'")).firstMatch.exists)
            XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS '@NewsBlur on X'")).firstMatch.exists)
            screenshot("complete-" + theme)
            app.buttons["Start reading"].tap()
            XCTAssertFalse(app.staticTexts["You’re all set up."].waitForExistence(timeout: 1))
            app.terminate()
        }
    }

    func test_canFinishSetupWhileSubscriptionsAreQueued() {
        let app = XCUIApplication()
        app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-onboarding-slow-additions"]
        app.launch()
        XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 15))
        let science = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Science'")).firstMatch
        for _ in 0..<4 where !science.isHittable { app.swipeUp() }
        science.tap()
        let add = app.buttons["onboarding.addBundle"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3), "Adding feeds must immediately return to Explore interests.")
        XCTAssertTrue(science.isHittable, "Returning must preserve the category scroll position.")
        XCTAssertEqual(science.value as? String, "5 feeds selected")
        screenshot("returned-to-interests")
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].tap()
        screenshot("loading-final")
        XCTAssertFalse(app.staticTexts["Loading your feeds…"].exists, "Completion must keep subscription and refresh progress in the background.")
        XCTAssertTrue(app.buttons["Start reading"].isEnabled)
        app.buttons["Start reading"].tap()
        if app.buttons["Sidebar"].firstMatch.exists { app.buttons["Sidebar"].firstMatch.tap() }
        screenshot("loading-reader")
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].exists, "The feed list must retain the nonblocking loading state until the final refresh completes.")
        let loading = app.staticTexts["Loading your feeds…"].firstMatch
        XCTAssertGreaterThanOrEqual(loading.frame.minX, app.frame.minX, "The loading notifier must stay inside the feeds column.")
        XCTAssertLessThanOrEqual(loading.frame.maxX, app.frame.maxX)
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].waitForNonExistence(timeout: 60), "The spinner must clear after queued additions and the final feed refresh finish.")
        screenshot("loading-reader-finished")
        XCTAssertFalse(app.staticTexts["You’re all set up."].waitForExistence(timeout: 1))
        app.terminate()
    }

    private func screenshot(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "onboarding-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
