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
