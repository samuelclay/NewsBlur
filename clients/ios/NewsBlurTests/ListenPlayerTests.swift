import AVFoundation
import XCTest

@testable import NewsBlur

/// ListenPlayerTests.swift: which story Listen moves on to when one ends or Next story is tapped
/// (ListenPlayer.swift upNextStories). Every test uses the list order StoriesCollection.m builds from the stories
/// it is given, with intelligence filtering off so each story keeps a place in the list.
final class Test_ListenPlayerUpNext: XCTestCase {
    private func story(_ name: String, read: Bool) -> [String: Any] {
        ["story_hash": hash(name), "story_title": name, "read_status": read ? 1 : 0, "story_feed_id": 1]
    }

    private func hash(_ name: String) -> String {
        "listen-player-tests:\(name)"
    }

    private func collection(_ stories: [[String: Any]], saved: Bool = false, read: Bool = false) -> StoriesCollection {
        let collection = StoriesCollection()
        collection.showHiddenStories = true
        collection.isSavedView = saved
        collection.isReadView = read
        collection.setStories(stories)
        return collection
    }

    private func upNext(after name: String, in collection: StoriesCollection, limit: Int = 10) -> [String] {
        ListenPlayer.upNextStories(after: hash(name), in: collection, limit: limit)
            .compactMap { $0["story_hash"] as? String }
    }

    func test_feeds_and_folders_continue_to_unread_stories_only() {
        let collection = collection([story("a", read: true), story("b", read: false), story("c", read: true),
                                     story("d", read: false), story("e", read: false)])
        XCTAssertEqual(upNext(after: "b", in: collection), [hash("d"), hash("e")])
    }

    func test_saved_stories_follow_the_list_order_although_every_story_is_read() {
        // ListenPlayerTests.swift: Saved Stories sorted oldest first with everything read must still advance.
        let collection = collection([story("a", read: true), story("b", read: true), story("c", read: true),
                                     story("d", read: true)], saved: true)
        XCTAssertEqual(upNext(after: "b", in: collection), [hash("c"), hash("d")])
    }

    func test_read_stories_follow_the_list_order() {
        let collection = collection([story("a", read: true), story("b", read: true), story("c", read: true)], read: true)
        XCTAssertEqual(upNext(after: "a", in: collection), [hash("b"), hash("c")])
    }

    func test_nothing_before_the_current_story_is_played() {
        let unreadBefore = collection([story("a", read: false), story("b", read: false), story("c", read: true)])
        XCTAssertEqual(upNext(after: "b", in: unreadBefore), [])
        let savedLast = collection([story("a", read: true), story("b", read: true)], saved: true)
        XCTAssertEqual(upNext(after: "b", in: savedLast), [])
    }

    func test_limit_caps_the_list_and_a_missing_story_has_no_next() {
        let collection = collection([story("a", read: true), story("b", read: true), story("c", read: true),
                                     story("d", read: true)], saved: true)
        XCTAssertEqual(upNext(after: "a", in: collection, limit: 2), [hash("b"), hash("c")])
        XCTAssertEqual(upNext(after: "a", in: collection, limit: 0), [])
        XCTAssertEqual(upNext(after: "not-loaded", in: collection), [])
    }
}

final class Test_ListenNarratorHandoff: XCTestCase {
    // ListenPlayerTests.swift: resolve the narrator from the actual manifest request, without downloading speech.
    private final class Server: AFHTTPSessionManager {
        var segmentFile: URL?
        var deliverLastSegment: (() -> Void)?

