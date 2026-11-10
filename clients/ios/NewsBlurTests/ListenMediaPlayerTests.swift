import AVFoundation
import MediaPlayer
import XCTest

@testable import NewsBlur

/// ListenMediaPlayerTests.swift's stand-in for AVPlayer: it records what ListenMediaPlayer.swift asks for, and the
/// test sends the events AVPlayer would.
private final class FakeMediaEngine: ListenMediaEngine {
    var onEvent: ((ListenMediaEngineEvent) -> Void)?
    var currentTime: TimeInterval = 0
    private(set) var loads: [(url: URL, startAt: TimeInterval)] = []
    private(set) var plays: [Double] = []
    private(set) var pauses = 0
    private(set) var seeks: [TimeInterval] = []
    private(set) var unloads = 0

    func load(_ url: URL, startAt: TimeInterval) {
        loads.append((url, startAt))
        currentTime = startAt
    }

    func play(rate: Double) {
        plays.append(rate)
    }

    func pause() {
        pauses += 1
    }

    func seek(to time: TimeInterval) {
        seeks.append(time)
        currentTime = time
    }

    func setRate(_ rate: Double) {}

    func unload() {
        unloads += 1
    }

    func send(_ event: ListenMediaEngineEvent) {
        onEvent?(event)
    }
}

/// ListenMediaPlayerTests.swift's stand-in for apps/media_player. Reads of /media_player/playback_state wait for the
/// test to answer them; POSTs are answered at once unless `holdsPosts` is set, with queue edits applied the way
/// apps/media_player/models.py applies them. A save makes its item current, and sync_playback_position answers
/// code -1 for anything else, as apps/media_player/views.py does.
private final class FakeMediaPlayerServer: ListenQueueTransport {
    var state: [String: Any] = ["queue": [], "history": [], "skip_back_seconds": 15, "skip_forward_seconds": 30,
                                "auto_play_next": true, "remember_position": true]
    private(set) var posts: [(path: String, parameters: [String: String])] = []
    private var heldReads: [(success: (Any?) -> Void, failure: (Error?) -> Void)] = []
    var holdsPosts = false
    private var heldPosts: [() -> Void] = []
    /// How many of the next save_playback_state requests fail, as they would offline.
    var failingSaves = 0

    var heldReadCount: Int { heldReads.count }

    func get(_ path: String, success: @escaping (Any?) -> Void, failure: @escaping (Error?) -> Void) {
        XCTAssertEqual(path, "/media_player/playback_state")
        heldReads.append((success, failure))
    }

    func post(_ path: String, parameters: [String: String], success: @escaping (Any?) -> Void,
              failure: @escaping (Error?) -> Void) {
        posts.append((path, parameters))
        if path == "/media_player/save_playback_state", failingSaves > 0 {
            failingSaves -= 1
            failure(URLError(.notConnectedToInternet))
            return
        }
        if holdsPosts {
            heldPosts.append { [unowned self] in self.answer(path, parameters: parameters, success: success) }
        } else {
            answer(path, parameters: parameters, success: success)
        }
    }

    func answerHeldPosts() {
        holdsPosts = false
        while !heldPosts.isEmpty {
            heldPosts.removeFirst()()
        }
    }

    private func answer(_ path: String, parameters: [String: String], success: @escaping (Any?) -> Void) {
        if path == "/media_player/sync_playback_position" {
            success(["code": parameters["media_url"] == state["current_media_url"] as? String ? 1 : -1])
            return
        }
        if path == "/media_player/save_playback_state" {
            for (key, value) in parameters {
                state[key] = value
            }
        }
        var queue = state["queue"] as? [[String: Any]] ?? []
        let sameItem: ([String: Any]) -> Bool = {
            $0["story_hash"] as? String == parameters["story_hash"] && $0["media_url"] as? String == parameters["media_url"]
        }
        switch path {
        case "/media_player/add_to_media_queue":
            queue.removeAll(where: sameItem)
            if let position = parameters["position"].flatMap(Int.init), position <= queue.count {
                queue.insert(parameters, at: position)
            } else {
                queue.append(parameters)
            }
        case "/media_player/remove_from_media_queue":
            queue.removeAll(where: sameItem)
        case "/media_player/add_to_media_history":
            // apps/media_player/models.py add_to_history: most recent first, one entry per item.
            var history = state["history"] as? [[String: Any]] ?? []
            history.removeAll(where: sameItem)
            history.insert(parameters, at: 0)
            state["history"] = history
        default:
            break
        }
        state["queue"] = queue
        success(["playback_state": state])
    }

