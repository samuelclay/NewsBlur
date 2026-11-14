import Foundation
import XCTest
@testable import FeedSubscriptionRequest

final class Test_FeedSubscriptionRequest: XCTestCase {
    func test_folderPickerExcludesNavigationItemsAndDefaultsToTopLevel() {
        let folders = ["discover_sites", "daily_briefing", "everything", "Tech", "Tech ▸ Swift", "saved_stories", "river_global"]
        XCTAssertEqual(FeedSubscriptionRequest.selectableFolders(folders), ["everything", "Tech", "Tech ▸ Swift"])
        XCTAssertEqual(FeedSubscriptionRequest.selectableFolders([]), ["everything"])
    }

    func test_selectedFolderAndNewFolderPreserveSpecialCharacters() throws {
        let request = try FeedSubscriptionRequest.make(
            url: XCTUnwrap(URL(string: "https://example.com/rss")),
            host: "https://newsblur.com", token: "secret",
            folder: "Science & Tech", newFolder: "AI + ML")
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertEqual(body, "url=https%3A%2F%2Fexample.com%2Frss&folder=Science%20%26%20Tech&new_folder=AI%20%2B%20ML")
    }

    func test_formPreservesFeedQueryParameters() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/feed.xml?token=a+b=c&category=science#latest"))
        let request = try FeedSubscriptionRequest.make(url: url, host: "https://newsblur.com/", token: "secret")
        XCTAssertEqual(request.url?.absoluteString, "https://newsblur.com/api/add_url/secret")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertEqual(body, "url=https%3A%2F%2Fexample.com%2Ffeed.xml%3Ftoken%3Da%2Bb%3Dc%26category%3Dscience%23latest&folder=")
        let fields = body.components(separatedBy: "&")
        XCTAssertEqual(String(fields[0].dropFirst(4)).removingPercentEncoding, url.absoluteString)
        XCTAssertEqual(fields[1], "folder=", "The API requires an explicit empty folder to subscribe at the top level.")
    }

    func test_customHostPathAndTokenArePreserved() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/rss"))
        let request = try FeedSubscriptionRequest.make(url: url, host: "https://reader.example.com/newsblur/", token: "a/b+c")
        XCTAssertEqual(request.url?.absoluteString, "https://reader.example.com/newsblur/api/add_url/a%2Fb%2Bc")
    }

    func test_remoteURLAcceptsSafariURLAndPlainText() throws {
        let address = "https://ngrislain.github.io/feed.xml"
        XCTAssertEqual(FeedSubscriptionRequest.remoteURL(URL(string: address))?.absoluteString, address)
        XCTAssertEqual(FeedSubscriptionRequest.remoteURL("  \(address)\n")?.absoluteString, address)
        XCTAssertNotNil(FeedSubscriptionRequest.remoteURL("http://example.com/rss"))
    }

    func test_remoteURLRejectsFilesScriptsAndUnrelatedText() {
        for value in ["file:///tmp/feed.xml", "javascript:alert(1)", "newsblur://feed/1", "/feed.xml", "some shared text", "https://example.com/a b", "https://user:pass@example.com/feed"] {
            XCTAssertNil(FeedSubscriptionRequest.remoteURL(value), value)
        }
    }

    func test_missingCredentialsDoNotCreateRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/feed"))
        XCTAssertThrowsError(try FeedSubscriptionRequest.make(url: url, host: "https://newsblur.com", token: ""))
        XCTAssertThrowsError(try FeedSubscriptionRequest.make(url: url, host: "file:///tmp", token: "secret"))
    }

    func test_wrappedAPISuccessReturnsFeedID() throws {
        let response = Data("({\"code\":1,\"message\":\"OK\",\"usersub\":42})".utf8)
        XCTAssertEqual(try FeedSubscriptionRequest.feedID(data: response, statusCode: 200), "42")
    }

    func test_plainJSONSuccessReturnsFeedID() throws {
        let response = Data("{\"code\":1,\"usersub\":\"42\"}".utf8)
        XCTAssertEqual(try FeedSubscriptionRequest.feedID(data: response, statusCode: 200), "42")
    }

    func test_APIErrorRetainsUsefulMessage() {
        let response = Data("({\"code\":-1,\"message\":\"This site does not have an RSS feed.\",\"usersub\":null})".utf8)
        XCTAssertThrowsError(try FeedSubscriptionRequest.feedID(data: response, statusCode: 200)) { error in
            XCTAssertEqual(error.localizedDescription, "This site does not have an RSS feed.")
        }
    }

    func test_invalidResponsesNeverConfirmSubscription() {
        for response in ["", "<html>Sign in</html>", "({\"code\":1,\"usersub\":null})", "({\"code\":1,\"usersub\":0})", "({\"code\":0,\"usersub\":42})", "({\"code\":1,\"usersub\":\"invalid\"})"] {
            XCTAssertThrowsError(try FeedSubscriptionRequest.feedID(data: Data(response.utf8), statusCode: 200), response)
        }
    }

    func test_HTTPFailureNeverConfirmsSubscription() {
        let response = Data("({\"code\":1,\"usersub\":42})".utf8)
        for status in [302, 401, 403, 429, 500] {
            XCTAssertThrowsError(try FeedSubscriptionRequest.feedID(data: response, statusCode: status))
        }
    }
}