        override func post(_ url: String, parameters: Any?, progress: ((Progress) -> Void)?,
                           success: ((URLSessionDataTask, Any?) -> Void)?,
                           failure: ((URLSessionDataTask?, Error) -> Void)?) -> URLSessionDataTask? {
            let task = URLSession.shared.dataTask(with: URL(string: url)!)
            var reply: [String: Any] = ["code": 1, "playback_state": [:]]
            if url.hasSuffix("/listen/manifest") {
                let choices = (parameters as? [String: String])?["voice_choices"] ?? "{}"
                let voices = (try? JSONDecoder().decode([String: String].self, from: Data(choices.utf8))) ?? [:]
                reply["manifest_id"] = "test"
                if segmentFile != nil {
                    reply["segments"] = (0..<3).map { ["index": $0, "duration": 2] }
                }
                reply["voice"] = ["voice_id": voices["en"] ?? "default"]
            }
            if url.hasSuffix("/listen/segment"), let segmentFile {
                reply["url"] = segmentFile.absoluteString
                if (parameters as? [String: String])?["index"] == "2" {
                    deliverLastSegment = { success?(task, reply) }
                    return task
                }
            }
            success?(task, reply)
            return task
        }

        override func get(_ url: String, parameters: Any?, progress: ((Progress) -> Void)?,
                          success: ((URLSessionDataTask, Any?) -> Void)?,
                          failure: ((URLSessionDataTask?, Error) -> Void)?) -> URLSessionDataTask? {
            let task = URLSession.shared.dataTask(with: URL(string: url)!)
            DispatchQueue.main.async { success?(task, ["playback_state": [:]]) }
            return task
        }
    }

    // ListenPlayerTests.swift controls when the queue advances so a headless runner needs no audio output.
    private final class NarrationQueue: AVQueuePlayer {
        private(set) var playbackRequests = 0

        override func playImmediately(atRate rate: Float) {
            playbackRequests += 1
        }

        func finishCurrentItem() throws {
            let item = try XCTUnwrap(currentItem)
            advanceToNextItem()
            NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: item)
        }
    }

    func test_continuous_narration_activates_the_audio_session_once_across_segments() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        var activations = 0
        let queue = NarrationQueue()
        let player = ListenPlayer(player: queue) { _ in
            activations += 1
        }
        let server = Server()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200))
        buffer.frameLength = buffer.frameCapacity
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        server.segmentFile = url
        let oldManager = app.networkManager
        app.networkManager = server
        let key = ListenAudioMix.playOverOtherAudioKey
        let oldMix = UserDefaults.standard.object(forKey: key)
        ListenAudioMix.playsOverOtherAudio = true
        defer {
            player.stop(saving: false)
            app.networkManager = oldManager
            UserDefaults.standard.set(oldMix, forKey: key)
            try? FileManager.default.removeItem(at: url)
        }

        player.start(story: ["story_hash": "1:listen-session", "story_feed_id": 1])
        func waitUntil(_ description: String, _ condition: @escaping () -> Bool) throws {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
            let result = XCTWaiter.wait(for: [ready], timeout: SimulatorTestTiming.realWorkTimeout)
            guard result == .completed else {
                let message = "\(description). Segment \(player.segmentIndex), status \(player.status)"
                throw NSError(domain: "ListenPlayerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        try waitUntil("The first segment should start with the second queued behind it") {
            queue.playbackRequests > 0 && queue.items().count == 2
        }
        try queue.finishCurrentItem()
        try waitUntil("The queued segment should play and request the third segment") {
            player.segmentIndex == 1 && server.deliverLastSegment != nil
        }
        try queue.finishCurrentItem()
        try waitUntil("Listen should buffer while the third segment downloads") {
            player.segmentIndex == 2 && player.status == .buffering
        }

        let deliverLastSegment = try XCTUnwrap(server.deliverLastSegment)
        let requestsBeforeLastClip = queue.playbackRequests
        deliverLastSegment()
        server.deliverLastSegment = nil
        try waitUntil("Listen should start the late-arriving clip") { queue.playbackRequests > requestsBeforeLastClip }
        XCTAssertEqual(activations, 1, "Queued and late-arriving paragraphs must leave the active mixer alone")

        player.pause()
        player.play()
        XCTAssertEqual(activations, 2, "Resuming after a pause must reacquire the audio session")
    }

    func test_podcast_handoff_continues_the_rotation_and_closing_either_player_restarts_it() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let previousManager = app.networkManager
        let defaults = UserDefaults.standard
        let key = ListenPreferences.rotationsKey
        let previousRotation = defaults.object(forKey: key)
        app.networkManager = Server()
        defaults.set(#"{"en":[{"voice_id":"a"},{"voice_id":"b"},{"voice_id":"c"}]}"#, forKey: key)
        let player = ListenPlayer.shared
        let podcast = ListenMediaPlayer.shared
        let item = ListenMediaItem(storyHash: "1:podcast", mediaURL: "file:///no-podcast.mp3", title: "", feedId: nil)
        defer {
            player.stop(saving: false)
            podcast.stop(saving: false)
            ListenQueue.shared.reset()
            app.networkManager = previousManager
            defaults.set(previousRotation, forKey: key)
        }

        func playStory(_ hash: String) -> String? {
            player.start(story: ["story_hash": hash])
            return player.manifest?.voice?.id
        }

        XCTAssertEqual(playStory("1:first"), "a")
        podcast.start(item)
        XCTAssertEqual(playStory("1:next"), "b")
        player.stop()
        XCTAssertEqual(playStory("1:new"), "a")
        podcast.start(item)
        podcast.stop()
        XCTAssertEqual(playStory("1:again"), "a")
    }
}

