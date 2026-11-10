import XCTest

@testable import NewsBlur

/// ListenQueueTests.swift's stand-in for apps/media_player. It holds every request until the test answers it, so a
/// test can deliver a later request first the way a slow network can. Edits change the queue the way
/// apps/media_player/models.py does when the test answers them; a read answers with the queue as it stood when the
/// read arrived.
private final class FakeMediaPlayerServer: ListenQueueTransport {
    struct Request {
        let path: String
        let parameters: [String: String]
        let snapshot: [[String: Any]]
        let success: (Any?) -> Void
        let failure: (Error?) -> Void
    }

    var queue: [[String: Any]] = []
    private(set) var unanswered: [Request] = []
    /// The edits the server ran, in the order it ran them.
    private(set) var ranEdits: [String] = []

    var queueIds: [String] {
        queue.map { "\($0["story_hash"] as? String ?? "")|\($0["media_url"] as? String ?? "")" }
    }

    func get(_ path: String, success: @escaping (Any?) -> Void, failure: @escaping (Error?) -> Void) {
        unanswered.append(Request(path: path, parameters: [:], snapshot: queue, success: success, failure: failure))
    }

    func post(_ path: String, parameters: [String: String], success: @escaping (Any?) -> Void,
              failure: @escaping (Error?) -> Void) {
        unanswered.append(Request(path: path, parameters: parameters, snapshot: queue, success: success,
                                  failure: failure))
    }

    /// Answers the request sent most recently, before any sent earlier.
    func answerNewest(failing: Bool = false) {
        let request = unanswered.removeLast()
        if failing {
            request.failure(NSError(domain: "ListenQueueTests", code: 500))
            return
        }
        if request.path == "/media_player/playback_state" {
            request.success(["playback_state": ["queue": request.snapshot]])
            return
        }
        run(request)
        request.success(["playback_state": ["queue": queue]])
    }

    private func run(_ request: Request) {
        ranEdits.append(request.path)
        let hash = request.parameters["story_hash"]
        let url = request.parameters["media_url"]
        switch request.path {
        case "/media_player/add_to_media_queue":
            queue.removeAll { $0["story_hash"] as? String == hash && $0["media_url"] as? String == url }
            queue.append(request.parameters)
        case "/media_player/remove_from_media_queue":
            queue.removeAll { $0["story_hash"] as? String == hash && $0["media_url"] as? String == url }
        case "/media_player/reorder_media_queue":
            // apps/media_player/models.py reorder_queue drops anything queue_order leaves out.
            let data = Data((request.parameters["queue_order"] ?? "[]").utf8)
            let order = (try? JSONSerialization.jsonObject(with: data)) as? [[String: String]] ?? []
            queue = order.compactMap { wanted in
                queue.first { $0["story_hash"] as? String == wanted["story_hash"]
                    && $0["media_url"] as? String == wanted["media_url"] }
            }
        default:
            XCTFail("Unexpected request \(request.path)")
        }
    }
}

final class Test_ListenQueue: XCTestCase {
    private func item(_ hash: String, type: String = "listen", url: String? = nil) throws -> ListenQueueItem {
        try XCTUnwrap(ListenQueueItem(json: entry(hash, type: type, url: url)))
    }

    private func entry(_ hash: String, type: String = "listen", url: String? = nil) -> [String: Any] {
        ["story_hash": hash, "media_url": url ?? "/listen/story/\(hash)", "media_type": type, "media_title": hash,
         "feed_id": 42]
    }

    private func story(_ hash: String) -> [String: Any] {
        ["story_hash": hash, "story_title": hash, "story_feed_id": "42"]
    }

    private func id(_ hash: String) -> String {
        "\(hash)|/listen/story/\(hash)"
    }

