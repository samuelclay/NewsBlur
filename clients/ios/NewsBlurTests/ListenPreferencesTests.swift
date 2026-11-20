import XCTest

@testable import NewsBlur

final class Test_ListenPreferences: XCTestCase {
    private let keys = [ListenPreferences.rotationsKey, ListenPreferences.voicesKey, ListenPreferences.deliveryKey, ListenPreferences.stabilityKey,
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

    @MainActor func test_slowRotationSaveCannotOverwriteNewerEdits() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let oldManager = app.networkManager
        let oldProfile = app.dictUserProfile
        let server = DelayedPreferenceServer()
        app.networkManager = server
        defer {
            app.networkManager = oldManager
            app.dictUserProfile = oldProfile
        }
        let first = [ListenRotationVoice(id: "a", name: "Amelia")]
        let latest = first + [ListenRotationVoice(id: "b", name: "Jon")]
        ListenPreferences.setRotation(first, forLanguage: "en")
        ListenPreferences.setRotation(latest, forLanguage: "en")
        XCTAssertEqual(ListenPreferences.rotations["en"], latest)
        while let complete = server.requests.popLast() { complete() }
        XCTAssertEqual(server.savedRotations["en"]?.map { $0["voice_id"] }, ["a", "b"])
    }

    // ListenPreferencesTests.swift: server sync must preserve order and names, discard malformed/duplicate
    // entries, and clear the old account's list. Treating the nested JSON as listen_voices would lose it.
    func test_rotationSyncAndAccountReset() {
        ListenPreferences.syncFromUserProfile(["preferences": ["listen_voice_rotations":
            "{\"en\":[{\"voice_id\":\"a\",\"name\":\"Amelia\"},{\"voice_id\":\"a\"},{\"voice_id\":\"b\",\"name\":\"Jon\"},{\"voice_id\":\"\"}],\"fr\":false}"]])
        XCTAssertEqual(ListenPreferences.rotations["en"]?.map(\.id), ["a", "b"])
        XCTAssertEqual(ListenPreferences.rotations["en"]?.last?.name, "Jon")
        XCTAssertNil(ListenPreferences.rotations["fr"])
        ListenPreferences.syncFromUserProfile(["preferences": [:]])
        XCTAssertTrue(ListenPreferences.rotations.isEmpty)
    }

    // ListenPreferencesTests.swift: advancing at manifest refresh instead of story change would skip voices.
    // The requested voice consumes its turn even when the provider temporarily uses a fallback.
    func test_rotationKeepsStoryVoiceAndResetsWithSession() {
        let lists = ["en": [ListenRotationVoice(id: "a", name: "A"), ListenRotationVoice(id: "b", name: "B")],
                     "fr": [ListenRotationVoice(id: "c", name: "C"), ListenRotationVoice(id: "d", name: "D")]]
        var session = ListenVoiceRotationSession()
        session.beginStory("one", rotations: lists)
        XCTAssertEqual(session.choices, ["en": "a", "fr": "c"])
        session.record(language: "en", resolvedVoice: "fallback")
        session.beginStory("one", rotations: lists)
        XCTAssertEqual(session.choices["en"], "a")
        session.beginStory("two", rotations: lists)
        XCTAssertEqual(session.choices, ["en": "b", "fr": "c"])
        session.record(language: "en", resolvedVoice: "b")
        session.beginStory("three", rotations: lists)
        XCTAssertEqual(session.choices["en"], "a")
        session = ListenVoiceRotationSession()
        session.beginStory("four", rotations: lists)
        XCTAssertEqual(session.choices["en"], "a")
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

private final class DelayedPreferenceServer: AFHTTPSessionManager {
    var requests: [() -> Void] = []
    var savedRotations: [String: [[String: String]]] = [:]
    override func post(_ url: String, parameters: Any?, progress: ((Progress) -> Void)?,
                       success: ((URLSessionDataTask, Any?) -> Void)?,
                       failure: ((URLSessionDataTask?, Error) -> Void)?) -> URLSessionDataTask? {
        let task = URLSession.shared.dataTask(with: URL(string: url)!)
        let values = parameters as? [String: String]
        requests.append {
            self.savedRotations = ListenJSON.objectFromString(values?[ListenPreferences.rotationsKey]) as? [String: [[String: String]]] ?? [:]
            success?(task, ["code": 1])
        }
        return task
    }
}
