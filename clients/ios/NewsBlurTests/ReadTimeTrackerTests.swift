import XCTest

@testable import NewsBlur

final class ReadTimeTrackerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ReadTimeTracker.shared.resetForTesting()
    }

    override func tearDown() {
        ReadTimeTracker.shared.resetForTesting()
        super.tearDown()
    }

    func test_tickForTestingAccumulatesReadTimeForTrackedStory() {
        let tracker = ReadTimeTracker.shared

        tracker.startTracking(storyHash: "story:1")
        tracker.tickForTesting()

        XCTAssertEqual(tracker.getAndResetReadTime(storyHash: "story:1"), 1)
    }

    func test_flushReadTimesRestoresQueuedTimesAfterFailure() throws {
        let tracker = ReadTimeTracker.shared

        tracker.queueReadTime(storyHash: "story:1", seconds: 5)
        tracker.postReadTimesHandler = { _, _, _, failure in
            failure()
        }

        tracker.flushReadTimes()

        let json = try XCTUnwrap(tracker.consumeQueuedReadTimesJSON())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Int])

        XCTAssertEqual(object["story:1"], 5)
    }
}