    /// A queue that has loaded `entries` from `server`.
    private func loadedQueue(_ server: FakeMediaPlayerServer, entries: [[String: Any]]) -> ListenQueue {
        server.queue = entries
        let queue = ListenQueue(transport: server)
        queue.refresh()
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), server.queueIds)
        return queue
    }

    // ListenQueueTests.swift: /media_player/reorder_media_queue drops anything left out, so reordering Up Next on
    // iOS must send the whole queue with a podcast queued on the web still in its place.
    func test_reorderingListenStoriesKeepsOtherQueuedMediaInPlace() throws {
        let first = try item("1:a")
        let podcast = try item("9:pod", type: "podcast", url: "https://example.com/episode.mp3")
        let second = try item("2:b")
        let third = try item("3:c")
        let merged = ListenQueue.merging(listenOrder: [third, first, second], into: [first, podcast, second, third])
        XCTAssertEqual(merged.map(\.id), [third.id, podcast.id, first.id, second.id])
    }

    func test_queueItemsFromOtherPlatformsAreNotPlayedAsListenStories() throws {
        XCTAssertTrue(try item("1:a").isListen)
        XCTAssertFalse(try item("9:pod", type: "podcast", url: "https://example.com/episode.mp3").isListen)
        XCTAssertEqual(try item("1:a").feedId, "42")
    }

    // ListenQueueTests.swift: the server reads and replaces the whole queue on every edit, so quick edits go out one
    // at a time in the order they were made, even when the network would deliver a later one first.
    func test_quickEditsReachTheServerOneAtATimeInTheOrderTheyWereMade() {
        let server = FakeMediaPlayerServer()
        let podcast = entry("9:pod", type: "podcast", url: "https://example.com/episode.mp3")
        let queue = loadedQueue(server, entries: [entry("1:a"), podcast, entry("2:b")])

        queue.add(story: story("3:c"))
        queue.remove(storyHash: "1:a")
        queue.add(story: story("1:a"))
        queue.moveListenItems(fromOffsets: [2], toOffset: 0)
        let expected = ["9:pod|https://example.com/episode.mp3", id("1:a"), id("2:b"), id("3:c")]
        XCTAssertEqual(queue.items.map(\.id), expected)
        XCTAssertEqual(server.unanswered.count, 1)

        while !server.unanswered.isEmpty {
            XCTAssertEqual(server.unanswered.count, 1)
            server.answerNewest()
        }
        XCTAssertEqual(server.ranEdits, ["/media_player/add_to_media_queue", "/media_player/remove_from_media_queue",
                                         "/media_player/add_to_media_queue", "/media_player/reorder_media_queue"])
        XCTAssertEqual(server.queueIds, expected)
        XCTAssertEqual(queue.items.map(\.id), expected)
    }

    // ListenQueueTests.swift: an edit that fails doesn't hold back the ones after it, and once they've all been
    // answered Up Next shows what the server really has.
    func test_failedEditStillSendsTheNextAndEndsOnTheServersQueue() {
        let server = FakeMediaPlayerServer()
        let queue = loadedQueue(server, entries: [entry("1:a")])

        queue.add(story: story("2:b"))
        queue.add(story: story("3:c"))
        XCTAssertEqual(server.unanswered.count, 1)
        server.answerNewest(failing: true)
        XCTAssertEqual(server.unanswered.map(\.path), ["/media_player/add_to_media_queue"])
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), [id("1:a"), id("3:c")])

        queue.add(story: story("4:d"))
        server.answerNewest(failing: true)
        XCTAssertEqual(server.unanswered.map(\.path), ["/media_player/playback_state"])
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), [id("1:a"), id("3:c")])
    }

    // ListenQueueTests.swift: a queue read that left before an edit can't undo the edit when it arrives after it.
    func test_queueReadFromBeforeAnEditDoesNotUndoIt() {
        let server = FakeMediaPlayerServer()
        let queue = loadedQueue(server, entries: [entry("1:a")])

        queue.refresh()
        queue.add(story: story("2:b"))
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), [id("1:a"), id("2:b")])
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), [id("1:a"), id("2:b")])
    }

    // ListenQueueTests.swift: logging out forgets edits still waiting to be sent, and the previous account's answer
    // arriving afterwards doesn't bring its queue back.
    func test_resetDropsWaitingEditsAndIgnoresThePreviousAccountsAnswer() {
        let server = FakeMediaPlayerServer()
        let queue = loadedQueue(server, entries: [entry("1:a")])

        queue.add(story: story("2:b"))
        queue.add(story: story("3:c"))
        queue.reset()
        XCTAssertEqual(queue.items.map(\.id), [])
        server.answerNewest()
        XCTAssertEqual(queue.items.map(\.id), [])
        XCTAssertTrue(server.unanswered.isEmpty)
    }
}
