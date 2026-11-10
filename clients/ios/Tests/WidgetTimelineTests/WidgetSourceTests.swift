// WidgetSourceTests.swift covers independent selections, nested folders, and safe cache boundaries.
import XCTest
@testable import WidgetTimeline

final class Test_WidgetSource: XCTestCase {
    func test_faviconsSurviveAppCatalogReplacementAndStayWithinTheirAccount() throws {
        let suite = "WidgetSourceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let host = "https://newsblur.com"
        defaults.set("alice", forKey: "share:username")
        defaults.set(host, forKey: "share:host")
        let icon = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=")!
        WidgetSourceCatalog.store(dictionary: ["feeds": ["1": ["feed_title": "First"]]], username: "alice", host: host, defaults: defaults)
        WidgetSourceCatalog.storeFavicons(["1": icon.base64EncodedString(), "9": icon.base64EncodedString(), "authenticated": true, "user_id": 1, "result": "ok"], username: "alice", host: host, defaults: defaults)
        XCTAssertEqual(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "1"), icon)
        XCTAssertNil(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "9"))

        // WidgetSourceTests.swift reproduces the main app's iconless catalog replacement.
        let replacement = try JSONSerialization.data(withJSONObject: ["username": "alice", "host": host, "feeds": ["1": ["feed_title": "Renamed"]]])
        defaults.set(replacement, forKey: WidgetSourceCatalog.key)
        XCTAssertEqual(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "1"), icon)
        defaults.set("bob", forKey: "share:username")
        WidgetSourceCatalog.store(dictionary: ["feeds": ["1": ["feed_title": "Bob's site"]]], username: "bob", host: host, defaults: defaults)
        XCTAssertNil(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "1"))
        WidgetSourceCatalog.storeFavicons(["1": icon.base64EncodedString()], username: "alice", host: host, defaults: defaults)
        XCTAssertNil(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "1"), "Late responses from a previous account must be ignored")
        defaults.set("https://other.example", forKey: "share:host")
        XCTAssertNil(WidgetSourceCatalog.load(defaults: defaults).favicon(for: "1"))
    }

    func test_invalidFaviconFallsBackWithoutDiscardingTheCatalog() throws {
        let suite = "WidgetSourceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("alice", forKey: "share:username")
        defaults.set("https://newsblur.com", forKey: "share:host")
        WidgetSourceCatalog.store(dictionary: ["feeds": ["1": ["feed_title": "First"]]], username: "alice", host: "https://newsblur.com", defaults: defaults)
        WidgetSourceCatalog.storeFavicons(["1": "bad image!"], username: "alice", host: "https://newsblur.com", defaults: defaults)
        let loaded = WidgetSourceCatalog.load(defaults: defaults)
        XCTAssertEqual(loaded.feedIDs(for: "all"), ["1"])
        XCTAssertNil(loaded.favicon(for: "1"))
    }

    func test_pickerReturnsCachedCatalogWithoutWaitingForNetwork() async throws {
        let suite = "WidgetSourceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("alice", forKey: "share:username")
        defaults.set("https://newsblur.com", forKey: "share:host")
        for feeds: [String: [String: String]] in [["1": ["feed_title": "Cached Site"]], [:]] {
            let data = try JSONSerialization.data(withJSONObject: ["username": "alice", "host": "https://newsblur.com", "feeds": feeds])
            defaults.set(data, forKey: WidgetSourceCatalog.key)
            var refreshes = 0
            let loaded = await WidgetSourceCatalog.loadForPicker(defaults: defaults) { refreshes += 1 }
            XCTAssertEqual(refreshes, 0, "WidgetSourceTests.swift requires both populated and empty cached accounts to open immediately.")
            XCTAssertEqual(loaded.feeds.count, feeds.count)
        }
    }

    func test_pickerLoadsNetworkOnlyWhenAccountCatalogIsMissing() async throws {
        let suite = "WidgetSourceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("alice", forKey: "share:username")
        defaults.set("https://newsblur.com", forKey: "share:host")
        var refreshes = 0
        let loaded = await WidgetSourceCatalog.loadForPicker(defaults: defaults) {
            refreshes += 1
            let data = try! JSONSerialization.data(withJSONObject: ["username": "alice", "host": "https://newsblur.com", "feeds": ["2": ["feed_title": "Fetched Site"]]])
            defaults.set(data, forKey: WidgetSourceCatalog.key)
        }
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(loaded.feedIDs(for: "all"), ["2"])
    }

    let catalog = WidgetSourceCatalog(dictionary: [
        "feeds": ["1": ["feed_title": "First"], "2": ["feed_title": "Second"], "3": ["feed_title": "Third"]],
        "flat_folders": [" ": [3], "Science": [1], "Science - Space": [2, 1], "Science Fiction": [3], "Empty": []]
    ])

    func test_separateWidgetsResolveOnlyTheirSelectedSources() {
        XCTAssertEqual(catalog.feedIDs(for: "folder:Science"), ["1", "2"])
        XCTAssertEqual(catalog.feedIDs(for: "feed:3"), ["3"])
        XCTAssertEqual(catalog.feedIDs(for: "folder:Science - Space"), ["1", "2"])
        XCTAssertEqual(catalog.feedIDs(for: "all"), ["1", "2", "3"])
        XCTAssertNil(catalog.folders[" "])
    }

    func test_emptyOrDeletedSelectionNeverFallsBackToAllStories() {
        for source in ["folder:Empty", "folder:Deleted", "feed:99", "invalid"] {
            XCTAssertEqual(catalog.feedIDs(for: source), [])
        }
    }

    func test_cachedStoriesCannotCrossAccountsServersSelectionsOrChangedMembership() {
        func key(_ host: String = "https://newsblur.com", _ user: String = "alice", _ source: String = "folder:Science", _ feeds: [String] = ["1", "2"]) -> String {
            WidgetSourceCatalog.cacheFilename(host: host, username: user, source: source, feedIDs: feeds)
        }
        let base = key()
        XCTAssertEqual(base, key("https://newsblur.com", "alice", "folder:Science", ["2", "1"]))
        XCTAssertNotEqual(base, key("https://other.example"))
        XCTAssertNotEqual(base, key("https://newsblur.com", "bob"))
        XCTAssertNotEqual(base, key("https://newsblur.com", "alice", "feed:1"))
        XCTAssertNotEqual(base, key("https://newsblur.com", "alice", "folder:Science", ["1"]))
    }

    func test_catalogFromPreviousAccountIsRejected() throws {
        let suite = "WidgetSourceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("bob", forKey: "share:username")
        defaults.set("https://newsblur.com", forKey: "share:host")
        let data = try JSONSerialization.data(withJSONObject: ["username": "alice", "host": "https://newsblur.com", "feeds": catalog.feeds])
        defaults.set(data, forKey: WidgetSourceCatalog.key)
        XCTAssertTrue(WidgetSourceCatalog.load(defaults: defaults).feeds.isEmpty)
    }
}
