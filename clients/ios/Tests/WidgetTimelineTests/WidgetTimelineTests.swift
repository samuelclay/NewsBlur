import Foundation
import WidgetKit
import XCTest
@testable import WidgetTimeline

final class Test_WidgetTimeline: XCTestCase {
    private struct StoryEntry: TimelineEntry {
        let date: Date
        let title: String
    }

    func test_fetchedStoriesAreNotScheduledAsFutureUpdates() {
        let fetchedAt = Date(timeIntervalSince1970: 1_792_605_600)
        let timeline = WidgetTimeline.make(at: fetchedAt) {
            StoryEntry(date: $0, title: "Latest story")
        }

        XCTAssertEqual(timeline.entries.count, 1,
                       "Repeating the same fetched stories delays the next network refresh.")
        XCTAssertEqual(timeline.entries.first?.date, fetchedAt)
        XCTAssertEqual(timeline.entries.first?.title, "Latest story")
        XCTAssertEqual(timeline.policy, .after(fetchedAt.addingTimeInterval(15 * 60)),
                       "Request fresh stories after 15 minutes, including in Release builds.")
    }
}
