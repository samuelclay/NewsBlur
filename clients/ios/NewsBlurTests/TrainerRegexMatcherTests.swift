import XCTest

@testable import NewsBlur

/// TrainerRegexMatcherTests.swift checks that a reader's regex can't freeze the trainer or a story header by
/// backtracking for minutes on story text it doesn't match.
@MainActor final class Test_TrainerRegexMatcher: XCTestCase {
    /// (a+)+$ tries every way to split a run of a's before giving up, so this text would take years unbounded.
    private let catastrophicPattern = "(a+)+$"
    private let longNonMatchingText = "<p>" + String(repeating: "a", count: 20_000) + "!</p>"

    func test_catastrophicPatternStopsWithinItsBudgetInsteadOfGuessing() {
        let started = ProcessInfo.processInfo.systemUptime
        let outcome = TrainerRegexMatcher.outcome(of: catastrophicPattern, in: longNonMatchingText,
                                                  budget: TrainerRegexMatcher.typingBudget)
        let elapsed = ProcessInfo.processInfo.systemUptime - started

        XCTAssertEqual(outcome, .timedOut, "The trainer says it couldn't check rather than reporting no match")
        // The search checks its deadline every fraction of a millisecond. The margin only absorbs CI runner stalls.
        XCTAssertLessThan(elapsed, TrainerRegexMatcher.typingBudget + SimulatorTestTiming.realWorkTimeout)
    }

    func test_typedPatternIsSearchedOffTheMainThread() async {
        let started = ProcessInfo.processInfo.systemUptime
        let outcome = await TrainerRegexMatcher.outcomeOffMainThread(of: catastrophicPattern, in: longNonMatchingText)
        let elapsed = ProcessInfo.processInfo.systemUptime - started

        XCTAssertEqual(outcome, .timedOut)
        XCTAssertLessThan(elapsed, TrainerRegexMatcher.typingBudget + SimulatorTestTiming.realWorkTimeout)
    }

    func test_ordinaryPatternsStillMatchCaseInsensitively() {
        let story = "<p>Swift 6.2 ships with stricter concurrency checking.</p>"
        let budget = TrainerRegexMatcher.drawingBudget
        XCTAssertEqual(TrainerRegexMatcher.outcome(of: "\\bswift\\b", in: story, budget: budget), .matches)
        XCTAssertEqual(TrainerRegexMatcher.outcome(of: "kotlin|java", in: story, budget: budget), .noMatch)
        XCTAssertEqual(TrainerRegexMatcher.outcome(of: catastrophicPattern, in: "aaaa", budget: budget), .matches)
        XCTAssertNil(TrainerRegexMatcher.outcome(of: "(unclosed", in: story, budget: budget), "An invalid pattern has no outcome")
    }

    func test_storyHeaderMatchesGiveUpWithinTheirBudget() throws {
        let regex = try NSRegularExpression(pattern: catastrophicPattern, options: [.caseInsensitive])
        let title = String(repeating: "a", count: 5_000) + "!"
        let started = ProcessInfo.processInfo.systemUptime
        XCTAssertNil(TrainerRegexMatcher.matches(of: regex, in: title, budget: TrainerRegexMatcher.drawingBudget),
                     "StoryDetailObjCViewController.m leaves the title unmarked")
        XCTAssertNil(TrainerRegexMatcher.firstMatch(of: regex, in: title, budget: TrainerRegexMatcher.drawingBudget))
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started,
                          2 * TrainerRegexMatcher.drawingBudget + SimulatorTestTiming.realWorkTimeout)

        let words = try NSRegularExpression(pattern: "\\bswift\\b", options: [.caseInsensitive])
        let headline = "Swift on the server, Swift on the watch"
        let found = TrainerRegexMatcher.matches(of: words, in: headline, budget: TrainerRegexMatcher.drawingBudget)
        XCTAssertEqual(found?.map(\.range), [NSRange(location: 0, length: 5), NSRange(location: 21, length: 5)])
        XCTAssertEqual(TrainerRegexMatcher.firstMatch(of: words, in: headline, budget: TrainerRegexMatcher.drawingBudget)?.range,
                       NSRange(location: 0, length: 5))
    }
}