    func answerReads() {
        let reads = heldReads
        heldReads = []
        reads.forEach { $0.success(["playback_state": state]) }
    }

    func failReads() {
        let reads = heldReads
        heldReads = []
        reads.forEach { $0.failure(NSError(domain: "ListenMediaPlayerTests", code: 502)) }
    }

    func posted(_ path: String) -> [[String: String]] {
        posts.filter { $0.path == path }.map(\.parameters)
    }

    var saves: [[String: String]] { posted("/media_player/save_playback_state") }
    var syncs: [[String: String]] { posted("/media_player/sync_playback_position") }
    var historyAdds: [[String: String]] { posted("/media_player/add_to_media_history") }

    func queueEntry(hash: String, url: String, type: String = "audio") -> [String: Any] {
        ["story_hash": hash, "media_url": url, "media_type": type, "media_title": hash, "feed_id": "1"]
    }
}

/// ListenMediaPlayerTests.swift's stand-in for ListenPlayer.swift: starting a queued story stops the podcast, as
/// ListenPlayer.start(story:) does.
private final class FakeListenSession: ListenSessionHandoff {
    var isActive = false
    private(set) var handoffStops = 0
    private(set) var playedQueued: [ListenQueueItem] = []
    weak var media: ListenMediaPlayer?

    func stopForHandoff() {
        handoffStops += 1
        isActive = false
    }

    func play(queued item: ListenQueueItem) {
        media?.stopForHandoff()
        playedQueued.append(item)
        isActive = true
    }
}

/// A Listen story playing, for the remote command router.
private final class FakeRemoteSession: ListenRemoteControllable {
    var isActive = false
    var wantsToPlay = false
    var canSeek = true
    var hasNextTrack = false
    private(set) var calls: [String] = []

    func play() { calls.append("play") }
    func pause() { calls.append("pause") }
    func togglePlayPause() { calls.append("toggle") }
    func skipBackward() { calls.append("back") }
    func skipForward() { calls.append("forward") }
    func seek(toRemotePosition time: TimeInterval) { calls.append("seek \(time)") }
    func playNextTrack() { calls.append("next") }
}

/// ListenMediaPlayerTests.swift: podcast episodes played by ListenMediaPlayer.swift resume where the web or Android
/// left them, save their place for those devices, follow the web's skip and auto-play settings, and hand over to
/// Listen cleanly.
final class Test_ListenMediaPlayer: XCTestCase {
    private var engine: FakeMediaEngine!
    private var server: FakeMediaPlayerServer!
    private var queue: ListenQueue!
    private var listen: FakeListenSession!
    private var player: ListenMediaPlayer!
    private var now = Date(timeIntervalSince1970: 1_000_000)
    private var scheduled: [() -> Void] = []
    private var miniPlayerHides = 0

    private let episodeURL = "https://cdn.example.com/episodes/42.mp3"
    private let episode = ListenMediaItem(storyHash: "1:aaaaaa", mediaURL: "https://cdn.example.com/episodes/42.mp3",
                                          title: "Episode 42", feedId: "1")

    override func setUp() {
        super.setUp()
        engine = FakeMediaEngine()
        server = FakeMediaPlayerServer()
        queue = ListenQueue(transport: server)
        listen = FakeListenSession()
        scheduled = []
        miniPlayerHides = 0
        let environment = ListenMediaPlayer.Environment(
            now: { [unowned self] in self.now },
            schedule: { [unowned self] _, work in self.scheduled.append(work) },
            showMiniPlayer: {},
            hideMiniPlayer: { [unowned self] in self.miniPlayerHides += 1 },
            stateDidChange: {},
            publishesNowPlaying: false,
            listenSession: { [unowned self] in self.listen },
            feedTitle: { _ in "The Feed" },
            activateAudioSession: {},
            deactivateAudioSession: {}
        )
        player = ListenMediaPlayer(engine: engine, queue: queue, environment: environment)
        listen.media = player
    }

    override func tearDown() {
        player = nil
        queue = nil
        super.tearDown()
    }

    /// Starts `item` and answers its playback state read with the server's state.
    private func start(_ item: ListenMediaItem? = nil) {
        player.start(item ?? episode)
        server.answerReads()
    }

    private func savedCurrent(hash: String, url: String, type: String = "audio", position: Double, duration: Double) {
        server.state["current_story_hash"] = hash
        server.state["current_media_url"] = url
        server.state["current_media_type"] = type
        server.state["current_position"] = position
        server.state["current_duration"] = duration
    }

