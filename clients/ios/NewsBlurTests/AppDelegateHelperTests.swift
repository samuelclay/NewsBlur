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

    func test_upgradeSettings_doesNotMigrateCurrentReleases() {
        defaults.set(true, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 154)

        XCTAssertNil(defaults.object(forKey: "default_mark_read_filter"))
        XCTAssertNil(defaults.object(forKey: "override_mark_read_filter"))
    }
}
