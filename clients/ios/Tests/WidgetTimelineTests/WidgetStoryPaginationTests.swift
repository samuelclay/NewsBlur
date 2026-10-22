import XCTest
@testable import WidgetTimeline

final class Test_WidgetStoryPagination: XCTestCase {
    private struct Story: Identifiable {
        let id: Int
    }

    func test_fullyHiddenFirstPageDoesNotReportNoUnreadStories() {
        var pages = WidgetStoryPagination<Story>(limit: 6)
        XCTAssertEqual(pages.append([], hiddenCount: 6), .nextPage)
        XCTAssertEqual(pages.page, 2)
        XCTAssertEqual(pages.append((1...6).map { Story(id: $0) }, hiddenCount: 0), .complete)
        XCTAssertEqual(pages.stories.map(\.id), Array(1...6))
    }

    func test_partiallyHiddenPagesFillTheWidgetInNewestOrder() {
        var pages = WidgetStoryPagination<Story>(limit: 6)
        XCTAssertEqual(pages.append([Story(id: 1)], hiddenCount: 5), .nextPage)
        XCTAssertEqual(pages.append((2...6).map { Story(id: $0) }, hiddenCount: 1), .complete)
        XCTAssertEqual(pages.stories.map(\.id), Array(1...6))
    }

    func test_fullHiddenPagesStopAtBudgetWithoutClaimingTheRiverIsEmpty() {
        var pages = WidgetStoryPagination<Story>(limit: 6, maximumPages: 2)
        XCTAssertEqual(pages.append([], hiddenCount: 6), .nextPage)
        XCTAssertEqual(pages.append([], hiddenCount: 6), .pageLimit)
        XCTAssertEqual(pages.page, 2)
        XCTAssertEqual(pages.resolvedStories(cached: [Story(id: 99)], reachedEnd: false).map(\.id), [99])
    }

    func test_shortPageConfirmsTheEndOfTheRiver() {
        var pages = WidgetStoryPagination<Story>(limit: 6)
        XCTAssertEqual(pages.append([], hiddenCount: 0), .complete)
        XCTAssertTrue(pages.stories.isEmpty)
        XCTAssertTrue(pages.resolvedStories(cached: [Story(id: 99)], reachedEnd: true).isEmpty)
    }

    func test_laterPageFailureKeepsFreshPartialResults() {
        var pages = WidgetStoryPagination<Story>(limit: 6)
        XCTAssertEqual(pages.append([Story(id: 1)], hiddenCount: 5), .nextPage)
        XCTAssertEqual(pages.resolvedStories(cached: [Story(id: 99)], reachedEnd: false).map(\.id), [1])
    }

    func test_newArrivalsBetweenPagesDoNotDuplicateStories() {
        var pages = WidgetStoryPagination<Story>(limit: 6)
        XCTAssertEqual(pages.append([Story(id: 1)], hiddenCount: 5), .nextPage)
        XCTAssertEqual(pages.append((1...6).map { Story(id: $0) }, hiddenCount: 0), .complete)
        XCTAssertEqual(pages.stories.map(\.id), Array(1...6))
    }
}