    func test_voice_sample_does_not_leave_a_playing_podcast_mixing_with_other_apps() throws {
        let key = ListenAudioMix.playOverOtherAudioKey
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        UserDefaults.standard.set(true, forKey: key)
        start()
        let preview = ListenVoicePreviewPlayer(mediaPlayer: player)
        let voice = try XCTUnwrap(ListenVoice(json: ["voice_id": "test"]))
        // ListenMediaPlayerTests.swift drives the same local-file preview entry point as a completed download.
        preview.play(URL(fileURLWithPath: "/tmp/newsblur-preview-test.caf"), voice: voice)
        XCTAssertEqual(AVAudioSession.sharedInstance().routeSharingPolicy, .longFormAudio)
        XCTAssertFalse(AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers))
        preview.stop()
        XCTAssertTrue(player.wantsToPlay)
        XCTAssertEqual(AVAudioSession.sharedInstance().routeSharingPolicy, .longFormAudio)
        XCTAssertFalse(AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers))
    }

    // MARK: - Resuming

    func test_episodePausedOnAnotherDeviceResumesAtItsSavedPlace() {
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 1234.5, duration: 3600)
        start()
        XCTAssertEqual(engine.loads.count, 1)
        XCTAssertEqual(engine.loads.first?.url.absoluteString, episodeURL)
        XCTAssertEqual(engine.loads.first?.startAt, 1234.5)
        XCTAssertEqual(engine.plays.count, 1)
        XCTAssertEqual(player.elapsed, 1234.5)
    }

    func test_currentItemMatchesOnStoryHashWhenTheEnclosureURLChanged() {
        savedCurrent(hash: episode.storyHash, url: "http://cdn.example.com/episodes/42.mp3?tracking=1",
                     position: 600, duration: 3600)
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 600)
    }

    func test_anotherEpisodeAsTheCurrentItemStartsFromTheBeginning() {
        savedCurrent(hash: "2:bbbbbb", url: "https://cdn.example.com/other.mp3", position: 900, duration: 3600)
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 0)
    }

    func test_listenPlaceInTheSameStoryIsNotAPlaceInTheEpisode() {
        savedCurrent(hash: episode.storyHash, url: "/listen/story/\(episode.storyHash)", type: "listen",
                     position: 120, duration: 400)
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 0)
    }

    func test_rememberPositionOffStartsFromTheBeginning() {
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 1234, duration: 3600)
        server.state["remember_position"] = false
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 0)
    }

    func test_episodeReplacedByAnotherItemResumesFromHistory() {
        savedCurrent(hash: "3:cccccc", url: "/listen/story/3:cccccc", type: "listen", position: 30, duration: 300)
        server.state["history"] = [["story_hash": episode.storyHash, "media_url": episodeURL, "media_type": "audio",
                                    "position": "845.0", "duration": "3600.0"]]
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 845)
    }

    func test_episodeSavedAtItsEndStartsOver() {
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 3598, duration: 3600)
        start()
        XCTAssertEqual(engine.loads.first?.startAt, 0)
    }

    func test_unansweredStateReadStartsFromTheLastKnownStateAndALateAnswerChangesNothing() {
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 300, duration: 3600)
        queue.refresh()
        server.answerReads()
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 999, duration: 3600)

        player.start(episode)
        XCTAssertTrue(engine.loads.isEmpty, "Nothing loads before the state or the timeout")
        XCTAssertEqual(player.status, .loading)
        scheduled.forEach { $0() }
        XCTAssertEqual(engine.loads.map(\.startAt), [300])

        server.answerReads()
        XCTAssertEqual(engine.loads.count, 1)
    }

    func test_failedStateReadStartsFromTheLastKnownState() {
        savedCurrent(hash: episode.storyHash, url: episodeURL, position: 300, duration: 3600)
        queue.refresh()
        server.answerReads()

        player.start(episode)
        server.failReads()
        XCTAssertEqual(engine.loads.map(\.startAt), [300])
    }

    // MARK: - Saving the place

    func test_positionIsSyncedEveryTenSecondsWhilePlaying() {
        start()
        XCTAssertEqual(server.saves.count, 1, "The new current item is saved as it starts")
        let saved = server.saves.last
        XCTAssertEqual(saved?["current_media_url"], episodeURL)
        XCTAssertEqual(saved?["current_story_hash"], episode.storyHash)
        XCTAssertEqual(saved?["current_media_type"], "audio")
        XCTAssertEqual(saved?["is_playing"], "true")
        XCTAssertEqual(saved?["current_position"], "0.0")
        // ListenMediaPlayerTests.swift: iOS never sends a stale copy of the web's settings, a rate nobody changed
        // here, or a length it doesn't know yet.
        for key in ["skip_back_seconds", "skip_forward_seconds", "auto_play_next", "remember_position",
                    "resume_on_load", "current_volume", "current_playback_rate", "current_duration"] {
            XCTAssertNil(saved?[key], key)
        }

        engine.send(.playing)
        let start = now
        for second in 1...25 {
            now = start.addingTimeInterval(TimeInterval(second))
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertEqual(server.saves.count, 1, "Playing writes Redis only, like the web's websocket")
        XCTAssertEqual(server.syncs.map { $0["position"] }, ["10.0", "20.0"])
        XCTAssertEqual(server.syncs.last?["media_url"], episodeURL)
        XCTAssertEqual(server.syncs.last?["is_playing"], "true")
        XCTAssertEqual(server.syncs.last?["playback_rate"], "1.00")
        XCTAssertNil(server.syncs.last?["duration"], "An unknown length isn't sent as zero")
    }

    func test_syncingStopsOnceAnotherDeviceMakesSomethingElseCurrent() {
        start()
        engine.send(.ready(duration: 3600))
        engine.send(.playing)
        server.state["current_media_url"] = "https://cdn.example.com/web-started-this.mp3"
        for second in 1...45 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertEqual(server.syncs.count, 1, "Code -1 stops the syncs; nothing retries")
        XCTAssertEqual(server.syncs.first?["duration"], "3600.0")

        // ListenMediaPlayerTests.swift: pausing here saves the episode as current again, so syncing picks up.
        player.pause()
        player.play()
        engine.send(.playing)
        for second in 46...56 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertEqual(server.syncs.count, 2)
    }

    /// Runs the work the player scheduled (retries and the playback state timeout), as time passing would.
    private func runScheduled() {
        let work = scheduled
        scheduled = []
        work.forEach { $0() }
    }

    func test_startSaveThatFailedIsRetriedUntilSyncingCanBegin() {
        server.failingSaves = 2
        start()
        engine.send(.ready(duration: 3600))
        engine.send(.playing)
        for second in 1...25 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertTrue(server.syncs.isEmpty, "No syncs while the server doesn't know the episode is current")

        runScheduled()
        XCTAssertEqual(server.saves.count, 2, "First retry, still offline")
        XCTAssertTrue(server.syncs.isEmpty)
        runScheduled()
        XCTAssertEqual(server.saves.count, 3, "Second retry lands")
        XCTAssertEqual(server.saves.last?["current_media_url"], episodeURL)
        XCTAssertEqual(server.saves.last?["current_position"], "25.0")
        XCTAssertEqual(server.saves.last?["is_playing"], "true")

        for second in 26...36 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertEqual(server.syncs.count, 1, "Syncing begins once the episode is current")
        runScheduled()
        XCTAssertEqual(server.saves.count, 3, "Nothing retries after the save landed")
    }

    func test_episodeStartedWhileAnotherEpisodesRetryWaitsGetsItsOwnRetry() {
        // ListenMediaPlayerTests.swift: offline, episode 42's start save fails, then 43 starts: 42's paused save
        // and 43's start save fail too.
        server.failingSaves = 3
        start()
        engine.send(.time(60))
        let other = ListenMediaItem(storyHash: "8:gggggg", mediaURL: "https://cdn.example.com/episodes/43.mp3",
                                    title: "Episode 43", feedId: "1")
        start(other)
        engine.send(.ready(duration: 3600))
        engine.send(.playing)

        runScheduled()
        let otherSaves = server.saves.filter { $0["current_media_url"] == other.mediaURL }
        XCTAssertEqual(otherSaves.count, 2, "Episode 43's failed start save is retried")
        XCTAssertEqual(server.saves.last?["current_media_url"], other.mediaURL, "42's stale retry stays quiet")
        for second in 1...11 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertEqual(server.syncs.map { $0["media_url"] }, [other.mediaURL])
    }

    func test_retryForAnEpisodeHandedOffSinceDoesNothing() {
        server.failingSaves = 1
        start()
        engine.send(.time(120))
        player.stopForHandoff()
        let saves = server.saves.count
        runScheduled()
        XCTAssertEqual(server.saves.count, saves, "A stale retry can't make the old episode current again")
    }

    func test_podcastRateIsSavedOnlyOnceItChangesHere() {
        server.state["current_playback_rate"] = 1.25
        start()
        XCTAssertNil(server.saves.last?["current_playback_rate"])
        XCTAssertEqual(engine.plays.last, 1.25, "The web's podcast speed applies")
        player.setSpeed(1.5)
        XCTAssertEqual(server.saves.last?["current_playback_rate"], "1.50")
        player.pause()
        XCTAssertEqual(server.saves.last?["current_playback_rate"], "1.50")
    }

    func test_switchingEpisodesSavesThePreviousOnePausedBeforeTheNextBecomesCurrent() {
        start()
        engine.send(.ready(duration: 3600))
        engine.send(.playing)
        engine.send(.time(300))
        let next = ListenMediaItem(storyHash: "8:gggggg", mediaURL: "https://cdn.example.com/episodes/43.mp3",
                                   title: "Episode 43", feedId: "1")
        player.start(next)
        server.answerReads()

        let stateRequests = server.posts.filter { $0.path != "/media_player/remove_from_media_queue" }.suffix(3)
        XCTAssertEqual(stateRequests.map(\.path), ["/media_player/save_playback_state",
                                                   "/media_player/add_to_media_history",
                                                   "/media_player/save_playback_state"])
        XCTAssertEqual(stateRequests.first?.parameters["current_media_url"], episodeURL)
        XCTAssertEqual(stateRequests.first?.parameters["current_position"], "300.0")
        XCTAssertEqual(stateRequests.first?.parameters["is_playing"], "false")
        XCTAssertEqual(stateRequests.last?.parameters["current_media_url"], next.mediaURL)
        XCTAssertEqual(stateRequests.last?.parameters["is_playing"], "true")
    }

    func test_resumeReadWaitsForTheHandedOffEpisodesSave() {
        start()
        engine.send(.time(300))
        server.holdsPosts = true
        player.start(ListenMediaItem(storyHash: "8:gggggg", mediaURL: "https://cdn.example.com/episodes/43.mp3",
                                     title: "Episode 43", feedId: "1"))
        XCTAssertEqual(server.heldReadCount, 0, "The read waits until the previous episode's save has landed")
        server.answerHeldPosts()
        XCTAssertEqual(server.heldReadCount, 1)
    }

    func test_episodeLeftPartWayOnAnotherDeviceGoesToHistoryWhenAnotherStarts() {
        savedCurrent(hash: "9:hhhhhh", url: "https://cdn.example.com/web-episode.mp3", position: 600, duration: 1800)
        server.state["current_media_title"] = "Web episode"
        start()
        XCTAssertEqual(server.historyAdds.map { $0["media_url"] }, ["https://cdn.example.com/web-episode.mp3"])
        XCTAssertEqual(server.historyAdds.first?["position"], "600.0")
        XCTAssertEqual(server.historyAdds.first?["media_title"], "Web episode")
        let historyIndex = server.posts.firstIndex { $0.path == "/media_player/add_to_media_history" } ?? .max
        let saveIndex = server.posts.firstIndex { $0.path == "/media_player/save_playback_state" } ?? .min
        XCTAssertLessThan(historyIndex, saveIndex)
    }

    func test_storyReadAloudAsTheCurrentItemIsNotPutInHistory() {
        savedCurrent(hash: "3:cccccc", url: "/listen/story/3:cccccc", type: "listen", position: 30, duration: 300)
        start()
        XCTAssertTrue(server.historyAdds.isEmpty)
    }

    func test_nothingIsSyncedWhilePaused() {
        start()
        engine.send(.playing)
        player.pause()
        for second in 1...25 {
            now = now.addingTimeInterval(1)
            engine.send(.time(TimeInterval(second)))
        }
        XCTAssertTrue(server.syncs.isEmpty)
    }

    func test_pausingSavesThePlaceAtOnce() {
        start()
        engine.send(.playing)
        now = now.addingTimeInterval(2)
        engine.send(.time(62))
        player.pause()
        XCTAssertEqual(server.saves.count, 2)
        XCTAssertEqual(server.saves.last?["current_position"], "62.0")
        XCTAssertEqual(server.saves.last?["is_playing"], "false")
        XCTAssertEqual(engine.pauses, 1)
    }

    func test_backgroundingAndQuittingSaveThePlace() {
        start()
        engine.send(.playing)
        engine.send(.time(75))
        player.applicationDidEnterBackground()
        XCTAssertEqual(server.saves.last?["current_position"], "75.0")
        XCTAssertEqual(server.saves.last?["is_playing"], "true")
        player.applicationWillTerminate()
        XCTAssertEqual(server.saves.last?["is_playing"], "false")
    }

    func test_closedEpisodeResumesAfterAnotherEpisodeTakesItsPlace() {
        start()
        engine.send(.ready(duration: 3600))
        engine.send(.playing)
        engine.send(.time(300))
        player.stop()
        XCTAssertEqual(server.historyAdds.last?["media_url"], episodeURL)
        XCTAssertEqual(server.historyAdds.last?["position"], "300.0")

        let other = ListenMediaItem(storyHash: "8:gggggg", mediaURL: "https://cdn.example.com/episodes/43.mp3",
                                    title: "Episode 43", feedId: "1")
        start(other)
        XCTAssertEqual(server.state["current_media_url"] as? String, other.mediaURL, "Episode 43 replaced 42 as current")
        start()
        XCTAssertEqual(engine.loads.last?.url.absoluteString, episodeURL)
        XCTAssertEqual(engine.loads.last?.startAt, 300, "History still has where episode 42 was closed")
    }

    func test_closingSavesThePlaceInsteadOfClearingTheSharedState() {
        start()
        engine.send(.time(40))
        player.stop()
        XCTAssertEqual(server.saves.last?["current_position"], "40.0")
        XCTAssertEqual(server.saves.last?["is_playing"], "false")
        XCTAssertTrue(server.posted("/media_player/clear_playback_state").isEmpty)
        XCTAssertFalse(player.isActive)
        XCTAssertEqual(miniPlayerHides, 1)
    }

    // MARK: - Skips and remote commands

    func test_skipsUseTheIntervalsSavedInThePlayerSettings() {
        server.state["skip_back_seconds"] = 10
        server.state["skip_forward_seconds"] = 60
        start()
        engine.send(.ready(duration: 200))
        engine.send(.time(100))
        player.skipForward()
        XCTAssertEqual(engine.seeks.last, 160)
        player.skipBackward()
        XCTAssertEqual(engine.seeks.last, 150)
        engine.send(.time(5))
        player.skipBackward()
        XCTAssertEqual(engine.seeks.last, 0)
        engine.send(.time(180))
        player.skipForward()
        XCTAssertEqual(engine.seeks.last, 200, "Never past the end")
    }

    func test_remoteCommandsControlWhicheverPlayerIsActive() {
        server.state["skip_back_seconds"] = 5
        server.state["skip_forward_seconds"] = 60
        let story = FakeRemoteSession()
        let commands = ListenRemoteCommands(sessions: { [unowned self] in [self.player, story] },
                                            settings: { [unowned self] in self.queue.settings })
        XCTAssertEqual(commands.handle(.togglePlayPause), .noActionableNowPlayingItem)

        story.isActive = true
        XCTAssertEqual(commands.handle(.skipForward), .success)
        XCTAssertEqual(story.calls, ["forward"])
        XCTAssertEqual(commands.handle(.nextTrack), .noSuchContent)

        story.isActive = false
        start()
        XCTAssertEqual(commands.skipIntervals.backward, 5)
        XCTAssertEqual(commands.skipIntervals.forward, 60)
        engine.send(.ready(duration: 3000))
        engine.send(.playing)
        engine.send(.time(1000))
        XCTAssertEqual(commands.handle(.skipForward), .success)
        XCTAssertEqual(engine.seeks.last, 1060)
        XCTAssertEqual(commands.handle(.skipBackward), .success)
        XCTAssertEqual(engine.seeks.last, 1055)
        let saves = server.saves.count
        XCTAssertEqual(commands.handle(.changePosition(42)), .success)
        XCTAssertEqual(engine.seeks.last, 42)
        XCTAssertEqual(server.saves.count, saves + 1, "Scrubbing from the lock screen saves the place")
        XCTAssertEqual(commands.handle(.togglePlayPause), .success)
        XCTAssertFalse(player.wantsToPlay)
        XCTAssertEqual(commands.handle(.play), .success)
        XCTAssertTrue(player.wantsToPlay)
        XCTAssertEqual(commands.handle(.nextTrack), .noSuchContent)
        XCTAssertTrue(story.calls == ["forward"], "The story player hears nothing while the podcast plays")
    }

    // MARK: - Up Next

    func test_finishedEpisodeGoesToHistoryAndAutoPlayStartsTheNextQueuedEpisode() {
        let nextURL = "https://cdn.example.com/episodes/43.mp3"
        server.state["queue"] = [server.queueEntry(hash: "4:video", url: "https://youtube.com/embed/x", type: "youtube"),
                                 server.queueEntry(hash: "5:dddddd", url: nextURL)]
        queue.refresh()
        server.answerReads()
        start()
        engine.send(.ready(duration: 1800))
        engine.send(.playing)
        engine.send(.finished)

        XCTAssertEqual(server.historyAdds.count, 1)
        XCTAssertEqual(server.historyAdds.first?["media_url"], episodeURL)
        XCTAssertEqual(server.historyAdds.first?["position"], "1800.0")
        XCTAssertEqual(player.item?.mediaURL, nextURL)
        XCTAssertEqual(server.posted("/media_player/remove_from_media_queue").map { $0["media_url"] }, [nextURL])
        server.answerReads()
        XCTAssertEqual(engine.loads.last?.url.absoluteString, nextURL)
        XCTAssertEqual(queue.items.map(\.mediaType), ["youtube"], "The video waits for the web")
        XCTAssertEqual(server.historyAdds.count, 1, "The finished episode is recorded once")
    }

    func test_autoPlayOffStaysOnTheFinishedEpisode() {
        server.state["auto_play_next"] = false
        server.state["queue"] = [server.queueEntry(hash: "5:dddddd", url: "https://cdn.example.com/episodes/43.mp3")]
        queue.refresh()
        server.answerReads()
        start()
        engine.send(.ready(duration: 1800))
        engine.send(.playing)
        engine.send(.finished)

        XCTAssertEqual(player.status, .finished)
        XCTAssertEqual(player.item?.mediaURL, episodeURL)
        XCTAssertEqual(engine.loads.count, 1)
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(server.saves.last?["is_playing"], "false")
        XCTAssertEqual(server.saves.last?["current_position"], "1800.0")
    }

    func test_queuedStoryReadAloudIsHandedToListenWhenAnEpisodeEnds() {
        server.state["queue"] = [server.queueEntry(hash: "6:eeeeee", url: "/listen/story/6:eeeeee", type: "listen")]
        queue.refresh()
        server.answerReads()
        start()
        engine.send(.ready(duration: 900))
        engine.send(.finished)

        XCTAssertEqual(listen.playedQueued.map(\.storyHash), ["6:eeeeee"])
        XCTAssertFalse(player.isActive)
        XCTAssertEqual(server.historyAdds.count, 1)
    }

    func test_episodeQueuedBehindAStoryReadAloudPlaysInTheEpisodePlayerNext() {
        let podcastURL = "https://cdn.example.com/episodes/44.mp3"
        server.state["queue"] = [server.queueEntry(hash: "4:video", url: "https://youtube.com/embed/x", type: "youtube"),
                                 server.queueEntry(hash: "10:podcast", url: podcastURL),
                                 server.queueEntry(hash: "11:story", url: "/listen/story/11:story", type: "listen")]
        queue.refresh()
        server.answerReads()
        // ListenMediaPlayerTests.swift: story "1:story" is being read aloud, and Up Next is a video, an episode
        // played as the Play Last pill queued it, and another story.
        listen.isActive = true
        XCTAssertTrue(ListenPlayer.hasNextQueued(in: queue, playingStoryHash: "1:story"))

        var storiesRead: [String] = []
        let first = ListenPlayer.takeNextQueued(from: queue, playingStoryHash: "1:story")
        XCTAssertEqual(first?.mediaURL, podcastURL, "Queue order, with the video passed over")
        ListenPlayer.route(try! XCTUnwrap(first), playStory: { storiesRead.append($0["story_hash"] as? String ?? "") },
                           media: player)
        XCTAssertEqual(player.item?.mediaURL, podcastURL)
        XCTAssertEqual(listen.handoffStops, 1, "The story stops before the episode plays")
        XCTAssertTrue(storiesRead.isEmpty)
        XCTAssertEqual(queue.items.map(\.mediaType), ["youtube", "listen"], "The video stays queued for the web")

        let second = ListenPlayer.takeNextQueued(from: queue, playingStoryHash: nil)
        ListenPlayer.route(try! XCTUnwrap(second), playStory: { storiesRead.append($0["story_hash"] as? String ?? "") },
                           media: player)
        XCTAssertEqual(storiesRead, ["11:story"])
        XCTAssertFalse(ListenPlayer.hasNextQueued(in: queue, playingStoryHash: "11:story"))
    }

    func test_storyBeingReadIsNotItsOwnNextItem() {
        server.state["queue"] = [server.queueEntry(hash: "1:story", url: "/listen/story/1:story", type: "listen")]
        queue.refresh()
        server.answerReads()
        XCTAssertFalse(ListenPlayer.hasNextQueued(in: queue, playingStoryHash: "1:story"))
        XCTAssertNil(ListenPlayer.takeNextQueued(from: queue, playingStoryHash: "1:story"))
        XCTAssertEqual(queue.items.count, 1)
    }

    func test_playNextAndPlayLastQueueTheEpisodeLikeTheWeb() {
        queue.add(media: ListenMediaItem(storyHash: "7:ffffff", mediaURL: "https://cdn.example.com/a.mp3",
                                         title: "A", feedId: "1"))
        let position = queue.add(media: episode, position: 0)
        XCTAssertEqual(position, 1)
        let adds = server.posted("/media_player/add_to_media_queue")
        XCTAssertNil(adds.first?["position"])
        XCTAssertEqual(adds.last?["position"], "0")
        XCTAssertEqual(adds.last?["media_type"], "audio")
        XCTAssertEqual(queue.playableItems.map(\.mediaURL), [episodeURL, "https://cdn.example.com/a.mp3"])

        // ListenMediaPlayerTests.swift: an episode starting is taken off Up Next, as media_player_view.js does.
        start()
        XCTAssertEqual(queue.playableItems.map(\.mediaURL), ["https://cdn.example.com/a.mp3"])
        XCTAssertTrue(player.hasNextTrack)
    }

    // MARK: - Handoff with Listen

    func test_startingAnEpisodeStopsTheStoryBeingReadAloud() {
        listen.isActive = true
        start()
        XCTAssertEqual(listen.handoffStops, 1)
        XCTAssertTrue(player.isActive)
    }

    func test_listenStartingStopsTheEpisodeAndKeepsItsPlaceInHistory() {
        start()
        engine.send(.ready(duration: 3600))
        engine.send(.playing)
        engine.send(.time(300))
        let saves = server.saves.count
        player.stopForHandoff()

        XCTAssertFalse(player.isActive)
        XCTAssertEqual(server.historyAdds.last?["media_url"], episodeURL)
        XCTAssertEqual(server.historyAdds.last?["position"], "300.0")
        XCTAssertEqual(server.saves.count, saves + 1)
        XCTAssertEqual(server.saves.last?["current_position"], "300.0")
        XCTAssertEqual(server.saves.last?["is_playing"], "false")
        XCTAssertEqual(server.posts.last?.path, "/media_player/add_to_media_history",
                       "Saved paused, then History, before Listen saves itself as current")
        XCTAssertEqual(miniPlayerHides, 0, "The mini player stays up for Listen")
        XCTAssertGreaterThanOrEqual(engine.unloads, 2)
    }

    // MARK: - Story cards

    func test_audioTheAppCannotPlayStaysInTheStorysOwnPlayer() {
        // ListenMediaPlayerTests.swift: a relative src has no server to stream from here, so the card hands back.
        XCTAssertFalse(ListenMediaStoryBridge.perform("toggle", url: "/episodes/42.mp3",
                                                      story: ["story_hash": episode.storyHash]))
        XCTAssertFalse(ListenMediaStoryBridge.perform("last", url: "not a url",
                                                      story: ["story_hash": episode.storyHash]))
    }

    // MARK: - Server state

    func test_playbackStateReadsSettingsAndPositionsFromStringsOrNumbers() {
        let state = ListenPlaybackState(json: ["skip_back_seconds": "0", "skip_forward_seconds": 45,
                                               "auto_play_next": "false", "remember_position": 1,
                                               "current_media_url": episodeURL, "current_story_hash": episode.storyHash,
                                               "current_media_type": "audio", "current_position": "12.5",
                                               "current_duration": 100, "current_playback_rate": "1.5"])
        XCTAssertEqual(state.settings, ListenPlaybackSettings(skipBackSeconds: 15, skipForwardSeconds: 45,
                                                              autoPlayNext: false, rememberPosition: true))
        XCTAssertEqual(state.currentPlaybackRate, 1.5)
        XCTAssertEqual(state.resumePosition(for: episode), 12.5)
    }
}
