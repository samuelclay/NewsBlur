import XCTest

@testable import NewsBlur

final class AppDelegateHelperTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "default_scroll_read_filter",
        "override_scroll_read_filter",
        "default_mark_read_filter",
        "override_mark_read_filter",
        "feed:1:scroll_read_filter",
        "feed:1:mark_read_filter",
        "feed:2:scroll_read_filter",
        "feed:2:mark_read_filter",
        "custom_domain",
    ]
    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()

        for key in keys {
            if let value = defaults.object(forKey: key) {
                savedValues[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            defaults.removeObject(forKey: key)
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            }
        }

        savedValues.removeAll()
        super.tearDown()
    }

    func test_upgradeSettings_migratesGlobalAndPerFeedScrollPreferences() {
        defaults.set(true, forKey: "default_scroll_read_filter")
        defaults.set(true, forKey: "override_scroll_read_filter")
        defaults.set(false, forKey: "feed:1:scroll_read_filter")
        defaults.set(true, forKey: "feed:2:scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(defaults.string(forKey: "default_mark_read_filter"), "scroll")
        XCTAssertTrue(defaults.bool(forKey: "override_mark_read_filter"))
        XCTAssertEqual(defaults.string(forKey: "feed:1:mark_read_filter"), "selection")
        XCTAssertEqual(defaults.string(forKey: "feed:2:mark_read_filter"), "scroll")
    }

    func test_upgradeSettings_doesNotOverwriteCurrentReleases() {
        defaults.set(true, forKey: "default_scroll_read_filter")
        defaults.set("selection", forKey: "default_mark_read_filter")
        defaults.set(false, forKey: "override_mark_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 154)

        XCTAssertEqual(defaults.string(forKey: "default_mark_read_filter"), "selection")
        XCTAssertFalse(defaults.bool(forKey: "override_mark_read_filter"))
    }

    func test_appDelegateURL_normalizesCustomDomainToOrigin() {
        defaults.set("  newsblur.local:8443/reader?foo=bar  ", forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, "https://newsblur.local:8443")
        XCTAssertEqual(appDelegate.host, "newsblur.local")
    }

    func test_appDelegateURL_fallsBackToDefaultWhenCustomDomainIsInvalid() {
        defaults.removeObject(forKey: "custom_domain")
        let defaultURL = NewsBlurAppDelegate().url

        defaults.set("https://", forKey: "custom_domain")
        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, defaultURL)
    }

    func test_setCustomDomainForTesting_doesNotPersistFakeDomainIntoUserDefaults() {
        defaults.removeObject(forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()
        appDelegate.setCustomDomainForTesting("https://ui-test.newsblur.example")

        XCTAssertEqual(appDelegate.url, "https://ui-test.newsblur.example")
        let bundleIdentifier = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persistedValue = defaults.persistentDomain(forName: bundleIdentifier)?["custom_domain"]
        XCTAssertNil(persistedValue)
    }
}
