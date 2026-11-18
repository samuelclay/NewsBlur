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

    // Filling the gap must keep every story exactly once and in the list's order: a page that overlaps the stories
    // already listed moves the cursor past them instead of listing them again.
    func test_newestPagesFillTheGapWithoutListingAStoryTwice() {
        let listed = [story("12:e", 500), story("12:d", 400), story("12:a", 100)]
        let first = NewStoriesGapMerge.merge(page: [story("12:i", 900), story("12:h", 800)], into: listed,
                                             cursor: 0, oldestFirst: false)
        XCTAssertEqual(hashes(first.stories), ["12:i", "12:h", "12:e", "12:d", "12:a"])
        XCTAssertEqual(first.cursor, 2, "the gap sits between the newest page and the stories already listed")
        XCTAssertFalse(first.reachedEnd)

        let second = NewStoriesGapMerge.merge(page: [story("12:g", 700), story("12:e", 500), story("12:c", 300)],
                                              into: first.stories, cursor: first.cursor, oldestFirst: false)
        XCTAssertEqual(hashes(second.stories), ["12:i", "12:h", "12:g", "12:e", "12:d", "12:c", "12:a"])
        XCTAssertEqual(second.inserted, ["12:g", "12:c"])
        XCTAssertEqual(second.cursor, 6)
    }

    // A listed story read on another device drops out of an unread list's fresh pages; the cursor must still pass it,
    // or every later story would land above it, out of order.
    func test_gapCursorPassesListedStoriesThePagesNoLongerInclude() {
        let listed = [story("12:read", 500), story("12:b", 200)]
        let result = NewStoriesGapMerge.merge(page: [story("12:c", 300)], into: listed, cursor: 0, oldestFirst: false)
        XCTAssertEqual(hashes(result.stories), ["12:read", "12:c", "12:b"])
    }

    // The gap closes when a page reaches the last listed story, handing paging back to the list; an oldest-first
    // list's new stories join its end.
    func test_gapClosesWhenThePagesReachTheEndOfTheList() {
        let listed = [story("12:a", 100), story("12:b", 200)]
        let caughtUp = NewStoriesGapMerge.merge(page: [story("12:b", 200), story("12:c", 300)], into: listed,
                                                cursor: 1, oldestFirst: true)
        XCTAssertEqual(hashes(caughtUp.stories), ["12:a", "12:b", "12:c"])
        XCTAssertTrue(caughtUp.reachedEnd)

        let stillOpen = NewStoriesGapMerge.merge(page: [story("12:x", 900)], into: listed, cursor: 0, oldestFirst: false)
        XCTAssertFalse(stillOpen.reachedEnd)
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
        XCTAssertTrue(buffer.needsNewestPage(list: list), "anything unfetched loads the newest page instead")
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

    // A few stories under the cap go straight in; only an overflow loads the newest page.
    func test_fewStoriesInsertDirectly() {
        var buffer = RealtimeNewStoryBuffer()
        let list = storyList(unreadOnly: true)
        _ = buffer.announce("12:a", list: list)
        _ = buffer.addFetched([story("12:a", 100)], userProfiles: [], list: list, listedHashes: [])
        XCTAssertFalse(buffer.needsNewestPage(list: list))
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
}