/// ListenPlayerTests.swift: the listening allowance reads in the period apps/listen/usage.py sends. Premium Archive
/// and Archive Extra reset at midnight on the 1st of the month, Premium Pro at midnight on Sunday, both in the
/// account's timezone, which `resets_at` carries as its offset.
final class Test_ListenUsageAllowance: XCTestCase {
    private var savedLanguage: Any?
    private var savedTimeZone = NSTimeZone.default

    override func setUp() {
        super.setUp()
        savedLanguage = UserDefaults.standard.object(forKey: NBLocalization.preferenceKey)
        UserDefaults.standard.set("en", forKey: NBLocalization.preferenceKey)
        savedTimeZone = NSTimeZone.default
        // A device west of the account, where midnight in New York is still the evening before.
        NSTimeZone.default = TimeZone(identifier: "Pacific/Honolulu")!
    }

    override func tearDown() {
        NSTimeZone.default = savedTimeZone
        UserDefaults.standard.set(savedLanguage, forKey: NBLocalization.preferenceKey)
        super.tearDown()
    }

    private func usage(tier: String, period: String, limit: Double, resetsAt: String) -> ListenUsage {
        ListenUsage(json: ["tier": tier, "is_archive_tier": true, "period": period, "seconds_used": 1800,
                           "seconds_limit": limit, "seconds_remaining": limit - 1800, "resets_at": resetsAt])!
    }

    func test_monthlyAllowanceSaysThisMonthAndResetsOnTheFirst() throws {
        let archive = usage(tier: "archive", period: "month", limit: 3600, resetsAt: "2026-12-01T00:00:00-05:00")

        XCTAssertTrue(try XCTUnwrap(archive.allowanceLeftText).hasSuffix(" left this month"))
        XCTAssertTrue(try XCTUnwrap(archive.allowanceOfLimitText).hasSuffix(" of listening left this month"))
        let reset = try XCTUnwrap(archive.resetText)
        XCTAssertTrue(reset.hasPrefix("Resets on "), reset)
        XCTAssertTrue(reset.contains("December"), reset)
    }

    func test_weeklyAllowanceSaysThisWeekAndResetsOnSunday() throws {
        let pro = usage(tier: "pro", period: "week", limit: 36000, resetsAt: "2026-11-29T00:00:00-05:00")

        XCTAssertTrue(try XCTUnwrap(pro.allowanceLeftText).hasSuffix(" left this week"))
        XCTAssertTrue(try XCTUnwrap(pro.allowanceOfLimitText).hasSuffix(" of listening left this week"))
        XCTAssertEqual(pro.resetText, "Resets Sunday")
    }
}
