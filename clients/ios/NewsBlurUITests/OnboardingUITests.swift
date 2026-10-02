import XCTest

final class Test_OnboardingUI: XCTestCase {
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
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
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
        done.tap()
        XCTAssertTrue(science.waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["Make this bundle yours."].exists)
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

    func test_importDiscoveryBundlesAndFinishAcrossThemes() {
        for theme in ["light", "sepia", "medium", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-newsblur-ui-testing", "-newsblur-ui-test-screen", "onboarding", "-newsblur-ui-test-theme", theme]
            app.launch()
            XCTAssertTrue(app.buttons["Import OPML"].waitForExistence(timeout: 15))
            let all = app.buttons["onboarding.interest.all"]
            let technology = app.buttons["onboarding.interest.Technology"]
            XCTAssertTrue(technology.waitForExistence(timeout: 10))
            XCTAssertEqual(all.frame.height, technology.frame.height, accuracy: 1, "Cards must keep equal heights when their titles wrap.")
            if app.frame.width > 600 {
                XCTAssertEqual(all.frame.minY, technology.frame.minY, accuracy: 1)
                XCTAssertGreaterThan(technology.frame.minX, all.frame.maxX)
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
            XCTAssertTrue(app.staticTexts["Make this bundle yours."].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["Add 5 feeds to folder"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["discover-story-title-rss-story-0"].exists)
            screenshot("bundle-" + theme)
            app.buttons["Add 5 feeds to folder"].tap()
            app.buttons["Done"].tap()
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.staticTexts["You’re all set up."].waitForExistence(timeout: 5))
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
        let add = app.buttons["Add 5 feeds to folder"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["Done"].isEnabled)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].tap()
        screenshot("loading-final")
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].isHittable, "Completion must visibly show progress while subscriptions are still queued.")
        XCTAssertTrue(app.buttons["Start reading"].isEnabled)
        app.buttons["Start reading"].tap()
        screenshot("loading-reader")
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].exists, "The feed list must retain the nonblocking loading state until the final refresh completes.")
        XCTAssertTrue(app.staticTexts["Loading your feeds…"].waitForNonExistence(timeout: 25), "The spinner must clear after queued additions and the final feed refresh finish.")
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
