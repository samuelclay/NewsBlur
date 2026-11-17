import XCTest

@testable import NewsBlur

/// Runs scheduled work by hand, so count batching can be checked without waiting on real timers.
@MainActor private final class ManualScheduler {
    var now = Date(timeIntervalSince1970: 1_000_000)
    private var tasks: [(id: Int, fireDate: Date, work: () -> Void)] = []
    private var nextId = 0

    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        nextId += 1
        let id = nextId
        tasks.append((id, now.addingTimeInterval(delay), work))
        return { [weak self] in self?.tasks.removeAll { $0.id == id } }
    }

    func advance(by seconds: TimeInterval) {
        let target = now.addingTimeInterval(seconds)
        while let next = tasks.filter({ $0.fireDate <= target }).min(by: { $0.fireDate < $1.fireDate }) {
            tasks.removeAll { $0.id == next.id }
            now = next.fireDate
            next.work()
        }
        now = target
    }
}

@MainActor final class Test_RealtimeUpdates: XCTestCase {
    // node/unread_counts.coffee emits (channel, message). Handing handlers only the first argument, as Ask AI's
    // handlers expect, would drop every story:read and feed: message.
    func test_realtimeHandlersGetChannelAndMessageWhileAskAIStillGetsItsPayload() async {
        let socket = NewsBlurSocketClient(serverURLProvider: { nil })
        let userUpdate = expectation(description: "user:update arguments")
        let askAIChunk = expectation(description: "ask_ai:chunk payload")
        var arguments: [Any] = []
        var chunk: [String: Any]?
        socket.subscribeArguments(event: "user:update") { received in
            arguments = received
            userUpdate.fulfill()
        }
        socket.subscribe(event: "ask_ai:chunk") { payload in
            chunk = payload as? [String: Any]
            askAIChunk.fulfill()
        }

        socket.receive(frame: #"42["user:update","samuel","story:read:42:a1b2c3"]"#)
        socket.receive(frame: #"42["ask_ai:chunk",{"chunk":"Hello"}]"#)

        await fulfillment(of: [userUpdate, askAIChunk], timeout: SimulatorTestTiming.realWorkTimeout)
        XCTAssertEqual(arguments as? [String], ["samuel", "story:read:42:a1b2c3"])
        XCTAssertEqual(chunk?["chunk"] as? String, "Hello")
    }

    // Story hashes contain a colon, apps/analyzer/views.py joins feed ids with commas, and blurblog counts are
    // filed under social:<id>. Splitting any of these wrong flips the wrong story or refreshes the wrong feed.
    func test_userMessagesKeepWholeHashesAndEveryFeedId() {
        XCTAssertEqual(RealtimeUserMessage("story:read:42:a1b2c3"), .storyRead(hash: "42:a1b2c3"))
        XCTAssertEqual(RealtimeUserMessage("story:unread:42:a1b2c3"), .storyUnread(hash: "42:a1b2c3"))
        XCTAssertEqual(RealtimeUserMessage("story:starred:42:a1b2c3"), .starred(hash: "42:a1b2c3"))
        XCTAssertEqual(RealtimeUserMessage("feed:12,34,56"), .feedCounts(feedIds: ["12", "34", "56"]))
        XCTAssertEqual(RealtimeUserMessage("social:99"), .socialCounts(feedId: "social:99"))
        XCTAssertEqual(RealtimeUserMessage("reload:feeds"), .reloadFeeds)
        XCTAssertEqual(RealtimeUserMessage("notification:42:a1b2c3,A title"), .ignored)
    }

    // A burst of reads elsewhere must cost one request, not one per feed.
    func test_countRefreshesDueTogetherShareOneRequest() {
        let scheduler = ManualScheduler()
        var requests: [[String]] = []
        let queue = RealtimeCountRefreshQueue(now: { scheduler.now }, schedule: scheduler.schedule) { requests.append($0) }

        queue.enqueue(["12"], delay: 1)
        queue.enqueue(["34"], delay: 1.5)
        queue.enqueue(["56"], delay: 30)
        scheduler.advance(by: 1)
        XCTAssertEqual(requests, [["12", "34"]])

        scheduler.advance(by: 30)
        XCTAssertEqual(requests, [["12", "34"], ["56"]])
    }

    // A popular feed's long subscriber delay must not postpone a refresh the user's own read already asked for.
    func test_feedAskedForAgainKeepsItsEarlierTime() {
        let scheduler = ManualScheduler()
        var requests: [[String]] = []
        let queue = RealtimeCountRefreshQueue(now: { scheduler.now }, schedule: scheduler.schedule) { requests.append($0) }

        queue.enqueue(["12"], delay: 1)
        queue.enqueue(["12"], delay: 50)
        scheduler.advance(by: 1)

        XCTAssertEqual(requests, [["12"]])
        XCTAssertTrue(queue.pendingFeedIds.isEmpty)
    }

    // A reload:feeds after an OPML import can name hundreds of feeds, which must split under the URL limit.
    func test_largeRefreshSplitsIntoBoundedRequests() {
        let scheduler = ManualScheduler()
        var requests: [[String]] = []
        let queue = RealtimeCountRefreshQueue(now: { scheduler.now }, schedule: scheduler.schedule) { requests.append($0) }
        let feedIds = (1...250).map(String.init)

        queue.enqueue(feedIds, delay: 0)
        scheduler.advance(by: 0)

        XCTAssertTrue(requests.allSatisfy { $0.count <= RealtimeCountRefreshQueue.maximumFeedsPerRequest })
        XCTAssertEqual(Set(requests.flatMap { $0 }), Set(feedIds))
    }

    private func storyList(oldestFirst: Bool = false, unreadOnly: Bool = true, intelligence: Int = 0,
                           loadedLastPage: Bool = false) -> RealtimeStoryList {
        RealtimeStoryList(key: "feed:12", feedIds: ["12", "34"], oldestFirst: oldestFirst, unreadOnly: unreadOnly,
                          intelligence: intelligence, showHiddenStories: false, loadedLastPage: loadedLastPage)
    }

    // Fetching announcements the list can't use costs every client a request for nothing.
    func test_onlyAnnouncementsThatBelongAtTheListsEdgeAreFetched() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let listed: [TimeInterval] = [999_000, 998_000]
        func fetches(_ hash: String = "12:new", feedId: String = "12", timestamp: TimeInterval = 999_500,
                     list: RealtimeStoryList? = nil) -> Bool {
            RealtimeNewStories.shouldFetch(storyHash: hash, feedId: feedId, timestamp: timestamp, list: list ?? storyList(),
                                           knownHashes: ["12:old"], listedTimestamps: listed, now: now)
        }

        XCTAssertTrue(fetches())
        XCTAssertFalse(fetches(feedId: "78"), "a feed outside the open list")
        XCTAssertFalse(fetches("12:old"), "a story already listed")
        XCTAssertFalse(fetches(timestamp: 1_000_000 + 2 * 60 * 60), "dated hours ahead")
        XCTAssertFalse(fetches(timestamp: 997_000), "older than every loaded story; a later page brings it")
        XCTAssertFalse(fetches(list: storyList(oldestFirst: true)), "oldest first, before its last page loads")
        XCTAssertTrue(fetches(list: storyList(oldestFirst: true, loadedLastPage: true)))
    }

    // An unread list must not gain a story another device already read, and the stories join in the list's order.
    func test_fetchedStoriesJoinInListOrderWithoutReadOnesOrOtherFeeds() {
        let stories: [[String: Any]] = [
            ["story_hash": "12:a", "story_feed_id": 12, "story_timestamp": "100", "read_status": 0],
            ["story_hash": "34:b", "story_feed_id": 34, "story_timestamp": "300", "read_status": 0],
            ["story_hash": "12:c", "story_feed_id": 12, "story_timestamp": "200", "read_status": 1],
            ["story_hash": "78:d", "story_feed_id": 78, "story_timestamp": "400", "read_status": 0],
            ["story_hash": "12:e", "story_feed_id": 12, "story_timestamp": "250", "read_status": 0],
        ]

        let newestFirst = RealtimeNewStories.insertable(stories, list: storyList(), knownHashes: ["12:e"])
        XCTAssertEqual(newestFirst.compactMap { $0["story_hash"] as? String }, ["34:b", "12:a"])

        let everything = RealtimeNewStories.insertable(stories, list: storyList(oldestFirst: true, unreadOnly: false),
                                                       knownHashes: [])
        XCTAssertEqual(everything.compactMap { $0["story_hash"] as? String }, ["12:a", "12:c", "12:e", "34:b"])
    }

    // In Focus the pill must not promise stories the list hides.
    func test_pillCountsOnlyStoriesTheListShows() {
        let stories: [[String: Any]] = [
            ["story_hash": "12:liked", "intelligence": ["feed": 1, "author": 0, "tags": 0, "title": 0]],
            ["story_hash": "12:neutral", "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]],
            ["story_hash": "12:disliked", "intelligence": ["feed": -1, "author": 0, "tags": 0, "title": 0]],
        ]

        XCTAssertEqual(RealtimeNewStories.visibleCount(stories, list: storyList(intelligence: 1)), 1)
        XCTAssertEqual(RealtimeNewStories.visibleCount(stories, list: storyList(intelligence: 0)), 2)
    }

    // Inserted stories land in order among the loaded ones, and a story already listed isn't listed twice.
    func test_insertedStoriesTakeTheirPlaceInTheLoadedList() {
        let collection = StoriesCollection()
        let newestFirst = collection.activeOrder != "oldest"
        func story(_ hash: String, _ timestamp: Int) -> [String: Any] {
            ["story_hash": hash, "story_feed_id": 12, "story_timestamp": "\(timestamp)", "read_status": 0,
             "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]]
        }
        let loaded = [story("12:c", 300), story("12:b", 200), story("12:a", 100)]
        collection.setStories(newestFirst ? loaded : loaded.reversed())

        let inserted = collection.insertRealtimeStories([story("12:d", 250), story("12:b", 200), story("12:e", 400)])

        XCTAssertEqual(inserted, 2)
        let hashes = (collection.activeFeedStories ?? []).compactMap { ($0 as? [String: Any])?["story_hash"] as? String }
        let expected = ["12:e", "12:c", "12:d", "12:b", "12:a"]
        XCTAssertEqual(hashes, newestFirst ? expected : expected.reversed())
        XCTAssertEqual(Int(collection.storyCount), expected.count)
    }
}
