import XCTest

@testable import NewsBlur

final class Test_ListenQueue: XCTestCase {
    private func item(_ hash: String, type: String = "listen", url: String? = nil) throws -> ListenQueueItem {
        try XCTUnwrap(ListenQueueItem(json: ["story_hash": hash, "media_url": url ?? "/listen/story/\(hash)",
                                             "media_type": type, "media_title": hash, "feed_id": 42]))
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
}
