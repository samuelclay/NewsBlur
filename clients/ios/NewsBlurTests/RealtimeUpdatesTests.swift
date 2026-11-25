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

    // A story the reader's classifiers hide (a disliked tag, author or title) must never arrive through the pill,
    // even at the All level or with hidden stories shown, which list hidden stories too: Sam's Android phone
    // offered two Hoodline stories his tag filters hide.
    func test_pillNeverOffersHiddenStories() {
        let stories: [[String: Any]] = [
            ["story_hash": "12:neutral", "story_feed_id": 12, "story_timestamp": "200", "read_status": 0,
             "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]],
            ["story_hash": "12:hidden-by-tag", "story_feed_id": 12, "story_timestamp": "300", "read_status": 0,
             "intelligence": ["feed": 0, "author": 0, "tags": -1, "title": 0]],
        ]
        let showingHidden = RealtimeStoryList(key: "feed:12", feedIds: ["12"], oldestFirst: false, unreadOnly: true,
                                              intelligence: -1, showHiddenStories: true, loadedLastPage: false)

        XCTAssertEqual(RealtimeNewStories.visibleCount(stories, list: storyList(intelligence: -1)), 1)
        XCTAssertEqual(RealtimeNewStories.visibleCount(stories, list: showingHidden), 1)
        let inserted = RealtimeNewStories.insertable(stories, list: showingHidden, knownHashes: [])
        XCTAssertEqual(inserted.compactMap { $0["story_hash"] as? String }, ["12:neutral"])
    }

    // Stories the pill holds go where the reader is looking, the top of a newest-first list or the end of an
    // oldest-first one, even one published before stories already listed; a story already listed isn't listed twice.
    func test_insertedStoriesJoinTheListsNewEndWhateverTheirDates() {
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
        let expected = ["12:e", "12:d", "12:c", "12:b", "12:a"]
        XCTAssertEqual(hashes, newestFirst ? expected : expected.reversed())
        XCTAssertEqual(Int(collection.storyCount), expected.count)
    }


    private func story(_ hash: String, _ timestamp: Int) -> [String: Any] {
        ["story_hash": hash, "story_feed_id": 12, "story_timestamp": "\(timestamp)", "read_status": 0,
         "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]]
    }

    private func hashes(_ stories: [[String: Any]]) -> [String] {
        stories.compactMap { $0["story_hash"] as? String }
    }

    // A list left open overnight must stop fetching once the pill holds 20, yet still count what arrives after.
    func test_pillStopsFetchingAtTheCapButKeepsCounting() {
        var buffer = RealtimeNewStoryBuffer()
        let list = storyList(unreadOnly: true)
        var fetched = 0
        for index in 0..<(RealtimeNewStories.prefetchCap + 5) where buffer.announce("12:s\(index)", list: list) {
            fetched += 1
        }
        XCTAssertEqual(fetched, RealtimeNewStories.prefetchCap)
        let pending = buffer.takePending(limit: 100)
        _ = buffer.addFetched(pending.enumerated().map { story($1, 1000 + $0) }, userProfiles: [], list: list,
                              listedHashes: [])

        XCTAssertEqual(buffer.pillCount(list: list), RealtimeNewStories.prefetchCap + 5)
        XCTAssertTrue(buffer.needsNewestPage(list: list), "anything unfetched shows the newest stories instead")
        XCTAssertFalse(buffer.announce("12:more", list: list))
    }

    // A story read elsewhere must leave the count whether it was fetched or only counted.
    func test_storiesReadElsewhereLeaveThePillCount() {
        var buffer = RealtimeNewStoryBuffer()
        let list = storyList(unreadOnly: true)
        for index in 0...RealtimeNewStories.prefetchCap { _ = buffer.announce("12:s\(index)", list: list) }
        _ = buffer.addFetched([story("12:s0", 100)], userProfiles: [], list: list, listedHashes: [])
        let before = buffer.pillCount(list: list)

        buffer.setReadState(storyHash: "12:s0", read: true, list: list)
        buffer.setReadState(storyHash: "12:s\(RealtimeNewStories.prefetchCap)", read: true, list: list)

        XCTAssertEqual(buffer.pillCount(list: list), before - 2)
    }

    // A few stories under the cap go straight in; only an overflow shows the newest stories instead.
    func test_fewStoriesInsertDirectly() {
        var buffer = RealtimeNewStoryBuffer()
        let list = storyList(unreadOnly: true)
        _ = buffer.announce("12:a", list: list)
        _ = buffer.addFetched([story("12:a", 100)], userProfiles: [], list: list, listedHashes: [])
        XCTAssertFalse(buffer.needsNewestPage(list: list))
    }

    // Past the cap a tap shows the 20 newest-dated waiting stories, fetched or only counted: a newer arrival takes the
    // place of the oldest one kept, and an older one is left out. An oldest-first list takes the oldest instead.
    func test_tapPastTheCapPicksTheNewestDatedWaitingStories() {
        let list = storyList(unreadOnly: true)
        let cap = RealtimeNewStories.prefetchCap
        var buffer = RealtimeNewStoryBuffer()
        for index in 0..<cap { _ = buffer.announce("12:f\(index)", timestamp: TimeInterval(1_000 + index), list: list) }
        _ = buffer.addFetched((0..<cap).map { story("12:f\($0)", 1_000 + $0) }, userProfiles: [], list: list,
                              listedHashes: [], requested: buffer.takePending(limit: 100))
        _ = buffer.announce("12:older", timestamp: 500, list: list)
        _ = buffer.announce("12:newer", timestamp: 2_000, list: list)

        let newest = buffer.newestWaiting(limit: cap, oldestFirst: false)
        XCTAssertEqual(newest.unfetchedHashes, ["12:newer"])
        XCTAssertEqual(Set(hashes(newest.fetched)), Set((1..<cap).map { "12:f\($0)" }), "12:f0 was the oldest kept")

        let oldest = buffer.newestWaiting(limit: cap, oldestFirst: true)
        XCTAssertEqual(oldest.unfetchedHashes, ["12:older"])
        XCTAssertFalse(hashes(oldest.fetched).contains("12:f\(cap - 1)"))
    }

    /// Announces a story and, when the buffer fetches it, lands it at once, as a fetch that answers immediately would.
    private func announceAndLand(_ buffer: inout RealtimeNewStoryBuffer, _ hash: String, _ timestamp: Int,
                                 list: RealtimeStoryList) -> Bool {
        let fetches = buffer.announce(hash, timestamp: TimeInterval(timestamp), list: list)
        landPending(&buffer, list: list, timestamps: [hash: timestamp])
        return fetches
    }

    private func landPending(_ buffer: inout RealtimeNewStoryBuffer, list: RealtimeStoryList, timestamps: [String: Int]) {
        let requested = buffer.takePending(limit: 100)
        guard !requested.isEmpty else { return }
        _ = buffer.addFetched(requested.map { story($0, timestamps[$0] ?? 0) }, userProfiles: [], list: list,
                              listedHashes: [], requested: requested)
    }

    // Sam: past the cap the pill always holds the 20 a tap shows, loaded, so the tap doesn't wait on the network. A list
    // left open hears 25 stories, each newer than the last: the 20 newest end up loaded and the 5 oldest only counted.
    func test_pastTheCapTheNewestStoriesStayLoadedAndOlderOnesAreCounted() {
        let list = storyList(unreadOnly: true)
        let cap = RealtimeNewStories.prefetchCap
        var buffer = RealtimeNewStoryBuffer()
        for index in 0..<(cap + 5) { _ = announceAndLand(&buffer, "12:s\(index)", 1_000 + index, list: list) }

        XCTAssertEqual(Set(hashes(buffer.stories)), Set((5..<(cap + 5)).map { "12:s\($0)" }))
        XCTAssertEqual(Set(buffer.unfetchedHashes), Set((0..<5).map { "12:s\($0)" }))
        XCTAssertEqual(buffer.pillCount(list: list), cap + 5)
        XCTAssertTrue(buffer.needsNewestPage(list: list))
        XCTAssertEqual(buffer.newestWaiting(limit: cap, oldestFirst: false).unfetchedHashes, [],
                       "the tap shows the loaded 20 without fetching a story")
    }

    // A story newer than the 20 held is fetched right away, and once it lands the oldest of them drops to a count.
    func test_newerArrivalPastTheCapIsFetchedAndEvictsTheOldest() {
        let list = storyList(unreadOnly: true)
        let cap = RealtimeNewStories.prefetchCap
        var buffer = RealtimeNewStoryBuffer()
        for index in 0..<cap { _ = announceAndLand(&buffer, "12:s\(index)", 1_000 + index, list: list) }

        XCTAssertTrue(buffer.announce("12:newer", timestamp: 2_000, list: list), "the newer story is fetched")
        XCTAssertEqual(buffer.stories.count, cap, "the oldest stays loaded until the newer one lands")
        landPending(&buffer, list: list, timestamps: ["12:newer": 2_000])

        XCTAssertTrue(hashes(buffer.stories).contains("12:newer"))
        XCTAssertFalse(hashes(buffer.stories).contains("12:s0"))
        XCTAssertEqual(buffer.stories.count, cap)
        XCTAssertEqual(buffer.unfetchedHashes, ["12:s0"])
        XCTAssertEqual(buffer.pillCount(list: list), cap + 1)
        XCTAssertEqual(buffer.newestWaiting(limit: cap, oldestFirst: false).unfetchedHashes, [])
    }

    // A story older than the 20 held isn't fetched, only counted.
    func test_olderArrivalPastTheCapIsOnlyCounted() {
        let list = storyList(unreadOnly: true)
        let cap = RealtimeNewStories.prefetchCap
        var buffer = RealtimeNewStoryBuffer()
        for index in 0..<cap { _ = announceAndLand(&buffer, "12:s\(index)", 1_000 + index, list: list) }

        XCTAssertFalse(buffer.announce("12:older", timestamp: 500, list: list))
        XCTAssertTrue(buffer.pendingHashes.isEmpty)
        XCTAssertEqual(Set(hashes(buffer.stories)), Set((0..<cap).map { "12:s\($0)" }))
        XCTAssertEqual(buffer.unfetchedHashes, ["12:older"])
        XCTAssertEqual(buffer.pillCount(list: list), cap + 1)
    }

    // A loaded story read on another device leaves an unread list's pill, and the newest of the counted stories is
    // fetched in its place so the tap still needs no fetch.
    func test_aLoadedStoryReadElsewhereIsRefilledFromTheCountedOnes() {
        let list = storyList(unreadOnly: true)
        let cap = RealtimeNewStories.prefetchCap
        var buffer = RealtimeNewStoryBuffer()
        for index in 0..<cap { _ = announceAndLand(&buffer, "12:s\(index)", 1_000 + index, list: list) }
        _ = buffer.announce("12:o600", timestamp: 600, list: list)
        _ = buffer.announce("12:o700", timestamp: 700, list: list)

        buffer.setReadState(storyHash: "12:s19", read: true, list: list)

        XCTAssertEqual(buffer.pendingHashes, ["12:o700"], "the newest counted story is fetched to refill")
        landPending(&buffer, list: list, timestamps: ["12:o700": 700])
        XCTAssertEqual(buffer.stories.count, cap)
        XCTAssertTrue(hashes(buffer.stories).contains("12:o700"))
        XCTAssertEqual(buffer.unfetchedHashes, ["12:o600"])
        XCTAssertEqual(buffer.newestWaiting(limit: cap, oldestFirst: false).unfetchedHashes, [])
    }

    // The tap shows the loaded newest stories at once, before the list's first page answers, and the first page joins
    // below them when it does.
    func test_tapPastTheCapShowsLoadedStoriesBeforeTheFirstPageAnswers() {
        let (controller, collection) = makeStreamController(stories: (0..<30).map { story("12:old\($0)", 100 - $0) })
        collection.feedPage = 4
        let newest = (0..<RealtimeNewStories.prefetchCap).map { story("12:new\($0)", 1_000 - $0) }
        let load = NewestStoriesLoad(fetched: newest, needsDetails: false, profiles: [], list: storyList())
        controller.newestStoriesLoad = load

        controller.completeNewestStories(load)
        XCTAssertEqual(hashes(collection.activeFeedStories as? [[String: Any]] ?? []), hashes(newest),
                       "the newest stories show without waiting for the first page")
        XCTAssertTrue(controller.pageFetching, "the list's paging waits for the first page")

        load.firstPage = ["stories": [story("12:new0", 1_000), story("12:old0", 100), story("12:page", 99)]]
        load.firstPageDone = true
        controller.completeNewestStories(load)
        XCTAssertEqual(hashes(collection.activeFeedStories as? [[String: Any]] ?? []),
                       hashes(newest) + ["12:old0", "12:page"])
        XCTAssertEqual(collection.feedPage, 1)
        XCTAssertFalse(controller.pageFetching)
        XCTAssertNil(controller.newestStoriesLoad)
    }

    // A story announced again, as the server does when a feed refetches, must count once.
    func test_repeatedAnnouncementsCountOnce() {
        let list = storyList()
        let now = Date().timeIntervalSince1970
        withNewStoriesSetting(nil) {
            let updates = RealtimeUpdates(socket: NewsBlurSocketClient(serverURLProvider: { nil }))
            for index in 0...RealtimeNewStories.prefetchCap {
                updates.receiveNewStory(storyHash: "12:s\(index)", feedId: "12", timestamp: now - Double(index),
                                        list: list, listedStories: [])
            }
            updates.receiveNewStory(storyHash: "12:s\(RealtimeNewStories.prefetchCap)", feedId: "12", timestamp: now,
                                    list: list, listedStories: [])
            updates.receiveNewStory(storyHash: "12:s0", feedId: "12", timestamp: now, list: list, listedStories: [])
            XCTAssertEqual(updates.newStoriesWaiting(for: list), RealtimeNewStories.prefetchCap + 1)
            updates.storyListDidReload()
        }
    }

    // The first scroll away from the pill starts a five-second countdown, and nothing the reader does next moves it:
    // scrolling toward the pill, stopping, or scrolling on.
    func test_firstScrollAwayTucksThePillAwayFiveSecondsLater() {
        var presence = NewStoriesPillPresence()
        XCTAssertNil(presence.scrolled(awayFromPill: false, at: 10), "scrolling toward the pill starts nothing")
        XCTAssertEqual(presence.scrolled(awayFromPill: true, at: 12), 12 + NewStoriesPillPresence.hideAfterScrollingAway)
        XCTAssertNil(presence.scrolled(awayFromPill: true, at: 13), "only the first scroll away starts the countdown")
        XCTAssertNil(presence.scrolled(awayFromPill: false, at: 14))

        XCTAssertFalse(presence.hideTimerFired(at: 16.9))
        XCTAssertTrue(presence.hideTimerFired(at: 17))
        XCTAssertTrue(presence.isHiddenByScrolling)
    }

    // A tucked-away pill stays away for three full minutes after it hides, even when the scroll that started the
    // countdown was the last one, and every later scroll restarts the wait.
    func test_tuckedAwayPillReturnsAfterThreeIdleMinutes() {
        var presence = NewStoriesPillPresence()
        let hide = NewStoriesPillPresence.hideAfterScrollingAway
        let idle = NewStoriesPillPresence.returnAfterIdle
        _ = presence.scrolled(awayFromPill: true, at: 0)
        _ = presence.hideTimerFired(at: hide)
        XCTAssertFalse(presence.shouldReturn(at: idle + 1), "three minutes from the last scroll, but not from hiding")
        XCTAssertTrue(presence.shouldReturn(at: hide + idle))

        // Scrolling toward the pill also restarts the wait, and doesn't start another countdown.
        XCTAssertNil(presence.scrolled(awayFromPill: false, at: 60))
        XCTAssertNil(presence.scrolled(awayFromPill: true, at: 60))
        XCTAssertFalse(presence.shouldReturn(at: hide + idle))
        XCTAssertTrue(presence.shouldReturn(at: 60 + idle))
    }

    // The inline row tops the list whenever stories wait, so the floating pill shows only while the row is off screen,
    // and stays away after scrolling dismissed it until the idle wait starts it over.
    func test_pillFloatsOnlyWhileTheRowIsOffScreenAndNotDismissed() {
        var presence = NewStoriesPillPresence()
        XCTAssertFalse(presence.showsPill(waiting: 3, rowOnScreen: true), "the row shows the stories already")
        XCTAssertTrue(presence.showsPill(waiting: 3, rowOnScreen: false))
        XCTAssertFalse(presence.showsPill(waiting: 0, rowOnScreen: false), "nothing waiting")

        _ = presence.scrolled(awayFromPill: true, at: 0)
        _ = presence.hideTimerFired(at: NewStoriesPillPresence.hideAfterScrollingAway)
        XCTAssertFalse(presence.showsPill(waiting: 3, rowOnScreen: false), "dismissed by scrolling")

        // The pill coming back after the idle wait starts its presence over.
        presence = NewStoriesPillPresence()
        XCTAssertTrue(presence.showsPill(waiting: 3, rowOnScreen: false))
    }

    // A Mac's mouse wheel and trackpad move the list without UIKit's tracking, dragging or decelerating flags; that
    // scrolling must count as scrolling away from the pill, or the pill never tucks away on the Mac.
    func test_scrollingWithoutTouchCountsTowardHidingThePill() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let scrollView = UIScrollView(frame: window.bounds)
        scrollView.contentSize = CGSize(width: 320, height: 4_000)
        window.addSubview(scrollView)
        window.isHidden = false
        defer { window.isHidden = true }
        var moves: [CGFloat] = []
        let watch = NewStoriesPillScrollWatch(scrollView: scrollView, filter: NewStoriesPillScrollFilter(contentSize: .zero),
                                              isListMovingItself: { false }, onReaderScroll: { moves.append($0) },
                                              onLost: {})

        scrollView.contentOffset.y = 40
        scrollView.contentOffset.y = 100
        XCTAssertEqual(moves, [40, 60])

        // The pill code's own scroll to the top isn't the reader's.
        watch.listScrollsItself(at: CACurrentMediaTime())
        scrollView.contentOffset.y = 0
        XCTAssertEqual(moves, [40, 60])
        watch.stop()
    }

    // Reloads, lazy layout and the pill's own scrolls move the list too; counting them would hide the pill while the
    // reader sits still.
    func test_listsOwnMovesDontCountAsScrolling() {
        var filter = NewStoriesPillScrollFilter(contentSize: CGSize(width: 320, height: 4_000))
        XCTAssertEqual(filter.readerScroll(from: 0, to: 30, contentSize: CGSize(width: 320, height: 4_000), at: 10), 30)
        XCTAssertNil(filter.readerScroll(from: 30, to: 90, contentSize: CGSize(width: 320, height: 4_600), at: 10.1),
                     "a move that comes with a new content size is layout")
        XCTAssertEqual(filter.readerScroll(from: 90, to: 120, contentSize: CGSize(width: 320, height: 4_600), at: 10.2), 30)

        filter.listScrollsItself(at: 20)
        XCTAssertNil(filter.readerScroll(from: 120, to: 0, contentSize: CGSize(width: 320, height: 4_600), at: 20.3))
        XCTAssertEqual(filter.readerScroll(from: 0, to: 25, contentSize: CGSize(width: 320, height: 4_600),
                                           at: 20 + NewStoriesPillScrollFilter.ownScrollGrace + 0.01), 25)
    }

    private func withNewStoriesSetting(_ enabled: Bool?, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: RealtimeNewStories.settingKey)
        if let enabled { defaults.set(enabled, forKey: RealtimeNewStories.settingKey) }
        else { defaults.removeObject(forKey: RealtimeNewStories.settingKey) }
        defer { defaults.set(previous, forKey: RealtimeNewStories.settingKey) }
        body()
    }

    // With "Show new stories as they arrive" off, announcements must not be held for the pill or fetched; the
    // setting is on unless turned off.
    func test_newStoriesSettingOffIgnoresAnnouncements() {
        let list = storyList()
        let now = Date().timeIntervalSince1970
        withNewStoriesSetting(false) {
            let updates = RealtimeUpdates(socket: NewsBlurSocketClient(serverURLProvider: { nil }))
            updates.receiveNewStory(storyHash: "12:off", feedId: "12", timestamp: now, list: list, listedStories: [])
            XCTAssertEqual(updates.newStoriesWaiting(for: list), 0)
            XCTAssertFalse(updates.isNewStoryFetchScheduled)
        }
        withNewStoriesSetting(nil) {
            let updates = RealtimeUpdates(socket: NewsBlurSocketClient(serverURLProvider: { nil }))
            updates.receiveNewStory(storyHash: "12:on", feedId: "12", timestamp: now, list: list, listedStories: [])
            XCTAssertEqual(updates.newStoriesWaiting(for: list), 1)
            XCTAssertTrue(updates.isNewStoryFetchScheduled)
            updates.storyListDidReload()
        }
    }

    // Turning the setting off while stories wait must drop them and the fetch, not leave a pill to come back.
    func test_turningNewStoriesOffDropsWhatThePillHeld() {
        let list = storyList()
        withNewStoriesSetting(nil) {
            let updates = RealtimeUpdates(socket: NewsBlurSocketClient(serverURLProvider: { nil }))
            updates.receiveNewStory(storyHash: "12:waiting", feedId: "12", timestamp: Date().timeIntervalSince1970,
                                    list: list, listedStories: [])
            UserDefaults.standard.set(false, forKey: RealtimeNewStories.settingKey)
            updates.newStoriesSettingDidChange()
            XCTAssertEqual(updates.newStoriesWaiting(for: list), 0)
            XCTAssertFalse(updates.isNewStoryFetchScheduled)
        }
    }


    // /reader/river_stories?h= answers with a placeholder unread state. A story read on another device while it waited
    // to be fetched, or while the fetch was on its way, must not come back as unread: an unread list doesn't count it,
    // and a list of every story gets it as read.
    func test_storyReadElsewhereBeforeItsFetchLandsIsNotOfferedAsUnread() {
        let unreadList = storyList(unreadOnly: true)
        var buffer = RealtimeNewStoryBuffer()
        _ = buffer.announce("12:in-flight", list: unreadList)
        _ = buffer.announce("12:pending", list: unreadList)
        let firstFetch = buffer.takePending(limit: 1)
        buffer.setReadState(storyHash: "12:in-flight", read: true, list: unreadList)
        buffer.setReadState(storyHash: "12:pending", read: true, list: unreadList)
        _ = buffer.addFetched([story("12:in-flight", 100)], userProfiles: [], list: unreadList, listedHashes: [],
                              requested: firstFetch)
        let secondFetch = buffer.takePending(limit: 1)
        _ = buffer.addFetched([story("12:pending", 200)], userProfiles: [], list: unreadList, listedHashes: [],
                              requested: secondFetch)
        XCTAssertEqual(buffer.pillCount(list: unreadList), 0)

        let everyStory = storyList(unreadOnly: false)
        var all = RealtimeNewStoryBuffer()
        _ = all.announce("12:a", list: everyStory)
        let fetch = all.takePending(limit: 1)
        all.setReadState(storyHash: "12:a", read: true, list: everyStory)
        _ = all.addFetched([story("12:a", 100)], userProfiles: [], list: everyStory, listedHashes: [], requested: fetch)
        XCTAssertEqual(all.stories.first?["read_status"] as? Int, 1)
    }

    private func makeStreamController(stories: [[String: Any]]) -> (NewStoriesStreamTestController, StoriesCollection) {
        let app = NewsBlurAppDelegate()
        app.selectedIntelligence = 0
        app.recentlyReadStories = NSMutableDictionary()
        let collection = StoriesCollection()
        collection.appDelegate = app
        collection.setStories(stories)
        app.storiesCollection = collection
        let controller = NewStoriesStreamTestController()
        controller.appDelegate = app
        controller.storiesCollection = collection
        return (controller, collection)
    }

    // Past the cap a newest-first list shows exactly the newest waiting stories, as if it had just opened: everything
    // loaded before is dropped, and the list's first page follows without the stories already shown.
    func test_tapPastTheCapShowsTheNewestStoriesAndPagesFromTheFirstPage() {
        let (controller, collection) = makeStreamController(stories: (0..<30).map { story("12:old\($0)", 100 - $0) })
        collection.feedPage = 4
        let newest = (0..<RealtimeNewStories.prefetchCap).map { story("12:new\($0)", 1_000 - $0) }
        let firstPage: [String: Any] = ["stories": [story("12:new0", 1_000), story("12:new1", 999), story("12:old0", 100),
                                                    story("12:page", 99)]]

        controller.replaceWithNewestStories(newest, firstPage: firstPage, profiles: [])

        XCTAssertEqual(hashes(collection.activeFeedStories as? [[String: Any]] ?? []),
                       hashes(newest) + ["12:old0", "12:page"])
        XCTAssertEqual(collection.feedPage, 1, "the list pages on from its second page")
        XCTAssertFalse(controller.pageFinished)
    }

    // A tap's stories load after the scroll to the top. If the reader opens another list meanwhile, which drops the
    // load as resetFeedDetail does, they must not land in the new list or move its paging.
    func test_newestStoriesForAListTheReaderLeftLandNowhere() {
        let (controller, collection) = makeStreamController(stories: [story("12:b", 200), story("12:a", 100)])
        collection.feedPage = 3
        let load = NewestStoriesLoad(fetched: [story("12:c", 300)], needsDetails: false, profiles: [], list: storyList())
        load.firstPageDone = true
        controller.newestStoriesLoad = load
        controller.cancelNewestStories()

        controller.completeNewestStories(load)
        XCTAssertEqual(hashes(collection.activeFeedStories as? [[String: Any]] ?? []), ["12:b", "12:a"])
        XCTAssertEqual(collection.feedPage, 3)

        controller.newestStoriesLoad = load
        controller.completeNewestStories(load)
        XCTAssertEqual(hashes(collection.activeFeedStories as? [[String: Any]] ?? []), ["12:c"],
                       "the list the reader is still in shows them")
    }

    // A folder opened while feed 2 had no unread stories leaves feed 2 out of the folder's feed list, yet the pill takes
    // feed 2's new stories. The list's fresh paging after a tap past the cap must ask for feed 2 too.
    func test_pagingAfterATapPastTheCapAsksForEveryFeedThePillTakesStoriesFrom() throws {
        let (controller, collection) = makeStreamController(stories: [story("12:a", 100)])
        let app = try XCTUnwrap(controller.appDelegate)
        app.dictFeeds = NSMutableDictionary(dictionary: ["1": ["id": 1, "active": 1], "2": ["id": 2, "active": 1]])
        app.dictFolders = ["Tech": [1, 2]]
        collection.isRiverView = true
        collection.activeFolder = "Tech"
        collection.activeFolderFeeds = [1]

        controller.showNewestStories(fetched: [story("1:a", 200)], unfetchedHashes: [], profiles: [],
                                     list: storyList())

        let url = try XCTUnwrap(controller.requestedURLs.first)
        XCTAssertTrue(url.contains("f=1&f=2"), url)
    }
}

/// RealtimeUpdatesTests.swift records the list's page requests instead of sending them.
@MainActor private final class NewStoriesStreamTestController: FeedDetailViewController {
    var requestedURLs: [String] = []
    override var isLegacyTable: Bool { true }
    override func reloadTable() {}

    override func newestStoriesRequestURL(forPage page: Int) -> String! {
        requestedURLs.append(super.newestStoriesRequestURL(forPage: page) ?? "")
        return nil
    }
}
