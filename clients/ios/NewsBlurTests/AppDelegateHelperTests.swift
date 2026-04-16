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
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": ["everything"],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 4, 99],
            "News": [2, 3, "saved:query"],
            "saved_stories": ["saved:1"],
            "read_stories": ["read_stories"],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "99": ["id": 99, "temp": true],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 1, "nt": 0, "ng": 0],
            "3": ["ps": 0, "nt": 0, "ng": 0],
            "4": ["ps": 0, "nt": 1, "ng": 0],
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

        XCTAssertEqual(feedIds, ["1", "2"])
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
            "everything": ["everything"],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 99],
            "News": [2, 3, 4],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "99": ["id": 99, "temp": true],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
        ]

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "all") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["1", "2", "3", "4"])
    }
}
