import XCTest

@testable import NewsBlur

final class Test_ListenPreferences: XCTestCase {
    private let keys = [ListenPreferences.voicesKey, ListenPreferences.deliveryKey, ListenPreferences.stabilityKey,
                        ListenPreferences.similarityKey, ListenPreferences.styleKey, ListenPreferences.speakerBoostKey,
                        ListenPreferences.speedKey, ListenPreferences.autoContinueKey, ListenPreferences.highlightKey,
                        "show_sideoption_train", "show_sideoption_share", "show_sideoption_save", "show_ask_ai",
                        "show_sideoption_listen", "listen_migrated_show_ask_ai"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        saved = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) {
                saved[key] = value
            }
        }
        defaults.set(true, forKey: "listen_migrated_show_ask_ai")
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for key in keys {
            if let value = saved[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    private func profile(speed: String) -> [AnyHashable: Any] {
        let preferences: [String: Any] = ["listen_speed": speed, "listen_delivery": "natural",
                                          "show_sideoption_listen": true]
        let data = try! JSONSerialization.data(withJSONObject: preferences)
        return ["preferences": String(decoding: data, as: UTF8.self)]
    }

    private func notifications(during work: () -> Void) -> (writes: Int, listenKeys: [String]) {
        var writes = 0
        var listenKeys: [String] = []
        let center = NotificationCenter.default
        let defaultsObserver = center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { _ in
            writes += 1
        }
        let listenObserver = center.addObserver(forName: ListenPreferences.didChange, object: nil, queue: nil) { note in
            listenKeys += note.userInfo?["keys"] as? [String] ?? []
        }
        work()
        center.removeObserver(defaultsObserver)
        center.removeObserver(listenObserver)
        return (writes, listenKeys)
    }

    // ListenPreferencesTests.swift: every UserDefaults write redraws all of Preferences (PreferencesView.swift), so a
    // sync that finds nothing new must not write, and a real change writes only what changed.
    func test_syncWritesOnlyValuesThatChanged() {
        ListenPreferences.syncFromUserProfile(profile(speed: "1.25"))
        XCTAssertEqual(ListenPreferences.speed, 1.25)

        let repeated = notifications { ListenPreferences.syncFromUserProfile(profile(speed: "1.25")) }
        XCTAssertEqual(repeated.writes, 0)
        XCTAssertEqual(repeated.listenKeys, [])

        let changed = notifications { ListenPreferences.syncFromUserProfile(profile(speed: "1.5")) }
        XCTAssertGreaterThan(changed.writes, 0)
        XCTAssertEqual(changed.listenKeys, [ListenPreferences.speedKey])
        XCTAssertEqual(ListenPreferences.speed, 1.5)
    }
}
