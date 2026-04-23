import XCTest

@testable import NewsBlur

final class AppDelegateHelperTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "default_scroll_read_filter",
        "default_mark_read_filter",
        "release",
        "custom_domain",
    ]
    private var savedValues: [String: Any] = [:]
    private var bundleID: String { Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? "" }

    /// Read a user-set value from the persistent domain, excluding registered
    /// defaults that Settings.bundle adds at launch. Tests that assert "the
    /// migration did not write" must use this; `defaults.object(forKey:)` also
    /// returns the registered `scroll` default.
    private func userValue(_ key: String) -> Any? {
        return defaults.persistentDomain(forName: bundleID)?[key]
    }

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

    func test_upgradeSettings_migratesLegacyScrollFalseToSelection() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_upgradeSettings_migratesLegacyScrollTrueToScroll() {
        defaults.set(true, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "scroll")
    }

    func test_upgradeSettings_doesNotWriteMarkReadWhenLegacyKeyAbsent() {
        // Fresh install: no old boolean key. Migration must NOT force "selection",
        // which would override the Settings.bundle default of "scroll".
        AppDelegateHelper.shared.upgradeSettings(from: 0)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_upgradeSettings_doesNotOverwriteExistingMarkReadValue() {
        defaults.set(true, forKey: "default_scroll_read_filter")
        defaults.set("selection", forKey: "default_mark_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_upgradeSettings_doesNotMigrateWhenAlreadyPastMigrationRelease() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 154)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_applyReleaseUpgrade_readsPreviousReleaseBeforeOverwriting() {
        // Simulate a device that last ran an old build (release 120) and is
        // now launching build 328. The migration must see 120 and run.
        defaults.set(120, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
    }

    func test_applyReleaseUpgrade_skipsMigrationWhenStoredReleaseAlreadyPastThreshold() {
        defaults.set(200, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertNil(userValue("default_mark_read_filter"))
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
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

    func test_feedIdsForTopLevelRiverWithReadFilter_unread_usesModelUnreadCountsInsteadOfSidebarVisibility() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.selectedIntelligence = 0
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
            "saved_stories",
            "read_stories",
        ]
        // dictFolders["everything"] is the iOS-renamed bucket for top-level unfoldered feeds
        // (server's flat_folders_with_inactive[" "]). The river must include them.
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11, 99],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 4],
            "News": [2, 3, "saved:query"],
            "saved_stories": ["saved:1"],
            "read_stories": ["read_stories"],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 1, "nt": 0, "ng": 0],
            "3": ["ps": 0, "nt": 0, "ng": 0],
            "4": ["ps": 0, "nt": 1, "ng": 0],
            "10": ["ps": 1, "nt": 0, "ng": 0],
            "11": ["ps": 0, "nt": 0, "ng": 0],
        ]
        appDelegate.dictInactiveFeeds = [
            "4": ["id": 4],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
            "News": [0],
        ]
        feedsViewController.viewShowingAllFeeds = false

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "unread") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "1", "2"])
    }

    func test_feedIdsForTopLevelRiverWithReadFilter_all_returnsFullSubscribedFeedIds() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
        ]
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 99],
            "News": [2, 3, 4],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
        ]

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "all") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "11", "1", "2", "3", "4"])
    }
}
