import XCTest

final class AddSiteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_addSiteSheetLaunchesInUiTestMode() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.otherElements["add-site-header"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["add-site-url-field"].exists)
        XCTAssertTrue(app.buttons["add-site-submit-button"].exists)
    }

    func test_addSiteAutocompleteSelectionAndSubmitDismissesSheet() {
        let app = makeApp()
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

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-newsblur-ui-testing",
            "-newsblur-ui-test-screen",
            "add-site",
        ]
        return app
    }
}

private extension XCUIElement {
    func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
