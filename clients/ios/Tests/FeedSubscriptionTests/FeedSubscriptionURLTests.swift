import Foundation
import XCTest
@testable import FeedSubscriptionURLs

final class Test_FeedSubscriptionURL: XCTestCase {
    func test_preservesHTTPSAndFeedQueryParameters() {
        for value in ["feed:https://ngrislain.github.io/feed.xml", "feeds://ngrislain.github.io/feed.xml"] {
            XCTAssertEqual(FeedSubscriptionURL.parse(URL(string: value)!)?.absoluteString,
                           "https://ngrislain.github.io/feed.xml")
        }
        XCTAssertEqual(FeedSubscriptionURL.parse(URL(string: "feed:http://example.com/rss?a=1&b=2")!)?.absoluteString,
                       "http://example.com/rss?a=1&b=2")
        XCTAssertEqual(FeedSubscriptionURL.parse(URL(string: "feed://example.com/rss")!)?.absoluteString,
                       "http://example.com/rss")
    }

    func test_nestedWebSchemeAfterFeedSlashesPreservesOriginalURL() {
        for webURL in ["http://example.com/rss?a=1&b=2", "https://ngrislain.github.io/feed.xml"] {
            for prefix in ["feed://", "feeds://"] {
                XCTAssertEqual(FeedSubscriptionURL.parse(URL(string: prefix + webURL)!)?.absoluteString, webURL)
            }
        }
    }

    func test_decodesSubscriptionURLExactlyOnce() {
        var components = URLComponents(string: "newsblur://subscribe")!
        let feed = "https://example.com/rss?name=one%20two&filter=a+b"
        components.queryItems = [URLQueryItem(name: "url", value: feed)]
        XCTAssertEqual(FeedSubscriptionURL.parse(components.url!)?.absoluteString, feed)
    }

    func test_rejectsUnrelatedAndUnsafeLinks() {
        for value in ["https://example.com/rss", "newsblur://other?url=https://example.com", "newsblur://subscribe",
                      "feed:file:///tmp/rss.xml", "feed:javascript:alert(1)", "feed:https:///rss.xml",
                      "feeds://user:password@example.com/rss", "newsblur://subscribe?url=file:///tmp/rss.xml"] {
            XCTAssertNil(FeedSubscriptionURL.parse(URL(string: value)!), value)
        }
    }

    func test_requiresSuccessfulResponseAndValidFeed() {
        XCTAssertEqual(FeedSubscriptionURL.feedID(in: ["code": 1, "feed": ["id": 123]]), "123")
        XCTAssertEqual(FeedSubscriptionURL.feedID(in: ["code": 1, "feed": ["id": "123"]]), "123")
        XCTAssertNil(FeedSubscriptionURL.feedID(in: ["code": 0, "feed": ["id": "123"]]))
        for value: [String: Any] in [["code": -1, "feed": ["id": 123]], ["feed": ["id": 123]],
                                     ["code": 1], ["code": 1, "feed": ["id": 0]]] {
            XCTAssertNil(FeedSubscriptionURL.feedID(in: value))
        }
    }
}
