import Foundation

// SimulatorTestTiming.swift sizes waits on work a test does not schedule itself: real WKWebView navigation,
// font loading and layout, and production background queues. WebKit launches its WebContent and GPU processes
// on demand, and on a loaded simulator one launch alone has taken 18 seconds on GitHub's runners and 52 seconds
// locally. A wait on that work uses this budget instead of a few seconds; a passing test still continues as soon
// as its condition holds, so the budget only costs time when the test is about to fail anyway.
enum SimulatorTestTiming {
    static let realWorkTimeout: TimeInterval = 60
}
